# Spearo Diary — developer notes

Personal spearfishing log. Live at https://spearodiary.github.io/ (GitHub Pages, this repo's root).
There is also a Claude artifact version (no social, forecast or sharing): `dev/src/notebook.html`.

## Layout

| Path | What |
|---|---|
| `index.html` | **Built** site that GitHub Pages serves. Don't edit by hand — build it. |
| `dev/src/site.html` | Site source (empty Supabase config + `__BUILD__` placeholder). |
| `dev/src/notebook.html` | Claude artifact version, kept in sync with the site where it makes sense. |
| `dev/build.py` | Fills in the Supabase URL + publishable key and a build stamp → `index.html`. |
| `dev/sql/` | Supabase SQL, run in the SQL editor (see below). |
| `dev/tests/smoke.js` | Playwright smoke test for both versions, phone + desktop. |
| `dev/tests/mock.js` | Fake Supabase (localStorage) used by the tests. |
| `dev/tests/data/` | Small synthetic dive files (.fit, UDDF, Subsurface XML). No real user data here — the repo is public. |
| `sw.js`, `manifest.webmanifest`, `icons/` | PWA (home-screen app). |

## Everyday loop

```
# 1. edit dev/src/site.html (and dev/src/notebook.html if the change applies there too)
# 2. syntax + smoke test
node dev/tests/smoke.js
# 3. build and publish
python3 dev/build.py
git add -A && git commit -m "…" && git push
```

Pages deploys in a minute or two (`gh run list -R spearodiary/spearodiary.github.io -L 1`).
Phones running the home-screen app may need the app closed and reopened to pick up a new build.

The artifact is republished from `dev/src/notebook.html` with Claude's Artifact tool (same file path keeps the same URL).

## Rules

- Never lose entry data: changes to saved fields must stay backward compatible (old entries keep working).
- Test before publishing (smoke test + a look at the changed screen on phone width).
- Only the **publishable** Supabase key goes in the page. Never the secret / service_role key.

## Supabase

Project `mxerbyvbdednjnvhhjlp`. Tables: `entries`, `profiles`, `follows`, `shared_catches`, `likes`, `comments`.
Storage bucket `photos`: `uid/t/` thumbnails, `uid/m/` screen-size copies, `uid/share/` posted photos, `uid/share/avatar.jpg`.
Access is enforced with RLS; helper functions `can_see`, `tagged_by` (security definer).

SQL files in `dev/sql/`, in the order they were introduced:
`supabase-setup.sql` → `supabase-social.sql` → `supabase-friends.sql` → `supabase-pause.sql` → `supabase-online.sql` → `supabase-tags.sql`.
Status: everything up to `supabase-online.sql` has been run. **`supabase-tags.sql` — not confirmed** (needed so tagged friends can see shared photos).

Free-plan limits to watch (Usage page): 500 MB database, 1 GB file storage, 5 GB egress; no automatic backups; project pauses after a week without activity.
Auth uses email + password. Auth emails go out through a custom SMTP sender (the owner's Gmail with an app password), not Supabase's built-in mailer, which only reaches the project team (2/hour). Watch: Supabase's own limit for custom SMTP (Auth → Rate Limits, 30 emails/hour by default) and Gmail's daily sending cap.

## Code map (site.html)

- Entries: `readForm`, `openForm`, `entryHtml`, `saveEntry`; compact-mode fields `cfApply`/`CF`/`CF_DEF`; card order `cardOrd`/`C_DEF`.
- Import from dive computers: `fitParse` (binary .FIT), `xmlParse` (UDDF, Subsurface, Suunto SML, MacDive), `impSummary`, `impFile`.
  Both build the same compact dive log (`fitLog` / `dlFromDives`) stored as `entry.dlog`.
- Watch charts: `dlBuild` (all charts + insights), `dlogHtml` (grid), `dlOne` (single chart), `dlCombo` (overlay), `dlShow`;
  chart kit `dlFrame`/`dlBars`/`dlLine`/`dlScatter`; order + overlay choices in localStorage (`sn-dlord`, `sn-dlov`).
- Forecast ("Mar e tempo"): `fcLoad` (Open-Meteo: weather 14 days, sea 8 days = the marine API maximum; cached 1 h), `drawForecast`, folded strip `fcStrip`, palettes `FCS_*` + `sn-fcpal`.
  Hunting windows: `fwWindows` with the user's limits from Settings → Definições de mar e tempo (`sn-fcwin`, wind stored in knots).
- Chart settings: hidden charts `sn-dlhide` (Settings → Definições dos gráficos); interactive dive map `dlMapOpen` (Leaflet from unpkg, Esri imagery; site only).
- Social: `soMePage`, `soTagged`, `soShare`, `postSet`/`onBtn`/`canOnOff` (online/offline per post).
- Share image: `scOpen`/`scPaint`; avatar crop `avCrop`.
- Phone: windows pin the page behind them (body lock) and start under the status band.
