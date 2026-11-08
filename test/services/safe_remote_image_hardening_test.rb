# frozen_string_literal: true

require "test_helper"

class SafeRemoteImageHardeningTest < ActiveSupport::TestCase
  PNG = "\x89PNG\r\n\x1A\n".b + ("\x00".b * 64)

  class FakeResponse < Net::HTTPOK
    def initialize(chunks, headers = {})
      super("1.1", "200", "OK")
      @chunks = chunks
      headers.each { |k, v| self[k] = v }
    end

    def read_body
      @chunks.each { |c| yield c }
    end
  end

  def with_fake(addresses:, response:)
    calls = {}
    original_resolv = Resolv.method(:getaddresses)
    original_new = Net::HTTP.method(:new)
    Resolv.define_singleton_method(:getaddresses) { |_| addresses }
    http = Object.new
    %i[use_ssl= open_timeout= read_timeout= verify_mode=].each { |m| http.define_singleton_method(m) { |_| } }
    http.define_singleton_method(:use_ssl?) { true }
    http.define_singleton_method(:ipaddr=) { |ip| calls[:ipaddr] = ip }
    http.define_singleton_method(:request) do |_req, &blk|
      blk&.call(response)
      response
    end
    Net::HTTP.define_singleton_method(:new) { |*args| calls[:new_args] = args; http }
    yield calls
  ensure
    Resolv.define_singleton_method(:getaddresses, original_resolv)
    Net::HTTP.define_singleton_method(:new, original_new)
  end

  test "pins the connection to the vetted address and ignores env proxies" do
    with_fake(addresses: ["93.184.216.34"], response: FakeResponse.new([PNG], "content-type" => "image/png")) do |calls|
      io, filename = SafeRemoteImage.open("https://cdn.example/pic.png")
      assert_equal "93.184.216.34", calls[:ipaddr]
      assert_equal ["cdn.example", 443, nil], calls[:new_args]
      assert_equal "pic.png", filename
      assert_equal PNG, io.read
    end
  end

  test "rejects SVG even when served as an image" do
    with_fake(addresses: ["93.184.216.34"], response: FakeResponse.new(["<svg/>"], "content-type" => "image/svg+xml")) do
      assert_raises(SafeRemoteImage::UnsafeUrlError) { SafeRemoteImage.open("https://cdn.example/x.svg") }
    end
  end

  test "rejects bytes that are not an image despite content-type" do
    with_fake(addresses: ["93.184.216.34"], response: FakeResponse.new(["<html>"], "content-type" => "image/png")) do
      assert_raises(SafeRemoteImage::UnsafeUrlError) { SafeRemoteImage.open("https://cdn.example/x.png") }
    end
  end

  test "aborts streaming once the size cap is exceeded" do
    big = Array.new(11) { "\x00".b * 1.megabyte }
    with_fake(addresses: ["93.184.216.34"], response: FakeResponse.new([PNG] + big, "content-type" => "image/png")) do
      error = assert_raises(SafeRemoteImage::UnsafeUrlError) { SafeRemoteImage.open("https://cdn.example/x.png") }
      assert_match(/too large/, error.message)
    end
  end

  test "rejects declared oversize content-length before reading" do
    resp = FakeResponse.new([PNG], "content-type" => "image/png", "content-length" => (20.megabytes).to_s)
    with_fake(addresses: ["93.184.216.34"], response: resp) do
      assert_raises(SafeRemoteImage::UnsafeUrlError) { SafeRemoteImage.open("https://cdn.example/x.png") }
    end
  end

  test "rejects CGNAT, IPv4-mapped IPv6 and mixed public/private answers" do
    [["100.64.1.1"], ["::ffff:10.0.0.1"], ["93.184.216.34", "10.0.0.5"]].each do |addrs|
      with_fake(addresses: addrs, response: FakeResponse.new([PNG], "content-type" => "image/png")) do
        assert_raises(SafeRemoteImage::UnsafeUrlError, addrs.inspect) { SafeRemoteImage.open("https://cdn.example/x.png") }
      end
    end
  end
end
