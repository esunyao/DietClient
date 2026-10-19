'use strict';
(() => {
  const incoming = new URL(window.location.href);
  // Keep only the authorization response in memory; remove it from the address
  // bar before starting communication. No token or browser storage is used.
  window.history.replaceState(null, '', incoming.pathname);
  const status = document.getElementById('status');
  const values = incoming.searchParams;
  const state = values.get('state');
  const allowed = new Set(['state', 'code', 'error', 'error_description', 'error_uri', 'iss', 'session_state']);
  const duplicates = [...values.keys()].some(key => values.getAll(key).length !== 1);
  if (!state || !/^[a-zA-Z0-9_-]{20,128}$/.test(state) || duplicates || incoming.hash ||
      [...values.keys()].some(key => !allowed.has(key)) ||
      (values.has('code') === values.has('error'))) {
    status.textContent = 'Invalid sign-in response. Close this window and try again.';
    return;
  }
  const channel = new BroadcastChannel(`diet-oidc-${state}`);
  const message = JSON.stringify({type: 'oidc_callback', state,
    origin: incoming.origin, callback: incoming.toString()});
  let stopped = false;
  const send = () => { if (!stopped) channel.postMessage(message); };
  const timer = window.setInterval(send, 300);
  const expiry = window.setTimeout(() => {
    stopped = true;
    window.clearInterval(timer);
    channel.close();
    status.textContent = 'The application did not respond. Close this window and retry sign-in.';
  }, 30000);
  channel.onmessage = event => {
    if (event.origin !== incoming.origin || typeof event.data !== 'string') return;
    try {
      const data = JSON.parse(event.data);
      if (data.type !== 'oidc_ack' || data.state !== state) return;
      stopped = true;
      window.clearInterval(timer);
      window.clearTimeout(expiry);
      channel.close();
      status.textContent = 'Response returned. You may close this window.';
      window.close();
    } catch (_) { /* Ignore unrelated channel messages. */ }
  };
  send();
})();
