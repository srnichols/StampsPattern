# DAB / Aspire Remediation Plan — prioritized

Generated: 2025-09-04

Purpose
- Capture every high-value occurrence of Data API Builder (DAB) and Aspire artifacts, recommend safe actions, and flag infra/CI items that require staged migration.

How to read this file
- Priority: High / Medium / Low (impact to running systems decreases)
- Action: "wording-only" = edit docs or comments; "archive" = move to docs/archive or docs/obsolete; "verify+migrate" = requires live infra/secret verification + staged rollout; "no-change" = leave alone until migration window
- Verification steps: short checklist for someone who will perform the change

Summary status (high level)
- User-facing docs: updated (wording-only) where safe; more wording-only edits recommended.  
- Scripts: several references remain; update next with backward-compatible aliases.  
- Infra/CI/Secrets (.bicep, .json, .env, GitHub Actions): flagged as high risk — require verification before renaming/removal.

---

PRIORITIZED FILE LIST (high → low)

High priority — user-facing docs (wording-only edits safe)

1. `docs/OPERATIONS_GUIDE.md`
   - Snippet: "Runtime resource names and secrets such as `ca-stamps-dab` and `DAB_GRAPHQL_URL`..."
   - Recommended action: wording-only rebaseline (already applied); scan for remaining DAB mentions and remove where not infra-sensitive.
   - Risk: low
   - Verification: preview changes in docs site; run repo search for residual tokens.

2. `docs/DEVELOPER_QUICKSTART.md`
   - Snippet: "Note: Hot Chocolate is the active GraphQL backend..."
   - Recommended action: wording-only rebaseline (applied); replace remaining local dev examples that explicitly reference DAB ports where Hot Chocolate should be used.
   - Risk: low
   - Verification: run local quickstart guide; confirm `scripts/run-local.ps1` behavior unchanged.

3. `docs/SECRETS_AND_CONFIG.md`
   - Snippet: `DAB_GRAPHQL_URL` examples and `local.settings.json` sample
   - Recommended action: wording-only edit (applied); add migration note and alternate placeholder `<GRAPHQL_URL>` in examples.
   - Risk: low
   - Verification: ensure samples still valid for local dev; search for `local.settings.json` references.

4. `docs/TROUBLESHOOTING_PLAYBOOKS.md`
   - Snippet: playbook steps directly referencing `ca-stamps-dab`, `DAB_GRAPHQL_URL`, and az containerapp commands
   - Recommended action: wording-only for operator steps that remain valid; for CLI examples referencing live resource names, change to placeholders and flag for infra verification.
   - Risk: low→medium
   - Verification: run lint on docs; confirm examples use placeholders.

5. `docs/GLOSSARY.md`
   - Snippet: glossary entry describing DAB as legacy
   - Recommended action: wording-only (applied); keep link to DAB docs as legacy reference.
   - Risk: low
   - Verification: none required beyond CI docs build.

6. `docs/DEPLOYMENT_GUIDE.md`
   - Snippet: note about legacy outputs like `dab-graphql-url`
   - Recommended action: replace example output keys with `<GRAPHQL_OUTPUT>` and add migration note for infra outputs.
   - Risk: low
   - Verification: confirm example commands still work with placeholders.

Medium priority — scripts & samples (need careful edits)

7. `scripts/run-local.ps1`
   - Snippet: sets `$env:DAB_GRAPHQL_URL = "http://localhost:${dabPort}/graphql"` and contains comments about skipping automatic DAB startup
   - Recommended action: update to use `<GRAPHQL_URL>` placeholder and keep backwards-compatible env assignment (set DAB_GRAPHQL_URL if present). Add a short comment explaining DAB is legacy.
   - Risk: medium (local dev impact)
   - Verification: run `pwsh -File ./scripts/run-local.ps1` locally; confirm portal still connects using Hot Chocolate by default.

8. `scripts/stop-local.ps1`
   - Snippet: comment: "DAB (Data API Builder) is not managed by this script..."
   - Recommended action: wording-only confirmation; no functional change.
   - Risk: low
   - Verification: none

9. `scripts/diagnostics.ps1`
   - Snippet: uses variable `[string]$DabName = 'ca-stamps-dab'` and contains commands that tail logs for `ca-stamps-dab`.
   - Recommended action: keep variable but make it configurable via parameter; default retains `ca-stamps-dab` for backwards compatibility. Add CLI option to pass new resource name.
   - Risk: medium
   - Verification: run diagnostics script in a lab with the `-DabName` override and confirm behavior.

