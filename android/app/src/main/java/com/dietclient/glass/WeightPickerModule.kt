package com.dietclient.glass

import android.app.AlertDialog
import android.view.LayoutInflater
import android.widget.NumberPicker
import com.dietclient.R
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import kotlin.math.roundToInt

/**
 * 健康目标专用的原生体重选择器。保持既有交互，不与基础档案和身体测量的
 * 参数化 NumericPicker 共用，避免基础资料改动波及健康计划与提醒。
 * 界面布局在 res/layout/weight_picker_dialog.xml。
 */
class WeightPickerModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {
  override fun getName(): String = NAME

  @ReactMethod
  fun open(initialValue: Double, promise: Promise) {
    val activity = reactContext.currentActivity
    if (activity == null || activity.isFinishing) {
      promise.reject("NO_ACTIVITY", "无法打开体重选择器")
      return
    }

    activity.runOnUiThread {
      val content = LayoutInflater.from(activity).inflate(R.layout.weight_picker_dialog, null)
      val integerPicker = content.findViewById<NumberPicker>(R.id.wp_integer)
      val decimalPicker = content.findViewById<NumberPicker>(R.id.wp_decimal)

      val initialTenths = (initialValue.coerceIn(MIN_WEIGHT, MAX_WEIGHT) * 10).roundToInt()
      integerPicker.minValue = MIN_WEIGHT.toInt()
      integerPicker.maxValue = MAX_WEIGHT.toInt()
      integerPicker.value = initialTenths / 10
      integerPicker.wrapSelectorWheel = false
      integerPicker.descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
      integerPicker.setFormatter { "$it kg" }
      decimalPicker.minValue = 0
      decimalPicker.maxValue = 9
      decimalPicker.value = initialTenths % 10
      decimalPicker.wrapSelectorWheel = true
      decimalPicker.descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
      decimalPicker.setFormatter { ".$it" }

      fun normalizeMaximum() {
        if (integerPicker.value == MAX_WEIGHT.toInt() && decimalPicker.value != 0) {
          decimalPicker.value = 0
        }
      }
      integerPicker.setOnValueChangedListener { _, _, _ -> normalizeMaximum() }
      decimalPicker.setOnValueChangedListener { _, _, _ -> normalizeMaximum() }

      var settled = false
      fun settle(action: String, value: Double? = null) {
        if (settled) return
        settled = true
        promise.resolve(Arguments.createMap().apply {
          putString("action", action)
          if (value == null) putNull("value") else putDouble("value", value)
        })
      }

      val dialog = AlertDialog.Builder(activity)
        .setTitle(R.string.weight_picker_title)
        .setView(content)
        .setNegativeButton(R.string.picker_cancel) { _, _ -> settle("cancel") }
        .setNeutralButton(R.string.picker_clear) { _, _ -> settle("clear") }
        .setPositiveButton(R.string.picker_confirm) { _, _ ->
          normalizeMaximum()
          settle("confirm", integerPicker.value + decimalPicker.value / 10.0)
        }
        .create()
      dialog.setOnCancelListener { settle("cancel") }
      dialog.show()
    }
  }

  companion object {
    private const val MIN_WEIGHT = 10.0
    private const val MAX_WEIGHT = 500.0
    const val NAME = "WeightPicker"
  }
}
