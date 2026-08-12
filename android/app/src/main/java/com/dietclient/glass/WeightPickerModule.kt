package com.dietclient.glass

import android.app.AlertDialog
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.NumberPicker
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import kotlin.math.roundToInt

/**
 * 仅在用户点击目标体重字段时创建的原生双轮盘。
 *
 * Android NumberPicker 的滚动和惯性完全运行在原生 UI 线程；关闭后 Dialog 与子 View
 * 一并释放，不会给健康档案表单留下常驻的 JS 轮盘负担。
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
      val initialTenths = (initialValue.coerceIn(MIN_WEIGHT, MAX_WEIGHT) * 10).roundToInt()
      val integerPicker = NumberPicker(activity).apply {
        minValue = MIN_WEIGHT.toInt()
        maxValue = MAX_WEIGHT.toInt()
        value = initialTenths / 10
        wrapSelectorWheel = false
        descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
        setFormatter { "$it kg" }
      }
      val decimalPicker = NumberPicker(activity).apply {
        minValue = 0
        maxValue = 9
        value = initialTenths % 10
        wrapSelectorWheel = true
        descendantFocusability = NumberPicker.FOCUS_BLOCK_DESCENDANTS
        setFormatter { ".$it" }
      }

      fun normalizeMaximum() {
        if (integerPicker.value == MAX_WEIGHT.toInt() && decimalPicker.value != 0) {
          decimalPicker.value = 0
        }
      }
      integerPicker.setOnValueChangedListener { _, _, _ -> normalizeMaximum() }
      decimalPicker.setOnValueChangedListener { _, _, _ -> normalizeMaximum() }

      val density = activity.resources.displayMetrics.density
      val pickerWidth = (112 * density).roundToInt()
      val content = LinearLayout(activity).apply {
        orientation = LinearLayout.HORIZONTAL
        setPadding((12 * density).roundToInt(), 0, (12 * density).roundToInt(), 0)
        addView(integerPicker, LinearLayout.LayoutParams(pickerWidth, ViewGroup.LayoutParams.WRAP_CONTENT))
        addView(decimalPicker, LinearLayout.LayoutParams(pickerWidth, ViewGroup.LayoutParams.WRAP_CONTENT))
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

      val dialog = AlertDialog.Builder(activity)
        .setTitle("选择目标体重")
        .setView(content)
        .setNegativeButton("取消") { _, _ -> settle("cancel") }
        .setNeutralButton("清除") { _, _ -> settle("clear") }
        .setPositiveButton("确定") { _, _ ->
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
