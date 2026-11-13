# frozen_string_literal: true

require "rails_helper"
require "services"

RSpec.describe "UH original PDF upload and scanner delivery", :disable_cloud_storage_stub, type: :request do
  let(:s3) { S3Configuration.build }

  before do
    allow(AssetManager).to receive(:s3).and_return(s3)
    allow(s3).to receive(:fake?).and_return(true)
    login_as_stub_user
  end

  it "uploads a real PDF, scans it with ClamAV and makes the same bytes retrievable" do
    fixture = fixture_file_path("uh-asset-qa.pdf")
    original_bytes = File.binread(fixture)

    post "/assets", params: { asset: { file: load_fixture_file("uh-asset-qa.pdf") } }
    expect(response).to have_http_status(:created)

    asset = Asset.last
    expect(asset).to be_unscanned

    get download_media_path(id: asset, filename: "uh-asset-qa.pdf")
    expect(response).to have_http_status(:not_found)

    VirusScanJob.drain
    expect(asset.reload).to be_clean

    SaveToCloudStorageJob.drain
    expect(asset.reload).to be_uploaded

    get download_media_path(id: asset, filename: "uh-asset-qa.pdf")
    expect(response).to have_http_status(:found)

    download_url = response.headers.fetch("location")
    get download_url
    expect(response).to have_http_status(:success)
    expect(response.body.b).to eq(original_bytes)
  end

  it "rejects the harmless EICAR test file without releasing it into storage" do
    signature = "X5O!P%@AP[4" + 92.chr + "PZX54(P^)7CC)7}" + "$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"
    expect(signature.bytesize).to eq(68)

    Tempfile.create(["uh-antivirus-fixture-", ".txt"]) do |file|
      file.binmode
      file.write(signature)
      file.flush
      uploaded = Rack::Test::UploadedFile.new(file.path, "text/plain")

      post "/assets", params: { asset: { file: uploaded } }
      expect(response).to have_http_status(:created)

      asset = Asset.last
      VirusScanJob.drain
      expect(asset.reload).to be_infected
      SaveToCloudStorageJob.drain
      expect(asset.reload).not_to be_uploaded

      get download_media_path(id: asset, filename: File.basename(file.path))
      expect(response).to have_http_status(:not_found)
    end
  end
end
