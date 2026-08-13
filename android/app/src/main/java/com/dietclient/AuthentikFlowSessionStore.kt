package com.dietclient

import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import okhttp3.Headers
import okhttp3.Request

internal class AuthentikFlowSessionStore {
  private data class FlowSession(var cookie: String? = null)

  data class CookieAttachment(
    val name: String?,
    val attached: Boolean,
    val source: String,
  )

  private val sessions = ConcurrentHashMap<String, FlowSession>()

  fun create(): String {
    val sessionId = UUID.randomUUID().toString()
    sessions[sessionId] = FlowSession()
    return sessionId
  }

  fun close(sessionId: String) {
    sessions.remove(sessionId)
  }

  fun contains(sessionId: String): Boolean = sessions.containsKey(sessionId)

  /**
   * 将首次 GET 保存的 authentik_session 明确写入下一次请求的 Cookie header。
   * 返回值仅供脱敏诊断，绝不包含 Cookie value。
   */
  fun addCookie(
    sessionId: String,
    requestBuilder: Request.Builder,
    hasExplicitCookie: Boolean,
  ): CookieAttachment {
    if (hasExplicitCookie) {
      return CookieAttachment(AUTHENTIK_SESSION_COOKIE, true, "request_headers")
    }
    val session = sessions[sessionId]
      ?: return CookieAttachment(null, false, "session_missing")
    synchronized(session) {
      val cookie = session.cookie
        ?: return CookieAttachment(null, false, "session_store_empty")
      // 这里是注册 POST 实际添加 Cookie 的位置。使用 header() 覆盖而不是 addHeader()，
      // 保证每个请求只有一个 Cookie header，避免重复 Cookie 污染 Authentik Flow。
      requestBuilder.header("Cookie", cookie)
      return CookieAttachment(AUTHENTIK_SESSION_COOKIE, true, "session_store")
    }
  }

  fun absorb(sessionId: String, headers: Headers) {
    val session = sessions[sessionId] ?: return
    val nextCookie = headers.values("Set-Cookie")
      .firstOrNull { it.startsWith("authentik_session=", ignoreCase = true) }
      ?.substringBefore(';')
      ?: return
    synchronized(session) { session.cookie = nextCookie }
  }

  private companion object {
    private const val AUTHENTIK_SESSION_COOKIE = "authentik_session"
  }
}
