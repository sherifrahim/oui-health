# Finding 0002 — Samsung Account login already has a non-Samsung path

- **Target:** `com.samsung.android.app.watchmanager` v2.2.72, classes
  `...twatchmanager.samsungaccount.{SALoginHelper,SAGUIDHelper,QAStoreTokenGenerator,ScspSATokenHelper}`
  and `...setupwizard.contactus.connection.SAWebViewActivity`.
- **Category:** **(B)** — a channel Samsung already implemented for non-Samsung, with one **(A/C)**
  gap (silent token refresh).
- **Question answered:** can Samsung Account sign-in work on a non-Samsung phone? **Yes.** It uses
  your real account through Samsung's official web OAuth. Nothing is forged.
- **Status:** CONFIRMED by decompilation.

## Two sign-in paths, chosen by `isSamsungDevice()`

`SALoginHelper.requestSALogin()` branches:

```java
if (!PlatformUtils.isSamsungDevice()) {
    // NON-SAMSUNG: Samsung's own built-in WebView OAuth flow
    filter.addAction("com.samsung.android.app.watchmanager.ACTION_SA_WEBVIEW_LOGIN_SUCCESS");
    Intent i = new Intent(activity, SAWebViewActivity.class);
    i.putExtra("intent_data_scope_key", "galaxystore.openapi");
    activity.startActivity(i);
} else {
    // SAMSUNG: on-device Samsung Account app
    filter.addAction("com.samsung.account.SAMSUNGACCOUNT_SIGNIN_COMPLETED"); ...
    launchSALoginActivity(activity);
}
```

So the host **already ships** a non-Samsung login path. The interactive sign-in works off-Samsung
with no modification.

### The web OAuth endpoint (confirmed literals)

- `SAWebViewActivity` loads `https://account.samsung.com/accounts/wmanager/signInGate?`
  (US: `https://us.account.samsung.com/accounts/wmanager/signInGate?`)
- `client_id = "39kc4o8c10"`, `OSP_VER = "OSP_02"`, scope `galaxystore.openapi`
- On success it broadcasts `ACTION_SA_WEBVIEW_LOGIN_SUCCESS` and stores into SharedPreferences
  `SA_PREF_DATA`: `access_token`, `access_token_expiration_time`.

### The Samsung-phone path (for reference)

`launchSALoginActivity()` fires `com.osp.app.signin.action.ADD_SAMSUNG_ACCOUNT` (fallback
`com.msc.action.samsungaccount.SIGNIN_POPUP`) with `client_id=39kc4o8c10`, handled by the Samsung
Account app `com.osp.app.signin`. Token refresh uses `com.msc.action.samsungaccount.REQUEST_ACCESSTOKEN`.

## The one real gap: silent token refresh

`requestSATokenDataOnBackground()` (no UI, used for background sync) only refreshes on Samsung:

```java
if (isTokenExpired || !hasToken) {
    if (isSamsungDevice()) saTokenService.requestAccessToken(force);  // on-device SAClient
    // else: no-op  ← off-Samsung, background refresh does nothing
}
```

`tokenProcessAfterSignIn()` (has an Activity) does better off-Samsung — it falls back to
`requestSALogin()` → the WebView. So:

- **Interactive flows** (initial pairing, anything with a screen): work off-Samsung today.
- **Background/silent refresh**: off-Samsung it is a no-op, so when the token expires the app must
  re-prompt the WebView instead of refreshing quietly.

## How to make account login fully work off-Samsung

1. **Interactive login — nothing to do.** Use the phone normally; the WebView `signInGate` flow
   signs you into your real Samsung account and stores the token.
2. **Close the silent-refresh gap**, pick one:
   - **(A, cleanest) satisfy `isSamsungDevice()`** (finding 0001 lever) *and* install the standalone
     **Samsung Account app** `com.osp.app.signin` (it installs on non-Samsung phones). Then the
     on-device `REQUEST_ACCESSTOKEN` service path runs and refreshes silently, exactly like a
     Samsung phone.
   - **(B, no root) refresh via the web flow**: persist the `access_token` +
     `access_token_expiration_time` and re-run the `signInGate` WebView (it is usually a silent
     redirect when the SSO cookie is still valid) before expiry; write the result back into
     `SA_PREF_DATA`.

Both use your own account and Samsung's official OAuth — no credential forging, no token minting.

## Scope / risks

- Base split only; Samsung Health has its own account handling to analyze separately (needs that
  APK).
- Option 2A inherits finding 0001's risks (hook vs resign).
- The web flow's exact redirect params come from `SAWebViewActivity`'s URL builder — decompile it
  (`decompile_targets.py ... SAWebViewActivity`) before implementing option 2B.
- Reproduce: `decompile_targets.py tools/inputs/GalaxyWearable.apk requestSALogin launchSALoginActivity tokenProcessAfterSignIn`.
