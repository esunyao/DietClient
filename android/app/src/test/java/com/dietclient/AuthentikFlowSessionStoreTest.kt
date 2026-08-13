package com.dietclient

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AuthentikFlowSessionStoreTest {
  private lateinit var server: MockWebServer
  private val client = OkHttpClient()
  private val sessions = AuthentikFlowSessionStore()

  @Before
  fun setUp() {
    server = MockWebServer()
    server.start()
  }

  @After
  fun tearDown() {
    server.shutdown()
  }

  @Test
  fun cookiesAreIsolatedAndRemovedWithTheirFlowSession() {
    val firstSession = sessions.create()
    val secondSession = sessions.create()
    assertNotEquals(firstSession, secondSession)

    server.enqueue(MockResponse().setHeader("Set-Cookie", "authentik_session=first; Path=/; HttpOnly"))
    server.enqueue(MockResponse().setHeader("Set-Cookie", "authentik_session=second; Path=/; HttpOnly"))
    sessions.absorb(firstSession, client.newCall(Request.Builder().url(server.url("/start-first")).build()).execute().use { it.headers })
    sessions.absorb(secondSession, client.newCall(Request.Builder().url(server.url("/start-second")).build()).execute().use { it.headers })

    val firstRequest = Request.Builder().url(server.url("/submit-first"))
    val secondRequest = Request.Builder().url(server.url("/submit-second"))
    val firstAttachment = sessions.addCookie(firstSession, firstRequest, hasExplicitCookie = false)
    val secondAttachment = sessions.addCookie(secondSession, secondRequest, hasExplicitCookie = false)

    assertTrue(firstRequest.build().header("Cookie") == "authentik_session=first")
    assertTrue(secondRequest.build().header("Cookie") == "authentik_session=second")
    assertEquals("authentik_session", firstAttachment.name)
    assertTrue(firstAttachment.attached)
    assertEquals("session_store", firstAttachment.source)
    assertEquals("authentik_session", secondAttachment.name)

    sessions.close(firstSession)
    assertFalse(sessions.contains(firstSession))
    assertTrue(sessions.contains(secondSession))
  }
}
