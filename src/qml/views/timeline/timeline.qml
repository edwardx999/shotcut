/*
 * Copyright (c) 2013-2020 Meltytech, LLC
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.2
import QtQml.Models 2.1
import QtQuick.Controls 1.0
import Shotcut.Controls 1.0
import QtGraphicalEffects 1.0
import QtQuick.Window 2.2
import 'Timeline.js' as Logic

Rectangle {
    id: root
    SystemPalette { id: activePalette }
    color: activePalette.window

    signal clipClicked()

    function setZoom(value, targetX) {
        if (!targetX)
            targetX = scrollView.flickableItem.contentX + scrollView.width / 2
        var offset = targetX - scrollView.flickableItem.contentX
        var before = multitrack.scaleFactor

        toolbar.scaleSlider.value = value

        if (!settings.timelineCenterPlayhead)
            scrollView.flickableItem.contentX = Logic.clamp((targetX * multitrack.scaleFactor / before) - offset, 0, Logic.scrollMax().x)

        for (var i = 0; i < tracksRepeater.count; i++)
            tracksRepeater.itemAt(i).redrawWaveforms(false)
    }

    function adjustZoom(by, targetX) {
        setZoom(toolbar.scaleSlider.value + by, targetX)
    }

    function zoomIn() {
        adjustZoom(0.0625)
    }

    function zoomOut() {
        adjustZoom(-0.0625)
    }

    function zoomToFit() {
        setZoom(Math.pow((scrollView.width - 50) * multitrack.scaleFactor / tracksContainer.width - 0.01, 1/3))
    }

    function resetZoom() {
        setZoom(1.0)
    }

    function makeTracksTaller() {
        multitrack.trackHeight += 20
    }

    function makeTracksShorter() {
        multitrack.trackHeight = Math.max(10, multitrack.trackHeight - 20)
    }

    function pulseLockButtonOnTrack(index) {
        trackHeaderRepeater.itemAt(index).pulseLockButton()
    }

    function selectMultitrack() {
        for (var i = 0; i < trackHeaderRepeater.count; i++)
            trackHeaderRepeater.itemAt(i).selected = false
        cornerstone.selected = true
    }

    function trackAt(index) {
        return tracksRepeater.itemAt(index)
    }

    function resetDrag() {
        dragDelta = Qt.point(0, 0)
    }

    property int headerWidth: 140
    property int currentTrack: 0
    property color selectedTrackColor: Qt.rgba(0.8, 0.8, 0, 0.3);
    property alias trackCount: tracksRepeater.count
    property bool stopScrolling: false
    property color shotcutBlue: Qt.rgba(23/255, 92/255, 118/255, 1.0)
    property var dragDelta

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: menu.popup()
    }

    DropArea {
        anchors.fill: parent
        onEntered: {
            if (drag.formats.indexOf('application/vnd.mlt+xml') >= 0 || drag.hasUrls)
                drag.acceptProposedAction()
        }
        onExited: Logic.dropped()
        onPositionChanged: {
            if (drag.formats.indexOf('application/vnd.mlt+xml') >= 0 || drag.hasUrls)
                Logic.dragging(drag, drag.hasUrls? 0 : parseInt(drag.text))
        }
        onDropped: {
            if (drop.formats.indexOf('application/vnd.mlt+xml') >= 0) {
                if (currentTrack >= 0) {
                    Logic.acceptDrop(drop.getDataAsString('application/vnd.mlt+xml'))
                    drop.acceptProposedAction()
                }
            } else if (drop.hasUrls) {
                Logic.acceptDrop(drop.urls)
                drop.acceptProposedAction()
            }
            Logic.dropped()
        }
    }

    TimelineToolbar {
        id: toolbar
        width: parent.width
        anchors.top: parent.top
        z: 1
    }

    Row {
        anchors.top: toolbar.bottom
        Column {
            z: 1

            Rectangle {
                id: cornerstone
                property bool selected: false
                // Padding between toolbar and track headers.
                width: headerWidth
                height: ruler.height
                color: selected? shotcutBlue : activePalette.window
                border.color: selected? 'red' : 'transparent'
                border.width: selected? 1 : 0
                visible: trackHeaderRepeater.count
                z: 1
                Label {
                    text: qsTr('Output')
                    color: activePalette.windowText
                    elide: Qt.ElideRight
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 8
                }
                ToolButton {
                    visible: multitrack.filtered
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 20
                    implicitHeight: 20
                    iconName: 'view-filter'
                    iconSource: 'qrc:///icons/oxygen/32x32/status/view-filter.png'
                    tooltip: qsTr('Filters')
                    onClicked: {
                        timeline.selectMultitrack()
                        timeline.filteredClicked()
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        timeline.selectMultitrack()
                        if (mouse.button == Qt.RightButton) {
                            menu.popup()
                        }
                    }
                }
            }
            Flickable {
                // Non-slider scroll area for the track headers.
                contentY: scrollView.flickableItem.contentY
                width: headerWidth
                height: trackHeaders.height
                interactive: false

                Column {
                    id: trackHeaders
                    Repeater {
                        id: trackHeaderRepeater
                        model: multitrack
                        TrackHead {
                            trackName: model.name
                            isMute: model.mute
                            isHidden: model.hidden
                            isComposite: model.composite
                            isLocked: model.locked
                            isVideo: !model.audio
                            isFiltered: model.filtered
                            isBottomVideo: model.isBottomVideo
                            width: headerWidth
                            height: Logic.trackHeight(model.audio)
                            selected: false
                            current: index === currentTrack
                            onIsLockedChanged: tracksRepeater.itemAt(index).isLocked = isLocked
                            onClicked: {
                                currentTrack = index
                                timeline.selectTrackHead(currentTrack)
                            }
                        }
                    }
                }
                Rectangle {
                    // thin dividing line between headers and tracks
                    color: activePalette.windowText
                    width: 1
                    x: parent.x + parent.width
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                }
            }
        }
        MouseArea {
            id: tracksArea
            width: root.width - headerWidth
            height: root.height

            // This provides continuous scrubbing and scimming at the left/right edges.
            focus: true
            hoverEnabled: true
            onClicked: {
                timeline.position = (scrollView.flickableItem.contentX + mouse.x) / multitrack.scaleFactor
                bubbleHelp.hide()
            }
            property bool scim: false
            onReleased: scim = false
            onExited: scim = false
            onPositionChanged: {
                if (mouse.modifiers === (Qt.ShiftModifier | Qt.AltModifier) || mouse.buttons === Qt.LeftButton) {
                    timeline.position = (scrollView.flickableItem.contentX + mouse.x) / multitrack.scaleFactor
                    bubbleHelp.hide()
                    scim = true
                } else {
                    scim = false
                }
            }
            onWheel: Logic.onMouseWheel(wheel)

            Timer {
                id: scrubTimer
                interval: 25
                repeat: true
                running: parent.scim && parent.containsMouse
                         && (parent.mouseX < 50 || parent.mouseX > parent.width - 50)
                         && (timeline.position * multitrack.scaleFactor >= 50)
                onTriggered: {
                    if (parent.mouseX < 50)
                        timeline.position -= 10
                    else
                        timeline.position += 10
                }
            }

            Column {
                Flickable {
                    // Non-slider scroll area for the Ruler.
                    id: rulerFlickable
                    contentX: scrollView.flickableItem.contentX
                    width: root.width - headerWidth
                    height: ruler.height
                    interactive: false
                    // workaround to fix https://github.com/mltframework/shotcut/issues/777
                    onContentXChanged: if (contentX === 0) contentX = scrollView.flickableItem.contentX

                    Ruler {
                        id: ruler
                        width: tracksContainer.width
                        timeScale: multitrack.scaleFactor
                    }
                }
                ScrollView {
                    id: scrollView
                    width: root.width - headerWidth
                    height: root.height - ruler.height - toolbar.height
                    // workaround to fix https://github.com/mltframework/shotcut/issues/777
                    flickableItem.onContentXChanged: rulerFlickable.contentX = flickableItem.contentX
        
                    MouseArea {
                        width: tracksContainer.width + headerWidth
                        height: Math.max(trackHeaders.height + 30, root.height - ruler.height - toolbar.height)
                        acceptedButtons: Qt.NoButton
                        onWheel: Logic.onMouseWheel(wheel)

                        Column {
                            // These make the striped background for the tracks.
                            // It is important that these are not part of the track visual hierarchy;
                            // otherwise, the clips will be obscured by the Track's background.
                            Repeater {
                                model: multitrack
                                delegate: Rectangle {
                                    width: tracksContainer.width
                                    color: (index === currentTrack)? selectedTrackColor : (index % 2)? activePalette.alternateBase : activePalette.base
                                    height: Logic.trackHeight(audio)
                                }
                            }
                        }
                        Column {
                            id: tracksContainer
                            Repeater { id: tracksRepeater; model: trackDelegateModel }
                        }
                        Item {
                            id: selectionContainer
                            visible: false
                            Repeater {
                                id: selectionRepeater
                                model: timeline.selection
                                Rectangle {
                                    property var clip: trackAt(modelData.y).clipAt(modelData.x)
                                    property var track: trackAt(clip.trackIndex + dragDelta.y)
                                    x: clip.x + dragDelta.x
                                    y: track.y
                                    width: clip.width
                                    height: track.height
                                    color: 'transparent'
                                    border.color: 'red'
                                    visible: !clip.Drag.active && clip.trackIndex === clip.originalTrackIndex
                                }
                            }
                        }

                    }
                }
            }

            CornerSelectionShadow {
                y: tracksRepeater.count ? tracksRepeater.itemAt(currentTrack).y + ruler.height - scrollView.flickableItem.contentY : 0
                clip: timeline.selection.length ?
                        tracksRepeater.itemAt(timeline.selection[0].y).clipAt(timeline.selection[0].x) : null
                opacity: clip && clip.x + clip.width < scrollView.flickableItem.contentX ? 1 : 0
            }

            CornerSelectionShadow {
                y: tracksRepeater.count ? tracksRepeater.itemAt(currentTrack).y + ruler.height - scrollView.flickableItem.contentY : 0
                clip: timeline.selection.length ?
                        tracksRepeater.itemAt(timeline.selection[timeline.selection.length - 1].y).clipAt(timeline.selection[timeline.selection.length - 1].x) : null
                opacity: clip && clip.x > scrollView.flickableItem.contentX + scrollView.width ? 1 : 0
                anchors.right: parent.right
                mirrorGradient: true
            }

            Rectangle {
                id: cursor
                visible: timeline.position > -1
                color: activePalette.text
                width: 1
                height: root.height - scrollView.__horizontalScrollBar.height - toolbar.height
                x: timeline.position * multitrack.scaleFactor - scrollView.flickableItem.contentX
                y: 0
            }
            TimelinePlayhead {
                id: playhead
                visible: timeline.position > -1
                x: timeline.position * multitrack.scaleFactor - scrollView.flickableItem.contentX - 5
                y: 0
                width: 11
                height: 5
            }
        }
    }

    Rectangle {
        id: dropTarget
        height: multitrack.trackHeight
        opacity: 0.5
        visible: false
        Text {
            anchors.fill: parent
            anchors.leftMargin: 100
            text: settings.timelineRipple? qsTr('Insert') : qsTr('Overwrite')
            style: Text.Outline
            styleColor: 'white'
            font.pixelSize: Math.min(Math.max(parent.height * 0.8, 15), 30)
            verticalAlignment: Text.AlignVCenter
        }
    }

    Rectangle {
        id: bubbleHelp
        property alias text: bubbleHelpLabel.text
        color: application.toolTipBaseColor
        width: bubbleHelpLabel.width + 8
        height: bubbleHelpLabel.height + 8
        radius: 4
        states: [
            State { name: 'invisible'; PropertyChanges { target: bubbleHelp; opacity: 0} },
            State { name: 'visible'; PropertyChanges { target: bubbleHelp; opacity: 1} }
        ]
        state: 'invisible'
        transitions: [
            Transition {
                from: 'invisible'
                to: 'visible'
                OpacityAnimator { target: bubbleHelp; duration: 200; easing.type: Easing.InOutQuad }
            },
            Transition {
                from: 'visible'
                to: 'invisible'
                OpacityAnimator { target: bubbleHelp; duration: 200; easing.type: Easing.InOutQuad }
            }
        ]
        Label {
            id: bubbleHelpLabel
            color: application.toolTipTextColor
            anchors.centerIn: parent
        }
        function show(x, y, text) {
            bubbleHelp.x = x + tracksArea.x - scrollView.flickableItem.contentX - bubbleHelpLabel.width
            bubbleHelp.y = Math.max(toolbar.height, y + tracksArea.y - scrollView.flickableItem.contentY - bubbleHelpLabel.height)
            bubbleHelp.text = text
            if (bubbleHelp.state !== 'visible')
                bubbleHelp.state = 'visible'
        }
        function hide() {
            bubbleHelp.state = 'invisible'
            bubbleHelp.opacity = 0
        }
    }
    DropShadow {
        source: bubbleHelp
        anchors.fill: bubbleHelp
        opacity: bubbleHelp.opacity
        horizontalOffset: 3
        verticalOffset: 3
        radius: 8
        color: '#80000000'
        transparentBorder: true
        fast: true
    }

    Menu {
        id: menu
        MenuItem {
            text: qsTr('Add Audio Track')
            shortcut: 'Ctrl+U'
            onTriggered: timeline.addAudioTrack();
        }
        MenuItem {
            text: qsTr('Add Video Track')
            shortcut: 'Ctrl+I'
            onTriggered: timeline.addVideoTrack();
        }
        MenuItem {
            text: qsTr('Insert Track')
            shortcut: 'Ctrl+Alt+I'
            onTriggered: timeline.insertTrack()
        }
        MenuItem {
            text: qsTr('Remove Track')
            shortcut: 'Ctrl+Alt+U'
            onTriggered: timeline.removeTrack()
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr('Select All')
            shortcut: 'Ctrl+A'
            onTriggered: timeline.selectAll()
        }
        MenuItem {
            text: qsTr('Select None')
            shortcut: 'Ctrl+D'
            onTriggered: {
                timeline.selection = []
                multitrack.reload()
            }
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("Ripple All Tracks")
            shortcut: 'Ctrl+Alt+R'
            checkable: true
            checked: settings.timelineRippleAllTracks
            onTriggered: settings.timelineRippleAllTracks = checked
        }
        MenuItem {
            text: qsTr('Copy Timeline to Source')
            shortcut: 'Ctrl+Alt+C'
            onTriggered: timeline.copyToSource()
        }
        MenuSeparator {}
        MenuItem {
            enabled: multitrack.trackHeight > 10
            text: qsTr('Make Tracks Shorter')
            shortcut: 'Ctrl+-'
            onTriggered: makeTracksShorter()
        }
        MenuItem {
            text: qsTr('Make Tracks Taller')
            shortcut: 'Ctrl+='
            onTriggered: makeTracksTaller()
        }
        MenuItem {
            text: qsTr('Reset Track Height')
            onTriggered: multitrack.trackHeight = 50
        }
        MenuItem {
            text: qsTr('Show Audio Waveforms')
            checkable: true
            checked: settings.timelineShowWaveforms
            onTriggered: {
                if (checked) {
                    if (settings.timelineShowWaveforms) {
                        settings.timelineShowWaveforms = checked
                        for (var i = 0; i < tracksRepeater.count; i++)
                            tracksRepeater.itemAt(i).redrawWaveforms()
                    } else {
                        settings.timelineShowWaveforms = checked
                        for (i = 0; i < tracksRepeater.count; i++)
                            tracksRepeater.itemAt(i).remakeWaveforms(false)
                    }
                } else {
                    settings.timelineShowWaveforms = checked
                }
            }
        }
        MenuItem {
            text: qsTr('Show Video Thumbnails')
            checkable: true
            checked: settings.timelineShowThumbnails
            onTriggered: settings.timelineShowThumbnails = checked
        }
        MenuItem {
            text: qsTr('Center the Playhead')
            checkable: true
            checked: settings.timelineCenterPlayhead
            onTriggered: settings.timelineCenterPlayhead = checked
        }
        MenuSeparator {}
        MenuItem {
            id: propertiesMenuItem
            visible: false
            text: qsTr('Properties')
            onTriggered: timeline.openProperties()
        }
        MenuItem {
            text: qsTr('Reload')
            onTriggered: multitrack.reload()
        }
        onPopupVisibleChanged: {
            if (visible && application.OS === 'Windows' && __popupGeometry.height > 0) {
                // Try to fix menu running off screen. This only works intermittently.
                menu.__yOffset = Math.min(0, Screen.height - (__popupGeometry.y + __popupGeometry.height + 40))
                menu.__xOffset = Math.min(0, Screen.width - (__popupGeometry.x + __popupGeometry.width))
            }
        }
    }

    DelegateModel {
        id: trackDelegateModel
        model: multitrack
        Track {
            model: multitrack
            rootIndex: trackDelegateModel.modelIndex(index)
            height: Logic.trackHeight(audio)
            isAudio: audio
            isMute: mute
            isCurrentTrack: currentTrack === index
            timeScale: multitrack.scaleFactor
            onClipClicked: {
                var trackIndex = track.DelegateModel.itemsIndex
                var clipIndex = clip.DelegateModel.itemsIndex
                currentTrack = trackIndex
                if (mouse && mouse.modifiers & Qt.ControlModifier)
                    timeline.selection = Logic.toggleSelection(trackIndex, clipIndex)
                else if (mouse && mouse.modifiers & Qt.ShiftModifier)
                    timeline.selection = Logic.selectRange(trackIndex, clipIndex)
                else if (!Logic.selectionContains(trackIndex, clipIndex))
                    // select one
                    timeline.selection = [Qt.point(clipIndex, trackIndex)]
                root.clipClicked()
            }
            onClipDragged: {
                // This provides continuous scrolling at the left/right edges.
                if (x > scrollView.flickableItem.contentX + scrollView.width - 50) {
                    scrollTimer.item = clip
                    scrollTimer.backwards = false
                    scrollTimer.start()
                } else if (x < 50) {
                    scrollView.flickableItem.contentX = 0;
                    scrollTimer.stop()
                } else if (x < scrollView.flickableItem.contentX + 50) {
                    scrollTimer.item = clip
                    scrollTimer.backwards = true
                    scrollTimer.start()
                } else {
                    scrollTimer.stop()
                }
                dragDelta = Qt.point(clip.x - clip.originalX, clip.trackIndex - clip.originalTrackIndex)
                selectionContainer.visible = true
            }
            onClipDropped: {
                scrollTimer.running = false
                bubbleHelp.hide()
                selectionContainer.visible = false
            }
            onClipDraggedToTrack: {
                var i = clip.trackIndex + direction
                var track = trackAt(i)
                clip.reparent(track)
                clip.trackIndex = track.DelegateModel.itemsIndex
            }
            onCheckSnap: {
                for (var i = 0; i < tracksRepeater.count; i++)
                    tracksRepeater.itemAt(i).snapClip(clip)
            }
            Image {
                anchors.fill: parent
                source: "qrc:///icons/light/16x16/track-locked.png"
                fillMode: Image.Tile
                opacity: parent.isLocked
                visible: opacity
                Behavior on opacity { NumberAnimation {} }
                MouseArea {
                    anchors.fill: parent
                    onPressed: {
                        mouse.accepted = true;
                        trackHeaderRepeater.itemAt(index).pulseLockButton()
                    }
                }
            }
        }
    }
    
    Connections {
        target: timeline
        onPositionChanged: if (!stopScrolling) Logic.scrollIfNeeded()
        onDragging: Logic.dragging(pos, duration)
        onDropped: Logic.dropped()
        onDropAccepted: Logic.acceptDrop(xml)
        onSelectionChanged: {
            cornerstone.selected = timeline.isMultitrackSelected()
            var selectedTrack = timeline.selectedTrack()
            for (var i = 0; i < trackHeaderRepeater.count; i++)
                trackHeaderRepeater.itemAt(i).selected = (i === selectedTrack)
            propertiesMenuItem.visible = (cornerstone.selected || (selectedTrack >= 0 && selectedTrack < trackHeaderRepeater.count))
        }
        onZoomIn: zoomIn()
        onZoomOut: zoomOut()
        onZoomToFit: zoomToFit()
        onResetZoom: resetZoom()
        onMakeTracksShorter: makeTracksShorter()
        onMakeTracksTaller: makeTracksTaller()
    }

    Connections {
        target: multitrack
        onLoaded: toolbar.scaleSlider.value = Math.pow(multitrack.scaleFactor - 0.01, 1.0 / 3.0)
        onScaleFactorChanged: if (settings.timelineCenterPlayhead) Logic.scrollIfNeeded()
    }

    // This provides continuous scrolling at the left/right edges.
    Timer {
        id: scrollTimer
        interval: 25
        repeat: true
        triggeredOnStart: true
        property var item
        property bool backwards
        onTriggered: {
            var delta = backwards? -10 : 10
            if (item) item.x += delta
            scrollView.flickableItem.contentX += delta
            if (scrollView.flickableItem.contentX <= 0)
                stop()
        }
    }
}
