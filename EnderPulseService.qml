import QtQuick
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    function builtInVariant(id, name, target, icon) {
        return {
            id: id,
            name: name,
            audioTarget: target,
            audioBackend: "auto",
            customAudioSource: "",
            icon: icon,
            description: I18n.tr("EnderPulse audio source: ") + name
        }
    }

    function ensureSourceProfiles() {
        if (!pluginService || !pluginId)
            return false

        const current = pluginService.getPluginVariants(pluginId)
        const builtIns = [
            builtInVariant("builtin_output", I18n.tr("System output"), "system", "volume_up"),
            builtInVariant("builtin_microphone", I18n.tr("Microphone input"), "microphone", "mic")
        ]
        const normalized = builtIns.concat(current.filter(function(variant) {
            return variant.audioTarget !== "system" && variant.audioTarget !== "microphone"
        }))

        if (JSON.stringify(current) !== JSON.stringify(normalized))
            pluginService.savePluginData(pluginId, "variants", normalized)
        return true
    }

    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (root.ensureSourceProfiles())
                stop()
        }
    }
}
