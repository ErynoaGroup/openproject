# Erynoa header v1.1.2

One shared top bar above every RagFit service UI: RagFit | Source, RagFit | Plan,
RagFit | Memory, RagFit | Docs, RagFit | Auth and RagFit | Monitor.

| File | Purpose |
|------|---------|
| `erynoa-header.v1.html` | Framework-free partial (server templates), works without JS |
| `erynoa-header.v1.css` | Styles, all tokens as CSS custom properties |
| `erynoa-header.v1.js` | Optional `<erynoa-header>` web component, no deps, no network, no tracking |
| `erynoa-en-lockup.svg` | Byte-identical copy of the Erynoa master (brand asset, see `NOTICE.md`) |
| `SHA256SUMS` | Checksums of all distributable files (`sha256sum -c SHA256SUMS`) |
| `PROVENANCE.md` | Origin, logo source, how to record the pinned commit |
| `LICENSE` / `NOTICE.md` | MIT (code only) / brand notice: name and logo not licensed |

Keep the CSS and SVG **in the same directory** (the mask URL is relative).
Do not push them through an asset pipeline that fingerprints only one of them.
Recommended layout in a consumer: `…/erynoa/<version>/` (e.g.
`public/assets/erynoa/1.1.2/`), so caches never serve a stale file.

## Spec

| Property | Value |
|----------|-------|
| Height | `48px` desktop, `56px` below 640px (`--erh-height`, `--erh-height-mobile`) |
| Position | `--erh-position: sticky; top: 0` by default. Apps whose body never scrolls (OpenProject) set `relative` |
| z-index | Default `1000` via `--erh-z`. **Each app chooses its own value relative to its layers**: OpenProject sets it below 300 (spot scale: toast 300 … drop-modal 1000); Gitea checks Fomantic dropdowns/modals and lowers it if they overlap |
| Logo | Erynoa EN lockup, 22px high, painted via CSS mask in `currentColor` (one file, both themes) |
| Logo link | Configurable; default `https://source.<domain>/` (RagFit \| Source home — the bare domain hosts no service) |
| Themes | See below |
| Font | System stack, `Hanken Grotesk` first if the app already ships it. No font is bundled. |
| A11y | `role="banner"`, configurable skip link (default `#main`), `nav aria-label`, `aria-current="page"`, `:focus-visible` ring, contrast ≥ AA (values in CSS comments), touch targets ≥ 40px on mobile |
| Print | Hidden |

### Placeholders and attributes

| Purpose | Partial placeholder | Web component attribute | Default |
|---------|---------------------|-------------------------|---------|
| Base domain | `__ERYNOA_DOMAIN__` | `domain` | host minus first label |
| Logo link | `__ERH_HOME_URL__` | `home` | `https://source.<domain>/` |
| Skip target | `__ERH_SKIP_TARGET__` | `skip-target` | `#main` |
| Current service | `aria-current="page"` on the link | `current` | none |
| Theme | `data-erh-theme` on `<header>` or `<html>` | `theme` | OS preference |

No hostname, domain or IP is ever written into this package or a consumer
repo; the domain is resolved at runtime from the app's own host/config.

### Themes

Order of precedence: `data-erh-theme="dark|light"` on the header, then on
`<html>`, then `prefers-color-scheme`. Apps with a per-user theme must set the
attribute, otherwise the bar follows the OS:

- **Gitea** (`<html data-theme="gitea-light|gitea-dark|gitea-auto">`): render
  `data-erh-theme="dark"` when the theme name ends in `-dark`, `"light"` when it
  ends in `-light`, nothing for `-auto` (→ OS preference). Equivalent to
  `html[data-theme$="-dark"]` → dark.
- **OpenProject**: theme comes from the user preference; render `dark` when the
  user's theme is a dark theme, otherwise `light` (no attribute only if OP is in
  "sync with OS" mode).

## Integration per service

- **RagFit | Source (Gitea v28 fork, `ErynoaGroup/ragfit-source`)** — files must be
  **built into the fork**, not placed in `GITEA_CUSTOM` (that lives on the PVC
  and would hide image files and escape signing/SBOM). Paths:
  `templates/custom/header.tmpl` (CSS link
  `{{AssetUrlPrefix}}/erynoa/<version>/erynoa-header.v1.css`),
  `templates/custom/body_outer_pre.tmpl` (partial, first child of `<body>`
  above `#navbar`), `public/assets/erynoa/<version>/` (css, svg). No JS (CSP-safe).
  Domain: add a small template function in the fork, e.g. `ErynoaBaseDomain`,
  returning `setting.Domain` minus its first label (`source.<d>` → `<d>`); use
  it for `__ERYNOA_DOMAIN__`/`__ERH_HOME_URL__`. Skip target: Gitea has no
  `#main` — add an `id` to the `role="main"` element or point at an existing anchor.
  Navbar is not sticky, so no offset needed. Theme per "Themes".
