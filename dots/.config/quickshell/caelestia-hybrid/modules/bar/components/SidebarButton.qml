import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ScreenState screenState

    implicitWidth: Tokens.sizes.bar.innerWidth
    implicitHeight: Tokens.sizes.bar.innerWidth
    width: implicitWidth
    height: implicitHeight

    StateLayer {
        anchors.fill: undefined
        anchors.centerIn: parent
        implicitWidth: implicitHeight
        implicitHeight: Tokens.sizes.bar.innerWidth
        radius: Tokens.rounding.full
        cursorShape: Qt.PointingHandCursor
        onClicked: root.screenState.sidebar = !root.screenState.sidebar
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: "dock_to_right"
        color: root.screenState.sidebar ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        fontStyle: Tokens.font.icon.medium
    }
}
