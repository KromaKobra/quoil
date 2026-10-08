import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: dock

    readonly property string edge: Config.barEdges.includes(Config.barEdge) ? Config.barEdge : "top"
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property real sizeScale: Math.max(0.1, Config.barScale)
    readonly property real cellSize: Math.max(Config.workspaceDotSize + 8, Config.workspaceSpacing)
    readonly property real dockDepth: Config.barThickness + dip.cornerRadius

    WlrLayershell.namespace: "quoil-workspaces"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: dock.vertical || dock.edge === "top"
        bottom: dock.edge === "bottom"
        left: !dock.vertical || dock.edge === "left"
        right: dock.edge === "right"
    }

    implicitWidth: Math.ceil((vertical ? dockDepth : dip.span) * sizeScale)
    implicitHeight: Math.ceil((vertical ? dip.span : dockDepth) * sizeScale)

    DockShape {
        id: dip

        anchors.centerIn: parent
        anchors.alignWhenCentered: false
        width: span
        height: dock.dockDepth
        length: navigation.workspaceCount * dock.cellSize + 2 * Config.workspacePadding
        depth: Config.barThickness
        attachedToStart: true
        scale: dock.sizeScale
        rotation: ({ top: 0, right: 90, bottom: 180, left: -90 })[dock.edge]
        transform: Scale {
            origin.x: dip.width / 2
            xScale: dock.edge === "bottom" || dock.edge === "left" ? -1 : 1
        }

        Item {
            x: dip.startInset + Config.workspacePadding
            width: navigation.workspaceCount * dock.cellSize
            height: Config.barThickness

            Repeater {
                model: navigation.workspaceCount

                Item {
                    id: workspace

                    required property int index
                    readonly property int workspaceId: index + 1
                    readonly property bool selected: navigation.activeWorkspace === workspaceId

                    x: index * dock.cellSize
                    width: dock.cellSize
                    height: Config.barThickness

                    Accessible.role: Accessible.Button
                    Accessible.name: "Workspace " + workspaceId
                    Accessible.checkable: true
                    Accessible.checked: selected
                    Accessible.onPressAction: navigation.activateWorkspace(workspaceId)

                    Rectangle {
                        anchors.centerIn: parent
                        width: Config.workspaceDotSize * (workspace.selected ? 1.3 : 1)
                        height: width
                        radius: width / 2
                        color: workspace.selected ? Config.workspaceActiveColour : Config.barTextColour
                        opacity: workspace.selected ? 1 : pointer.containsMouse ? 0.75 : 0.35

                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: pointer

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: navigation.activateWorkspace(workspace.workspaceId)
                        onWheel: wheel => wheel.accepted = false
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent

        WorkspaceWheelHandler {
            id: navigation

            screen: dock.screen
        }
    }
}
