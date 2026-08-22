import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import "EnderPulseLogic.js" as EnderPulseLogic
Item {
    id: root

    property var pluginData: ({})
    property string instanceId: "default"
    property string defaultMode: "spectrum"
    property bool compact: false

    readonly property string mode: pluginData.mode ?? defaultMode
    readonly property string palette: pluginData.palette ?? "material"
    readonly property int bandCount: Math.max(16, Math.min(96, pluginData.bandCount ?? 48))
    readonly property int sensitivity: Math.max(20, Math.min(200, pluginData.sensitivity ?? 100))
    readonly property real smoothing: Math.max(0, Math.min(0.9, (pluginData.smoothing ?? 55) / 100))
    readonly property real glow: Math.max(0, Math.min(1, (pluginData.glow ?? 45) / 100))
    readonly property real backgroundOpacity: Math.max(0, Math.min(0.9, (pluginData.backgroundOpacity ?? 12) / 100))
    readonly property int fadeDelay: Math.max(1, Math.min(20, pluginData.fadeDelay ?? 4)) * 1000
    readonly property string audioTarget: pluginData.audioTarget ?? "system"
    readonly property string audioBackend: pluginData.audioBackend ?? "auto"
    readonly property string customAudioSource: pluginData.customAudioSource ?? ""
    readonly property string cavaInputSource: resolveInputSource()
    readonly property string cavaInputMethod: resolveInputMethod()
    readonly property int cavaFrameRate: 30
    readonly property int renderInterval: 34
    readonly property real audioThreshold: 0.012
    readonly property bool microphoneInput: audioTarget === "microphone"
        || (audioTarget.indexOf("pulse:") === 0 && !cavaInputSource.endsWith(".monitor"))
    readonly property real noiseFloor: microphoneInput ? 0.035 : 0

    property var values: []
    property var peaks: []
    property var pendingValues: []
    property var frameState: ({ count: 0, strongest: 0, pending: false })
    property int activeBandCount: 0
    property bool visibleAfterAudio: false
    property bool ready: false
    property int retryCount: 0
    property bool restartPending: false
    property bool intentionalStop: false
    property string brailleText: ""
    readonly property int maxRetries: 3

    readonly property string safeInstanceKey: {
        return EnderPulseLogic.safeInstanceKey(instanceId)
    }
    readonly property string configPath: Quickshell.cachePath("enderpulse-" + safeInstanceKey + ".conf")
    readonly property string configText:
        "[general]\n" +
        "bars = " + bandCount + "\n" +
        "framerate = " + cavaFrameRate + "\n" +
        "sensitivity = " + sensitivity + "\n" +
        "autosens = " + (microphoneInput ? 0 : 1) + "\n" +
        "channels = mono\n\n" +
        "[input]\n" +
        (cavaInputMethod.length > 0 ? "method = " + cavaInputMethod + "\n" : "") +
        "source = " + cavaInputSource + "\n" +
        (cavaInputMethod === "pipewire" ? "active = 1\nvirtual = 1\n" : "") +
        "\n" +
        "[output]\n" +
        "method = raw\n" +
        "channels = mono\n" +
        "raw_target = /dev/stdout\n" +
        "data_format = ascii\n" +
        "ascii_max_range = 1000\n" +
        "bar_delimiter = 59\n" +
        "frame_delimiter = 10\n"

    function safeSourceName(value, fallback) {
        const cleaned = String(value ?? "").replace(/[\r\n]/g, "").trim()
        return cleaned.length > 0 ? cleaned : fallback
    }

    function resolveInputSource() {
        if (audioTarget === "microphone")
            return "@DEFAULT_SOURCE@"
        if (audioTarget.indexOf("pulse:") === 0)
            return safeSourceName(audioTarget.substring(6), "auto")
        if (audioTarget === "custom")
            return safeSourceName(customAudioSource, "auto")
        return "auto"
    }

    function resolveInputMethod() {
        if (audioTarget === "microphone" || audioTarget.indexOf("pulse:") === 0)
            return "pulse"
        return audioBackend === "pipewire" || audioBackend === "pulse" ? audioBackend : ""
    }

    function makeBrailleText(count) {
        const leftBits = [1, 2, 4, 64]
        const rightBits = [8, 16, 32, 128]
        let result = ""

        for (let i = 0; i < count; i += 2) {
            const leftHeight = values[i] > audioThreshold
                ? Math.max(1, Math.min(4, Math.ceil(values[i] * 4))) : 0
            const rightHeight = i + 1 < count
                ? (values[i + 1] > audioThreshold
                    ? Math.max(1, Math.min(4, Math.ceil(values[i + 1] * 4))) : 0) : 0
            let dots = 0
            for (let row = 0; row < leftHeight; row++)
                dots |= leftBits[3 - row]
            for (let row = 0; row < rightHeight; row++)
                dots |= rightBits[3 - row]
            result += String.fromCharCode(0x2800 + dots)
        }

        return result
    }

    function paletteColor(position) {
        const t = Math.max(0, Math.min(1, position))
        let start
        let finish

        if (palette === "aurora") {
            start = Qt.rgba(0.16, 0.91, 0.73, 1)
            finish = Qt.rgba(0.54, 0.31, 0.96, 1)
        } else if (palette === "ember") {
            start = Qt.rgba(1.0, 0.72, 0.18, 1)
            finish = Qt.rgba(0.95, 0.18, 0.27, 1)
        } else if (palette === "mono") {
            start = Theme.surfaceText
            finish = Theme.surfaceVariantText
        } else {
            start = Theme.primary
            finish = Theme.secondary
        }

        return Qt.rgba(start.r + (finish.r - start.r) * t,
                       start.g + (finish.g - start.g) * t,
                       start.b + (finish.b - start.b) * t,
                       1)
    }

    function resetBandBuffers() {
        values = new Array(bandCount).fill(0)
        peaks = new Array(bandCount).fill(0)
        pendingValues = new Array(bandCount).fill(0)
        frameState.count = 0
        frameState.strongest = 0
        frameState.pending = false
        activeBandCount = bandCount
    }

    function acceptFrame(line) {
        if (!ready || !visible || !line || line.length === 0)
            return

        if (!EnderPulseLogic.parseCavaFrame(
                line, bandCount, pendingValues, frameState, noiseFloor))
            return

        if (!renderTimer.running
                && (compact || frameState.strongest > audioThreshold || visibleAfterAudio))
            renderTimer.start()
    }

    function renderPendingFrame() {
        if (!frameState.pending)
            return

        const count = frameState.count
        const strongest = frameState.strongest
        frameState.pending = false
        const renderSmoothing = smoothing * smoothing

        for (let i = 0; i < count; i++) {
            const smoothed = values[i] * renderSmoothing + pendingValues[i] * (1 - renderSmoothing)
            values[i] = smoothed
            peaks[i] = Math.max(smoothed, peaks[i] - 0.036)
        }

        activeBandCount = count
        if (mode === "braille")
            brailleText = makeBrailleText(count)
        if (strongest > audioThreshold) {
            visibleAfterAudio = true
            silenceTimer.stop()
        } else if (visibleAfterAudio && !silenceTimer.running) {
            silenceTimer.restart()
        }

        if (visibleAfterAudio)
            visualizer.requestPaint()
    }

    function rebuildCava() {
        if (!ready)
            return
        retryCount = 0
        restartPending = true
        restartTimer.restart()
    }

    function writeConfigAndStart() {
        if (!ready || !visible) {
            restartPending = false
            return
        }
        if (configPermissions.running)
            return
        restartPending = false
        configFile.setText(configText)
        configPermissions.running = true
    }

    function beginCavaRestart() {
        if (!ready || !visible) {
            restartPending = false
            return
        }

        retryTimer.stop()
        if (cavaProcess.running) {
            intentionalStop = true
            cavaProcess.running = false
        } else if (!configPermissions.running) {
            writeConfigAndStart()
        }
    }

    function suspendAudioWork() {
        restartTimer.stop()
        retryTimer.stop()
        renderTimer.stop()
        silenceTimer.stop()
        restartPending = false
        frameState.pending = false
        visibleAfterAudio = false
        if (cavaProcess.running) {
            intentionalStop = true
            cavaProcess.running = false
        }
        if (configPermissions.running)
            configPermissions.running = false
    }

    opacity: compact ? 1 : (visibleAfterAudio ? 1 : 0)
    Behavior on opacity {
        NumberAnimation { duration: 650; easing.type: Easing.InOutCubic }
    }

    Timer {
        id: silenceTimer
        interval: root.fadeDelay
        repeat: false
        onTriggered: {
            root.visibleAfterAudio = false
            renderTimer.stop()
        }
    }

    Timer {
        id: renderTimer
        interval: root.renderInterval
        repeat: true
        onTriggered: {
            if (!root.ready || !root.visible) {
                stop()
                return
            }
            if (!root.frameState.pending) {
                stop()
                return
            }
            root.renderPendingFrame()
        }
    }

    Timer {
        id: restartTimer
        interval: 250
        repeat: false
        onTriggered: root.beginCavaRestart()
    }

    Timer {
        id: retryTimer
        interval: 1800
        repeat: false
        onTriggered: {
            if (root.ready && root.visible && !cavaProcess.running
                    && !configPermissions.running) {
                root.restartPending = true
                root.beginCavaRestart()
            }
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        preload: false
        blockWrites: true
        atomicWrites: true
    }

    Process {
        id: configPermissions
        command: ["chmod", "600", root.configPath]
        running: false
        onRunningChanged: {
            if (running || !root.ready || !root.visible)
                return
            if (root.restartPending) {
                if (!restartTimer.running)
                    root.beginCavaRestart()
            } else {
                cavaProcess.running = true
            }
        }
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", root.configPath]
        running: false
        onRunningChanged: {
            if (running || !root.ready)
                return

            if (root.intentionalStop) {
                root.intentionalStop = false
                if (root.restartPending && !restartTimer.running)
                    root.beginCavaRestart()
            } else if (root.visible && root.retryCount < root.maxRetries) {
                root.retryCount++
                retryTimer.restart()
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root.acceptFrame(line) }
        }
    }

    Component.onCompleted: {
        resetBandBuffers()
        ready = true
        rebuildCava()
    }
    Component.onDestruction: {
        ready = false
        silenceTimer.stop()
        renderTimer.stop()
        retryTimer.stop()
        restartTimer.stop()
        restartPending = false
        intentionalStop = true
        cavaProcess.running = false
        configPermissions.running = false
    }
    onVisibleChanged: {
        if (!ready)
            return
        if (visible)
            rebuildCava()
        else
            suspendAudioWork()
    }
    onBandCountChanged: {
        if (ready) {
            resetBandBuffers()
            rebuildCava()
        }
    }
    onSensitivityChanged: if (ready) rebuildCava()
    onAudioTargetChanged: if (ready) rebuildCava()
    onAudioBackendChanged: if (ready) rebuildCava()
    onCustomAudioSourceChanged: if (ready && audioTarget === "custom") rebuildCava()
    onModeChanged: visualizer.requestPaint()
    onPaletteChanged: visualizer.requestPaint()
    onGlowChanged: visualizer.requestPaint()

    Rectangle {
        anchors.fill: parent
        radius: Math.min(Theme.cornerRadius, Math.min(width, height) / 5)
        color: Theme.surfaceContainer
        opacity: root.backgroundOpacity
    }

    Text {
        anchors.fill: parent
        anchors.margins: root.compact ? 1 : 12
        visible: root.mode === "braille"
        text: root.brailleText
        color: root.paletteColor(0.5)
        font.family: "monospace"
        font.pixelSize: root.compact
            ? Math.max(8, Math.min(height * 0.78, width / Math.max(1, text.length) * 1.65))
            : Math.max(8, height * 0.42)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    Canvas {
        id: visualizer
        anchors.fill: parent
        visible: root.mode !== "braille"
        renderStrategy: Canvas.Cooperative

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            const inset = root.compact ? 1 : 12
            const w = Math.max(1, width - inset * 2)
            const h = Math.max(1, height - inset * 2)
            const vals = root.values
            const held = root.peaks
            const count = root.activeBandCount
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            ctx.translate(inset, inset)
            if (count === 0)
                return

            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            if (root.mode === "radial") {
                const cx = w / 2
                const cy = h / 2
                const base = Math.max(12, Math.min(w, h) * 0.19)
                const reach = Math.max(10, Math.min(w, h) * 0.29)
                const lineWidth = Math.max(1.5, Math.min(5, Math.min(w, h) / 90))

                ctx.lineWidth = lineWidth
                for (let i = 0; i < count; i++) {
                    const angle = -Math.PI / 2 + i / count * Math.PI * 2
                    const amplitude = Math.max(0.025, vals[i])
                    const radius = base + amplitude * reach
                    const color = root.paletteColor(i / Math.max(1, count - 1))
                    ctx.strokeStyle = color
                    if (root.glow > 0) {
                        ctx.globalAlpha = root.glow * 0.2
                        ctx.lineWidth = lineWidth * (1 + root.glow * 3)
                        ctx.beginPath()
                        ctx.moveTo(cx + Math.cos(angle) * base, cy + Math.sin(angle) * base)
                        ctx.lineTo(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius)
                        ctx.stroke()
                        ctx.globalAlpha = 1
                        ctx.lineWidth = lineWidth
                    }
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(angle) * base, cy + Math.sin(angle) * base)
                    ctx.lineTo(cx + Math.cos(angle) * radius, cy + Math.sin(angle) * radius)
                    ctx.stroke()
                }

                ctx.lineWidth = Math.max(1, lineWidth * 0.55)
                ctx.strokeStyle = root.paletteColor(0.5)
                if (root.glow > 0) {
                    ctx.globalAlpha = root.glow * 0.18
                    ctx.lineWidth *= 1 + root.glow * 3
                    ctx.beginPath()
                    ctx.arc(cx, cy, base, 0, Math.PI * 2)
                    ctx.stroke()
                    ctx.globalAlpha = 1
                    ctx.lineWidth = Math.max(1, lineWidth / (1 + root.glow * 3))
                }
                ctx.beginPath()
                ctx.arc(cx, cy, base, 0, Math.PI * 2)
                ctx.stroke()
                return
            }

            const gap = Math.max(1, w / count * 0.18)
            const bandWidth = Math.max(1, (w - gap * (count - 1)) / count)
            const mirrored = root.mode === "mirror"
            const available = mirrored ? h * 0.46 : h * 0.9

            for (let j = 0; j < count; j++) {
                const x = j * (bandWidth + gap)
                const amplitude = vals[j] > root.audioThreshold ? vals[j] : 0
                const heldValue = held[j] ?? 0
                const peakAmplitude = heldValue > root.audioThreshold ? heldValue : 0
                const bandHeight = amplitude * available
                const color = root.paletteColor(j / Math.max(1, count - 1))
                ctx.fillStyle = color

                if (mirrored) {
                    if (amplitude === 0)
                        continue
                    if (root.glow > 0) {
                        const halo = Math.max(1, bandWidth * root.glow)
                        ctx.globalAlpha = root.glow * 0.16
                        ctx.fillRect(x - halo / 2, h / 2 - bandHeight - halo / 2,
                                     bandWidth + halo, bandHeight * 2 + halo)
                        ctx.globalAlpha = 1
                    }
                    ctx.fillRect(x, h / 2 - bandHeight, bandWidth, bandHeight * 2)
                } else {
                    if (amplitude > 0) {
                        if (root.glow > 0) {
                            const halo = Math.max(1, bandWidth * root.glow)
                            ctx.globalAlpha = root.glow * 0.16
                            ctx.fillRect(x - halo / 2, h - bandHeight - halo / 2,
                                         bandWidth + halo, bandHeight + halo)
                            ctx.globalAlpha = 1
                        }
                        ctx.fillRect(x, h - bandHeight, bandWidth, bandHeight)
                    }
                    if (peakAmplitude > 0) {
                        const peakY = h - peakAmplitude * available
                        ctx.globalAlpha = 0.55
                        ctx.fillRect(x, Math.max(0, peakY), bandWidth, Math.max(1, bandWidth * 0.22))
                        ctx.globalAlpha = 1
                    }
                }
            }
        }
    }
}
