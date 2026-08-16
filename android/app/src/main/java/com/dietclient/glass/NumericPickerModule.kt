package com.dietclient.glass

import android.animation.ValueAnimator
import android.app.Dialog
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
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
 * 界面布局在 res/layout/numeric_picker_dialog.xml，本类只负责滚轮配置与交互逻辑。
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

      val root = LayoutInflater.from(pickerContext).inflate(R.layout.numeric_picker_dialog, null)
      val titleView = root.findViewById<TextView>(R.id.np_title)
      val summary = root.findViewById<TextView>(R.id.np_summary)
      val tenthsRow = root.findViewById<View>(R.id.np_row_tenths)
      val integerWheel = root.findViewById<NumberPicker>(R.id.np_wheel_int)
      val decimalWheel = root.findViewById<NumberPicker>(R.id.np_wheel_dec)
      val singleWheel = root.findViewById<NumberPicker>(R.id.np_wheel)
      val clearButton = root.findViewById<TextView>(R.id.np_clear)
      val cancelButton = root.findViewById<TextView>(R.id.np_cancel)
      val confirmButton = root.findViewById<TextView>(R.id.np_confirm)
      titleView.text = title

      var selectedValue: () -> Double

      if (decimals == 1 && minimum == minimum.roundToInt().toDouble() && maximum == maximum.roundToInt().toDouble()) {
        // 带一位小数的双滚轮形态：整数轮 + 小数轮
        tenthsRow.visibility = View.VISIBLE
        singleWheel.visibility = View.GONE
        val initialTenths = (initialValue.coerceIn(minimum, maximum) * 10).roundToInt()
        integerWheel.minValue = minimum.roundToInt()
        integerWheel.maxValue = maximum.roundToInt()
        integerWheel.value = initialTenths / 10
        integerWheel.wrapSelectorWheel = false
        integerWheel.descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
        integerWheel.setFormatter { "$it" }
        decimalWheel.minValue = 0
        decimalWheel.maxValue = 9
        decimalWheel.value = initialTenths % 10
        decimalWheel.wrapSelectorWheel = true
        decimalWheel.descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
        decimalWheel.setFormatter { ".$it" }
        fun normalizeMaximum() {
          if (integerWheel.value == maximum.roundToInt() && decimalWheel.value != 0) {
            decimalWheel.value = 0
          }
        }
        fun currentValue(): Double = integerWheel.value + decimalWheel.value / 10.0
        fun refresh() {
          normalizeMaximum()
          summary.text = valueText(currentValue())
        }
        integerWheel.setOnValueChangedListener { _, _, _ -> refresh() }
        decimalWheel.setOnValueChangedListener { _, _, _ -> refresh() }
        styleWheel(integerWheel, ::dp)
        styleWheel(decimalWheel, ::dp)
        selectedValue = { currentValue() }
        refresh()
      } else {
        // 通用步进单滚轮形态
        tenthsRow.visibility = View.GONE
        singleWheel.visibility = View.VISIBLE
        singleWheel.minValue = 0
        singleWheel.maxValue = count
        singleWheel.value = initialIndex
        singleWheel.wrapSelectorWheel = false
        singleWheel.descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
        singleWheel.setFormatter { index -> valueText(valueAt(index)) }
        singleWheel.setOnValueChangedListener { _, _, next -> summary.text = valueText(valueAt(next)) }
        styleWheel(singleWheel, ::dp)
        selectedValue = { valueAt(singleWheel.value) }
        summary.text = valueText(selectedValue())
      }

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

      clearButton.visibility = if (allowClear) View.VISIBLE else View.GONE
      clearButton.setOnClickListener { close("clear") }
      cancelButton.setOnClickListener { close("cancel") }
      confirmButton.setOnClickListener { close("confirm", selectedValue()) }

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
