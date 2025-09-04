# Sample Galleries Index

A visual index of sample app galleries and the management portal. Click a card to open the gallery page with full-size screenshots and captions.

## Galleries

<style>
/* lightweight responsive grid for markdown viewers */
.gallery-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px;align-items:start}
.gallery-card{background:#fff;border-radius:8px;padding:12px;box-shadow:0 6px 18px rgba(0,0,0,0.06);transition:transform .12s ease}
.gallery-card:hover{transform:translateY(-4px)}
.gallery-thumb{width:100%;height:auto;border-radius:6px;display:block}
.gallery-title{margin:10px 0 4px 0;font-size:1.05rem}
.gallery-desc{margin:0;color:#6b7280;font-size:0.95rem}
</style>

<div class="gallery-grid">
	<a class="gallery-card" href="management-portal/docs/SCREENSHOTS.md">
		<img class="gallery-thumb" src="management-portal/docs/thumbnails/ManagmentPortal-Dashboard-Screenshot-thumb.png" alt="Management Portal dashboard thumbnail" />
		<div>
			<div class="gallery-title">Management Portal</div>
			<div class="gallery-desc">Overview dashboard, tenant and cell management screenshots.</div>
		</div>
	</a>

	<a class="gallery-card" href="samples/tasktracker/docs/SCREENSHOTS.md">
		<img class="gallery-thumb" src="samples/tasktracker/docs/thumbnails/TaskTrack-HomePage-screenshot.png" alt="TaskTracker home page thumbnail" />
		<div>
			<div class="gallery-title">TaskTracker</div>
			<div class="gallery-desc">TaskTracker sample app UI screenshots (home, new task, edit task).</div>
		</div>
	</a>

</div>

---

## How to add a gallery

1. Create a `docs/SCREENSHOTS.md` in your sample folder.
2. Add images to the same folder and (optionally) a `thumbnails/` subfolder.
3. To validate galleries locally, run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-galleries.ps1
```

This script checks all `SCREENSHOTS.md` files in the repo for missing image references.

