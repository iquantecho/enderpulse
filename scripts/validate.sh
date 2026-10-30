#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_dir"

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
"${NODE:-node}" tests/logic.test.mjs

if command -v qmllint >/dev/null 2>&1; then
    qmllint EnderPulse.qml EnderPulseBar.qml EnderPulseService.qml EnderPulseCapture.qml EnderPulseVisualizer.qml EnderPulseSettings.qml StartupCheck.qml
else
    echo "qmllint unavailable; skipping QML lint"
fi
