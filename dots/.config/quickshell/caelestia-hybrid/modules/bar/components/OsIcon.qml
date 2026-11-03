import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    property ScreenState screenState: null

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
        onClicked: {
            const s = root.screenState ?? ShellState.forActive();
            if (s) {
                s.launcher = !s.launcher;
            }
        }
    }

    Item {
        id: iconWrapper
        anchors.centerIn: parent
        width: 28
        height: 28
        transformOrigin: Item.Center

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 8000
            direction: RotationAnimation.Clockwise
            loops: Animation.Infinite
            running: root.visible
        }

        Image {
            id: emblemImage
            anchors.centerIn: parent
            width: 28
            height: 28
            source: "file://" + Paths.home + "/.local/share/redshift-os/icons/redshift-symbolic-compact.svg"
            fillMode: Image.PreserveAspectFit
            sourceSize.width: 64
            sourceSize.height: 64
            mipmap: true
            smooth: true
            asynchronous: true
            transformOrigin: Item.Center

            layer.enabled: true
            layer.effect: Colouriser {
                colorizationColor: (root.screenState?.launcher) ? Colours.palette.m3primary : Colours.palette.m3primary
            }
        }
    }
}