10. `samples/TaskTracker/TaskTracker.Blazor.csproj`
    - Snippet: project file contains removes for `Aspire/**` (Aspire references)
    - Recommended action: remove residual Aspire references if the Aspire folder is indeed gone (safe cleanup). Commit as small change.
    - Risk: low
    - Verification: build sample project and run tests if present.

High risk — infra / CI / secrets (verify + staged migration)

11. `management-portal/infra/management-portal.bicep`
    - Snippet: comments and references to `dab-graphql-url`, `DAB_GRAPHQL_URL removed` and DAB container app blocks
    - Recommended action: *verify live infra usage before changing*. If DAB container app already removed, remove comment blocks or rework output names. If outputs/KeyVault secrets still exist in deployed subscriptions, plan staged rename: create new outputs/secret aliases, update portal to read new name in parallel, cutover, then remove legacy.
    - Risk: high
    - Verification checklist:
      - Search deployed subscriptions for secret `DAB_GRAPHQL_URL` in Key Vaults
      - Confirm no CI workflow references the old output name
      - Add duplicate secret with new name and update a non-critical deployment to test reading both names

12. `management-portal/infra/main.bicep` and `management-portal/infra/management-portal.json`
    - Snippet: DAB-related sections and "DAB removed" comments
    - Recommended action: inspect if DAB resources are actually deployed. If not, remove artifacts. If deployed, do staged migration as above.
    - Risk: high
    - Verification: same as (11)

13. `.azure/Management-Portal/.env`
    - Snippet: AZURE_DAB_URL="https://ca-stamps-dab.whitetree-24b33d85.westus2.azurecontainerapps.io"
    - Recommended action: *verify* whether this .env is used by any CI runner or deploy scripts; if used only locally, replace value with `<GRAPHQL_URL>` placeholder and document the change.
    - Risk: medium→high (if CI uses it)
    - Verification: grep CI workflows for `.azure/Management-Portal/.env` usage; check GitHub secrets mapping.

14. `management-portal/infra/management-portal.json` (ARM compiled)
    - Snippet: comment: "DAB container app removed (no longer used)"
    - Recommended action: inspect and remove stale ARM outputs if not used; if used, follow staged migration.
    - Risk: high
    - Verification: inspect deployment history for the target resource group(s).

15. `.github/workflows/*` (various)
    - Snippet: CI steps building/pushing `management-portal/dab` or setting `DAB_GRAPHQL_URL` secrets
    - Recommended action: identify workflows that mention DAB images or secrets; update to use placeholders and/or remove DAB build steps. Do this in a feature branch and run CI to confirm no regressions.
    - Risk: high
    - Verification: run CI in test branch and confirm pipelines succeed.

Medium / archive — docs/archive and other historical files (low risk)

16. `docs/archive/*` (many files)
    - Snippet examples: `DEPLOYMENT_SUCCESS.md`, `DEPLOYMENT_SUMMARY.md` referencing `ca-stamps-dab` and internal URLs
    - Recommended action: move remaining archive files into `docs/obsolete/` (or `docs/archive/legacy`), add a one-line note that they are historical and kept for reference, then optionally remove from main docs index.
    - Risk: low
    - Verification: ensure no active doc links reference those files; update site navigation.

17. `docs/REPOSITORY_MAP.md`
    - Snippet: references `management-portal/dab/` folder
    - Recommended action: if the `management-portal/dab/` folder no longer exists, update map to point to Hot Chocolate code and mark `management-portal/dab/` as legacy if still present.
    - Risk: low
    - Verification: confirm file/folder presence and update accordingly.

Lower priority — one-pagers and checklist references (wording-only)

18. `docs/KNOWN_ISSUES.md`
    - Snippet: decision trees that mention `DAB_GRAPHQL_URL` and steps to set the secret
    - Recommended action: replace literal secret name with placeholder and keep note that legacy secret exists; add a pointer to remediation plan.
    - Risk: low
    - Verification: review diagrams and anchors after edits.

