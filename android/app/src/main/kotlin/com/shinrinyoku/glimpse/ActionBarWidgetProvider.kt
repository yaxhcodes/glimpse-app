package com.shinrinyoku.glimpse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** Search, Ask and Save in one pill on the home screen. Never changes, so never refreshes. */
class ActionBarWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        val views = RemoteViews(context.packageName, R.layout.widget_action_bar).apply {
            setOnClickPendingIntent(
                R.id.widget_search_field,
                WidgetIntents.shortcut(context, MainActivity.ACTION_SEARCH),
            )
            setOnClickPendingIntent(R.id.widget_ask, WidgetIntents.shortcut(context, MainActivity.ACTION_ASK))
            setOnClickPendingIntent(
                R.id.widget_capture,
                WidgetIntents.shortcut(context, MainActivity.ACTION_CAPTURE),
            )
        }
        manager.updateAppWidget(widgetIds, views)
    }
}

/** Widget taps land in MainActivity through the same actions as the launcher shortcuts. */
internal object WidgetIntents {
    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    fun shortcut(context: Context, action: String): PendingIntent =
        PendingIntent.getActivity(context, 0, launch(context).setAction(action), FLAGS)

    fun openApp(context: Context): PendingIntent =
        PendingIntent.getActivity(
            context,
            0,
            launch(context)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER),
            FLAGS,
        )

    /** One pending intent per widget; its extra follows the save on show. */
    fun openSave(context: Context, widgetId: Int, saveId: Long): PendingIntent =
        PendingIntent.getActivity(
            context,
            widgetId,
            launch(context)
                .setAction(MainActivity.ACTION_OPEN_SAVE)
                .putExtra(MainActivity.EXTRA_SAVE_ID, saveId),
            FLAGS,
        )

    private fun launch(context: Context) =
        Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
}
