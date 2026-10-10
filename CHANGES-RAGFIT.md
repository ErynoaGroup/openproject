# RagFit changes to OpenProject (ErynoaGroup/openproject → RagFit | Plan)

This repository is a modified version of OpenProject (GPL-3.0-only, © OpenProject GmbH).
Per GPLv3 §5(a), all modifications are listed here with date. Upstream notices are kept unchanged.

## 2026-10-10 — 0001 sso-unlock (branch `erynoa/sso-unlock`)

**What:** OpenID Connect provider setup and OIDC login work without a token.
Only the OIDC module is affected; SAML and all other token-gated features are unchanged.

- `modules/auth_plugins/lib/open_project/plugins/auth_plugin.rb`: `filtered_strategy?` also lets `:openid_connect` strategies through.
- `modules/openid_connect/app/controllers/openid_connect/providers_controller.rb`: `check_ee` before_action removed.
- `modules/openid_connect/app/views/openid_connect/providers/index.html.erb`: add button no longer disabled, upsell banner removed.
- `modules/openid_connect/lib/open_project/openid_connect/engine.rb`: admin menu entry no longer marked as token feature.

No tokens are created or simulated; `EnterpriseToken` itself is untouched.

**Why:** RagFit | Plan logs in through RagFit | Source (OIDC). ErynoaGroup holds no commercial
OpenProject contract or license (confirmed by the maintainers, 2026-10-10).
GPLv3 §10 grants every recipient the right to modify and run the program; the code is GPLv3
and no further restrictions may be imposed (§7, §10). Patch file: `ragfit/patches/0001-sso-unlock.patch`.
