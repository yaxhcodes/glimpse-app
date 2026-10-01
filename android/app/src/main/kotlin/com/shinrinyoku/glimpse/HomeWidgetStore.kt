package com.shinrinyoku.glimpse

import android.content.Context
import org.json.JSONArray

/** One save as the Rediscover widget shows it; written by Dart. */
internal data class WidgetSave(
    val id: Long,
    val title: String,
    val source: String,
    val savedAt: Long,
    val image: String?,
)

/**
 * What the home screen widgets know about the library. Flutter owns the data
 * (Isar, ranking, titles) and pushes a small ranked list here; the widgets
 * only read it, so they keep working while the app process is gone.
 */
internal object HomeWidgetStore {
    private const val PREFS = "glimpse_home_widgets"
    private const val KEY_SAVES = "rediscover_saves"
    private const val KEY_SKIPS = "skips_"

    /** How long one memory stays up before the widget turns to the next. */
    private const val ROTATION_MS = 3L * 60 * 60 * 1000

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun writeSaves(context: Context, json: String) {
        prefs(context).edit().putString(KEY_SAVES, json).apply()
    }

    fun saves(context: Context): List<WidgetSave> {
        val raw = prefs(context).getString(KEY_SAVES, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { i ->
                val o = array.optJSONObject(i) ?: return@mapNotNull null
                val title = o.optString("title").trim()
                if (title.isEmpty()) return@mapNotNull null
                WidgetSave(
                    id = o.optLong("id"),
                    title = title,
                    source = o.optString("source").trim(),
                    savedAt = o.optLong("savedAt"),
                    image = o.optString("image").takeIf { it.isNotBlank() },
                )
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /**
     * The save this widget shows now. Time turns the list over every few
     * hours, the skip button steps through it, and the widget id keeps two
     * copies of the widget from showing the same save.
     */
    fun pick(context: Context, widgetId: Int, saves: List<WidgetSave>): WidgetSave? {
        if (saves.isEmpty()) return null
        val slot = System.currentTimeMillis() / ROTATION_MS
        val skips = prefs(context).getInt(KEY_SKIPS + widgetId, 0)
        val index = Math.floorMod(slot + skips + widgetId, saves.size.toLong())
        return saves[index.toInt()]
    }

    fun skip(context: Context, widgetId: Int) {
        val p = prefs(context)
        p.edit().putInt(KEY_SKIPS + widgetId, p.getInt(KEY_SKIPS + widgetId, 0) + 1).apply()
    }

    fun forget(context: Context, widgetIds: IntArray) {
        val editor = prefs(context).edit()
        widgetIds.forEach { editor.remove(KEY_SKIPS + it) }
        editor.apply()
    }
}
