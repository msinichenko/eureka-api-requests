# fse-eureka-requests

Bruno collection for FOLIO/Eureka operational and migration requests — Keycloak, consortia, MGR, reindex, users/roles, MARC migrations, and related modules.

## Requirements

- [Bruno](https://www.usebruno.com/) desktop app (v1.x+)
- Network access to the target FOLIO/Kong/Keycloak environment
- Valid tenant/client/user credentials for that environment

## Quick Start

1. Clone this repo and open the folder in Bruno (**Open Collection**).
2. Create a new environment: **Environments → Create Environment** (e.g. `dev`, `int`, `perf`).
   - Copy variable names from `environments/example.bru` and fill in real values.
   - **Never commit an environment file with real credentials** — `environments/` is git-ignored.
3. Select your environment from the top-right dropdown.
4. Run auth requests in order:
   - `auth/get-keycloak-tenant-token` — sets `okapi-token`
   - `auth/get-keycloak-master-realm-admin-token` — sets `master-realm-token` (Keycloak admin endpoints only)
   - `auth/user-login-token` — sets `folio-user-token` (cookie/login-with-expiry flows only)
5. Run the target request(s) from the relevant folder.

## Environment Variables

Create these in your Bruno environment. See `environments/example.bru` for a template.

### Input variables (set manually)

| Variable | Description |
|---|---|
| `folio` | Environment prefix used in hostnames (e.g. `dev`, `int`) |
| `domain` | Base domain for Kong and Keycloak (e.g. `example.org`) |
| `realm` | Tenant realm name — also used as `x-okapi-tenant` |
| `tenant_client` | Keycloak client ID for `client_credentials` token flow |
| `tenant_client_secret` | Secret for `tenant_client` |
| `admin_client_secret` | Secret for the backend admin Keycloak client |
| `keycloak_username` | Keycloak admin/service account username |
| `keycloak_password` | Keycloak admin/service account password |
| `tenant_username` | FOLIO user login (for `login-with-expiry` flow) |
| `tenant_password` | FOLIO user password |

### Auto-set by auth scripts (do not set manually)

| Variable | Set by |
|---|---|
| `okapi-token` | `auth/get-keycloak-tenant-token` |
| `master-realm-token` | `auth/get-keycloak-master-realm-admin-token` |
| `folio-user-token` | `auth/user-login-token` |

## Collection Layout

| Folder | Purpose |
|---|---|
| `auth/` | Token acquisition and login flows |
| `mgr/` | Application registration, discovery, entitlements, tenant management |
| `consortia/` | Consortia tenant and affiliation operations |
| `users-roles/` | Users, roles, capabilities, role migrations |
| `reindex/` | Reindex and inventory/instance workflows |
| `mark-migrations/` | MARC remap/save/retry/error-report flows |
| `Keycloak/` | Keycloak realm, client, and user admin requests |
| `mod-entities-links/` | Authority/instance link management |
| `mod-source-record-storage/` | SRS MARC record access |
| `mod-inventory-storage/` | Inventory instance operations |
| `inventory-storage migration/` | Inventory storage migration jobs |
| `mod-reading-room/` | Reading room access and templates |
| `mod-record-specification/` | Record specification endpoints |
| `mod-template-engine/` | Template management |
| `bulk operations/` | Bulk user operations |
| `mapping-rules/` | MARC-bib mapping rule inspection |
| `timers/` | Timer-based job triggers |
| `Module reinstall/` | Module reinstall flows |

## Usage Notes

- All requests expect `x-okapi-token` and `x-okapi-tenant` to already be set. Run the relevant `auth/` request first.
- Requests with path parameters (e.g. `:consortia_id`, `:applicationId`) require you to fill in the value in the **Params** tab before running.
- Query parameters prefixed with `~` in the `.bru` source are **disabled** — enable them in Bruno's Params tab if needed.

## Security

- **Credentials go in Bruno environment variables only** — never hardcode them in request files.
- `environments/` is excluded by `.gitignore`. Do not force-add environment files.
- Tokens are short-lived; re-run auth requests if you get 401 responses.
- Before adding new requests, replace any environment-specific IDs (UUIDs, tenant names) with `{{variable}}` references or clearly marked `# REPLACE ME` comments.

## Suggested Workflow

1. Select the correct environment in Bruno.
2. Run the appropriate `auth/` request to obtain a token.
3. Execute read-only GET requests first to verify connectivity and IDs.
4. Execute write/update/delete requests only after confirming the target tenant and resource IDs.
5. Re-authenticate if you receive 401 errors (tokens expire).
