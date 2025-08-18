# DAB / Portal Fix — Progress Log

Purpose
- One-place record of what we changed to move the management-portal from in-memory/mock data to Data API Builder (DAB) + Cosmos DB, what worked, what failed, and next steps to resume work.

Status snapshot
- Branch: `cleanup/dab`
- Active PR: "chore(dab): cleanup DAB config and fix GraphQL mutation" (#4)
- Current blocker: live Container App `ca-stamps-dab` latest revision is Unhealthy / CrashLoop (portal GraphQL calls time out).

Checklist (requirements)
- [x] Update repo to use DAB image and schema. (files: `management-portal/dab/schema.graphql`, `dab-config.json`, DAB Dockerfile)
- [x] Update portal to use `DAB_GRAPHQL_URL` secretRef. (files: `management-portal/src/Portal/Services/GraphQLDataService.cs`, startup wiring)
- [x] Create/modify Seeder to seed Cosmos (AAD auth). (files: `management-portal/Seeder`)
- [x] Seeded representative baseline to `stamps-control-plane` (confirmed in Cosmos).
- [x] Edit IaC to set DAB `ingress.targetPort = 80`, use built image, and explicit `command`. (file: `management-portal/infra/management-portal.bicep`) — COMMITTED.
- [ ] Get a healthy running revision for `ca-stamps-dab` so the portal can query `/graphql`. (live fix in progress)
- [ ] Remove any malformed live env entries caused by earlier CLI/patch attempts.
- [ ] Validate portal → DAB end-to-end with logs and UI data shown.
- [ ] Cleanup temporary debug CI/tasks and consolidate deployment steps for local azd/Bicep/PowerShell.

What we've done (short)
- Fixed DAB image entrypoint and GraphQL schema in repo.
- Updated portal GraphQL client to match DAB schema and read secretRef for URL.
- Converted Seeder to use AAD credential flow and successfully seeded Cosmos after RBAC adjustments.
- Committed `management-portal.bicep` changes (targetPort=80, dab image, explicit command).
- Attempted live PATCHs and Bicep redeploy. Multiple live updates produced partial states and a crash-looping revision.

Live observations (useful logs)
- Portal logs show repeated POST attempts to DAB internal FQDN and HttpClient.Timeout cancellations after ~100s.
- DAB revisions show messages like:
  - "TargetPort 5000 does not match the listening port 80." (fixed in IaC)
  - "Container crashing: dab" and "1/1 Container crashing: dab" (current symptom)

Files changed (committed)
- management-portal/dab/Dockerfile
- management-portal/dab/dab-config.json
- management-portal/dab/schema.graphql
- management-portal/Seeder/*
- management-portal/src/Portal/* (GraphQL client wiring)
- management-portal/infra/management-portal.bicep (DAB targetPort, image, command)

Commands to resume / quick checks
- Check DAB revisions and health:

```pwsh
az containerapp revision list -g rg-stamps-mgmt -n ca-stamps-dab -o table
az containerapp show -g rg-stamps-mgmt -n ca-stamps-dab -o json | jq .properties.configuration.ingress
```

- Tail DAB logs (container `dab`):

```pwsh
az containerapp logs show -g rg-stamps-mgmt -n ca-stamps-dab --container dab --tail 300
```

- Redeploy the IaC (non-interactive):

```pwsh
az deployment group create -g rg-stamps-mgmt --template-file management-portal/infra/management-portal.bicep --parameters cosmosAccountName=cosmos-xgjwtecm3g5pi containerRegistryName=crxgjwtecm3g5pi location=westus2
```

- Verify portal logs while loading UI (look for successful POST -> 200 and GraphQL response):

```pwsh
az containerapp logs show -g rg-stamps-mgmt -n ca-stamps-portal --tail 200
```

Next troubleshooting steps (ordered)
1. Fetch DAB container logs and look for process startup errors, missing file paths, or permission errors. If logs show the binary missing, correct the image or entrypoint.
2. If container command is valid, ensure image has `dab` binary and that `/App/dab-config.json` exists at that path inside image. If missing, fix Dockerfile and rebuild/push the image to ACR.
3. If live resource is corrupted (malformed env entries), reapply IaC via Bicep to overwrite template cleanly. Use `az deployment group create` with required parameters (non-interactive).
4. After a healthy revision appears, tail DAB logs to confirm `/graphql` is listening and returns schema introspection or simple queries.
5. Load portal UI and confirm data appears. If not, capture portal logs and DAB logs for the same time window.
6. Once stable, create a short PR to remove temporary debug changes and document local deploy steps in `DEVELOPER_QUICKSTART.md`.

Notes & assumptions
- The repo branch with infra commits is `cleanup/dab` (PR #4).
- We used `crxgjwtecm3g5pi.azurecr.io` as ACR server; the managed identity `mi-stamps-mgmt` must have AcrPull.
- Seeder success required adding a data-plane RBAC role and temporarily loosening firewall rules.

How to pick this up later (quick)
- Start by viewing `DAB_FIX_PROGRESS.md` (this file).
- Run the "Check DAB revisions and health" commands above.
- If the latest revision is Failed/Unhealthy, run the redeploy IaC command. Watch revisions until `HealthState` becomes `Healthy` or `Running`.

If you want, I can also open a short PR that adds this file into docs and links it from `management-portal/README.md`.
