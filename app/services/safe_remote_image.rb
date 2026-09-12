require "ipaddr"
require "net/http"
require "resolv"
require "stringio"

# Downloads a remote image for Active Storage while blocking common SSRF targets.
class SafeRemoteImage
  ALLOWED_SCHEMES = %w[http https].freeze
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/png image/gif image/webp image/svg+xml image/jpg
  ].freeze
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
    validate_host!(uri)
    body, content_type = fetch!(uri)
    raise UnsafeUrlError, "Empty response" if body.blank?
    raise UnsafeUrlError, "Unsupported content type" unless allowed_content_type?(content_type)

    io = StringIO.new(body)
    io.set_encoding(Encoding::BINARY)
    [io, filename_for(uri, content_type)]
  end

  private

  def parse_uri!
    raise UnsafeUrlError, "URL is blank" if @raw_url.blank?

    uri = URI.parse(@raw_url)
    raise UnsafeUrlError, "Unsupported scheme" unless ALLOWED_SCHEMES.include?(uri.scheme)
    raise UnsafeUrlError, "Host required" if uri.host.blank?
    raise UnsafeUrlError, "Userinfo not allowed" if uri.userinfo.present?

    uri
  rescue URI::InvalidURIError
    raise UnsafeUrlError, "Invalid URL"
  end

  def validate_host!(uri)
    host = uri.host.downcase
    raise UnsafeUrlError, "Blocked host" if blocked_hostname?(host)

    Resolv.getaddresses(host).each do |addr|
      raise UnsafeUrlError, "Blocked address" if private_or_local_ip?(addr)
    end
  rescue Resolv::ResolvError
    raise UnsafeUrlError, "Host could not be resolved"
  end

  def blocked_hostname?(host)
    host == "localhost" ||
      host.end_with?(".localhost") ||
      host.end_with?(".local") ||
      host == "metadata.google.internal" ||
      host == "metadata"
  end

  def private_or_local_ip?(addr)
    ip = IPAddr.new(addr)
    ip.loopback? ||
      ip.link_local? ||
      ip.private? ||
      (ip.ipv4? && IPAddr.new("0.0.0.0/8").include?(ip)) ||
      (ip.ipv6? && (ip == IPAddr.new("::") || IPAddr.new("fc00::/7").include?(ip) || IPAddr.new("fe80::/10").include?(ip)))
  rescue IPAddr::InvalidAddressError
    true
  end

  def fetch!(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?

    request = Net::HTTP::Get.new(uri)
    response = http.request(request)

    # Do not follow redirects — they can point at internal addresses (SSRF).
    raise UnsafeUrlError, "Redirects are not allowed" if response.is_a?(Net::HTTPRedirection)
    raise UnsafeUrlError, "Download failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)
    raise UnsafeUrlError, "Image too large" if response.body.bytesize > MAX_BYTES

    [response.body, response["content-type"].to_s.split(";").first&.strip]
  end

  def allowed_content_type?(content_type)
    content_type.present? && ALLOWED_CONTENT_TYPES.include?(content_type.downcase)
  end

  def filename_for(uri, content_type)
    name = File.basename(uri.path.to_s)
    return name if name.present? && name.include?(".")

    ext = case content_type
          when "image/png" then "png"
          when "image/gif" then "gif"
          when "image/webp" then "webp"
          when "image/svg+xml" then "svg"
          else "jpg"
          end
    "image.#{ext}"
  end
end
