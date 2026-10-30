import QtQuick
import qs.Common
import qs.Modules.Plugins
import "EnderPulseLogic.js" as EnderPulseLogic

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
        const normalized = EnderPulseLogic.ensureBuiltInProfiles(current, builtIns)

        if (JSON.stringify(current) !== JSON.stringify(normalized))
            pluginService.savePluginData(pluginId, "variants", normalized)
        return true
    }

    Component.onCompleted: ensureSourceProfiles()
    onPluginServiceChanged: ensureSourceProfiles()
    onPluginIdChanged: ensureSourceProfiles()
}
