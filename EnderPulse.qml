import QtQuick
import Quickshell
import qs.Modules.Plugins

DesktopPluginComponent {
    id: root

    implicitWidth: 520
    implicitHeight: 220
    minWidth: 240
    minHeight: 140

    EnderPulseVisualizer {
        anchors.fill: parent
        pluginData: root.pluginData
        instanceId: "desktop-" + root.instanceId
        defaultMode: "spectrum"
    }
}
