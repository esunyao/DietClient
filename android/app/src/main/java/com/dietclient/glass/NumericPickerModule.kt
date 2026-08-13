package com.dietclient.glass

import android.animation.ValueAnimator
import android.app.Dialog
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.ColorDrawable
import android.view.Gravity
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.view.ContextThemeWrapper
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.NumberPicker
import android.widget.TextView
import com.dietclient.R
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import kotlin.math.roundToInt

/**
 * A short-lived native bottom picker. It deliberately owns its colors and motion so
 * Android's DayNight theme cannot make the wheel unreadable on a light surface.
 */
class NumericPickerModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {
  override fun getName(): String = NAME

  @ReactMethod
  fun open(
    initialValue: Double,
    title: String,
    unit: String,
    minimum: Double,
    maximum: Double,
    step: Double,
    allowClear: Boolean,
    promise: Promise,
  ) {
    val activity = reactContext.currentActivity
    if (activity == null || activity.isFinishing || step <= 0 || maximum < minimum) {
      promise.reject("NO_ACTIVITY", "无法打开数值选择器")
      return
    }

    activity.runOnUiThread {
      // Views must use the light dialog context as well as the light dialog window.
      // Creating NumberPicker with the Activity context is what previously let a dark
      // system theme draw pale wheel text over this deliberately light sheet.
      val pickerContext = ContextThemeWrapper(activity, R.style.HealthPickerDialog)
      val count = ((maximum - minimum) / step).roundToInt()
      val initialIndex = ((initialValue.coerceIn(minimum, maximum) - minimum) / step)
        .roundToInt().coerceIn(0, count)
      val decimals = step.toString().substringAfter('.', "").length
      val density = activity.resources.displayMetrics.density
      fun dp(value: Int) = (value * density).roundToInt()
      fun valueAt(index: Int): Double = (minimum + index * step).coerceIn(minimum, maximum)
      fun valueText(number: Double): String {
        val value = if (decimals == 0) number.roundToInt().toString() else "%1$.${decimals}f".format(number)
        return if (unit.isBlank()) value else "$value $unit"
      }
      fun rounded(color: Int, radius: Int) = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radius).toFloat()
      }

