// plaid_oauth_state_web.dart
//
// Web-only helpers that bridge the Plaid OAuth redirect (kleenops.web.app/
// plaid-oauth?oauth_state_id=...) back to the active Link session.
//
// When `openPlaidLink` runs on web, we persist the link_token to
// sessionStorage. If the browser later lands on the OAuth redirect path with
// an `oauth_state_id` query param, the app boot logic re-opens Plaid Link
// with `receivedRedirectUri: window.location.href` to resume the session.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _kLinkTokenKey = 'plaid.link_token';

void saveLinkToken(String token) {
  html.window.sessionStorage[_kLinkTokenKey] = token;
}

String? readLinkToken() {
  return html.window.sessionStorage[_kLinkTokenKey];
}

void clearLinkToken() {
  html.window.sessionStorage.remove(_kLinkTokenKey);
}

/// Returns the current window URL iff it appears to be a Plaid OAuth
/// redirect (path /plaid-oauth and contains `oauth_state_id`). Otherwise
/// returns null.
String? readOauthRedirectUri() {
  final loc = html.window.location;
  final path = loc.pathname ?? '';
  final search = loc.search ?? '';
  if (!path.contains('/plaid-oauth')) return null;
  if (!search.contains('oauth_state_id')) return null;
  return loc.href;
}
