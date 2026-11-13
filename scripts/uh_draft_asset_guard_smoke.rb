# frozen_string_literal: true
# Original native Rails controller tests with in-memory assets only.
# Staff authentication is simulated here; independent Signon/MFA is NOT tested.
require "rack/mock"
require "json"

class TestAsset
  attr_accessor :replacement
  attr_reader :id, :filename
  def initialize(id, draft, allowed = true, limited = false)
    @id, @draft, @allowed, @limited, @filename = id, draft, allowed, limited, "source.pdf"
  end
  def draft? = @draft
  def deleted? = false
  def access_limited? = @limited
  def accessible_by?(_user) = @allowed
  def uploaded? = true
  def filename_valid?(filename) = filename == @filename
  def redirect_url = nil
  def parent_document_url = nil
  def public_url_path = "/media/#{id}/#{filename}"
end

assets = {
  "draft" => TestAsset.new("draft", true),
  "live" => TestAsset.new("live", false),
  "wrong-role" => TestAsset.new("wrong-role", true, false, true),
  "editor" => TestAsset.new("editor", true, true, true),
  "old-draft" => TestAsset.new("old-draft", true),
  "old-issued" => TestAsset.new("old-issued", true)
}
assets["old-draft"].replacement = assets.fetch("draft")
assets["old-issued"].replacement = assets.fetch("live")
Asset.singleton_class.define_method(:find) { |id| assets.fetch(id.to_s) }
MediaController.class_eval do
  def proxy_to_s3_via_nginx(_asset)
    head :ok, content_type: "application/pdf"
  end
  def authenticate_user!
    true # Test identity double ONLY; no real Signon is exercised
  end
  def current_user
    @test_editor ||= Object.new
  end
end
raise "Run this in the candidate production Rails runtime" unless Rails.env.production?
client = Rack::MockRequest.new(Rails.application)
internal = "https://asset-manager.publishing.service.gov.uhrblx.com"
public = "https://assets.gov.uhrblx.com"
cases = []
check = lambda do |label, response, status, cache = nil|
  actual = response.status
  raise "#{label}: expected HTTP #{status}; got #{actual} #{response.body.to_s[0,150]}" unless actual == status
  cache_header = response.headers["cache-control"].to_s
  raise "#{label}: missing cache policy #{cache.inspect}, got #{cache_header.inspect}" if cache && !cache_header.include?(cache)
  cases << {label: label, status: actual, cache: cache_header}
end
media = ->(host, id) { "#{host}/media/#{id}/source.pdf" }
ENV["GDS_SSO_STRATEGY"] = "mock"
%w[draft old-draft wrong-role editor].each do |id|
  check.call("mock GET #{id}", client.get(media.call(internal,id)), 403, "no-store")
  check.call("mock HEAD #{id}", client.request("HEAD",media.call(internal,id)), 403, "no-store")
end
check.call("mock draft external host",client.get(media.call(public,"draft")),403,"no-store")
check.call("mock published GET",client.get(media.call(public,"live")),200)
check.call("mock published HEAD",client.request("HEAD",media.call(public,"live")),200)
old = client.get(media.call(internal,"old-issued"))
check.call("mock old draft -> already issued replacement",old,301)
raise "Live replacement redirect incorrect" unless old["location"].to_s.include?("assets.gov.uhrblx.com")
check.call("mock asset metadata GET",client.get("#{internal}/assets/draft"),403,"no-store")
check.call("mock asset metadata HEAD",client.request("HEAD","#{internal}/assets/draft"),403,"no-store")
check.call("mock asset creation POST denied",client.post("#{internal}/assets"),403,"no-store")
check.call("mock asset deletion DELETE denied",client.delete("#{internal}/assets/draft"),403,"no-store")
check.call("draft conditional GET cannot yield 304",client.get(media.call(internal,"draft"),
  "HTTP_IF_NONE_MATCH" => '"previous-public-cache-etag"'),403,"no-store")
ENV["GDS_SSO_STRATEGY"] = "real"
check.call("real-config simulated authorised editor GET",client.get(media.call(internal,"editor")),200,"no-store")
check.call("real-config simulated authorised editor HEAD",client.request("HEAD",media.call(internal,"editor")),200,"no-store")
check.call("real-config simulated wrong-role GET",client.get(media.call(internal,"wrong-role")),403,"no-store")
check.call("real-config simulated wrong-role HEAD",client.request("HEAD",media.call(internal,"wrong-role")),403,"no-store")
puts JSON.pretty_generate({product:"original native GOV.UK Asset Manager",candidate_only:true,
  cases:cases,pass:cases.length,real_sso_or_mfa_verified:false,
  source_or_production_data_written:false})
