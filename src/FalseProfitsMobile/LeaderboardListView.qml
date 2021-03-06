import QtQuick 2.7
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Window 2.2

import com.example.fpx 1.0
import io.material.xtra 1.0

ListView {
    id: listView
    focus: true
    clip: true
    currentIndex: -1
    boundsBehavior: Flickable.DragOverBounds

    delegate: ItemDelegate {
        height: delegateContent.height
        width: parent.width
        hoverEnabled: true

        ColumnLayout {
            id: delegateContent
            width: parent.width
            spacing: 0
            height: 60

            GridLayout {
                id: mainGrid
                Layout.leftMargin: FpStyle.screenEdgeLeftMargin
                Layout.topMargin: 3
                Layout.rightMargin: FpStyle.screenEdgeRightMargin
                Layout.bottomMargin: 3
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                columns: 5

                Image {
                    source: model.gravatarUrl ? model.gravatarUrl + "&s=" +
                                                Math.ceil(42 * Screen.devicePixelRatio) : ""
                    Layout.rowSpan: 2
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    fillMode: Image.PreserveAspectCrop
                }

                Label {
                    text: fpLocale.toIntString(model.rank)
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: 40
                    Layout.rowSpan: 2
                }

                Label {
                    text: model.displayName + (model.isCurrentUser ? " (me)" : "")
                    elide: Text.ElideRight
                    font.pixelSize: 16
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    Layout.rowSpan: 2
                }

                Label {
                    text: qsTr("%1%").arg(fpLocale.toDecimalString(model.profitPercent, 2))
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignRight
                    Layout.rowSpan: 2
                }
            }
        }
    }

    // Pull to refresh.
    onContentYChanged: {
        // If listView is pulled 200 points beyond it's maximum,
        // and it's not busy doing something, then refresh.
        if (contentY < -30 && contentY > -150)
        {
            if(!busyIndicator.visible)
                refreshTip.visible = true;
        }else {
            refreshTip.visible = false;
        }

        if(contentY < -200){
            if(busyIndicator.visible){
                return;
            } else {
                refreshLeaderboard()
            }
        }
    }

    // Label to indicate Pull to Refresh feature
    // Appears slightly below top of list, when list is pulled down a bit.
    Label {
        id: refreshTip
        text: "Pull to refresh..."
        visible: false
        parent: listView
        font.italic: true
        topPadding: 20
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }
}
