# 🤝 Contributing to Azure Stamps Pattern

Thanks for helping improve the Azure Stamps Pattern! This guide explains how to contribute code, docs, and ideas.

- What’s inside: Workflow, branch/commit guidance, PR checklist, docs style, and tooling
- Best for: Developers, DevOps/Platform engineers, architects, technical writers
- Outcomes: Faster reviews, consistent docs, reliable builds

---

## 🧭 Quick Navigation

| Section | What you’ll find |
|---------|-------------------|
| [Code of Conduct](#-code-of-conduct) | Community expectations |
| [Before You Start](#-before-you-start) | Fork/clone, branching, tooling |
| [Development Workflow](#-development-workflow) | Branching, commits, tests |
| [Pull Request Checklist](#-pull-request-checklist) | Ready-to-merge criteria |
| [Reporting Issues & Ideas](#-reporting-issues--ideas) | How to open high‑signal issues |
| [Documentation Style Guide](#-documentation-style-guide) | Visual tone and content rules |
| [Security & Responsible Disclosure](#-security--responsible-disclosure) | Security reporting |
| [License](#-license) | MIT |

Last updated: August 2025

---

## 🌟 Code of Conduct

Please be respectful and considerate in all interactions. See our [Code of Conduct](./CODE_OF_CONDUCT.md). For reporting guidance, jump to [Reporting a Concern](./CODE_OF_CONDUCT.md#-reporting-a-concern).

---

## 🚀 Before You Start

1. Fork this repository and clone your fork.
2. Create a feature branch from `master`:
   - Branch naming: `feat/<scope>`, `fix/<scope>`, `docs/<scope>`, `chore/<scope>`
3. Install prerequisites as needed (see project README for scripts and tooling).

> Tip: Use the provided scripts in `scripts/` for local runs and validations where applicable.

---

## 🛠️ Development Workflow

1. Keep changes focused and incremental. Prefer multiple small PRs over one large PR.
2. Use Conventional Commits where practical:
   - `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`
3. Include clear, descriptive PR titles and summaries.
4. Add or update tests and docs when behavior changes.
5. Ensure CI passes (build, lint, basic checks) if configured.

---

## ✅ Pull Request Checklist

- [ ] Clear description of the change and rationale
- [ ] Scope is focused; unrelated changes split out
- [ ] Added/updated docs where needed
- [ ] Added/updated tests (if applicable)
- [ ] No broken links or anchors in docs
- [ ] Follows commit and branch conventions

> For docs PRs, please run the link checker locally before opening the PR:
>
> PowerShell: `pwsh -File ./scripts/verify-doc-links.ps1 -IncludeImages`

---

## 🐛 Reporting Issues & 💡 Ideas

- Use <a href="https://github.com/srnichols/StampsPattern/issues" target="_blank" rel="noopener" title="Opens in a new tab">GitHub Issues</a>&nbsp;<sup>↗</sup>.
- Include: expected vs actual behavior, repro steps, environment, logs/screenshots.
- Tag with `bug`, `enhancement`, or `question` as appropriate.

---

## 📝 Documentation Style Guide

Use this style for all Markdown under `docs/` and the root `README.md` where applicable.

### Structure

- Start with a short, value‑focused intro.
- Include three bullets near the top: “What’s inside”, “Best for”, “Outcomes”.
- Use clear emoji section headers for scannability (e.g., `## 🧭`, `## 🚀`).
- Prefer compact, actionable prose over long narrative.

### Voice & Wording

- Use “Azure Stamps Pattern” when referring to the solution.
- Keep tone friendly, direct, and enterprise‑ready.
- Use ASCII punctuation and sentence‑case headings.

### Compliance Statements

- Overall CAF/WAF compliance: 94/100
- WAF Security pillar: 96/100
- Do not state 96/100 as the overall score

### Mermaid Diagrams

- All diagrams must use a per‑diagram init with neutral theme:

```
%%{init: {"theme":"base","themeVariables":{"background":"transparent","primaryColor":"#E6F0FF","primaryTextColor":"#1F2937","primaryBorderColor":"#94A3B8","lineColor":"#94A3B8","secondaryColor":"#F3F4F6","tertiaryColor":"#DBEAFE","clusterBkg":"#F8FAFC","clusterBorder":"#CBD5E1","edgeLabelBackground":"#F8FAFC","fontFamily":"Segoe UI, Roboto, Helvetica, Arial, sans-serif"}} }%%
```

- Use triple backticks with `mermaid`.
- Always use `flowchart` (LR/TD/TB) headers, not `graph`.
- Prefer `\n` line breaks in labels; `<br/>` is acceptable for tighter layout.
- Icon helpers encouraged: prefix short node labels with small emoji (e.g., 🌍 Front Door, 🔌 APIM, 🚪 App Gateway, 🐳 Container Apps, 🗄️ SQL, 🌐 Cosmos DB, 🔐 Key Vault, 📊 Log Analytics) to improve scannability.
- Keep diagrams minimal and readable.

### Links & Anchors

- Prefer relative links (e.g., `./file.md`, `../folder/file.md`).
- Validate all links; remove or fix dead links.
- Match anchors exactly; verify section titles if you change headings.

---

## 🔒 Security & Responsible Disclosure

If you discover a security issue, please do not open a public issue. Email your Microsoft representative or use private channels to report it responsibly. We’ll coordinate a fix and disclosure plan.

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the [MIT License](./LICENSE).

---

Thanks again for contributing, you make this project better for everyone! 🙌
