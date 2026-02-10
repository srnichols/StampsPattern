# Documentation Style Guide — Instructions

applyTo: "docs/**/*.md,README.md,CONTRIBUTING.md,CHANGELOG.md"

## Document Structure

- Start every guide with the banner: `# Azure Stamps Pattern - Architecture (ASPA)`
- Follow with a short, value-focused intro paragraph
- Include three bullets near the top:
  - **What's inside**: Brief content summary
  - **Best for**: Target audience roles
  - **Outcomes**: What the reader gains
- Add a "Who Should Read This Guide?" section with role-based bullets
- Add a Quick Navigation table linking to all major sections

## Section Headers

- Use clear emoji section headers for scannability: `## 🧭`, `## 🚀`, `## 🏗️`, `## 📝`, `## 🛡️`
- Use sentence-case for headings
- Keep section hierarchy shallow (avoid more than 3 heading levels where possible)

## Voice & Tone

- Use **"Azure Stamps Pattern"** as the canonical product name
- Keep tone friendly, direct, and enterprise-ready
- Use ASCII punctuation throughout
- Prefer compact, actionable prose over long narrative
- Address the reader directly ("you") when giving instructions

## Compliance Statements

- Overall CAF/WAF compliance: **94/100** — always state this as the overall score
- WAF Security pillar: **96/100** — never state 96/100 as the overall score
- Link to `docs/CAF_WAF_COMPLIANCE_ANALYSIS.md` when referencing compliance numbers

## Terminology

| Correct | Avoid |
|---------|-------|
| CELL | cell, Cell, stamp (lowercase) |
| Azure Stamps Pattern | Stamps Pattern, stamps-pattern |
| Microsoft Entra External ID | Azure AD B2C (except in legacy context) |
| Hot Chocolate | HotChocolate, hot-chocolate |
| GraphQL | graphql, GraphQl |
| Cosmos DB | CosmosDB, Cosmos |
| APIM | Api Management (in casual references) |

## Links

- Use relative paths for internal docs: `./docs/ARCHITECTURE_GUIDE.md`
- For external links that should open in new tabs, use the HTML pattern:
  ```html
  <a href="./docs/FILE.md" target="_blank" rel="noopener" title="Opens in a new tab">Link Text</a>&nbsp;<sup>↗</sup>
  ```
- Run link checker before committing: `pwsh -File ./scripts/verify-doc-links.ps1 -IncludeImages`

## Code Blocks

- Always specify language in fenced code blocks: ` ```bicep `, ` ```powershell `, ` ```csharp `, ` ```json `
- Use real, runnable commands in examples — not pseudocode
- Include comments in code blocks to explain non-obvious steps

## Diagrams

- Use Mermaid for architecture diagrams embedded in markdown
- Include theme configuration for consistent rendering
- Use descriptive node labels with emoji prefixes for visual grouping

## Footer

- Each doc should end with a reference section or "What's Next" links
- Include last-updated date where applicable
