# Management Portal Screenshots

This page shows the screenshots located in this folder. Images are displayed as thumbnails and link to the full-size images so they render nicely on GitHub and stay fast to load.

Images live in `management-portal/docs` — you can link to them from other docs using the same relative path.

---

## Gallery (click a thumbnail to open the full-size image)

<table>
  <tr>
    <td align="center">
      <a href="ManagmentPortal-Dashboard-Screenshot.png">
        <img src="thumbnails/ManagmentPortal-Dashboard-Screenshot-thumb.png" alt="Management Portal dashboard showing summary widgets and health KPIs for tenant and system metrics" width="300" />
      </a>
      <p><strong>Dashboard</strong><br /><em>Overview dashboard showing active tenants count, recent alerts, and system health KPIs.</em></p>
    </td>
    <td align="center">
      <a href="ManagmentPortal-Tenants-Screenshot.png">
        <img src="thumbnails/ManagmentPortal-Tenants-Screenshot-thumb.png" alt="Tenants list with search, filter and quick actions for each tenant entry" width="300" />
      </a>
      <p><strong>Tenants</strong><br /><em>Tenant directory with search, filters, status badges and quick action buttons (view, edit, deactivate).</em></p>
    </td>
  </tr>
  <tr>
    <td align="center">
      <a href="ManagmentPortal-Cell-Screenshot.png">
        <img src="thumbnails/ManagmentPortal-Cell-Screenshot-thumb.png" alt="Cell overview showing cell health, allocated resources and active replicas" width="300" />
      </a>
      <p><strong>Cell</strong><br /><em>Cell overview showing health indicators, resource usage and replica counts.</em></p>
    </td>
    <td align="center">
      <a href="ManagmentPortal-CellMgmt-Screenshot.png">
        <img src="thumbnails/ManagmentPortal-CellMgmt-Screenshot-thumb.png" alt="Cell management form with configuration options for scaling, networking and runtime settings" width="300" />
      </a>
      <p><strong>Cell Management</strong><br /><em>Form-based cell configuration with fields for scaling, networking, and runtime parameters.</em></p>
    </td>
  </tr>
  <tr>
    <td align="center">
      <a href="ManagmentPortal-Infrastructure-Screenshot.png">
        <img src="thumbnails/ManagmentPortal-Infrastructure-Screenshot-thumb.png" alt="Infrastructure mapping view with resources grouped by region and resource type" width="300" />
      </a>
      <p><strong>Infrastructure</strong><br /><em>Visualization of resources and their relationships across regions and resource types.</em></p>
    </td>
    <td align="center">
      <a href="ManagmentPortal-Operations-Screenshot.png">
        <img src="thumbnails/ManagmentPortal-Operations-Screenshot-thumb.png" alt="Operations dashboard showing recent alerts, logs and timeline of incidents" width="300" />
      </a>
      <p><strong>Operations</strong><br /><em>Operations view with recent alerts, queryable logs and incident timeline to aid troubleshooting.</em></p>
    </td>
  </tr>
  <tr>
    <td align="center">
      <a href="ManagmentPortal-NewTenant-Screenshot.png">
        <img src="thumbnails/ManagmentPortal-NewTenant-Screenshot-thumb.png" alt="New tenant wizard showing required metadata fields and initial configuration options" width="300" />
      </a>
      <p><strong>New Tenant</strong><br /><em>Wizard-style new tenant creation screen with required metadata and optional initial settings.</em></p>
    </td>
    <td></td>
  </tr>
</table>

---

## How to regenerate thumbnails locally

I included a PowerShell helper `generate-thumbnails.ps1` in this folder that uses ImageMagick to create thumbnails (300px wide by default). Run it from this folder like:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\generate-thumbnails.ps1 -Width 300
```

The script writes thumbnails to `management-portal/docs/thumbnails` with the `-thumb` suffix.

## CI / automated generation

A GitHub Actions workflow (.github/workflows/generate-thumbnails.yml) is included. It runs on push and on manual dispatch and will generate thumbnails and push them back to the repository automatically.

## Notes and tips

- If images are large, thumbnails speed up page rendering; clicking a thumbnail opens the full image.
- For accessibility, edit the `alt` text and captions to be more descriptive if needed.
- If you want different thumbnail sizes or a different filename convention, edit `generate-thumbnails.ps1` and the workflow accordingly.
