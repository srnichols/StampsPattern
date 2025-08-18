# Documentation Improvement Recommendations (First-Time Reader Focus)

Audience and intent
- Persona: First-time reader exploring the Azure Stamps Pattern to understand what it is, how to deploy it, and how to operate it.
- Goal: Make onboarding faster by reducing friction, duplication, and ambiguity, and by providing clear “happy paths”.

---

## 1) Repository capabilities model (what the code can do)

High-level components
- Infra (Bicep)
  - Global/hub/regional/host layers, traffic routing, policy-as-code, advanced security, monitoring.
  - Container Apps environment; management portal (Container App); DAB (Data API Builder) service; ACR; App Insights; Log Analytics; Cosmos DB control-plane.
- Functions app (AzureArchitecture)
  - Core functions: `CreateTenantFunction`, `AddUserToTenantFunction`, `GetTenantInfoFunction`, `CellManagementFunction`, `DocumentationFunction`.
  - Support: caching service, host config, indexing policies, bicep modules for networking and security.
- Management portal
  - UI reads from DAB GraphQL; AAD authentication; displays Tenants, Cells, Operations dashboards.
  - Seeder utility populates baseline data into Cosmos DB via AAD (DefaultAzureCredential).
- Scripts and ops helpers
  - RBAC ensure scripts (Cosmos data-plane), OIDC setup and service principal fixes, troubleshooting guides.
  - Local dev tasks (Azurite, Functions runtime), link checking (lychee).

Key integration paths
- Portal → DAB → Cosmos DB (GraphQL)
- Infra deploys Container Apps, ACR, Cosmos, monitoring
- Auth via Azure AD (id_token for portal; RBAC for DAB/Cosmos)
- Optional KV vs container-app secrets patterns (currently container-app secrets)

---

## 2) Strengths observed in current documentation

- Clear central index: `docs/DOCS.md` with role-based paths and progressive learning flow.
- Deep coverage: architecture, deployment patterns, operations, security, cost, naming, parameterization.
- Quickstart for developers and “run locally” steps.
- Glossary is comprehensive and helpful for newcomers.
- Known issues guide with many practical tips.
- Navigation tables and mermaid learning maps are compelling.

---

## 3) Pain points for newcomers (first‑time reader lens)

- Multiple entry points (README, DOCS, Quick Navigation tables) can feel duplicative; it’s not obvious which one to follow first.
- Deployment “happy path” isn’t distilled into a single minimal set of steps before branching into options.
- Live data path (Portal ↔ DAB ↔ Cosmos) isn’t summarized end-to-end in one place; troubleshooting requires jumping between guides.
- Secret management patterns (Key Vault vs container-app secrets) are mentioned but not presented as a clear decision tree or quick checklist.
- Conditional Access and OIDC guidance are in separate scripts/notes; a single “Auth & CI Strategy” page would reduce confusion.
- Known Issues is long; lack of a short “top 10” or decision-tree view slows resolution.
- Some emoji/heading styles and quick navigation tables are inconsistent across docs; can distract skimmers.
- TROUBLESHOOT_AUTH.md is empty; creates dead-end.
- Some commands don’t declare shell profile (pwsh) consistently; copy-paste can fail for Windows users.

---

## 4) Top recommendations (prioritized: P0 → P2)

P0 – Make the first 60 minutes smooth
1. Create a “Start Here” section in README that points to one exact “happy path”:
   - 10-step Minimal Happy Path: Deploy core infra + DAB + Portal; seed data; open dashboard; verify health.
   - Link out to advanced options only after success.
2. New guide: “Live Data Path (Portal ↔ DAB ↔ Cosmos)” with:
   - One diagram, URLs, env vars, and how secrets/MI/RBAC tie together.
   - Quick checks: curl GraphQL, tail Container Apps logs, validate Cosmos containers, seed rerun.
3. Consolidate authentication and CI guidance:
   - “Auth & CI Strategy” page: AAD app (id_token), redirect URIs, OIDC vs SP secret (with CA considerations), GitHub federated credential steps, common AADSTS errors.
