pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services

Item {
    id: root

    property bool skipIntroAnimation: false
    property bool animated: true
    property bool colored: false
    property color topColour: Colours.palette.m3primary
    property color bottomColour: Colours.palette.m3onSurface

    signal animationCompleted

    implicitWidth: 112
    implicitHeight: 112

    Logo {
        id: logo
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        animated: root.animated
        colored: root.colored
        topColour: root.topColour
        bottomColour: root.bottomColour
    }

    Component.onCompleted: {
        root.animationCompleted();
    }
}
