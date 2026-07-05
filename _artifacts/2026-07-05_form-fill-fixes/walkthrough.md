# Walkthrough — Booking Form Fixes

**Date:** 2026-07-05 · **Branch:** `claude/form-fill-fixes-plan-oso671` · **PR:** #1

## What changed

### Fix 1 — Phone number replaces Instagram handle
- `BookingForm.tsx`: the "Instagram Handle" field is now "Phone Number" (`type="tel"`, `name="phone"`, optional).
- `route.ts`: booking email shows **Phone** instead of Instagram.

### Fix 2 — Reference image upload with client-side compression
- `BookingForm.tsx`: added a multi-file image input (max 4) under Reference Links, with a live count/hint. On submit, images are compressed in-browser via `browser-image-compression` (~1 MB / 1600px max) and sent as base64 attachments. Button shows "Compressing..." → "Transmitting...".
- `route.ts`: validates/caps attachments (≤4, must have `filename`+`content`) and attaches them to the **artist** email only. Adds a "Reference Images: N attached" line. Client auto-reply stays attachment-free.
- Added dependency: `browser-image-compression@^2.0.2`.
- No Firebase Storage used (per decision) — rides the existing Resend email flow.

### Fix 3 — Auto-reply locked against iPhone dark mode
- `route.ts`: rebuilt the client auto-reply as a `bgcolor`-locked table layout. Page + card backgrounds set via `bgcolor` HTML attributes (respected even when clients override CSS), `color-scheme`/`supported-color-schemes` set to `dark`, plus Gmail `[data-ogsc]`/`[data-ogsb]` override selectors forcing the fixed palette. Renders identically in iPhone light and dark.

## Verification
- `npm install` + `npm run build` → compiled successfully, TypeScript passed (Next 16; `next lint` was removed upstream, so build is the typecheck).
- Pre-existing unrelated warning: `metadataBase` not set.
- ⚠️ Live email requires `RESEND_API_KEY` in the deployed/preview env — locally the route simulates success. Fix 3's dark-mode behavior must be confirmed on a real iPhone; if it still shifts, the fallback is rendering the card as a hosted PNG (not yet needed).

## Task Checklist
- [x] Fix 1 — phone field (form + email)
- [x] Fix 2 — image upload + compression + attachments (no Firebase)
- [x] Fix 3 — dark-mode-locked auto-reply (table/bgcolor)
- [x] Build + typecheck pass
- [x] Committed + pushed; draft PR #1 updated

## Your Actions
1. Set `RESEND_API_KEY` (and verify the `brkntattoos.com` sender domain in Resend) in the deploy/preview env, then submit a live test.
2. Open the auto-reply on your iPhone in **both** light and dark mode and confirm no color shift.
3. Review draft PR #1; mark ready / merge when satisfied.
