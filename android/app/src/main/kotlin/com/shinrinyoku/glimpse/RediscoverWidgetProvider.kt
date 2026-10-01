package com.shinrinyoku.glimpse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Shader
import android.icu.text.RelativeDateTimeFormatter
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.sqrt

/**
 * The Rediscover home screen widget: one save you may have forgotten, its
 * picture filling the widget (frosted where the words sit) when it has one.
 * Tapping opens the save; the button by the date shows another.
 */
class RediscoverWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        renderAsync(context, widgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        newOptions: Bundle,
    ) {
        renderAsync(context, intArrayOf(widgetId))
    }

    override fun onDeleted(context: Context, widgetIds: IntArray) {
        HomeWidgetStore.forget(context, widgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SKIP) {
            val widgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                HomeWidgetStore.skip(context, widgetId)
                renderAsync(context, intArrayOf(widgetId))
            }
            return
        }
        super.onReceive(context, intent)
    }

    /** Decoding a picture is too slow for the main thread; keep the receiver alive meanwhile. */
    private fun renderAsync(context: Context, widgetIds: IntArray) {
        val pending = goAsync()
        val app = context.applicationContext
        renderer.execute {
            try {
                render(app, widgetIds)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private const val ACTION_SKIP = "com.shinrinyoku.glimpse.widget.REDISCOVER_SKIP"
        private val renderer = Executors.newSingleThreadExecutor()

        fun isInUse(context: Context): Boolean = widgetIds(context).isNotEmpty()

        /** Re-renders every placed widget, e.g. after Dart pushed fresh saves. */
        fun refreshAll(context: Context) {
            val app = context.applicationContext
            renderer.execute { render(app, widgetIds(app)) }
        }

        private fun widgetIds(context: Context): IntArray =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, RediscoverWidgetProvider::class.java))

        private fun render(context: Context, widgetIds: IntArray) {
            if (widgetIds.isEmpty()) return
            val manager = AppWidgetManager.getInstance(context)
            val saves = HomeWidgetStore.saves(context)
            for (widgetId in widgetIds) {
                val size = WidgetSize.of(manager.getAppWidgetOptions(widgetId))
                val save = HomeWidgetStore.pick(context, widgetId, saves)
                val views = try {
                    if (save == null) {
                        emptyViews(context)
                    } else {
                        memoryViews(context, widgetId, save, size, canSkip = saves.size > 1)
                    }
                } catch (t: Throwable) {
                    android.util.Log.w("Glimpse", "Rediscover widget render failed: $t")
                    emptyViews(context)
                }
                manager.updateAppWidget(widgetId, views)
            }
        }

        private fun memoryViews(
            context: Context,
            widgetId: Int,
            save: WidgetSave,
            size: WidgetSize,
            canSkip: Boolean,
        ): RemoteViews {
            val narrow = size.widthDp < 200
            val density = context.resources.displayMetrics.density
            val textWidthPx = ((size.widthDp - 32) * density).toInt()
            // Title size (sp) and lines over a picture: a calm scale that never shouts.
            val photoTitle = when {
                narrow -> 15f to 2
                size.heightDp >= 260 -> 20f to 3
                size.heightDp >= 220 -> 20f to 2
                else -> 18f to 2
            }
            var titleArt = titleArt(context, save.title, photoTitle, textWidthPx)
            val photo = save.image?.let { path ->
                // Room the words take at the foot: padding, eyebrow, title, meta
                // row. Frost only that, so the rest of the picture stays sharp.
                val titleDp = titleArt?.let { it.bitmap.height / density }
                    ?: (estimatedLines(save.title, size.widthDp - 32f, photoTitle.first, photoTitle.second) *
                        photoTitle.first * 1.3f)
                val wordsDp = 16f + 13f + 6f + titleDp + 2f + 32f
                WidgetPhoto.loadFrosted(context, path, size, wordsDp)
            }
            val views = RemoteViews(
                context.packageName,
                if (photo != null) R.layout.widget_rediscover_photo else R.layout.widget_rediscover,
            )
            val title = if (photo != null) {
                views.setImageViewBitmap(R.id.widget_photo, photo)
                photoTitle
            } else {
                // The fused corner mark stands in for a missing picture. Below
                // Android 12 it can't be clipped to the rounded card, and on a
                // narrow card it would sit behind the title.
                views.setViewVisibility(
                    R.id.widget_watermark,
                    if (!narrow && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) View.VISIBLE else View.GONE,
                )
                val cardTitle = when {
                    size.heightDp < 140 -> 16f to 2
                    size.heightDp >= 200 -> 18f to 4
                    else -> 17f to 3
                }
                titleArt = titleArt(context, save.title, cardTitle, textWidthPx)
                cardTitle
            }
            views.setTextViewText(R.id.widget_title, save.title)
            views.setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, title.first)
            views.setInt(R.id.widget_title, "setMaxLines", title.second)

            val ago = savedAgo(save.savedAt)
            val meta = when {
                save.source.isEmpty() -> ago
                // A narrow widget has room for one: when, not where.
                narrow -> ago
                else -> "${save.source} · $ago"
            }
            views.setTextViewText(R.id.widget_meta, meta)
            views.setContentDescription(android.R.id.background, "${save.title}. $meta")

            // The words in the app's own typeface, when it loads.
            val onPhoto = photo != null
            inkArt(context, views, R.id.widget_title, R.id.widget_title_art, titleArt, onPhoto, alpha = 255)
            val eyebrow = context.getString(R.string.widget_eyebrow)
                .uppercase(context.resources.configuration.locales[0])
            inkArt(
                context,
                views,
                R.id.widget_eyebrow,
                R.id.widget_eyebrow_art,
                WidgetText.render(
                    context,
                    eyebrow,
                    WidgetText.Face.SEMIBOLD,
                    sp = 10.5f,
                    widthPx = textWidthPx,
                    maxLines = 1,
                    letterSpacingEm = 0.1f,
                    hug = true,
                ),
                onPhoto,
                alpha = if (onPhoto) 204 else 184,
            )
            val skipRoomPx = if (canSkip) (40 * density).toInt() else 0
            inkArt(
                context,
                views,
                R.id.widget_meta,
                R.id.widget_meta_art,
                WidgetText.render(
                    context,
                    meta,
                    WidgetText.Face.REGULAR,
                    sp = 12f,
                    widthPx = textWidthPx - skipRoomPx,
                    maxLines = 1,
                ),
                onPhoto,
                alpha = if (onPhoto) 191 else 184,
            )

            views.setOnClickPendingIntent(
                android.R.id.background,
                WidgetIntents.openSave(context, widgetId, save.id),
            )
            views.setViewVisibility(R.id.widget_next, if (canSkip) View.VISIBLE else View.GONE)
            if (canSkip) {
                val skip = Intent(context, RediscoverWidgetProvider::class.java)
                    .setAction(ACTION_SKIP)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                views.setOnClickPendingIntent(
                    R.id.widget_next,
                    PendingIntent.getBroadcast(
                        context,
                        widgetId,
                        skip,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
            return views
        }

        private fun titleArt(
            context: Context,
            title: String,
            spec: Pair<Float, Int>,
            widthPx: Int,
        ): WidgetText.Rendered? = WidgetText.render(
            context,
            title,
            WidgetText.Face.SEMIBOLD,
            sp = spec.first,
            widthPx = widthPx,
            maxLines = spec.second,
            letterSpacingEm = -0.01f,
            lineSpacingSp = 1f,
        )

        /**
         * Swaps a line of plain text for its Instrument Sans image. Over a
         * picture the words are white; on the tonal card Android 12+ tints them
         * from the theme, so they follow dark mode and the wallpaper live.
         */
        private fun inkArt(
            context: Context,
            views: RemoteViews,
            textId: Int,
            artId: Int,
            art: WidgetText.Rendered?,
            onPhoto: Boolean,
            alpha: Int,
        ) {
            if (art == null) return
            views.setImageViewBitmap(artId, art.bitmap)
            views.setViewVisibility(artId, View.VISIBLE)
            views.setViewVisibility(textId, View.GONE)
            when {
                onPhoto -> {
                    views.setInt(artId, "setColorFilter", Color.WHITE)
                    views.setInt(artId, "setImageAlpha", alpha)
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> views.setColorStateList(
                    artId,
                    "setImageTintList",
                    if (alpha < 255) R.color.widget_on_primary_container_muted else R.color.widget_on_primary_container,
                )
                else -> {
                    views.setInt(artId, "setColorFilter", context.getColor(R.color.widget_on_primary_container))
                    views.setInt(artId, "setImageAlpha", alpha)
                }
            }
        }

        private fun emptyViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_rediscover_empty)
            views.setViewVisibility(
                R.id.widget_watermark,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) View.VISIBLE else View.GONE,
            )
            views.setOnClickPendingIntent(android.R.id.background, WidgetIntents.openApp(context))
            views.setOnClickPendingIntent(
                R.id.widget_cta,
                WidgetIntents.shortcut(context, MainActivity.ACTION_CAPTURE),
            )
            return views
        }

        /** Roughly how many lines [text] wraps to; medium sans averages ~0.52em a glyph. */
        private fun estimatedLines(text: String, widthDp: Float, sp: Float, maxLines: Int): Int {
            val perLine = (widthDp / (sp * 0.52f)).coerceAtLeast(1f)
            return kotlin.math.ceil(text.length / perLine).toInt().coerceIn(1, maxLines)
        }

        /** "3 months ago", in the device's language. */
        private fun savedAgo(savedAt: Long): String {
            val formatter = RelativeDateTimeFormatter.getInstance()
            val days = ((System.currentTimeMillis() - savedAt) / DAY_MS).coerceAtLeast(0)
            return when {
                days < 1 -> formatter.format(
                    RelativeDateTimeFormatter.Direction.THIS,
                    RelativeDateTimeFormatter.AbsoluteUnit.DAY,
                )
                days < 2 -> formatter.format(
                    RelativeDateTimeFormatter.Direction.LAST,
                    RelativeDateTimeFormatter.AbsoluteUnit.DAY,
                )
                days < 7 -> formatter.format(
                    days.toDouble(),
                    RelativeDateTimeFormatter.Direction.LAST,
                    RelativeDateTimeFormatter.RelativeUnit.DAYS,
                )
                days < 30 -> formatter.format(
                    (days / 7).toDouble(),
                    RelativeDateTimeFormatter.Direction.LAST,
                    RelativeDateTimeFormatter.RelativeUnit.WEEKS,
                )
                days < 365 -> formatter.format(
                    (days / 30).toDouble(),
                    RelativeDateTimeFormatter.Direction.LAST,
                    RelativeDateTimeFormatter.RelativeUnit.MONTHS,
                )
                else -> formatter.format(
                    (days / 365).toDouble(),
                    RelativeDateTimeFormatter.Direction.LAST,
                    RelativeDateTimeFormatter.RelativeUnit.YEARS,
                )
            }
        }

        private const val DAY_MS = 24L * 60 * 60 * 1000
    }
}

