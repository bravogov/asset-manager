#!/bin/sh
# Run in a separate, source-pinned Asset Manager maintenance container with
# the signature directory mounted read-write. The scanning web/worker mounts
# that directory read-only. No application database or file records are edited.
set -eu

test -d /var/lib/clamav || { echo "Missing ClamAV signature volume" >&2; exit 1; }
test "$(id -u)" -eq 0 || { echo "Maintenance requires an isolated root-owned updater container" >&2; exit 1; }
test -x /usr/local/bin/freshclam || { echo "Original ClamAV updater is unavailable" >&2; exit 1; }

config=/tmp/uh-freshclam-maintenance.conf
printf 'DatabaseDirectory /var/lib/clamav\nDatabaseMirror database.clamav.net\nDatabaseOwner root\nLogTime yes\n' > "$config"
freshclam --config-file="$config" --stdout
clamscan --version
