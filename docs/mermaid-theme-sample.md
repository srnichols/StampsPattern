# Mermaid Theme Samples (Per-Diagram Init)

This page shows how a single-line Mermaid init directive can set a consistent theme per diagram (useful on GitHub where there’s no global site config).

- Neutral (light-friendly) theme with transparent background
- Dark theme with transparent background

## Neutral theme example

```mermaid
%%{init: {"theme":"base","themeVariables":{"background":"transparent","primaryColor":"#E6F0FF","primaryTextColor":"#1F2937","primaryBorderColor":"#94A3B8","lineColor":"#94A3B8","secondaryColor":"#F3F4F6","tertiaryColor":"#DBEAFE","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","edgeLabelBackground":"#F8FAFC","fontFamily":"Segoe UI, Roboto, Helvetica, Arial, sans-serif"}} }%%
graph TD
  A[Neutral Theme] --> B[Matches our default look]
  B --> C[No per-node style lines]
  C --> D[Portable across GitHub & docs sites]
```

## Dark theme example

```mermaid
%%{init: {"theme":"dark","themeVariables":{"background":"transparent"}} }%%
graph TD
  A[Dark Theme] --> B[High contrast edges]
  B --> C[Good for dark mode docs]
  C --> D[Still avoids per-node style overrides]
```

## Notes
- Keep the init line as the first line inside each ```mermaid block.
- Prefer themeVariables for small tweaks (background, fonts) over per-node `style` lines.
- For truly global theming, use a docs generator (MkDocs/Docusaurus) and set Mermaid theme in site config.