      val root = LinearLayout(pickerContext).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(dp(20), dp(10), dp(20), dp(20))
        background = GradientDrawable().apply {
          setColor(Color.rgb(249, 252, 255))
          cornerRadii = floatArrayOf(
            dp(28).toFloat(), dp(28).toFloat(), dp(28).toFloat(), dp(28).toFloat(),
            0f, 0f, 0f, 0f,
          )
        }
      }

      root.addView(View(pickerContext).apply {
        background = rounded(Color.rgb(201, 213, 226), 3)
      }, LinearLayout.LayoutParams(dp(36), dp(4)).apply {
        gravity = Gravity.CENTER_HORIZONTAL
        bottomMargin = dp(16)
      })
      root.addView(TextView(pickerContext).apply {
        text = title
        textSize = 21f
        setTextColor(Color.rgb(15, 23, 42))
        setTypeface(typeface, 1)
      })
      val summary = TextView(pickerContext).apply {
        textSize = 16f
        setTextColor(Color.rgb(0, 113, 227))
        setTypeface(typeface, 1)
        gravity = Gravity.CENTER
        setPadding(0, dp(12), 0, dp(6))
      }
      root.addView(summary, LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        LinearLayout.LayoutParams.WRAP_CONTENT,
      ))

      val wheelFrame = FrameLayout(pickerContext)
      val pickerRow = LinearLayout(pickerContext).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER
      }
      val numberPicker: NumberPicker
      val decimalPicker: NumberPicker?
      val selectedValue: () -> Double

      if (decimals == 1 && minimum == minimum.roundToInt().toDouble() && maximum == maximum.roundToInt().toDouble()) {
        val initialTenths = (initialValue.coerceIn(minimum, maximum) * 10).roundToInt()
        numberPicker = NumberPicker(pickerContext).apply {
          minValue = minimum.roundToInt()
          maxValue = maximum.roundToInt()
          value = initialTenths / 10
          wrapSelectorWheel = false
          descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
          setFormatter { "$it" }
        }
        decimalPicker = NumberPicker(pickerContext).apply {
          minValue = 0
          maxValue = 9
          value = initialTenths % 10
          wrapSelectorWheel = true
          descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
          setFormatter { ".$it" }
        }
        fun normalizeMaximum() {
          if (numberPicker.value == maximum.roundToInt() && decimalPicker.value != 0) {
            decimalPicker.value = 0
          }
        }
        fun currentValue(): Double = numberPicker.value + decimalPicker.value / 10.0
        fun refresh() {
          normalizeMaximum()
          summary.text = valueText(currentValue())
        }
        numberPicker.setOnValueChangedListener { _, _, _ -> refresh() }
        decimalPicker.setOnValueChangedListener { _, _, _ -> refresh() }
        styleWheel(numberPicker, ::dp)
        styleWheel(decimalPicker, ::dp)
        selectedValue = { currentValue() }
        pickerRow.addView(numberPicker, LinearLayout.LayoutParams(0, dp(190), 1.35f))
        pickerRow.addView(decimalPicker, LinearLayout.LayoutParams(0, dp(190), 1f))
        refresh()
      } else {
        decimalPicker = null
        numberPicker = NumberPicker(pickerContext).apply {
          minValue = 0
          maxValue = count
          value = initialIndex
          wrapSelectorWheel = false
          descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
          setFormatter { index -> valueText(valueAt(index)) }
          setOnValueChangedListener { _, _, next -> summary.text = valueText(valueAt(next)) }
        }
        styleWheel(numberPicker, ::dp)
        selectedValue = { valueAt(numberPicker.value) }
        pickerRow.addView(numberPicker, LinearLayout.LayoutParams(
          LinearLayout.LayoutParams.MATCH_PARENT,
          dp(190),
        ))
        summary.text = valueText(selectedValue())
      }
      wheelFrame.addView(pickerRow, FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT,
        dp(190),
      ))
      val focusTop = dp(75)
      listOf(focusTop, focusTop + dp(40)).forEach { topMargin ->
        wheelFrame.addView(View(pickerContext).apply {
          background = ColorDrawable(Color.rgb(180, 219, 249))
          isClickable = false
          isFocusable = false
        }, FrameLayout.LayoutParams(
          FrameLayout.LayoutParams.MATCH_PARENT,
          dp(1),
        ).apply { gravity = Gravity.TOP; this.topMargin = topMargin })
      }
      root.addView(wheelFrame, LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT,
        dp(190),
      ))

      var settled = false
      fun settle(action: String, value: Double? = null) {
        if (settled) return
        settled = true
        promise.resolve(Arguments.createMap().apply {
          putString("action", action)
          if (value == null) putNull("value") else putDouble("value", value)
        })
      }

      lateinit var dialog: Dialog
      var closing = false
      fun close(action: String, selected: Double? = null) {
        if (closing) return
        closing = true
        root.animate()
          .translationY(dp(24).toFloat())
          .alpha(0f)
          .setDuration(140)
          .setInterpolator(DecelerateInterpolator())
          .withEndAction {
            settle(action, selected)
            dialog.dismiss()
          }
          .start()
        animateDim(dialog, 0f, 140)
      }

      val actions = LinearLayout(pickerContext).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(0, dp(12), 0, 0)
      }
      fun action(text: String, textColor: Int, fillColor: Int?, onClick: () -> Unit): TextView = TextView(pickerContext).apply {
        this.text = text
        textSize = 15f
        gravity = Gravity.CENTER
        setTypeface(typeface, 1)
        setTextColor(textColor)
        minHeight = dp(48)
        background = fillColor?.let { rounded(it, 14) }
        setOnClickListener { onClick() }
      }
      if (allowClear) {
        actions.addView(action("清除", Color.rgb(100, 116, 139), null) { close("clear") },
          LinearLayout.LayoutParams(0, dp(48), 1f))
      }
      actions.addView(action("取消", Color.rgb(71, 85, 105), null) { close("cancel") },
        LinearLayout.LayoutParams(0, dp(48), 1f))
      actions.addView(action("确定", Color.WHITE, Color.rgb(0, 113, 227)) {
        close("confirm", selectedValue())
      }, LinearLayout.LayoutParams(0, dp(48), 1f))
      root.addView(actions)

      dialog = Dialog(activity, R.style.HealthPickerDialog).apply {
        requestWindowFeature(Window.FEATURE_NO_TITLE)
        setContentView(root)
        setCanceledOnTouchOutside(false)
        setOnCancelListener { close("cancel") }
      }
      dialog.window?.apply {
        setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
        setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
        setGravity(Gravity.BOTTOM)
        addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        attributes = attributes.apply { dimAmount = 0f }
      }
      root.alpha = 0f
      root.translationY = dp(24).toFloat()
      dialog.show()
      dialog.window?.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
      root.animate()
        .translationY(0f)
        .alpha(1f)
        .setDuration(180)
        .setInterpolator(DecelerateInterpolator())
        .start()
      animateDim(dialog, 0.30f, 180)
    }
  }

  private fun styleWheel(picker: NumberPicker, dp: (Int) -> Int) {
    picker.setBackgroundColor(Color.TRANSPARENT)
    picker.setPadding(dp(6), 0, dp(6), 0)
    // NumberPicker exposes the selected value as its embedded EditText. Setting it
    // explicitly prevents the DayNight text palette from producing white-on-white text.
    for (index in 0 until picker.childCount) {
      val child = picker.getChildAt(index)
      if (child is TextView) {
        child.setTextColor(Color.rgb(15, 23, 42))
        child.textSize = 24f
        child.setTypeface(child.typeface, 1)
        child.setBackgroundColor(Color.TRANSPARENT)
      }
    }
  }

  private fun animateDim(dialog: Dialog, target: Float, duration: Long) {
    val window = dialog.window ?: return
    val initial = window.attributes.dimAmount
    ValueAnimator.ofFloat(initial, target).apply {
      this.duration = duration
      addUpdateListener { animator ->
        window.attributes = window.attributes.apply { dimAmount = animator.animatedValue as Float }
      }
      start()
    }
  }

  companion object { const val NAME = "NumericPicker" }
}
