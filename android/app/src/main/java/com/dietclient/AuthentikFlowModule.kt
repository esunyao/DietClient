package com.dietclient

import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import java.io.IOException
import org.json.JSONObject
import okhttp3.Call
import okhttp3.Callback
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response

/**
 * Authentik Flow executor 的短生命周期原生会话。
 *
 * HttpOnly authentik_session 不会暴露给 JS，并且严格按 sessionId 隔离，避免注册、
 * 登录和重发邮件的 Cookie 串用。
 */
class AuthentikFlowModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private val sessions = AuthentikFlowSessionStore()
  private val client = OkHttpClient.Builder()
    .followRedirects(false)
    .followSslRedirects(false)
    .build()

  override fun getName(): String = NAME

  @ReactMethod
  fun createSession(promise: Promise) {
    promise.resolve(sessions.create())
  }

  @ReactMethod
  fun closeSession(sessionId: String, promise: Promise) {
    sessions.close(sessionId)
    promise.resolve(null)
  }

  @ReactMethod
  fun request(
    sessionId: String,
    method: String,
    url: String,
    headers: ReadableMap,
    body: String?,
    promise: Promise,
  ) {
    if (!sessions.contains(sessionId)) {
      promise.reject("AUTHENTIK_FLOW_SESSION_CLOSED", "Authentik Flow 会话已结束。")
      return
    }

    val httpUrl = url.toHttpUrlOrNull()
    if (httpUrl == null || httpUrl.host != AUTHENTIK_HOST || !isAllowedPath(httpUrl.encodedPath)) {
      promise.reject("INVALID_AUTHENTIK_FLOW_URL", "仅允许访问 Authentik Flow 或授权跳转地址。")
      return
    }

    val requestBuilder = Request.Builder().url(httpUrl)
    headers.toHashMap().forEach { (name, value) ->
      if (value is String) requestBuilder.header(name, value)
    }
    // Flow executor 严格按 JSON API 调用。即使 JS 桥接层未传入，也不允许
    // OkHttp 回退到 */* 导致 Authentik 返回 HTML/跳转响应。
    requestBuilder.header("Accept", JSON_ACCEPT)
    // 显式固定虚拟主机，排除网关按 Host 路由时与桌面调试请求不一致。
    requestBuilder.header("Host", AUTHENTIK_AUTHORITY)
    val cookieAttachment = sessions.addCookie(sessionId, requestBuilder, headers.hasKey("Cookie"))

    val requestBody = body?.toRequestBody(JSON_MEDIA_TYPE)
    val request = requestBuilder.method(method, requestBody).build()
    if (BuildConfig.DEBUG) {
      Log.i(
        LOG_TAG,
        "request method=${request.method} path=${request.url.encodedPath} " +
          "accept=${request.header("Accept")} " +
          "cookieName=${cookieAttachment.name ?: "none"} " +
          "cookieAttached=${cookieAttachment.attached} cookieSource=${cookieAttachment.source} " +
          "flowId=${request.header("x-authentik-id") != null} " +
          "origin=${request.header("Origin") != null} referer=${request.header("Referer") != null}",
      )
      Log.i(LOG_TAG, "DEBUG_FULL_REQUEST_BEGIN method=${request.method}")
      Log.i(LOG_TAG, "DEBUG_FULL_REQUEST_URL ${request.url}")
      request.headers.forEach { (name, value) ->
        val safeValue = if (name.equals("Cookie", ignoreCase = true)) "<redacted>" else value
        Log.i(LOG_TAG, "DEBUG_FULL_REQUEST_HEADER $name: $safeValue")
      }
      Log.i(LOG_TAG, "DEBUG_FULL_REQUEST_BODY ${redactPasswords(body)}")
      Log.i(LOG_TAG, "DEBUG_FULL_REQUEST_END method=${request.method}")
    }
    client.newCall(request).enqueue(object : Callback {
      override fun onFailure(call: Call, error: IOException) {
        promise.reject("AUTHENTIK_FLOW_NETWORK_ERROR", "Authentik Flow 网络请求失败。", error)
      }

      override fun onResponse(call: Call, response: Response) {
        response.use {
          // ResponseBody 只能读取一次，先缓存，供 Debug 输出与 RN 桥接共同使用。
          val responseBody = it.body?.string().orEmpty()
          sessions.absorb(sessionId, it.headers)
          if (BuildConfig.DEBUG) {
            val location = it.header("Location")
              ?.toHttpUrlOrNull()
              ?.encodedPath
              ?: it.header("Location")?.substringBefore('?')?.substringBefore('#')
              ?: "none"
            Log.i(
              LOG_TAG,
              "response method=${request.method} path=${request.url.encodedPath} " +
                "status=${it.code} contentType=${it.header("Content-Type") ?: "none"} " +
                "location=$location",
            )
            Log.i(LOG_TAG, "DEBUG_FULL_RESPONSE_BEGIN method=${request.method} status=${it.code}")
            it.headers.forEach { (name, value) ->
              val safeValue = if (name.equals("Set-Cookie", ignoreCase = true)) "<redacted>" else value
              Log.i(LOG_TAG, "DEBUG_FULL_RESPONSE_HEADER $name: $safeValue")
            }
            Log.i(LOG_TAG, "DEBUG_FULL_RESPONSE_BODY ${responseBody.ifEmpty { "<empty>" }}")
            Log.i(LOG_TAG, "DEBUG_FULL_RESPONSE_END method=${request.method} status=${it.code}")
          }

          val result = Arguments.createMap().apply {
            putInt("status", it.code)
            putString("body", responseBody)
            putMap("headers", Arguments.createMap().apply {
              it.headers.names().forEach { name -> putString(name, it.header(name)) }
            })
          }
          promise.resolve(result)
        }
      }
    })
  }

  private companion object {
    private const val NAME = "AuthentikFlow"
    private const val AUTHENTIK_HOST = "auth.lovedage.com"
    private const val AUTHENTIK_AUTHORITY = "auth.lovedage.com:8093"
    private const val FLOW_PATH_PREFIX = "/api/v3/flows/executor/"
    private const val AUTHORIZATION_PATH = "/application/o/authorize/"
    private const val JSON_ACCEPT = "application/json"
    private const val LOG_TAG = "AuthentikFlow"
    private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

    private fun redactPasswords(body: String?): String {
      if (body.isNullOrBlank()) return "<none>"
      return try {
        JSONObject(body).apply {
          if (has("password")) put("password", "<redacted>")
          if (has("password-repeat")) put("password-repeat", "<redacted>")
        }.toString()
      } catch (_: Exception) {
        "<unparseable body; length=${body.length}>"
      }
    }

    private fun isAllowedPath(path: String): Boolean =
      path.startsWith(FLOW_PATH_PREFIX) || path == AUTHORIZATION_PATH
  }
}
