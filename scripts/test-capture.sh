#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/enderpulse-test.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
cp "$repo_dir/EnderPulseCapture.qml" "$test_dir/"
cp "$repo_dir/tests/capture.qml" "$test_dir/shell.qml"
QT_QPA_PLATFORM=offscreen timeout 22s qs -p "$test_dir"
