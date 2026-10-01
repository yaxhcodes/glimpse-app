package com.shinrinyoku.glimpse

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import kotlin.math.ceil

/**
 * Widget text in the app's own typeface. Launchers inflate widgets in a
 * restricted context that can't load app fonts, and OEM skins swap the
 * system families, so the words are laid out here in Instrument Sans (the
 * file Flutter already ships) and handed over as alpha-only images that
 * the launcher colours.
 */
internal object WidgetText {
    enum class Face(val file: String) {
        REGULAR("InstrumentSans-Regular.ttf"),
        SEMIBOLD("InstrumentSans-SemiBold.ttf"),
    }

    class Rendered(val bitmap: Bitmap, val lines: Int)

    private val faces = HashMap<Face, Typeface?>()

    private fun typeface(context: Context, face: Face): Typeface? = synchronized(faces) {
        faces.getOrPut(face) {
            try {
                Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/${face.file}")
            } catch (_: Exception) {
                null
            }
        }
    }

    /**
     * [text] wrapped to [widthPx] and cut to [maxLines] with an ellipsis, or
     * null if the font is missing (the layout's plain text then shows).
     * [hug] trims the image to the text's own width, for one-liners that sit
     * beside an icon.
     */
    fun render(
        context: Context,
        text: String,
        face: Face,
        sp: Float,
        widthPx: Int,
        maxLines: Int,
        letterSpacingEm: Float = 0f,
        lineSpacingSp: Float = 0f,
        hug: Boolean = false,
    ): Rendered? {
        val typeface = typeface(context, face) ?: return null
        if (text.isBlank() || widthPx <= 0) return null
        val metrics = context.resources.displayMetrics
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG or TextPaint.SUBPIXEL_TEXT_FLAG).apply {
            this.typeface = typeface
            // Honours the user's font size, like a TextView would.
            textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sp, metrics)
            letterSpacing = letterSpacingEm
        }
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, widthPx)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, lineSpacingSp, metrics), 1f)
            .setIncludePad(false)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()
        val width = if (hug) {
            (0 until layout.lineCount)
                .maxOf { ceil(layout.getLineWidth(it)).toInt() }
                .coerceIn(1, widthPx)
        } else {
            widthPx
        }
        val bitmap = Bitmap.createBitmap(width, layout.height.coerceAtLeast(1), Bitmap.Config.ALPHA_8)
        layout.draw(Canvas(bitmap))
        return Rendered(bitmap, layout.lineCount)
    }
}
