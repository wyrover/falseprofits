import QtQuick 2.4
import QtQuick.Controls 2.2

import com.example.fpx 1.0

DetailedQuotePageForm {
    signal tradeButtonClicked(string symbol)

    property string currentSymbol
    property int busyIndicatorVisibility: 0

    orderButton.onClicked: {
        if (currentSymbol !== "") {
            tradeButtonClicked(currentSymbol)
        }
    }

    starButton.onClicked: {
        toggleStarred()
    }

    onCurrentSymbolChanged: {
        clearQuote()
        symbolText = currentSymbol
        updateQuote()
        updateStarredState()
    }

    Dialog {
        id: errorDialog
        parent: appNavStack
        title: qsTr("Error")
        standardButtons: Dialog.Ok
        modal: true
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        implicitHeight: 160
        implicitWidth: parent.width * 0.9

        Label {
            id: errorDialogText
            anchors.fill: parent
            wrapMode: Text.WordWrap
        }
    }

    function clearQuote() {
        companyNameText = ""
        industryText = ""
        lastPriceLabel.text = ""
        bidText = ""
        askText = ""
        changePriceText = ""
        direction = 0
        changePercentText = ""
        dayLowText = ""
        dayHighText = ""
    }

    function updateQuote() {
        incrementBusyIndicatorVisibility()
        var quoteResp = fpCore.getQuotes(currentSymbol)
        quoteResp.onFinished.connect(function() {
            decrementBusyIndicatorVisibility()
            if (!quoteResp.hasError()) {
                var quotes = fpType.makeJsonQuotes(quoteResp.payload())
                var quote = quotes.find(currentSymbol)
                if (quote.isValid) {
                    lastPriceLabel.text = quote.last
                    bidText = quote.bid
                    askText = quote.ask

                    var change = quote.change
                    changePriceText = change ? quote.change : "-"
                    direction = change > 0 ? 1 : change < 0 ? -1 : 0

                    var pctChange = quote.changePercent
                    changePercentText = pctChange ? qsTr("%1%").arg(pctChange) : "-"

                    dayLowText = quote.dayLow
                    dayHighText = quote.dayHigh
                }
            } else {
                errorDialogText.text = quoteResp.errorMessage()
                errorDialog.open()
            }
        })

        incrementBusyIndicatorVisibility()
        var detailsResp = fpCore.getShareDetails(currentSymbol)
        detailsResp.onFinished.connect(function() {
            decrementBusyIndicatorVisibility()
            if (!detailsResp.hasError()) {
                companyNameText = detailsResp.companyName
                industryText = detailsResp.industry
            } else {
                errorDialogText.text = detailsResp.errorMessage()
                errorDialog.open()
            }
        })
    }

    function updateStarredState() {
        starred = watchlistWrapper.model.getRowOfSymbol(currentSymbol) >= 0
    }

    function toggleStarred() {
        if (currentSymbol !== "") {
            if (!starred) {
                var addNotifier = watchlistWrapper.addSymbol(currentSymbol)
                incrementBusyIndicatorVisibility()
                addNotifier.onFinished.connect(function() {
                    // TODO(seamus): Handle errors
                    decrementBusyIndicatorVisibility()
                    updateStarredState()
                })
            } else {
                var removeNotifier = watchlistWrapper.removeSymbol(currentSymbol)
                incrementBusyIndicatorVisibility()
                removeNotifier.onFinished.connect(function() {
                    // TODO(seamus): Handle errors
                    decrementBusyIndicatorVisibility()
                    updateStarredState()
                })
            }
        }
    }

    function incrementBusyIndicatorVisibility() {
        busyIndicator.visible = true
        busyIndicatorVisibility = busyIndicatorVisibility + 1
    }

    function decrementBusyIndicatorVisibility() {
        busyIndicatorVisibility = busyIndicatorVisibility - 1
        if (busyIndicatorVisibility == 0) {
            busyIndicator.visible = false
        }
    }
}
