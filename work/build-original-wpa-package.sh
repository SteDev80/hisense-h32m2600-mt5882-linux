#!/bin/sh
set -eu

repo=/mnt/c/Users/steki/Documents/Codex/2026-08-30/referenced-chatgpt-conversation-this-is-an
wpa_source="$repo/outputs/firmware-original-20260903-172654/inspection-p11/wpa-original/bin/wpa_supplicant/common"
runtime_source="$repo/outputs/firmware-original-20260903-172654/inspection-p11/wpa-runtime"
output="$repo/outputs/wpa-original-hisense/h32-wpa-original.tar.gz"
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT HUP INT TERM

mkdir -p "$stage/h32-wpa-original/bin" "$stage/h32-wpa-original/lib" "$stage/h32-wpa-original/basic-lib"
for name in wpa_supplicant wpa_cli iwconfig iwlist iwpriv libnl-3.so.200 libnl-genl-3.so.200; do
    cp -a "$wpa_source/$name" "$stage/h32-wpa-original/bin/"
done
cp -a "$runtime_source/lib/." "$stage/h32-wpa-original/lib/"
cp -a "$runtime_source/basic/lib/libssl.so.1.0.0" "$stage/h32-wpa-original/basic-lib/"
cp -a "$runtime_source/basic/lib/libcrypto.so.1.0.0" "$stage/h32-wpa-original/basic-lib/"

(
    cd "$stage/h32-wpa-original"
    find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)
mkdir -p "$(dirname "$output")"
tar -czf "$output" -C "$stage" h32-wpa-original
sha256sum "$output"