- **RagFit | Plan (OpenProject 17.9, public GPLv3)** — serve CSS + SVG together
  from `public/erynoa-header/`; stylesheet via the `view_layouts_base_html_head`
  hook, partial rendered before `.op-app-header` via a small override of
  `app/views/layouts/base.html.erb` (or a `view_layouts_base_body_top` hook).
  The body does not scroll: set `--erh-position: relative`, subtract
  `var(--erh-height)` (mobile `--erh-height-mobile`) from the
  `calc(100dvh - var(--header-height))` heights of `#wrapper`, `#main-menu`,
  `#content-wrapper`. Below OP's `$breakpoint-sm`, the fixed `.op-app-header`
  gets `top: var(--erh-height-mobile)` and the bar height is added to the body
  margin. `--erh-z` below 300. Skip target `#content-wrapper`. MIT code is
  GPL-compatible; the logo stays excluded per `NOTICE.md`.
- **RagFit | Memory** — no UI at the moment. When one exists (or Memory's UI is
  rebuilt inside Source), use the partial or `<erynoa-header current="memory">`.
- **RagFit | Docs (Next.js 16 + Fumadocs)** — copy to `public/erynoa/<version>/`,
  link the CSS in `app/layout.tsx`, render the partial as a server component
  (domain from env/request host) above `<RootProvider>`; offset Fumadocs' sticky
  nav with `top: var(--erh-height)`. Skip target = Fumadocs main id.
- **RagFit | Auth (Next.js + Ory Elements, `ErynoaGroup/ragfit-auth`, `ui/`)** — copy
  to `ui/public/erynoa/<version>/`, link the CSS in the root layout and render
  the partial (server component, `current="auth"`, domain from request host) above
  the Ory Elements cards on login, registration, recovery, verification, settings
  and consent pages. No JS needed.

## Tokens and fonts

There is no web token file in `.assets` yet; the canonical Erynoa palette is the
monochrome LaTeX brand package. Header light tokens map to it.

| What | Path | License / status |
|------|------|------------------|
| Color tokens (erynoaInk `#0A0A0A`, erynoaText `#46463F`, erynoaMuted `#8A8A84`, erynoaHairline `#E4E4DF`, erynoaRule `#D2D2CB`, erynoaSurface `#ECECE9`, erynoaPaper `#F5F5F3`, erynoaCanvas `#FBFBFA`) | `templates/latex/tex/latex/erynoa/erynoa-brand.sty` (lines 29–38) | Erynoa, internal |
| Design rules | `templates/latex/DESIGN.md` | Erynoa, internal |
| Header tokens | `templates/web/erynoa-header/erynoa-header.v1.css` (`--erh-*`) | MIT |
| Hanken Grotesk (sans: UI, nav) | `fonts/hanken-grotesk/HankenGrotesk-{Regular,Italic,Medium,MediumItalic,SemiBold,SemiBoldItalic}.otf` + `fonts/hanken-grotesk/OFL.txt` | SIL OFL 1.1 (keep `OFL.txt` with the files) |
| Newsreader 16pt (serif) | `fonts/newsreader/Newsreader16pt-{Regular,Italic,Medium,MediumItalic}.ttf` + `fonts/newsreader/OFL.txt` | SIL OFL 1.1 |
| Font provenance + SHA-256 | `fonts/README.md` | — |

The fonts are OTF/TTF (no WOFF2). Apps that want Hanken Grotesk self-host it
from these files; otherwise the system stack applies.

## Versioning

> **Tag `erynoa-header-v1.1.0` is invalid** — it points to v1.0.0 content (`250d5b85`). Pin `erynoa-header-v1.1.2` or later by commit SHA. See `CHANGELOG.md`.

SemVer tags `erynoa-header-vX.Y.Z` (this: `erynoa-header-v1.1.2`). File names
carry the major (`*.v1.*`); a breaking change (markup, class/token names,
height) creates `*.v2.*`. Consumers pin by **commit SHA** and record it in their
PROVENANCE along with `SHA256SUMS`. After changing a file run `just header-sums`,
then `just header-check`.

## Licensing

Code: MIT (`LICENSE`, SPDX headers) — GPL-compatible, fine in the public GPLv3
repo of RagFit | Plan. Erynoa name and logo: brand assets of Erynoa, all rights
reserved, not licensed (`NOTICE.md`); forks must remove them.
