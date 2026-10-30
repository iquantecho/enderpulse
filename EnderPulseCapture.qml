import QtQuick
import Quickshell.Io

// Owns capture only. Rendering and host visibility belong to the caller.
Item {
    id: root

    required property string configPath
    required property string configText
    property bool active: true
    property bool configured: false
    property int retryCount: 0
    property string errorMessage: ""
    property string savedConfig: ""
    readonly property bool capturing: cavaProcess.running
    readonly property bool exhausted: retryCount > 3
    signal frame(string line)

    function restart() {
        configured = false
        retryCount = 0
        errorMessage = ""
        retryTimer.stop()
        if (active)
            restartTimer.restart()
        else
            restartTimer.stop()
    }

    onActiveChanged: restart()
    onConfigTextChanged: restart()
    onConfigPathChanged: {
        savedConfig = ""
        restart()
    }
    Component.onCompleted: restart()

    Timer {
        id: restartTimer
        interval: 250
        onTriggered: {
            // Wait for the previous reader and permission update before rewriting.
            if (cavaProcess.running || configPermissions.running) {
                restart()
                return
            }
            // FileView emits no saved signal when setText receives cached text.
            if (root.savedConfig === root.configText)
                configPermissions.running = true
            else
                configFile.setText(root.configText)
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        preload: false
        atomicWrites: true
        onSaved: {
            root.savedConfig = configFile.text()
            if (root.active && !restartTimer.running)
                configPermissions.running = true
        }
        onSaveFailed: {
            root.errorMessage = "Cannot write the Cava configuration. Check cache permissions."
        }
    }

    Process {
        id: configPermissions
        command: ["chmod", "600", root.configPath]
        onExited: exitCode => {
            if (!root.active || restartTimer.running)
                return
            if (exitCode === 0)
                root.configured = true
            else
                root.errorMessage = "Cannot secure the Cava configuration. Check cache permissions."
        }
    }

    Timer {
        id: retryTimer
        interval: 1800
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", root.configPath]
        running: root.active && root.configured && !root.exhausted && !retryTimer.running
        onStarted: root.errorMessage = ""
        onExited: exitCode => {
            if (!root.active || !root.configured)
                return
            root.retryCount++
            if (root.exhausted) {
                if (!root.errorMessage)
                    root.errorMessage = "Cava stopped (exit " + exitCode + "). Check the audio source, then reload EnderPulse."
            } else {
                retryTimer.restart()
            }
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => root.frame(line)
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.trim())
                    root.errorMessage = line.trim().slice(0, 300)
            }
        }
    }
}