4. Known Issues overhaul (two-layer):
   - Short “Top 10 Fixes” at the top (copy/paste commands).
   - Keep long-form recipes below, indexed and cross-linked.
5. Fix TROUBLESHOOT_AUTH.md (or merge into the Auth & CI Strategy page and delete the empty file).
6. Ensure all commands are pwsh-friendly and one-per-line blocks with explicit shells; add “copy” ready snippets.

P1 – Reduce duplication and improve navigation
7. Unify “Quick Navigation” patterns: pick one table style (columns, icons) and use consistently across README and DOCS.md.
8. In DOCS.md, move “Progressive Learning Path” to the top and keep “Role-based Paths” right after; de-emphasize long link tables initially.
9. Add a “Repository Map” page: folders, key files, and where typical tasks live (infra, portal, DAB, functions, scripts).
10. Add a “Capabilities Matrix”: which enterprise features are implemented, experimental, or roadmap (e.g., Web App Firewall, advanced monitoring, policy-as-code).
11. Cross-link the Seeder doc from Deployment Guide and Portal User Guide (and from the new Live Data Path).

P2 – Improve depth and consistency
12. Create “Secrets & Configuration” guide:
    - Container-app secrets vs Key Vault references; pros/cons, when to use each.
    - Required env vars for Portal and DAB; example param files.
13. Add “RBAC Cheat Sheet”:
    - Infra (Contributor, AcrPull).
    - Data-plane (Cosmos DB Built-in Data Contributor).
    - KV access (Secrets User).
    - Scope examples and az CLI one-liners.
14. “Troubleshooting Decision Trees”: small mermaid flowcharts for:
    - Deployment failures (Bicep/IaC).
    - Portal shows no data.
    - DAB won’t start / schema errors.
    - AAD auth errors (common codes with remediations).
15. Normalize headings/emoji and code fences; adopt a mini style guide checklist (see below).
16. Add a short “How We Version” in README (tie into VERSION file and tags).
17. Provide a “Local Portal & DAB run” quickstart (if feasible), or explicitly say we don’t support local DAB run and why.

---

## 5) Specific edits by file (actionable)

- README.md
  - Add “Start Here: Minimal Happy Path” (10 steps).
  - Cut duplicate navigation lists; link to DOCS.md as the primary index.
  - Add “How We Version” with reference to VERSION and releases page.
- docs/DOCS.md
  - Move “Progressive Learning Path” above the fold.
  - Add links to new “Live Data Path” and “Auth & CI Strategy”.
  - Add “Repository Map” and “Capabilities Matrix” sections.
- docs/DEPLOYMENT_GUIDE.md
  - Introduce a Minimal Path (P0) before options; explicitly call out seeding and quick validation.
  - Add a “Post-deploy smoke test” block (portal URL, GraphQL health, Cosmos documents).
- docs/MANAGEMENT_PORTAL_USER_GUIDE.md
  - Add “Where data comes from” panel linking to Live Data Path.
  - Add a “Common errors and where to look” section (Portal logs vs DAB logs).
- docs/KNOWN_ISSUES.md
  - Add “Top 10 fixes” at top with anchor links to long-form solutions.
  - Insert troubleshooting trees for Portal/DAB/AAD.
- docs/SECURITY_GUIDE.md
  - Reference Auth & CI Strategy and OIDC setup; note Conditional Access caveats.
- docs/DEVELOPER_QUICKSTART.md
  - Ensure pwsh commands are consistent; add “Common Windows pitfalls” callouts.
- docs/GLOSSARY.md
  - Add mini “Where to go next” box: Concepts → Architecture → Deployment → Live Data Path.
- docs/ARCHITECTURE_GUIDE.md
  - Add one-page E2E runtime diagram (Portal ↔ DAB ↔ Cosmos ↔ Monitoring).
- docs/OPERATIONS_GUIDE.md
  - Add “Log locations and quick commands” for Container Apps, DAB, Portal, and Functions.
- NEW: docs/LIVE_DATA_PATH.md
  - Single source for Portal ↔ DAB ↔ Cosmos; env vars; curl samples; seed; common errors.
