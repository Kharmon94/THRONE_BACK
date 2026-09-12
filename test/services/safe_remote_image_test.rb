# frozen_string_literal: true

require "test_helper"
require "resolv"
require "net/http"

class SafeRemoteImageTest < ActiveSupport::TestCase
  test "rejects blank url" do
    assert_raises(SafeRemoteImage::UnsafeUrlError) { SafeRemoteImage.open("") }
  end

  test "rejects localhost hostname" do
    assert_raises(SafeRemoteImage::UnsafeUrlError) { SafeRemoteImage.open("http://localhost/image.png") }
  end

  test "rejects loopback IP" do
    assert_raises(SafeRemoteImage::UnsafeUrlError) { SafeRemoteImage.open("http://127.0.0.1/image.png") }
  end

  test "rejects private IP hostname resolution" do
    original = Resolv.method(:getaddresses)
    Resolv.define_singleton_method(:getaddresses) { |_| ["10.0.0.5"] }
    begin
      error = assert_raises(SafeRemoteImage::UnsafeUrlError) do
        SafeRemoteImage.open("http://evil.example/image.png")
      end
      assert_match(/Blocked address/, error.message)
    ensure
      Resolv.define_singleton_method(:getaddresses, original)
    end
  end

  test "rejects redirects" do
    original_resolv = Resolv.method(:getaddresses)
    original_http = Net::HTTP.method(:new)
    Resolv.define_singleton_method(:getaddresses) { |_| ["93.184.216.34"] }

    redirect = Net::HTTPFound.new("1.1", "302", "Found")
    http = Object.new
    http.define_singleton_method(:use_ssl=) { |_| }
    http.define_singleton_method(:use_ssl?) { true }
    http.define_singleton_method(:open_timeout=) { |_| }
    http.define_singleton_method(:read_timeout=) { |_| }
    http.define_singleton_method(:verify_mode=) { |_| }
    http.define_singleton_method(:request) { |_| redirect }
    Net::HTTP.define_singleton_method(:new) { |*_args| http }

    begin
      error = assert_raises(SafeRemoteImage::UnsafeUrlError) do
        SafeRemoteImage.open("https://cdn.example/image.png")
      end
      assert_match(/Redirects/, error.message)
    ensure
      Resolv.define_singleton_method(:getaddresses, original_resolv)
      Net::HTTP.define_singleton_method(:new, original_http)
    end
  end
end
