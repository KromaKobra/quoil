import "navpane"
import QtQuick
import QtQuick.Layouts
import Quoil.Config
import qs.modules.nexus

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.large

    SearchBar {
        Layout.fillWidth: true
        nState: root.nState
    }

    NavLocations {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -topMargin
        Layout.bottomMargin: -bottomMargin
        nState: root.nState
    }
}
