# Changelog — Erynoa header

## 1.1.2 — 2026-10-14
- New nav entry **Monitor** (`monitor.<domain>`, `current="monitor"`) after Auth, in HTML partial and web component.
- Narrow phones: below 400px tighter spacing (link padding 5px, 13px text, 16px logo, gap 4px); all six entries fit at 375 and 360px.
  Nav shrinks with the header (`min-width: 0`), scrolls horizontally at 320px with hidden scrollbar; every link stays reachable via Tab.
- No "Ops" entry: there is no RagFit | Ops service/hostname yet; add it when one exists (one line in HTML and JS).

## 1.1.1 — 2026-10-13
- Ships the v1.1.0 review changes that were missing from the squash merge of
  PR #4 (theme selectors, versioned `*.v1.*` files, `SHA256SUMS`/`PROVENANCE.md`,
  configurable skip/home links, `--erh-position`, per-app z-index, integration
  docs, tokens and fonts section).
- **Tag `erynoa-header-v1.1.0` is invalid:** it points to `250d5b85`, which
  contains only the v1.0.0 content. Do not pin it; use `erynoa-header-v1.1.1`
  or its commit SHA. The tag is kept (tags are never moved or deleted).

## 1.1.0 — never released (see 1.1.1)

## 1.0.0 — 2026-10-11
- Initial package (PR #4, merge `250d5b85`).
