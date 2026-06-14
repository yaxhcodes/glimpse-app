# AI proxy worker — moved

The Cloudflare Worker that the app calls for AI (Gemini / Voyage) and the
free-tier `/quota` endpoint lives in its **own repository**, not here:

➡️ **https://github.com/yaxhcodes/glimpse-proxy**

That repo is the deployed source of truth (Hono + TypeScript, `src/index.ts`,
served at `https://glimpse-proxy.glimpse.workers.dev`). Deploy from there with
`npm run deploy`.

The old `glimpse-proxy/` JavaScript copy that used to sit in this folder was a
stale mirror that was never deployed — it has been removed to avoid confusion.
Make worker changes in the external repo above.
