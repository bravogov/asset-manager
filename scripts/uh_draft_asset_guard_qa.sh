#!/bin/sh
set -eu
BASE=/srv/uhde/candidates/docs-html-pdf-pipeline-20261105
docker run --rm --network uh-docs-isolated-20261105 \
  --cap-drop ALL --security-opt no-new-privileges \
  --entrypoint /bin/sh \
  -e RAILS_ENV=production -e GOVUK_ENVIRONMENT=production \
  -e GOVUK_APP_DOMAIN=publishing.service.gov.uhrblx.com \
  -e GDS_SSO_STRATEGY=mock \
  -e JWT_AUTH_SECRET=isolated-test-only-jwt-unused \
  -e SECRET_KEY_BASE=isolated-test-only-session-nonlive-20261109 \
  -e ALLOW_FAKE_S3_IN_PRODUCTION_FOR_PUBLISHING_E2E_TESTS=1 \
  -e PLEK_SERVICE_ASSETS_URI=https://assets.gov.uhrblx.com \
  -e PLEK_SERVICE_DRAFT_ASSETS_URI=https://draft-assets.publishing.service.gov.uhrblx.com \
  --mount type=bind,src="$BASE/asset-manager/scripts/uh_draft_asset_guard_smoke.rb",dst=/tmp/uh-draft-guard-smoke.rb,readonly \
  govuh/asset-manager:docs-draft-guard-20261109 \
  -lc 'bundle exec rails runner /tmp/uh-draft-guard-smoke.rb'
