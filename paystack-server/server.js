/**
 * Crystal Cascade — Paystack verification backend
 * ─────────────────────────────────────────────────
 * Serves the sideloaded-install (non-Play-Store) purchase fallback.
 * Play Store installs are untouched — they keep using Google Play Billing.
 *
 * Why this file has to exist at all: Paystack's own docs say plainly not to
 * call their API directly from a mobile client, because that means shipping
 * your secret key inside the compiled app, where anyone with a decompiler
 * can pull it out. This server holds the secret key instead — set via the
 * PAYSTACK_SECRET_KEY environment variable, never hardcoded, never committed.
 * The Flutter app only ever talks to THIS server, never to api.paystack.co
 * directly.
 *
 * See README.md in this folder for deployment steps.
 */

const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;
const PAYSTACK_BASE = 'https://api.paystack.co';

// ─── Server-side price table ─────────────────────────────────────────────────
// This is the ONLY place price is decided. The app never sends an amount —
// only a productId — specifically so a modified/patched client can't talk
// itself into a cheaper price. Values are in kobo (NGN subunit: ₦1 = 100 kobo).
//
// ⚠️ These are placeholder conversions of the existing USD Play Store prices
// at a rough ~₦1,500/$1 rate, rounded for clean numbers. Verify/adjust these
// against your Paystack dashboard and current exchange rates before going
// live — getting this wrong means real over- or under-charging.
const PRICES_KOBO = {
  remove_ads_day:     150000,   // ~$0.99  → ₦1,500
  remove_ads_weekend: 450000,   // ~$2.99  → ₦4,500
  remove_ads_month:   1350000,  // ~$8.99  → ₦13,500
  hint_pack_small:    150000,   // ~$0.99  → ₦1,500
  hint_pack_large:    300000,   // ~$1.99  → ₦3,000
  coin_pack_starter:  150000,   // ~$0.99  → ₦1,500
  mega_pack:          750000,   // ~$4.99  → ₦7,500
};

function requireSecretKey(res) {
  if (!PAYSTACK_SECRET_KEY) {
    res.status(500).json({ error: 'Server misconfigured: PAYSTACK_SECRET_KEY is not set.' });
    return false;
  }
  return true;
}

// ── POST /paystack/initialize ────────────────────────────────────────────────
// Body: { productId, email, callbackUrl }
// Returns: { authorizationUrl, reference }
app.post('/paystack/initialize', async (req, res) => {
  if (!requireSecretKey(res)) return;

  const { productId, email, callbackUrl } = req.body || {};
  const amount = PRICES_KOBO[productId];

  if (!amount) {
    return res.status(400).json({ error: `Unknown productId: ${productId}` });
  }
  if (!email || typeof email !== 'string') {
    return res.status(400).json({ error: 'A valid email is required.' });
  }

  try {
    const response = await fetch(`${PAYSTACK_BASE}/transaction/initialize`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email,
        amount,               // server-determined — never trust a client-sent amount
        currency: 'NGN',
        callback_url: callbackUrl,
        metadata: { productId },
      }),
    });

    const data = await response.json();

    if (!data.status) {
      console.error('[initialize] Paystack rejected:', data.message);
      return res.status(502).json({ error: data.message || 'Paystack initialize failed.' });
    }

    return res.json({
      authorizationUrl: data.data.authorization_url,
      reference: data.data.reference,
    });
  } catch (err) {
    console.error('[initialize] error:', err);
    return res.status(500).json({ error: 'Could not reach Paystack.' });
  }
});

// ── POST /paystack/verify ────────────────────────────────────────────────────
// Body: { reference, productId }
// Returns: { verified: boolean }
//
// Two checks matter here, not just one: the payment must be marked
// "success" by Paystack itself (server-to-server, using the secret key —
// never trust a client's say-so), AND the amount actually paid must meet
// the expected price for productId. Checking status alone would let someone
// pay for the cheapest item and then claim that reference covers the
// most expensive one.
app.post('/paystack/verify', async (req, res) => {
  if (!requireSecretKey(res)) return;

  const { reference, productId } = req.body || {};
  const expectedAmount = PRICES_KOBO[productId];

  if (!reference) return res.status(400).json({ error: 'reference is required.' });
  if (!expectedAmount) return res.status(400).json({ error: `Unknown productId: ${productId}` });

  try {
    const response = await fetch(
      `${PAYSTACK_BASE}/transaction/verify/${encodeURIComponent(reference)}`,
      { headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` } }
    );
    const data = await response.json();
    const paid = data && data.data;

    const success =
      data.status === true &&
      paid?.status === 'success' &&
      paid?.currency === 'NGN' &&
      typeof paid?.amount === 'number' &&
      paid.amount >= expectedAmount;

    if (!success) {
      console.warn('[verify] not verified:', { reference, productId, paidStatus: paid?.status, paidAmount: paid?.amount, expectedAmount });
    }

    return res.json({ verified: success });
  } catch (err) {
    console.error('[verify] error:', err);
    return res.status(500).json({ error: 'Could not reach Paystack.' });
  }
});

app.get('/health', (req, res) => res.json({ ok: true }));

// ── Run standalone (Render / Railway / any plain Node host) ─────────────────
if (require.main === module) {
  const port = process.env.PORT || 3000;
  app.listen(port, () => console.log(`Paystack backend listening on :${port}`));
}

// ── Firebase Cloud Functions export ──────────────────────────────────────────
// Uncomment these two lines if deploying via Firebase — see README.md.
// const functions = require('firebase-functions');
// exports.api = functions.https.onRequest(app);

module.exports = app;