- NEW: docs/AUTH_CI_STRATEGY.md
  - AAD app setup, OIDC federated credential, redirect URIs, common AAD error codes, GitHub secrets minimal set.
- NEW: docs/SECRETS_AND_CONFIG.md
  - Container-app secrets vs Key Vault; examples for both; pros/cons decision tree.
- NEW: docs/RBAC_CHEATSHEET.md
  - Roles, scopes, principals, commands.

---

## 6) Style and consistency guide (mini checklist)

- Headings and emoji: use at most one emoji per H1/H2; consistent capitalization (Title Case for H1/H2).
- Command blocks:
  - Use proper fences and tags: ```powershell for pwsh; one command per line; no mixed shells.
  - Provide variables at the top of a block; avoid inline substitutions when possible.
- Tables:
  - Keep column counts consistent; avoid overly wide tables; link text concise.
- Cross-links:
  - Always prefer relative links; include anchors for subsections.
  - Backlink from each new page to DOCS.md and README.
- Diagrams:
  - Use shared mermaid template; keep one core E2E runtime diagram and reuse it.
- Tone:
  - Favor imperative, concise how-to steps; defer deep theory to the Architecture Guide.
- Maintenance:
  - Update DOCS.md when adding or removing files; keep “Core Guides” section current.

---

## 7) Automation and guardrails

- Link checking: keep `lychee` config; add a docs CI job that fails on broken internal links.
- Spelling and lint: add markdownlint and codespell; keep a baseline and gradually improve.
- Doc “smoke tests”: a short script that validates critical anchors exist (e.g., headings in core guides).
- Versioning: auto-update “What’s New” in releases/ when VERSION tag is created (optional).

---

## 8) Suggested task backlog (checklist)

P0 (next 1–2 days)
- [ ] README: Add “Start Here: Minimal Happy Path” (10 steps).
- [ ] NEW: docs/LIVE_DATA_PATH.md (diagram + checks + seeding).
- [ ] Known Issues: Add “Top 10 Fixes” section.
- [ ] TROUBLESHOOT_AUTH.md: replace with Auth & CI Strategy (or remove and redirect).
- [ ] Ensure all command blocks specify `powershell` and are copy-paste safe on Windows.

P1 (this week)
- [ ] DOCS.md: Move progressive path to top; link to new guides; unify nav tables.
- [ ] NEW: docs/AUTH_CI_STRATEGY.md; consolidate scattered auth notes and scripts.
- [ ] NEW: docs/SECRETS_AND_CONFIG.md with clear decision tree.
- [ ] Add “Repository Map” and “Capabilities Matrix”.

P2 (next)
- [ ] KNOWN_ISSUES: Add troubleshooting decision trees.
- [ ] ARCHITECTURE_GUIDE: Add E2E runtime diagram block.
- [ ] OPERATIONS_GUIDE: Add “Logs & Quick Commands”.
- [ ] Add markdownlint + codespell to CI for docs.

Ownership
- Doc owner: …
- Tech reviewers: Infra, Portal/DAB, Security
- ETA targets: P0 (2d), P1 (5d), P2 (1–2w)

---

## 9) Appendix: references to existing docs

- DOCS hub: `docs/DOCS.md`
- Quickstart: `docs/DEVELOPER_QUICKSTART.md`
- Deployment: `docs/DEPLOYMENT_GUIDE.md`, `docs/DEPLOYMENT_ARCHITECTURE_GUIDE.md`
- Architecture: `docs/ARCHITECTURE_GUIDE.md`
- Ops & Security: `docs/OPERATIONS_GUIDE.md`, `docs/SECURITY_GUIDE.md`
- Cost/Naming/Param: `docs/COST_OPTIMIZATION_GUIDE.md`, `docs/NAMING_CONVENTIONS_GUIDE.md`, `docs/PARAMETERIZATION_GUIDE.md`
- Known issues: `docs/KNOWN_ISSUES.md`
- Glossary: `docs/GLOSSARY.md`
