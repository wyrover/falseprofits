import QtQuick 2.4
import QtQuick.Controls 2.2

import com.example.fpx 1.0

BigChartPageForm {
    property string currentSymbol
    property string chartDataRange: "1mo"
    property string chartInterval: "1h"
    property int candleOpenMode: 0
    property int candlesRequestId: 0
    property var historyData
    property int tickCountForWidth: 5

    FpChartDataWrapper {
        id: chartDataWrapper
        coreClient: fpCore
    }

    Component.onCompleted: {
        chartDataWrapper.hackMargin(bigChartView.candleSeries)
        chartDataWrapper.hackCandlestickSeriesPen(bigChartView.candleSeries, "#000", 1.0, true)
        bigChartView.candleSeries.visible = candleCharTypeButton.checked

        intervalText = chartInterval.toUpperCase()
    }

    Component.onDestruction: {
        chartDataWrapper.hackRemoveAllSeriesAndAxes(bigChartView.candleSeries)
    }

    bigChartView.onWidthChanged: {
        updateLastPriceLabel()
    }

    bigChartView.onHeightChanged: {
        updateLastPriceLabel()
    }

    onCurrentSymbolChanged: {
        symbolText = currentSymbol
        updateSmallChartTitle()
        fillChart()
    }

    onChartIntervalChanged: {
        intervalText = chartInterval.toUpperCase()
        updateSmallChartTitle()
    }

    onChartDataRangeChanged: {
        if (chartDataRange == "1d") {chartInterval = "2m"}
        else if (chartDataRange == "5d") {chartInterval = "15m"}
        else if (chartDataRange == "1mo") {chartInterval = "1h"}
        else if (chartDataRange == "6mo") {chartInterval = "1d"}
        else if (chartDataRange == "ytd") {chartInterval = "1d"}
        else if (chartDataRange == "1y")  {chartInterval = "1wk"}
        else if (chartDataRange == "5y") {chartInterval = "1mo"}
        else if (chartDataRange == "max") {chartInterval = "1mo"}

        syncRangeButtonGroupWithChartInterval()

        fillChart()
    }

    rangeButtonGroup.onClicked2: {
        chartDataRange = button.text
    }

    onWidthChanged: {
        tickCountForWidth = Math.round(Math.min(5, width / 140))
    }

    onTickCountForWidthChanged: {
        bigChartView.xAxis.tickCount = tickCountForWidth
        updateTickLabels()
    }

    chartTypeButtonGroup.onClicked2: {
        bigChartView.lineSeries.visible = lineChartTypeButton.checked
        bigChartView.candleSeries.visible = candleCharTypeButton.checked
    }

    bigChartView.candleSeries.onVisibleChanged: {
        if (!bigChartView.candleSeries.visible) {
            bigChartView.candleSeries.clear()
            updateLineSeries()
        } else {
            updateCandleSeries()
        }
    }

    function updateLineSeries() {
        chartDataWrapper.updateCloseSeries(bigChartView.lineSeries, historyData)
    }

    function updateCandleSeries() {
        if (candleOpenMode === 1) {
            chartDataWrapper.updateSeriesPrevClose(bigChartView.candleSeries, historyData)
        } else {
            chartDataWrapper.updateSeriesFirstTick(bigChartView.candleSeries, historyData)
        }
    }

    function updateLastPriceLabel() {
        // This function uses historyData instead of getting the last
        // price from the series as CandlestickSeries.at() doesn't work
        // (always returns null)

        if (!historyData) {
            return;
        }

        var lastClosePrice = historyData.close.length > 0 ?
                    historyData.close[historyData.close.length - 1] : undefined
        var lastBarIndex = historyData.xData.length >= historyData.close.length ?
                    historyData.close.length : undefined

        if (lastBarIndex && lastClosePrice) {
            axisLastPriceLabel.visible = true
            axisLastPriceLabel.text = fpLocale.toShortDecimalString(lastClosePrice)
            var lastPoint = bigChartView.mapToPosition(
                        Qt.point(lastBarIndex, lastClosePrice),
                        !bigChartView.candleSeries.visible ? bigChartView.lineSeries :
                                                             bigChartView.candleSeries)
            axisLastPriceLabel.xBackbone = lastPoint.x
            axisLastPriceLabel.lastPricePixel = lastPoint.y
        } else {
            axisLastPriceLabel.visible = false
        }
    }

    function syncRangeButtonGroupWithChartInterval() {
        for (var i = 0; i < rangeButtonGroup.buttons.length; ++i) {
            if (rangeButtonGroup.buttons[i].text.toLowerCase() === chartDataRange.toLowerCase()) {
                if (!rangeButtonGroup.buttons[i].checked) {
                    rangeButtonGroup.buttons[i].checked = true
                }

                break
            }
        }
    }

    function fitDataRange() {
        if (!historyData) {
            return
        }

        // TODO return struct from C++ containing all min max for x&y
        var minPrice = chartDataWrapper.minPrice(historyData)
        var maxPrice = chartDataWrapper.maxPrice(historyData)
        if (maxPrice === 0) {
            maxPrice = 1000
        }
        var padding = maxPrice !== minPrice ? ((maxPrice - minPrice) * 0.05) : 0.01
        minPrice -= padding
        maxPrice += padding
        bigChartView.yAxis.min = minPrice
        bigChartView.yAxis.max = maxPrice

        bigChartView.xAxis.min = 0
        bigChartView.xAxis.max = historyData.xData.length

        updateLastPriceLabel()
        updateSmallChartTitle()
    }

    function updateTickLabels() {
        if (!historyData) {
            return
        }

        var dateFormat = ""
        if (chartDataRange === "1d" || chartInterval === "1m" || chartInterval === "2m") {
            dateFormat = "hh:mm"
        } else if (chartInterval === "1h") {
            dateFormat = "dd MMM"
        } else {
            dateFormat = "dd MMM yy"
        }

        bigChartView.xAxisLabelsAxis.categories = chartDataWrapper.makeDateCategoryLabels(
                    historyData, bigChartView.xAxis.tickCount, dateFormat)
    }

    function fillChart() {
        var reqArgs = fpType.makeCandlesRequestArgs()
        reqArgs.symbol = currentSymbol
        reqArgs.range = chartDataRange
        reqArgs.interval = chartInterval

        var candlesResp = chartDataWrapper.getCandles(reqArgs)
        var thisRequestId = candlesRequestId + 1
        candlesRequestId = thisRequestId
        busyIndicator.incrementVisibility()
        candlesResp.onFinished.connect(function() {
            busyIndicator.decrementVisibility()

            if (thisRequestId < candlesRequestId) {
                return
            }

            var hist = chartDataWrapper.makeCandleSeries(candlesResp.payload());
            historyData = hist
            maybeHasChartData = hist.xData.length > 0

            if (bigChartView.candleSeries.visible) {
                updateCandleSeries()
            }
            if (bigChartView.lineSeries.visible) {
                updateLineSeries()
            }

            fitDataRange()
            updateTickLabels()
        })
    }

    function updateSmallChartTitle() {
        // This function uses historyData instead of getting the last
        // price from the series as CandlestickSeries.at() doesn't work
        // (always returns null)

        var haveTitle = false

        if (historyData) {
            var lastClosePrice = historyData.close.length > 0 ?
                        historyData.close[historyData.close.length - 1] : undefined
            var lastOpenPrice = historyData.close.length >= historyData.open.length ?
                        historyData.open[historyData.close.length - 1] : undefined
            var lastHighPrice = historyData.close.length >= historyData.high.length ?
                        historyData.high[historyData.high.length - 1] : undefined
            var lastLowPrice = historyData.close.length >= historyData.low.length ?
                        historyData.low[historyData.close.length - 1] : undefined
            var lastBarIndex = historyData.xData.length >= historyData.close.length ?
                        historyData.close.length : undefined

            if (lastBarIndex && lastClosePrice && lastOpenPrice && lastHighPrice && lastLowPrice) {
                smallChartTitle = symbolText + ", " + intervalText + ",  O: " +
                        fpLocale.toShortDecimalString(lastOpenPrice) + "  H: " +
                        fpLocale.toShortDecimalString(lastHighPrice) + "  L: " +
                        fpLocale.toShortDecimalString(lastLowPrice) + "  C: " +
                        fpLocale.toShortDecimalString(lastClosePrice)
                haveTitle = true
            }
        }

        if (!haveTitle) {
            smallChartTitle = symbolText + ", " + intervalText
        }
    }

    function onRefreshTriggered() {
        fillChart()
    }
}
