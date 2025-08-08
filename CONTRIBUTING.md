# Contributing to StampsPattern

Thank you for your interest in contributing to the StampsPattern project!

## How to Contribute

- **Bug Reports & Feature Requests:**
  - Use [GitHub Issues](https://github.com/srnichols/StampsPattern/issues) to report bugs or request features.

- **Pull Requests:**
  1. Fork the repository and create your branch from `master`.
  2. Make your changes with clear, descriptive commit messages.
  3. Ensure your code follows the project style and passes any tests.
  4. Submit a pull request and describe your changes.

- **Discussions & Questions:**
  - Use [GitHub Discussions](https://github.com/srnichols/StampsPattern/discussions) for questions, ideas, or help.

## Code of Conduct

Please be respectful and considerate in all interactions. See [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) if available.

---

We appreciate your contributions!

---

## Documentation Conventions (Style Guide)

Please follow these rules for all Markdown docs under `docs/`:

  - What’s inside, Best for, Outcomes
  - Overall CAF/WAF compliance: 94/100
  - WAF Security pillar: 96/100
  - Do not state 96/100 as the overall score
  - Mermaid blocks use triple backticks with `mermaid`
  - Use `\n` inside Mermaid labels instead of `<br/>`
  - Keep diagrams minimal and readable
  - Use ASCII punctuation (quotes, dashes, ellipses)
  - Clear, concise, action‑oriented prose
  - Prefer relative links (`./file.md`, `../folder/file.md`)
  - Validate links resolve; remove or fix dead links
  - Avoid linking to deleted stubs


### Pre-PR checklist for docs
- Run the relative link check locally:
  - PowerShell: `pwsh -File ./scripts/verify-doc-links.ps1 -IncludeImages`
- Ensure “Quick summary” is present at top of each guide and that compliance scores are consistent (Overall 94/100; WAF Security 96/100 where relevant).
Before opening a PR, skim related guides for consistent wording and anchors. Small inconsistencies are welcome fixes.
