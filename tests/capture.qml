import QtQuick
import Quickshell
import "." as EnderPulse

// Run with ./scripts/test-capture.sh.
// Uses real Cava and the current user's audio server; no audio is recorded.
ShellRoot {
    id: test
    property int stage: 0
    property int ticks: 0
    property int frames: 0
    property string validConfig: "[general]\nbars=16\nframerate=30\n[input]\nmethod=pulse\nsource=auto\n[output]\nmethod=raw\nraw_target=/dev/stdout\ndata_format=ascii\nascii_max_range=1000\nbar_delimiter=59\nframe_delimiter=10\n"

    EnderPulse.EnderPulseCapture {
        id: capture
        configPath: Quickshell.cachePath("enderpulse-capture-test.conf")
        configText: test.validConfig
        onFrame: test.frames++
    }

    EnderPulse.EnderPulseCapture {
        id: unwritable
        configPath: "/dev/null/enderpulse-test.conf"
        configText: test.validConfig
    }

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            test.ticks++
            if (test.ticks > 180) {
                console.error("FAIL capture lifecycle: stage", test.stage, capture.errorMessage)
                Qt.exit(1)
            }
            switch (test.stage) {
            case 0:
                if (test.frames < 3)
                    return
                if (!unwritable.errorMessage || unwritable.capturing) {
                    console.error("FAIL configuration write errors must block capture")
                    Qt.exit(1)
                }
                console.log("PASS failed config write blocks capture and reports an error")
                console.log("PASS capture starts and emits frames")
                capture.active = false
                test.stage++
                break
            case 1:
                if (capture.capturing)
                    return
                test.frames = 0
                test.stage++
                break
            case 2:
                if (test.frames !== 0 || capture.configured) {
                    console.error("FAIL hidden capture continued")
                    Qt.exit(1)
                }
                console.log("PASS hidden capture stops")
                capture.active = true
                test.stage++
                break
            case 3:
                if (test.frames < 3)
                    return
                console.log("PASS capture resumes without a configuration change")
                capture.configText = test.validConfig.replace("bars=16", "bars=32")
                test.frames = 0
                test.stage++
                break
            case 4:
                if (test.frames < 3)
                    return
                console.log("PASS capture resumes with a changed configuration")
                capture.configText = "[input]\nmethod=not_a_backend\n"
                test.stage++
                break
            case 5:
                if (!capture.exhausted || capture.capturing)
                    return
                if (!capture.errorMessage || capture.retryCount !== 4) {
                    console.error("FAIL retry limit or missing diagnostics")
                    Qt.exit(1)
                }
                console.log("PASS failure is diagnosed and retries are bounded")
                capture.configText = test.validConfig
                test.frames = 0
                test.stage++
                break
            case 6:
                if (test.frames < 3)
                    return
                if (capture.errorMessage || capture.retryCount !== 0) {
                    console.error("FAIL recovery retained stale error state")
                    Qt.exit(1)
                }
                console.log("PASS settings change recovers capture")
                Qt.exit(0)
            }
        }
    }
}
