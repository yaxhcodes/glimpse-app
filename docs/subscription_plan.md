# Glimpse subscription plan

## Launch pricing

- India: ₹299 per month
- Other storefronts: US$7.99 per month (or the store's localized equivalent)

Prices are owned by Google Play / App Store Connect and surfaced through
RevenueCat. They are intentionally not hardcoded in the Flutter app.

## Product allowances

| Feature | Free | Glimpse Pro |
| --- | --- | --- |
| Ordinary link saving | Unlimited | Unlimited |
| AI-enriched saves | 30 lifetime | 500 per UTC month |
| Ask Glimpse | 30 per UTC month | Expanded access, subject to fair use |
| Search | 30 per UTC month | Expanded access, subject to fair use |

An item is still saved locally when its AI allowance is exhausted; it simply
skips AI enrichment. Product copy must not describe AI, Ask, or search as
unlimited.

## Cost and abuse protection

Product allowances and infrastructure safeguards are separate. The gateway
verifies the `Glimpse Pro` RevenueCat entitlement server-side and also applies
rate limits to paid operations. Current safeguards include:

- AI save/enrichment calls: 3 per minute, 30 per day, 500 per month
- Ask Glimpse model calls: 6 per minute, 60 per hour, 20 per day, 600 per month
- Generic model calls retain their independent gateway ceiling

These safeguards protect the service from automation and compromised clients;
they are not marketed as additional plan benefits.

## Release configuration

1. Configure the monthly products and localized prices in Google Play and App
   Store Connect.
2. Attach both products to the RevenueCat offering and the exact entitlement
   identifier `Glimpse Pro`.
3. Add the RevenueCat v1 secret API key to the proxy Worker:
   `npx wrangler secret put REVENUECAT_V1_SECRET_API_KEY`.
4. Verify a free customer receives the lifetime-30 allowance and a subscribed
   customer receives the monthly-500 allowance before deploying the new app.
