#!/bin/sh
# Native web and Sidekiq entry point for BravoGov's production image.
# Refuse an untrusted/missing Signon configuration before accepting requests.
set -eu
ruby /app/scripts/uh_production_auth_preflight.rb
exec "$@"
