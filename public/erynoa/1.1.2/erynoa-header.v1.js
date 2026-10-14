// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Erynoa — <erynoa-header> v1.1.2. No deps, no network calls, no tracking.
// Usage: <erynoa-header current="plan" [domain="example.org"] [skip-target="#main"] [home="https://…/"] [theme="dark|light"]></erynoa-header>
// home defaults to https://source.<domain>/.
// Without `domain`, the base domain is derived from location.hostname by dropping the first label
// (plan.example.org -> example.org). Requires erynoa-header.v1.css loaded in the page.
(() => {
  const SERVICES = [["source", "Source"], ["plan", "Plan"], ["memory", "Memory"], ["docs", "Docs"], ["auth", "Auth"], ["monitor", "Monitor"]];
  const baseDomain = (h) => { const p = h.split("."); return p.length > 2 ? p.slice(1).join(".") : h; };
  class ErynoaHeader extends HTMLElement {
    static get observedAttributes() { return ["current", "domain", "skip-target", "home", "theme"]; }
    connectedCallback() { this.render(); }
    attributeChangedCallback() { if (this.isConnected) this.render(); }
    render() {
      const domain = this.getAttribute("domain") || baseDomain(location.hostname);
      const current = this.getAttribute("current") || "";
      const skip = this.getAttribute("skip-target") || "#main";
      const home = this.getAttribute("home") || `https://source.${domain}/`;
      const theme = this.getAttribute("theme");
      const slot = this.querySelector(".erh-slot-end");
      const h = document.createElement("header");
      h.className = "erh"; h.setAttribute("role", "banner"); h.dataset.erynoaHeader = "1.1.2";
      if (theme === "dark" || theme === "light") h.dataset.erhTheme = theme;
      const a = (cls, href, text) => { const e = document.createElement("a"); e.className = cls; e.href = href; if (text) e.textContent = text; return e; };
      h.append(a("erh-skip", skip, "Skip to content"));
      const brand = a("erh-brand", home); brand.setAttribute("aria-label", "Erynoa");
      const logo = document.createElement("span"); logo.className = "erh-logo"; logo.setAttribute("role", "img"); logo.setAttribute("aria-label", "Erynoa");
      brand.append(logo); h.append(brand);
      const nav = document.createElement("nav"); nav.className = "erh-nav"; nav.setAttribute("aria-label", "RagFit services");
      const ul = document.createElement("ul");
      for (const [id, label] of SERVICES) {
        const li = document.createElement("li"); const l = a("", `https://${id}.${domain}/`, label);
        l.dataset.erhService = id; if (id === current) l.setAttribute("aria-current", "page");
        li.append(l); ul.append(li);
      }
      nav.append(ul); h.append(nav);
      const end = slot || document.createElement("div"); end.className = "erh-slot-end"; h.append(end);
      this.replaceChildren(h);
    }
  }
  if (!customElements.get("erynoa-header")) customElements.define("erynoa-header", ErynoaHeader);
})();
