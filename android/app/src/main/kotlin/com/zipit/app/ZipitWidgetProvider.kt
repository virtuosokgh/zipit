package com.zipit.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews

class ZipitWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.zipit_widget_layout)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

            val regionName = prefs.getString("region_name", "최신 실거래") ?: "최신 실거래"
            val avgPrice = prefs.getString("avg_price", "") ?: ""

            views.setTextViewText(R.id.region_name, regionName)
            views.setTextViewText(R.id.avg_price, avgPrice)

            // 실거래 5개 행
            val tradeRowIds = intArrayOf(
                R.id.trade_row_1, R.id.trade_row_2, R.id.trade_row_3,
                R.id.trade_row_4, R.id.trade_row_5
            )
            val tradeNameIds = intArrayOf(
                R.id.trade_name_1, R.id.trade_name_2, R.id.trade_name_3,
                R.id.trade_name_4, R.id.trade_name_5
            )
            val tradePriceIds = intArrayOf(
                R.id.trade_price_1, R.id.trade_price_2, R.id.trade_price_3,
                R.id.trade_price_4, R.id.trade_price_5
            )
            val tradeDateIds = intArrayOf(
                R.id.trade_date_1, R.id.trade_date_2, R.id.trade_date_3,
                R.id.trade_date_4, R.id.trade_date_5
            )

            for (i in 0 until 5) {
                val name = prefs.getString("trade_name_$i", "") ?: ""
                val price = prefs.getString("trade_price_$i", "") ?: ""
                val date = prefs.getString("trade_date_$i", "") ?: ""

                if (name.isNotEmpty()) {
                    views.setViewVisibility(tradeRowIds[i], View.VISIBLE)
                    views.setTextViewText(tradeNameIds[i], name)
                    views.setTextViewText(tradePriceIds[i], price)
                    views.setTextViewText(tradeDateIds[i], date)
                } else {
                    views.setViewVisibility(tradeRowIds[i], View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
