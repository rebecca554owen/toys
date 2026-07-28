#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

PPP_SKIP_MAIN=1 source "$ROOT_DIR/sh/ppp.sh"
PPP_DIR="$TEST_DIR/ppp"
BACKUP_DIR="$PPP_DIR/backup"
CONFIG_FILE="$PPP_DIR/appsettings.json"
RELEASE_METADATA_FILE="$PPP_DIR/.toys-release.json"
KERNEL_VERSION=6.0.0
mkdir -p "$PPP_DIR" "$TEST_DIR/bin"
export PATH="$TEST_DIR/bin:$PATH"

curl() {
    printf '%s\n' '{"tag_name":"v6.7.0"}'
}
[ "$(get_latest_version)" = 'v6.7.0' ]
unset -f curl

cat > "$TEST_DIR/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
if [ "${MOCK_SYSTEMCTL_FAIL:-0}" = "1" ] && [ "$1" = "start" ]; then
    exit 1
fi
exit 0
EOF
chmod +x "$TEST_DIR/bin/systemctl"

cat > "$PPP_DIR/ppp" <<'EOF'
#!/usr/bin/env bash
echo "Version:      ${MOCK_BINARY_VERSION:-v6.7.0}"
EOF
chmod +x "$PPP_DIR/ppp"
printf '{}\n' > "$CONFIG_FILE"

get_latest_version() {
    is_release_tag "$MOCK_LATEST_VERSION" || return 1
    printf '%s\n' "$MOCK_LATEST_VERSION"
}

assert_contains() {
    local output=$1
    local expected=$2
    if ! grep -Fq "$expected" <<< "$output"; then
        echo "expected line not found: $expected" >&2
        echo "$output" >&2
        exit 1
    fi
}

export MOCK_BINARY_VERSION=v6.7.0
MOCK_LATEST_VERSION=v6.7.0
status=$(print_update_status)
assert_contains "$status" 'UPDATE_STATUS=up-to-date'

MOCK_LATEST_VERSION=v6.8.0
status=$(print_update_status)
assert_contains "$status" 'UPDATE_STATUS=update-available'

MOCK_LATEST_VERSION=v6.6.0
status=$(print_update_status)
assert_contains "$status" 'UPDATE_STATUS=up-to-date'

MOCK_LATEST_VERSION=v6.8.0-rc.1
if print_update_status >/dev/null 2>&1; then
    echo 'pre-release tag was accepted unexpectedly' >&2
    exit 1
fi

MOCK_LATEST_VERSION=v6.8.0
MOCK_BINARY_VERSION=2.0.0.0-20260727152428
status=$(print_update_status)
assert_contains "$status" 'UPDATE_STATUS=untracked'
MOCK_BINARY_VERSION=v6.7.0

write_release_metadata v6.7.0 openppp2-linux-amd64-tc.zip
download_selected_asset() {
    local version=$1
    local asset=$2
    printf '#!/usr/bin/env bash\necho "Version:      %s"\n' "$version" > "$PPP_DIR/ppp"
    chmod +x "$PPP_DIR/ppp"
    SELECTED_ASSET="$asset"
}

MOCK_LATEST_VERSION=v6.8.0
update_ppp latest false
assert_contains "$(cat "$RELEASE_METADATA_FILE")" '"tag": "v6.8.0"'
assert_contains "$(cat "$RELEASE_METADATA_FILE")" '"asset": "openppp2-linux-amd64-tc.zip"'

MOCK_LATEST_VERSION=v6.9.0
download_selected_asset() {
    return 1
}
update_ppp latest false && {
    echo 'failed update unexpectedly succeeded' >&2
    exit 1
}
assert_contains "$("$PPP_DIR/ppp" --help)" 'Version:      v6.8.0'

rm -f "$RELEASE_METADATA_FILE"
printf '#!/usr/bin/env bash\necho "Version:      2.0.0.0-20260727152428"\n' > "$PPP_DIR/ppp"
chmod +x "$PPP_DIR/ppp"
MOCK_LATEST_VERSION=v6.9.0
select_download_version() {
    printf '#!/usr/bin/env bash\necho "Version:      v6.9.0"\n' > "$PPP_DIR/ppp"
    chmod +x "$PPP_DIR/ppp"
    SELECTED_ASSET='openppp2-linux-amd64.zip'
}
update_ppp latest false
assert_contains "$(cat "$RELEASE_METADATA_FILE")" '"asset": "openppp2-linux-amd64.zip"'

MOCK_LATEST_VERSION=v6.10.0
download_selected_asset() {
    printf '#!/usr/bin/env bash\necho "Version:      v6.10.0"\n' > "$PPP_DIR/ppp"
    chmod +x "$PPP_DIR/ppp"
    SELECTED_ASSET="$2"
}
export MOCK_SYSTEMCTL_FAIL=1
update_ppp latest false && {
    echo 'service-start failure unexpectedly succeeded' >&2
    exit 1
}
unset MOCK_SYSTEMCTL_FAIL
assert_contains "$("$PPP_DIR/ppp" --help)" 'Version:      v6.9.0'

echo 'PPP update tests passed'
