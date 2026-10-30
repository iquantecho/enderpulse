import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.DCommon.Widgets
import "EnderPulseLogic.js" as EnderPulseLogic

PluginSettings {
    id: root
    pluginId: "enderPulse"

    property var detectedAudioSources: []
    property string sourceDetectionError: ""
    readonly property var audioSourceOptions: {
        const options = [
            { label: I18n.tr("System output (automatic)"), value: "system" },
            { label: I18n.tr("Default microphone"), value: "microphone" },
            { label: I18n.tr("Custom Cava source"), value: "custom" }
        ]
        return options.concat(detectedAudioSources)
    }
    readonly property var additionalSourceProfiles: variants.filter(function(variant) {
        return variant.id !== "builtin_output" && variant.id !== "builtin_microphone"
    })

    function loadDetectedSources(output) {
        const options = []
        const seen = ({})
        let sources
        try {
            sources = JSON.parse(output)
            if (!Array.isArray(sources))
                throw new Error("Expected a source list")
        } catch (error) {
            sourceDetectionError = I18n.tr("Audio devices could not be listed. Refresh the list or enter a custom source.")
            return
        }
        sourceDetectionError = ""
        for (const source of sources) {
            if (!source || typeof source.name !== "string" || !source.name || seen[source.name])
                continue
            seen[source.name] = true
            const kind = source.name.endsWith(".monitor")
                ? I18n.tr("output monitor") : I18n.tr("input")
            const duplicateName = sources.some(other => other && other.name !== source.name
                && other.description === source.description)
            options.push({
                label: (source.description || source.name)
                    + (duplicateName ? " — " + source.name : "") + " (" + kind + ")",
                value: "pulse:" + source.name
            })
        }

        detectedAudioSources = options
    }

    function sourceLabel(target) {
        const option = audioSourceOptions.find(function(candidate) {
            return candidate.value === target
        })
        return option?.label ?? target
    }

    function profileExists(target, backend, customSource) {
        const profile = EnderPulseLogic.sourceProfile(target, backend, customSource)
        return variants.some(function(variant) {
            const candidate = EnderPulseLogic.sourceProfile(variant.audioTarget,
                variant.audioBackend ?? "auto", variant.customAudioSource ?? "")
            return candidate.audioTarget === profile.audioTarget
                && candidate.audioBackend === profile.audioBackend
                && candidate.customAudioSource === profile.customAudioSource
        })
    }

    function addSourceProfile(target, name) {
        if (!pluginService)
            return
        const backend = audioBackendSetting.value
        const customSource = customAudioSourceSetting.value
        if (profileExists(target, backend, customSource)
                || (target === "custom" && !EnderPulseLogic.safeSourceName(customSource, "")))
            return

        const profile = EnderPulseLogic.sourceProfile(target, backend, customSource)
        profile.id = "source_" + Date.now()
        profile.name = name
        profile.icon = "graphic_eq"
        profile.description = I18n.tr("EnderPulse audio source: ") + sourceLabel(target)
        pluginService.savePluginData(pluginId, "variants",
            pluginService.getPluginVariants(pluginId).concat([profile]))
        loadVariants()
    }

    Process {
        id: sourceDetector
        command: ["pactl", "--format=json", "list", "sources"]
        running: false
        onExited: exitCode => {
            if (exitCode !== 0)
                root.sourceDetectionError = I18n.tr("Audio devices could not be listed. Check that pactl and the audio server are available, then refresh.")
        }
        stdout: StdioCollector {
            onStreamFinished: root.loadDetectedSources(text)
        }
    }

    Component.onCompleted: sourceDetector.running = true

    StyledText {
        width: parent.width
        text: I18n.tr("Bar and dock widgets")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Add System output or Microphone input in Settings → Bar → Widgets, or in the dock editor. Click a visualizer to open these settings; hovering leaves your work alone. Appearance below is shared by both built-in sources.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        id: audioTargetSetting
        settingKey: "audioTarget"
        label: I18n.tr("Desktop / default audio source")
        description: I18n.tr("Built-in output and microphone widgets keep their own sources. This selects the desktop/default widget and the source profile below.")
        defaultValue: "system"
        options: root.audioSourceOptions
    }

    DButton {
        width: parent.width
        text: I18n.tr("Refresh audio devices")
        iconName: "refresh"
        busy: sourceDetector.running
        enabled: !sourceDetector.running
        onClicked: sourceDetector.running = true
    }

    StyledText {
        width: parent.width
        visible: root.sourceDetectionError !== ""
        text: root.sourceDetectionError
        color: Theme.surfaceText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        id: audioBackendSetting
        visible: audioTargetSetting.value === "system" || audioTargetSetting.value === "custom"
        settingKey: "audioBackend"
        label: I18n.tr("Cava audio backend")
        description: I18n.tr("Automatic is best for system output; detected sources use PulseAudio compatibility")
        defaultValue: "auto"
        options: [
            { label: I18n.tr("Automatic"), value: "auto" },
            { label: I18n.tr("PipeWire"), value: "pipewire" },
            { label: I18n.tr("PulseAudio"), value: "pulse" }
        ]
    }

    StringSetting {
        id: customAudioSourceSetting
        visible: audioTargetSetting.value === "custom"
        settingKey: "customAudioSource"
        label: I18n.tr("Custom Cava source")
        description: I18n.tr("Enter a PulseAudio source name, or a PipeWire object.path or object.serial for the selected backend")
        placeholder: "alsa_input… or object.serial"
        defaultValue: ""
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Additional source profile")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Optional: make the selected source available in the bar or dock widget picker. Creating a profile does not place a widget.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    DButton {
        readonly property bool alreadyAvailable: root.profileExists(
            audioTargetSetting.value,
            audioBackendSetting.value,
            customAudioSourceSetting.value)

        width: parent.width
        text: alreadyAvailable
            ? I18n.tr("Selected source is already available")
            : I18n.tr("Create source profile")
        iconName: alreadyAvailable ? "check" : "add"
        wrapText: true
        enabled: !alreadyAvailable && (audioTargetSetting.value !== "custom"
            || EnderPulseLogic.safeSourceName(customAudioSourceSetting.value, "") !== "")
        onClicked: root.addSourceProfile(audioTargetSetting.value,
                                         root.sourceLabel(audioTargetSetting.value))
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.additionalSourceProfiles.length > 0

        StyledText {
            text: I18n.tr("Additional source profiles")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        Repeater {
            model: root.additionalSourceProfiles

            delegate: Row {
                required property var modelData
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    width: parent.width - removeButton.width - parent.spacing
                    text: modelData.name
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }

                DButton {
                    id: removeButton
                    text: I18n.tr("Remove")
                    Accessible.name: I18n.tr("Remove profile: ") + modelData.name
                    iconName: "delete"
                    onClicked: root.removeVariant(modelData.id)
                }
            }
        }
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Appearance")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "mode"
        label: I18n.tr("Visual style")
        description: I18n.tr("Choose how the frequency bands are arranged")
        defaultValue: "spectrum"
        options: [
            { label: I18n.tr("Braille spectrum"), value: "braille" },
            { label: I18n.tr("Spectrum"), value: "spectrum" },
            { label: I18n.tr("Mirrored pulse"), value: "mirror" },
            { label: I18n.tr("Radial orbit"), value: "radial" }
        ]
    }

    SliderSetting {
        settingKey: "barLength"
        label: I18n.tr("Bar length")
        description: I18n.tr("Width on a horizontal bar or height on a vertical bar")
        defaultValue: 180
        minimum: 80
        maximum: 420
        unit: "px"
    }

    SelectionSetting {
        settingKey: "palette"
        label: I18n.tr("Palette")
        defaultValue: "material"
        options: [
            { label: I18n.tr("Material theme"), value: "material" },
            { label: I18n.tr("Aurora"), value: "aurora" },
            { label: I18n.tr("Ember"), value: "ember" },
            { label: I18n.tr("Monochrome"), value: "mono" }
        ]
    }

    SliderSetting {
        settingKey: "bandCount"
        label: I18n.tr("Frequency bands")
        description: I18n.tr("More bands show finer audio detail and use more rendering work")
        defaultValue: 48
        minimum: 16
        maximum: 96
    }

    SliderSetting {
        settingKey: "sensitivity"
        label: I18n.tr("Sensitivity")
        description: I18n.tr("Microphones use fixed gain; output monitors adjust automatically")
        defaultValue: 100
        minimum: 20
        maximum: 200
        unit: "%"
    }

    SliderSetting {
        settingKey: "smoothing"
        label: I18n.tr("Smoothing")
        description: I18n.tr("Higher values create more fluid motion")
        defaultValue: 55
        minimum: 0
        maximum: 90
        unit: "%"
    }

    SliderSetting {
        settingKey: "glow"
        label: I18n.tr("Glow")
        defaultValue: 45
        minimum: 0
        maximum: 100
        unit: "%"
    }

    SliderSetting {
        settingKey: "backgroundOpacity"
        label: I18n.tr("Background opacity")
        defaultValue: 12
        minimum: 0
        maximum: 90
        unit: "%"
    }

    SliderSetting {
        settingKey: "fadeDelay"
        label: I18n.tr("Fade after silence")
        description: I18n.tr("Desktop widgets fade out; bar widgets keep their space and clear when silent")
        defaultValue: 4
        minimum: 1
        maximum: 20
        unit: "s"
    }
}