19. `docs/LIVE_DATA_PATH.md`
    - Snippet: multiple references to DAB container app commands and `dab-config.json`
    - Recommended action: convert concrete examples to placeholders and add notes about Hot Chocolate configuration files (if different).
    - Risk: low→medium
    - Verification: run listed GraphQL queries against Hot Chocolate endpoint; confirm guidance accurate.

20. `docs/DEPLOYMENT_GUIDE.md` (additional occurrences)
    - Snippet: output name `dab-graphql-url` in deployment outputs
    - Recommended action: replace example output name with `<GRAPHQL_OUTPUT>` and record infra migration steps in remediation plan.
    - Risk: low
    - Verification: test example `az deployment group show` on a non-prod deployment using placeholder mapping.

21. `docs/AUTH_CI_STRATEGY.md`
    - Snippet: CI steps building/pushing DAB (`docker build -t $ACR/my-dab:latest ./management-portal/dab`)
    - Recommended action: if `management-portal/dab` no longer exists or is unused, remove build steps; otherwise, archive that folder and stop building the image.
    - Risk: medium
    - Verification: run CI dry-run and validate artifacts produced.

22. `management-portal/README.md`
    - Snippet: "AppHost is no longer dependent on the .NET Aspire runtime..."
    - Recommended action: wording-only cleanup (applied where present); ensure AppHost docs don't reference Aspire runtime beyond historical note.
    - Risk: low
    - Verification: none beyond docs preview.

23. `management-portal/AppHost/Program.cs`
    - Snippet: Console.WriteLine("AppHost shim: Aspire AppHost usage removed.")
    - Recommended action: keep small comment indicating removal; if code is dead, consider removing AppHost shim and associated Aspire references after a quick build/test.
    - Risk: medium
    - Verification: build `management-portal` solution and run unit tests.

24. `global.json`
    - Snippet: contains dependency "Aspire.Hosting.AppHost.Sdk": "9.4.0"
    - Recommended action: confirm whether Aspire SDK is actively used; if not, remove entry and run `dotnet restore` / build to validate.
    - Risk: medium
    - Verification: run `dotnet build` for affected projects; confirm no missing SDK errors.

25. `CHANGELOG.md`
    - Snippet: mentions "Rebaseline: Hot Chocolate GraphQL, DAB removal, doc and infra cleanup"
    - Recommended action: update changelog entry to reflect rebaseline progress and link to remediation plan `docs/dab-remediation-plan.md`.
    - Risk: low
    - Verification: review changelog after edits.

---

Staged migration checklist (for infra/CI items)
1. Inventory: use `az` and GitHub to verify where `DAB_GRAPHQL_URL`, `ca-stamps-dab`, `dab-graphql-url` appear in *deployed* resources and CI (Key Vaults, Container Apps, GitHub Secrets, pipeline envs).
2. Backfill: create duplicate secrets/outputs with the new name (e.g., `GRAPHQL_URL`), keeping legacy name present.
3. Update code: change code/config to read new names but fall back to old ones (dual-read pattern) in one deploy.
4. Smoke test: deploy to a staging environment and test portal GraphQL calls.
5. Cutover: update non-production first, then production during maintenance window.
6. Cleanup: after 48–72 hours of successful operation, remove legacy names and docs references.

---

Next steps I can take (choose one or more):
- A: Expand this plan to include every grep match as a CSV (file, exact snippet, line number) and commit to `docs/dab-remediation-full.csv` (useful for automation).  
- B: Open a branch and apply the safe, low-risk wording-only edits across all top-level docs (done for a subset); continue in small batches.  
- C: Prepare an infra migration checklist per affected resource (Key Vault, Container App, GitHub workflow) with commands and sample Bicep changes.
- D: Run tests / builds for changed projects (`dotnet build`, run sample) to ensure no compile regressions after Aspire removals.

Requested confirmation
- Reply with which of (A,B,C,D) to run next. If you want a custom mix, tell me and I will proceed.


---

Requirements coverage mapping
- Verify DAB/Aspire are no longer active runtimes: partially covered — repo matches found; live infra verification required (see staged migration checklist).  
- Replace DAB references in user-facing docs: in progress — top-level docs updated; more remain.  
- Validate screenshot galleries: done (script run).  
- Move/archive obsolete docs: suggested (docs/archive items flagged); can be moved on approval.  
- Preserve runtime identifiers unless migration approved: user approved migration; plan recommends staged migration steps.  