/** The widget's size in dp, as the launcher reports it for portrait. */
internal data class WidgetSize(val widthDp: Int, val heightDp: Int) {
    companion object {
        fun of(options: Bundle?): WidgetSize {
            val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
            val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT) ?: 0
            return WidgetSize(
                widthDp = if (width > 0) width else 250,
                heightDp = if (height > 0) height else 160,
            )
        }
    }
}

/**
 * Turns a cached save picture into the widget's full-bleed backdrop. The
 * foot, where the words sit, is frosted: blurred until any text in the
 * picture dissolves, then veiled as much as the picture's brightness needs
 * for white words to read. Widgets can't blur live, so it is baked in.
 * Widget bitmaps cross a binder call, so the pixel count is capped.
 */
internal object WidgetPhoto {
    fun loadFrosted(context: Context, path: String, size: WidgetSize, wordsDp: Float): Bitmap? {
        if (!File(path).isFile) return null
        return try {
            // Android 12+ rounds the card; below that, cut the corners here.
            val rounded = Build.VERSION.SDK_INT < Build.VERSION_CODES.S
            val density = context.resources.displayMetrics.density
            // The words travel as images too; leave them room in the transaction.
            val maxPixels = if (rounded) 150_000f else 260_000f
            val shrink = minOf(
                1f,
                sqrt(maxPixels / (size.widthDp * density * size.heightDp * density)),
            )
            val px = density * shrink
            val width = (size.widthDp * px).toInt().coerceAtLeast(1)
            val height = (size.heightDp * px).toInt().coerceAtLeast(1)

            val base = decodeCover(path, width, height) ?: return null
            val canvas = Canvas(base)

            // Fully frosted from just above the words, feathered over 32dp.
            val solidTop = (height - (wordsDp + 6f) * px).coerceIn(height * 0.15f, height.toFloat())
            val fadeTop = (solidTop - 32f * px).coerceAtLeast(0f)

            val small = Bitmap.createScaledBitmap(
                base,
                (width / 12).coerceAtLeast(2),
                (height / 12).coerceAtLeast(2),
                true,
            )
            boxBlur(small, radius = 2, passes = 3)
            val brightness = lowerLuminance(small, solidTop / height)
            val frost = Bitmap.createScaledBitmap(small, width, height, true)
            small.recycle()

            canvas.saveLayer(null, null)
            canvas.drawBitmap(
                frost,
                0f,
                0f,
                Paint(Paint.FILTER_BITMAP_FLAG).apply {
                    colorFilter = ColorMatrixColorFilter(ColorMatrix().apply { setSaturation(1.2f) })
                },
            )
            canvas.drawRect(
                0f,
                0f,
                width.toFloat(),
                height.toFloat(),
                Paint().apply {
                    shader = LinearGradient(
                        0f,
                        fadeTop,
                        0f,
                        solidTop,
                        Color.TRANSPARENT,
                        Color.BLACK,
                        Shader.TileMode.CLAMP,
                    )
                    xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
                },
            )
            canvas.restore()
            frost.recycle()

            // A bright picture needs a deeper veil than a dark one.
            val veil = (0.30f + 0.45f * brightness).coerceIn(0.30f, 0.72f)
            val solidStop = ((solidTop - fadeTop) / (height - fadeTop)).coerceIn(0.01f, 0.99f)
            canvas.drawRect(
                0f,
                0f,
                width.toFloat(),
                height.toFloat(),
                Paint(Paint.DITHER_FLAG).apply {
                    shader = LinearGradient(
                        0f,
                        fadeTop,
                        0f,
                        height.toFloat(),
                        intArrayOf(
                            Color.TRANSPARENT,
                            Color.argb((veil * 0.75f * 255).toInt(), 0, 0, 0),
                            Color.argb((veil * 255).toInt(), 0, 0, 0),
                        ),
                        floatArrayOf(0f, solidStop, 1f),
                        Shader.TileMode.CLAMP,
                    )
                },
            )

            val out = Bitmap.createBitmap(
                width,
                height,
                if (rounded) Bitmap.Config.ARGB_8888 else Bitmap.Config.RGB_565,
            )
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG or Paint.DITHER_FLAG)
            if (rounded) {
                paint.shader = BitmapShader(base, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
                val radius = context.resources.getDimension(R.dimen.widget_radius) * shrink
                Canvas(out).drawRoundRect(
                    RectF(0f, 0f, width.toFloat(), height.toFloat()),
                    radius,
                    radius,
                    paint,
                )
            } else {
                Canvas(out).drawBitmap(base, 0f, 0f, paint)
            }
            base.recycle()
            out
        } catch (t: Throwable) {
            android.util.Log.w("Glimpse", "Widget photo failed: $t")
            null
        }
    }

