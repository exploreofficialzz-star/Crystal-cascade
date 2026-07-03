# Crystal Cascade — Paystack Backend

Small verification server for the Paystack fallback purchase path
(sideloaded / non-Play-Store installs only). Play Store installs are
untouched — they keep using Google Play Billing exactly as before.

## Why this exists

Paystack's own docs are direct about this: **never call the Paystack API
from your frontend** — doing so from a mobile app means shipping your
secret key inside the compiled APK, where it can be pulled out with a
decompiler. This server holds the secret key instead. The Flutter app only
ever talks to *this* server — never to `api.paystack.co` directly.

## What it does

- `POST /paystack/initialize` — looks up the price for a `productId` from
  its own table (the app never sends an amount, so a modified client can't
  talk itself into a cheaper price), asks Paystack for a checkout URL,
  returns it.
- `POST /paystack/verify` — confirms with Paystack, server-to-server, that a
  payment really succeeded **and** that the amount paid covers the
  product's price, before telling the app it's safe to grant the reward.

## Before going live — please check these

1. **Verify the NGN prices** in `server.js` (`PRICES_KOBO`). They're a rough
   placeholder conversion of your existing USD Play Store prices at
   roughly ₦1,500/$1 — check them against your Paystack dashboard and
   current exchange rates, and adjust if your account settles in a
   different currency.
2. **Test with your test key first.** Set `PAYSTACK_SECRET_KEY=sk_test_...`
   and run a full purchase using one of Paystack's test cards before
   switching to `sk_live_...`. Paystack's docs have a list of test card
   numbers for this.
3. Confirm NGN is enabled on your Paystack account, or change `currency` in
   `server.js` if you're settling in a different one.
4. Once deployed, put the resulting base URL into
   `lib/services/paystack_service.dart` → `backendBaseUrl`. It's left as an
   obvious placeholder (`YOUR-BACKEND-URL-HERE`) on purpose — the app treats
   the Paystack path as "not configured" and fails safely until that's set,
   rather than pointing nowhere and silently failing every payment.

## Deploy — pick one

### Option A: Firebase Cloud Functions (nothing to manage)

1. `npm install -g firebase-tools` if you don't already have it.
2. `firebase login`
3. From this folder: `firebase init functions` — choose JavaScript, and
   when it asks about overwriting files, keep this existing `server.js`.
4. Uncomment the two Firebase export lines at the bottom of `server.js`.
5. Set the secret key without ever putting it in a file:
   `firebase functions:secrets:set PAYSTACK_SECRET_KEY`
6. `firebase deploy --only functions`
7. Your endpoints will be at:
   `https://<region>-<project-id>.cloudfunctions.net/api/paystack/initialize`
   and `.../api/paystack/verify` — use that base (up to `/api`) as
   `backendBaseUrl` in the Flutter service.

### Option B: Render / Railway (simple, free tier available)

1. Push this `paystack-server/` folder to a GitHub repo (its own, or a
   subfolder of your existing project — either works).
2. Create a new Web Service pointing at it.
   Build command: `npm install`. Start command: `npm start`.
3. In the host's dashboard, add an environment variable
   `PAYSTACK_SECRET_KEY` — never in code, never committed.
4. Copy the URL the host gives you into `backendBaseUrl`.

## The callback page

`callback-page/callback.html` is a tiny static "you can close this and
return to the app" page. The in-app checkout WebView intercepts Paystack's
redirect to this URL *before* it really needs to render, so its content
barely matters most of the time — but hosting it somewhere real (e.g. your
existing GitHub Pages, same place as your privacy policy) covers the rare
case where a device's WebView shows a frame before interception fires.
Host it wherever, then update the URL in two places to match:
`PaystackService.callbackUrl` in the Flutter app, and wherever you point
your Paystack dashboard's default callback URL.

## Never do this

- Never put `PAYSTACK_SECRET_KEY` in the Flutter app, in `constants.dart`,
  or in any file that ships inside the APK.
- Never commit a real `.env` file.
- Never paste the secret key into a chat with an AI assistant, including
  this one — set it directly as an environment variable on whatever you
  deploy to.

## What this design does and doesn't protect against

This setup stops the two realistic remote attacks: paying less than a
product costs (amount is always server-determined, never client-sent), and
claiming a reward without ever paying (verify always re-checks with
Paystack directly, server-to-server). It does **not** protect against
someone editing their own device's local save data directly — but nothing
short of a full server-authoritative economy (a much bigger undertaking)
protects against that for *any* purchase path, including the existing
Google Play Billing side of this same app. That's a reasonable, deliberate
scope match to the rest of the app's architecture, not an oversight.
