# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("scripts/uh_production_auth_preflight")

RSpec.describe UHProductionAuthenticationPreflight do
  let(:ready) do
    {
      "RAILS_ENV" => "production",
      "GDS_SSO_STRATEGY" => "real",
      "GDS_SSO_OAUTH_ID" => "uh-asset-manager-production-application-id",
      "GDS_SSO_OAUTH_SECRET" => "uh-candidate-test-only-credential-placeholder-not-a-real-secret",
      "PLEK_SERVICE_SIGNON_URI" => "https://signon.publishing.service.gov.uhrblx.com",
      "JWT_AUTH_SECRET" => "uh-test-only-placeholder-not-production-secret",
    }
  end

  it "accepts configured production settings without claiming authentication succeeded" do
    expect(described_class.errors(ready)).to be_empty
  end

  it "rejects production mock sign-in" do
    expect(described_class.errors(ready.merge("GDS_SSO_STRATEGY" => "mock"))).to include("GDS_SSO_STRATEGY must be real")
  end

  it "rejects absent or placeholder OAuth client credentials" do
    invalid = ready.merge("GDS_SSO_OAUTH_ID" => "test-oauth-id", "GDS_SSO_OAUTH_SECRET" => "test-oauth-secret")
    expect(described_class.errors(invalid).grep(/OAuth/).length).to eq(2)
  end

  it "rejects an invalid Signon service URL" do
    expect(described_class.errors(ready.merge("PLEK_SERVICE_SIGNON_URI" => "not-a-uri"))).to include("Signon service URL not set to GOV.UH")
  end

  it "rejects absent JWT signing configuration" do
    expect(described_class.errors(ready.merge("JWT_AUTH_SECRET" => ""))).to include("JWT signing configuration missing")
  end

  it "does not impose production settings on isolated unit tests" do
    expect(described_class.errors({ "RAILS_ENV" => "test" })).to be_empty
  end
end
