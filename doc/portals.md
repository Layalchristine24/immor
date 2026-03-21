# Real Estate Portal Landscape

## Implementation Status (as of 2026-03-21)

### Swiss Portals

| Portal | Status | Protection | Notes |
|---|---|---|---|
| flatfox.ch | ✅ Working | None | Public REST API, robots.txt allows scraping |
| homegate.ch | ❌ Blocked | DataDome | 403, code preserved for future use |
| immoscout24.ch | ❌ Blocked | DataDome + Cloudflare | 403 |
| comparis.ch | ❌ Blocked | DataDome | 403 |
| newhome.ch | ❌ Blocked | Cloudflare challenge | 403 |
| properstar.ch | ❌ Blocked | Azure Front Door | 403 |
| ronorp.net | ⚠️ Accessible | None | Minimal structured data, not useful |

### International Portals

| Portal | Country | Status | Notes |
|---|---|---|---|
| willhaben.at | Austria | ⚠️ Forbidden | Accessible but robots.txt explicitly forbids automated access |
| rightmove.co.uk | UK | ⚠️ No API | Page loads but no embedded JSON or public API |
| funda.nl | Netherlands | ⚠️ No API | Page loads but API endpoint returns HTML |
| fotocasa.es | Spain | ⚠️ No API | Page loads but API returns 403 |
| idealista.com | Spain/IT/PT | ❌ Blocked | DataDome, 403 |
| immobilienscout24.de | Germany | ❌ Blocked | 401 |
| immowelt.de | Germany/AT | ❌ Blocked | 403 |
| zillow.com | US | ❌ Blocked | 403 |
| casa.it | Italy | ❌ Blocked | 403 |

### Security Assessment

- All portals use **HTTPS** with valid TLS certificates
- flatfox has **HSTS** (Strict-Transport-Security)
- immor enforces rate limiting: 1 request per 2 seconds, 3 retries with backoff
- **robots.txt compliance**:
  - flatfox: Allows `/` (only blocks `/admin/`, `/cockpit/`) ✅
  - willhaben: Header says "It is expressively forbidden to use spiders, search robots or other automatic methods" ❌
  - Blocked portals enforce restrictions at infrastructure level (DataDome/Cloudflare)

### Key Finding

As of March 2026, **flatfox.ch is the only real estate portal** (Swiss or international) that:
1. Has a public REST API
2. Allows automated access in robots.txt
3. Does not use bot protection

All other major portals have adopted DataDome or Cloudflare bot protection. Adding new portals would require either:
- Official API access (partner agreements)
- Browser automation (Playwright/Selenium) — out of scope for httr2-based scraping

---

## Portal Details

### flatfox.ch (Working ✅)
- **API**: `/api/v1/public-listing/` (was `/api/v1/flat/`, changed ~2026)
- **Pagination**: `offset`/`limit` params, `next` field in response
- **Listings**: ~33k total (mostly RENT, some SALE)
- **Note**: API ignores all filter params (location, rooms, price, offer_type). Returns all listings sorted by `-published`.
- **Languages**: DE, FR, EN

### homegate.ch (Blocked ❌)
- **Traffic**: ~2M visits/mo
- **Protection**: DataDome bot detection
- **Was**: HTML with `__NEXT_DATA__` JSON — code preserved in `R/portal-homegate.R`
- **Part of**: Swiss Marketplace Group (SMG)

### immoscout24.ch (Blocked ❌)
- **Traffic**: ~2.6M visits/mo (market leader)
- **Protection**: DataDome + Cloudflare
- **Part of**: SMG group

### comparis.ch (Blocked ❌)
- **Traffic**: ~1.5M visits/mo
- **Protection**: DataDome
- **Note**: Meta-search aggregator
