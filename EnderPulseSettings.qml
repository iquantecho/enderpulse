import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "enderPulse"

    property var detectedAudioSources: []
    property bool profileCreationPending: false
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
        const lines = output.split("\n")

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].trim().split(/\s+/)
            if (fields.length < 2)
                continue
            const source = fields[1]
            if (!source || seen[source])
                continue
            seen[source] = true
            const kind = source.endsWith(".monitor")
                ? I18n.tr("output monitor") : I18n.tr("input")
            options.push({ label: source + " (" + kind + ")", value: "pulse:" + source })
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
        return variants.some(function(variant) {
            return variant.audioTarget === target
                && (variant.audioBackend ?? "auto") === backend
                && (variant.customAudioSource ?? "") === customSource
        })
    }

    function addSourceProfile(target, name) {
        if (profileCreationPending || !pluginService)
            return
        const backend = audioBackendSetting.value
        const customSource = customAudioSourceSetting.value
        if (profileExists(target, backend, customSource))
            return

        profileCreationPending = true
        const current = pluginService.getPluginVariants(pluginId)
        const profile = {
            audioTarget: target,
            audioBackend: backend,
            customAudioSource: customSource,
            icon: "graphic_eq",
            description: I18n.tr("EnderPulse audio source: ") + sourceLabel(target)
        }
        profile.id = "source_" + Date.now()
        profile.name = name
        pluginService.savePluginData(pluginId, "variants", current.concat([profile]))
        loadVariants()
        profileCreationPending = false
    }

    Process {
        id: sourceDetector
        command: ["sh", "-c", "command -v pactl >/dev/null 2>&1 && pactl list short sources 2>/dev/null || true"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.loadDetectedSources(text)
        }
    }

    Component.onCompleted: sourceDetector.running = true

    StyledText {
        width: parent.width
        text: I18n.tr("DankBar widgets")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Add System output or Microphone input from Settings → DankBar → Widgets. Adding a widget happens only there; this page configures EnderPulse and optional extra audio-source profiles.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    SelectionSetting {
        id: audioTargetSetting
        settingKey: "audioTarget"
        label: I18n.tr("Audio source")
        description: I18n.tr("Visualize system output, microphone input, or a specific detected source")
        defaultValue: "system"
        options: root.audioSourceOptions
    }

    SelectionSetting {
        id: audioBackendSetting
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
        settingKey: "customAudioSource"
        label: I18n.tr("Custom Cava source")
        description: I18n.tr("Used when Audio source is Custom; accepts a PipeWire object, PulseAudio source, or other Cava source name")
        placeholder: "alsa_input… or object.serial"
        defaultValue: ""
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Additional DankBar source")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: I18n.tr("Optional: create another source profile from the selection above. This makes it available in DankBar's widget picker; it does not place it on the bar.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    DankButton {
        readonly property bool alreadyAvailable: root.profileExists(
            audioTargetSetting.value,
            audioBackendSetting.value,
            customAudioSourceSetting.value)

        width: parent.width
        text: alreadyAvailable
            ? I18n.tr("Selected source is already available")
            : I18n.tr("Create source profile")
        iconName: alreadyAvailable ? "check" : "add"
        enabled: !alreadyAvailable && !root.profileCreationPending
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

                DankButton {
                    id: removeButton
                    text: I18n.tr("Remove profile")
                    iconName: "delete"
                    onClicked: root.removeVariant(modelData.id)
                }
            }
        }
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
        label: I18n.tr("DankBar length")
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
        description: I18n.tr("More bands show finer audio detail")
        defaultValue: 48
        minimum: 16
        maximum: 96
    }

    SliderSetting {
        settingKey: "sensitivity"
        label: I18n.tr("Sensitivity")
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
        defaultValue: 4
        minimum: 1
        maximum: 20
        unit: "s"
    }
}
