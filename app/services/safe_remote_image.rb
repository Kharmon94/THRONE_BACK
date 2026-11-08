require "ipaddr"
require "net/http"
require "resolv"
require "stringio"

# Downloads a remote image for Active Storage while blocking common SSRF targets.
#
# Hardening:
# - Only http/https, no userinfo, no redirects.
# - The hostname is resolved once; every resolved address must be public, and the
#   connection is pinned to that vetted address (Net::HTTP#ipaddr=) so a second
#   DNS lookup cannot rebind to an internal address. TLS still verifies the
#   certificate against the original hostname (SNI/verify use uri.host).
# - The body is streamed and aborted as soon as it exceeds MAX_BYTES.
# - Only raster formats are accepted (SVG is rejected: it can carry script), and
#   the bytes must match the image signature, not just the Content-Type header.
class SafeRemoteImage
  ALLOWED_SCHEMES = %w[http https].freeze
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/gif image/webp image/jpg].freeze
  MAX_BYTES = 10.megabytes
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  class UnsafeUrlError < StandardError; end

  def self.open(url)
    new(url).open
  end

  def initialize(url)
    @raw_url = url.to_s.strip
  end

  def open
    uri = parse_uri!
    address = resolve_public_address!(uri)
    body, content_type = fetch!(uri, address)
    raise UnsafeUrlError, "Empty response" if body.blank?
    raise UnsafeUrlError, "Unsupported content type" unless allowed_content_type?(content_type)

    sniffed = sniff_type(body)
    raise UnsafeUrlError, "File is not a supported image" if sniffed.nil?

    io = StringIO.new(body)
    io.set_encoding(Encoding::BINARY)
    [io, filename_for(uri, sniffed)]
  end

  private

  def parse_uri!
    raise UnsafeUrlError, "URL is blank" if @raw_url.blank?
    raise UnsafeUrlError, "URL is too long" if @raw_url.length > 2048

    uri = URI.parse(@raw_url)
    raise UnsafeUrlError, "Unsupported scheme" unless ALLOWED_SCHEMES.include?(uri.scheme&.downcase)
    raise UnsafeUrlError, "Host required" if uri.host.blank?
    raise UnsafeUrlError, "Userinfo not allowed" if uri.userinfo.present?

    uri
  rescue URI::InvalidURIError
    raise UnsafeUrlError, "Invalid URL"
  end

  # Resolves once and returns the address to connect to. All addresses must be
  # public; any private/loopback/link-local/reserved answer rejects the URL.
  def resolve_public_address!(uri)
    host = uri.host.downcase.delete_prefix("[").delete_suffix("]")
    raise UnsafeUrlError, "Blocked host" if blocked_hostname?(host)

    addresses = literal_ip?(host) ? [host] : Resolv.getaddresses(host)
    raise UnsafeUrlError, "Host could not be resolved" if addresses.empty?

    addresses.each do |addr|
      raise UnsafeUrlError, "Blocked address" if private_or_local_ip?(addr)
    end
    addresses.first
  rescue Resolv::ResolvError
    raise UnsafeUrlError, "Host could not be resolved"
  end

  def literal_ip?(host)
    IPAddr.new(host)
    true
  rescue IPAddr::InvalidAddressError
    false
  end

  def blocked_hostname?(host)
    host == "localhost" ||
      host.end_with?(".localhost") ||
      host.end_with?(".local") ||
      host.end_with?(".internal") ||
      host == "metadata.google.internal" ||
      host == "metadata"
  end

  BLOCKED_RANGES = %w[
    0.0.0.0/8 100.64.0.0/10 169.254.0.0/16 192.0.0.0/24 192.0.2.0/24
    198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 fc00::/7 fe80::/10 ff00::/8
  ].map { |cidr| IPAddr.new(cidr) }.freeze

  def private_or_local_ip?(addr)
    ip = IPAddr.new(addr)
    if ip.ipv6? && ip.ipv4_mapped?
      return private_or_local_ip?(ip.native.to_s)
    end

    ip.loopback? ||
      ip.link_local? ||
      ip.private? ||
      BLOCKED_RANGES.any? { |range| range.family == ip.family && range.include?(ip) }
  rescue IPAddr::InvalidAddressError
    true
  end

  def fetch!(uri, address)
    # nil proxy: never route through an env-configured proxy (would bypass IP pinning).
    http = Net::HTTP.new(uri.host, uri.port, nil)
    http.ipaddr = address if http.respond_to?(:ipaddr=)
    http.use_ssl = uri.scheme.downcase == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?

    request = Net::HTTP::Get.new(uri)
    request["Accept"] = ALLOWED_CONTENT_TYPES.join(", ")
    body = nil
    response = http.request(request) do |res|
      next unless res.is_a?(Net::HTTPSuccess)

      declared = res["content-length"].to_i
      raise UnsafeUrlError, "Image too large" if declared > MAX_BYTES

      buffer = +""
      buffer.force_encoding(Encoding::BINARY)
      res.read_body do |chunk|
        buffer << chunk
        raise UnsafeUrlError, "Image too large" if buffer.bytesize > MAX_BYTES
      end
      body = buffer
    end

    # Do not follow redirects — they can point at internal addresses (SSRF).
    raise UnsafeUrlError, "Redirects are not allowed" if response.is_a?(Net::HTTPRedirection)
    raise UnsafeUrlError, "Download failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    [body, response["content-type"].to_s.split(";").first&.strip]
  end

  def allowed_content_type?(content_type)
    content_type.present? && ALLOWED_CONTENT_TYPES.include?(content_type.downcase)
  end

  # Returns the real image type from magic bytes, or nil.
  def sniff_type(body)
    head = body.byteslice(0, 12).to_s.b
    return "image/png" if head.start_with?("\x89PNG\r\n\x1A\n".b)
    return "image/jpeg" if head.start_with?("\xFF\xD8\xFF".b)
    return "image/gif" if head.start_with?("GIF87a".b) || head.start_with?("GIF89a".b)
    return "image/webp" if head.start_with?("RIFF".b) && head.byteslice(8, 4) == "WEBP".b

    nil
  end

  def filename_for(uri, content_type)
    ext = case content_type
          when "image/png" then "png"
          when "image/gif" then "gif"
          when "image/webp" then "webp"
          else "jpg"
          end
    base = File.basename(uri.path.to_s, ".*").gsub(/[^A-Za-z0-9_-]/, "")[0, 60]
    "#{base.presence || 'image'}.#{ext}"
  end
end
