// plaid_oauth_state_io.dart
//
// No-op fallback for non-web platforms. The web variant
// (plaid_oauth_state_web.dart) uses window.sessionStorage and
// window.location to detect OAuth resumption.

void saveLinkToken(String token) {}

String? readLinkToken() => null;

void clearLinkToken() {}

String? readOauthRedirectUri() => null;
