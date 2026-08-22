import QtQuick
import Quickshell
import qs.Modules.Plugins

PluginComponent {
    id: root

    layerNamespacePlugin: "enderpulse"

    property string variantId: ""
    property var variantData: null
    property var popoutService: null

    pillClickAction: () => popoutService?.openSettingsWithTab("plugins")

    readonly property var visualizerData: {
        const shared = root.pluginData ?? ({})
        const instance = root.variantData ?? ({})
        return Object.assign({}, shared, instance)
    }
    readonly property int visualizerLength: Math.max(80, Math.min(420, visualizerData.barLength ?? 180))
    readonly property string screenKey: parentScreen?.name ?? "default"
    readonly property string instanceKey: variantId && variantId.length > 0 ? variantId : "default"

    horizontalBarPill: Component {
        Item {
            implicitWidth: root.visualizerLength
            implicitHeight: root.widgetThickness

            EnderPulseVisualizer {
                anchors.fill: parent
                pluginData: root.visualizerData
                instanceId: "bar-horizontal-" + root.screenKey + "-" + root.instanceKey
                defaultMode: "spectrum"
                compact: true
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.widgetThickness
            implicitHeight: root.visualizerLength

            EnderPulseVisualizer {
                anchors.centerIn: parent
                width: parent.height
                height: parent.width
                rotation: -90
                pluginData: root.visualizerData
                instanceId: "bar-vertical-" + root.screenKey + "-" + root.instanceKey
                defaultMode: "spectrum"
                compact: true
            }
        }
    }
}
