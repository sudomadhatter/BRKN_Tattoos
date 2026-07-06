# Implementation Plan — Booking Form Fixes

**Date:** 2026-07-05
**Branch:** `claude/form-fill-fixes-plan-oso671`
**Scope:** 2 files + 1 new dependency
- `frontend/src/components/sections/BookingForm.tsx`
- `frontend/src/app/api/contact/route.ts`
- add `browser-image-compression` to `frontend/package.json`

---

## Fix 1 — Replace Instagram handle with Phone number

**What:** Swap the "Instagram Handle" field for a "Phone Number" field.

**BookingForm.tsx** (lines ~143–147):
- Label `Instagram Handle` → `Phone Number`
- `<input name="instagram" placeholder="@" ...>` → `<input type="tel" name="phone" autoComplete="tel" placeholder="(555) 555-5555" ...>`
- Keep it optional (matches current Instagram field, which had no `required`).

**route.ts:**
- Destructure `phone` instead of `instagram` (line 16).
- Email HTML row (line 42): `<strong>Instagram:</strong> ${instagram...}` → `<strong>Phone:</strong> ${phone || 'Not provided'}`.

Low risk, purely a rename + input type change.

---

## Fix 2 — Reference image upload with client-side compression

**Recommended approach: compress in the browser, attach to the booking email.**
No new infrastructure (no Firebase Storage rules/auth needed) — it rides the existing Resend email flow.

**BookingForm.tsx:**
- Add a file input under the existing "Reference Links" field:
  `<input type="file" name="references" accept="image/*" multiple />` styled to match the dark theme, with a small helper line ("Up to 4 images — compressed automatically").
- Keep the existing `reference_url` text field (links + files both allowed).
- On submit, before the fetch:
  - Import `imageCompression` from `browser-image-compression`.
  - For each selected file (cap at **4**), compress to ~**1 MB / max 1600px**, then read to base64.
  - Add `attachments: [{ filename, content }]` to the JSON payload.
  - Show "Compressing..." on the button while this runs.

**route.ts:**
- Read `attachments` from the body; pass them to `resend.emails.send({ ..., attachments })` on the **artist** email only (not the client auto-reply).
- Guard: ignore if none; enforce the 4-file / size cap server-side too (Resend's hard limit is ~40 MB per message — compression keeps us far under it).

**Why not Firebase Storage:** it's available but adds storage-rule + upload plumbing and public-URL handling for marginal benefit. Email attachments are simpler and keep everything in one place for the artist. *If you'd rather have links to originals stored in Firebase instead of attachments, say so and I'll switch Fix 2 to that path.*

**New dependency:** `browser-image-compression` (~small, client-only, well-maintained).

---

## Fix 3 — Lock the auto-reply email against iPhone dark mode

**Problem:** The auto-reply is a dark design (`#0A0A0C` bg / `#EBEBE6` text). iOS Mail's dark mode applies its own color transforms and shifts the palette. The current `<meta color-scheme>` + `!important` isn't enough on iOS.

**Recommended fix (bulletproof-email technique — no image needed):**
1. Rebuild the card as a **table-based layout** using the `bgcolor` HTML attribute (e.g. `<td bgcolor="#0A0A0C">`) alongside the inline `style`. Dark-mode engines that override CSS `background-color` still generally respect the `bgcolor` attribute, so the color holds.
2. Add explicit dark-mode override selectors in the `<style>` block so clients that *do* transform colors are forced back to our palette:
   - Gmail: `[data-ogsc]` / `[data-ogsb]`
   - Apple Mail / iOS: `:root { color-scheme: light dark; }` (kept) + a `u + .body` / `u ~ div` targeted override wrapper.
3. Wrap text colors on the actual `<td>`/`<p>` elements (not just `<body>`) so nothing inherits a shifted color.

This keeps the email accessible, selectable, and identical in light and dark.

**Guaranteed fallback (only if the above still shifts on your device):** render the whole card as a single hosted PNG with alt text — 100% immune to dark mode, but not selectable/accessible. *I'll start with the table/bgcolor approach and only fall back to the image if you test it on your iPhone and it still moves.*

---

## Verification
- `npm run build` + `npm run lint` in `frontend/`.
- Manual: fill the form (phone shows, no Instagram), attach 1–4 images (compressed, artist email received with attachments), confirm auto-reply renders identically in iPhone light + dark.
- Note: without `RESEND_API_KEY` the route simulates success, so live email must be tested in the deployed/preview env.

## Rollout
- Commit per fix, push to `claude/form-fill-fixes-plan-oso671`, open a **draft PR**.

## Open decisions for you
1. **Fix 2 storage** — email attachments (recommended) vs. Firebase Storage links?
2. **Fix 3** — start with table/`bgcolor` locking (recommended); image fallback only if your device still shifts?