    /** The picture centre-cropped to exactly [width] x [height], mutable. */
    private fun decodeCover(path: String, width: Int, height: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        val cover = max(width.toFloat() / bounds.outWidth, height.toFloat() / bounds.outHeight)
        var sample = 1
        while (cover * sample * 2 <= 1f) sample *= 2
        val source = BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        ) ?: return null
        val scale = max(width.toFloat() / source.width, height.toFloat() / source.height)
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate((width - source.width * scale) / 2f, (height - source.height * scale) / 2f)
        }
        val out = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(source, matrix, Paint(Paint.FILTER_BITMAP_FLAG))
        source.recycle()
        return out
    }

    /** Average brightness (0..1) of the rows from [fromFraction] down. */
    private fun lowerLuminance(bitmap: Bitmap, fromFraction: Float): Float {
        val top = (bitmap.height * fromFraction).toInt().coerceIn(0, bitmap.height - 1)
        var sum = 0.0
        var count = 0
        for (y in top until bitmap.height) {
            for (x in 0 until bitmap.width) {
                val c = bitmap.getPixel(x, y)
                sum += 0.2126 * Color.red(c) + 0.7152 * Color.green(c) + 0.0722 * Color.blue(c)
                count++
            }
        }
        return if (count == 0) 0.5f else (sum / count / 255.0).toFloat()
    }

    /** Separable box blur, repeated: close to a gaussian on a tiny bitmap. */
    private fun boxBlur(bitmap: Bitmap, radius: Int, passes: Int) {
        val w = bitmap.width
        val h = bitmap.height
        val n = radius * 2 + 1
        var src = IntArray(w * h).also { bitmap.getPixels(it, 0, w, 0, 0, w, h) }
        var dst = IntArray(w * h)
        repeat(passes) {
            for (horizontal in booleanArrayOf(true, false)) {
                val lines = if (horizontal) h else w
                val length = if (horizontal) w else h
                for (line in 0 until lines) {
                    for (i in 0 until length) {
                        var r = 0
                        var g = 0
                        var b = 0
                        for (k in -radius..radius) {
                            val j = (i + k).coerceIn(0, length - 1)
                            val c = if (horizontal) src[line * w + j] else src[j * w + line]
                            r += Color.red(c)
                            g += Color.green(c)
                            b += Color.blue(c)
                        }
                        dst[if (horizontal) line * w + i else i * w + line] = Color.rgb(r / n, g / n, b / n)
                    }
                }
                val swap = src
                src = dst
                dst = swap
            }
        }
        bitmap.setPixels(src, 0, w, 0, 0, w, h)
    }
}
