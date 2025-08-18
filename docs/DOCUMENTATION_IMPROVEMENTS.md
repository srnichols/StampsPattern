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

## 4) Top recommendations

These recommendations form the baseline 1.0 documentation set for the Azure Stamps Pattern. They are organized to make the project easy to understand and operate for first-time readers and operators.

Core actions to include in this baseline:

- Provide a single "Start Here: Minimal Happy Path" that walks a new user through deploy → seed → validate.
- Add a `docs/LIVE_DATA_PATH.md` that shows the end-to-end Portal ↔ DAB ↔ Cosmos flow with env var names, secrets, and quick checks.
- Consolidate authentication and CI guidance into an `AUTH_CI_STRATEGY.md` page (AAD app registration, OIDC/GitHub federation, common errors).
- Improve `docs/KNOWN_ISSUES.md` with a concise "Top 10 Fixes" section and keep long-form recipes indexed below.
- Standardize code fences to `powershell` and ensure copy-paste safety for Windows users.

Follow-ups and lower-priority improvements

- Add a Repository Map and Capabilities Matrix for discoverability.
- Expand Secrets & Configuration and RBAC cheat sheets with scope examples and CLI snippets.
- Add troubleshooting decision trees and an E2E runtime diagram in the Architecture Guide.

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

- [x] README: Add “Start Here: Minimal Happy Path” (10 steps).
- [x] NEW: docs/LIVE_DATA_PATH.md (diagram + checks + seeding).
- [x] Known Issues: Add “Top 10 Fixes” section.
- [x] TROUBLESHOOT_AUTH.md: replaced — consolidated into `docs/AUTH_CI_STRATEGY.md` (see P1) and removed dead-end links.
- [x] Ensure all command blocks specify `powershell` and are copy-paste safe on Windows.

P1 (this week)

- [x] DOCS.md: Move progressive path to top; link to new guides; unify nav tables.
- [x] NEW: docs/AUTH_CI_STRATEGY.md; consolidate scattered auth notes and scripts.
- [x] NEW: docs/SECRETS_AND_CONFIG.md with clear decision tree.
- [x] Add “Repository Map” and “Capabilities Matrix”.
- [x] NEW: docs/RBAC_CHEATSHEET.md (exists)

P2 (next)

- [x] KNOWN_ISSUES: Add troubleshooting decision trees.
- [x] ARCHITECTURE_GUIDE: Add E2E runtime diagram block.
- [x] OPERATIONS_GUIDE: Add “Logs & Quick Commands”.
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
---

**📝 Document Version Information**
- **Version**: 1.4.0
- **Last Updated**: 2025-08-18 01:28:00 UTC  
- **Status**: Current
- **Next Review**: 2025-11