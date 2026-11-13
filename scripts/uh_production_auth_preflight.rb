# frozen_string_literal: true

require "uri"

# Preflight for the native Asset Manager web and Sidekiq release.
# An environment that passes these checks still requires a real authenticated
# editor-to-Asset-Manager upload, denial, scan, retrieval and rollback test.
module UHProductionAuthenticationPreflight
  module_function

  def errors(env)
    return [] unless env.fetch("RAILS_ENV", "development") == "production"

    failures = []
    failures << "GDS_SSO_STRATEGY must be real" unless env["GDS_SSO_STRATEGY"] == "real"

    id = env.fetch("GDS_SSO_OAUTH_ID", "")
    secret = env.fetch("GDS_SSO_OAUTH_SECRET", "")
    failures << "Asset Manager Signon OAuth client ID missing" if id.length < 16 || id == "test-oauth-id"
    failures << "Asset Manager Signon OAuth client secret missing" if secret.length < 24 || secret == "test-oauth-secret"

    signon_url = env.fetch("PLEK_SERVICE_SIGNON_URI", "")
    begin
      uri = URI.parse(signon_url)
      unless %w[http https].include?(uri.scheme) && uri.host.to_s.end_with?(".gov.uhrblx.com")
        failures << "Signon service URL not set to GOV.UH"
      end
    rescue URI::InvalidURIError
      failures << "Signon service URL invalid"
    end

    failures << "JWT signing configuration missing" if env.fetch("JWT_AUTH_SECRET", "").length < 32
    failures
  end
end

if $PROGRAM_NAME == __FILE__
  problems = UHProductionAuthenticationPreflight.errors(ENV)
  if problems.empty?
    puts "Asset Manager authentication configuration present; live Signon and upload tests still required"
  else
    warn "Asset Manager is not ready for production: #{problems.join('; ')}"
    exit 1
  end
end
