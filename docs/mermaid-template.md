# Mermaid Diagram Template (Light-Blue Base Theme)

Use this snippet as the standard for all diagrams.

```mermaid
%%{init: {"theme":"base","themeVariables":{"background":"transparent","primaryColor":"#E6F0FF","primaryTextColor":"#1F2937","primaryBorderColor":"#94A3B8","lineColor":"#94A3B8","secondaryColor":"#F3F4F6","tertiaryColor":"#DBEAFE","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","edgeLabelBackground":"#F8FAFC","fontFamily":"Segoe UI, Roboto, Helvetica, Arial, sans-serif"}} }%%
graph LR
  A[Start] --> B[Do something]
```

Notes:
- Keep background transparent for dark/light mode.
- Prefer concise labels; wrap with \n for line breaks.
- Use graph LR/TB based on flow.
