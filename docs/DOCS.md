# Documentation Hub

Your single source of truth for the Azure Stamps Pattern, organized by role and learning path to help you navigate architecture, deployment, operations, security, and compliance.

## 🎯 Start Here — 60 second checklist

- Read `README.md` (project overview & prerequisites).
- Run the Live Data Path: `docs/LIVE_DATA_PATH.md` to seed Cosmos and validate Management Portal ↔ DAB ↔ Cosmos.
- For local development: follow `docs/DEVELOPER_QUICKSTART.md` (run Functions + Portal locally).
- For deployments: open `docs/DEPLOYMENT_GUIDE.md` and use `scripts/deploy.ps1` or Bicep templates as documented.

## 👤 Who Should Use This Guide?

- **Newcomers:** Start here to understand the big picture and find your learning path
- **Developers/DevOps:** Quickly locate deployment, troubleshooting, and implementation guides
- **Solution Architects:** Access deep-dive technical and compliance documentation

## 📚 Documentation Overview

A complete index of the documentation set. Use this as a quick catalog and to verify coverage.

### Core Guides

- 🏗️ Architecture: [ARCHITECTURE_GUIDE.md](./ARCHITECTURE_GUIDE.md)
- 🚀 Deployment: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- 📐 Deployment Architecture Patterns: [DEPLOYMENT_ARCHITECTURE_GUIDE.md](./DEPLOYMENT_ARCHITECTURE_GUIDE.md)
- ⚙️ Operations: [OPERATIONS_GUIDE.md](./OPERATIONS_GUIDE.md)
- 🛡️ Security: [SECURITY_GUIDE.md](./SECURITY_GUIDE.md)
- 💰 Cost Optimization: [COST_OPTIMIZATION_GUIDE.md](./COST_OPTIMIZATION_GUIDE.md)
- 🧩 Parameterization: [PARAMETERIZATION_GUIDE.md](./PARAMETERIZATION_GUIDE.md)
- 🏷️ Naming Conventions: [NAMING_CONVENTIONS_GUIDE.md](./NAMING_CONVENTIONS_GUIDE.md)

### Management Portal

- 📘 User Guide: [MANAGEMENT_PORTAL_USER_GUIDE.md](./MANAGEMENT_PORTAL_USER_GUIDE.md)
- 🔁 Live Data Path: [LIVE_DATA_PATH.md](./LIVE_DATA_PATH.md)

### Enterprise Alignment

- 🧭 CAF/WAF Compliance Analysis: [CAF_WAF_COMPLIANCE_ANALYSIS.md](./CAF_WAF_COMPLIANCE_ANALYSIS.md)
- 🗺️ Azure Landing Zones: [LANDING_ZONES_GUIDE.md](./LANDING_ZONES_GUIDE.md)

### Developer & Authoring

- 🔐 Developer Security Guide: [DEVELOPER_SECURITY_GUIDE.md](./DEVELOPER_SECURITY_GUIDE.md)
- 👨‍💻 Developer Quickstart: [DEVELOPER_QUICKSTART.md](./DEVELOPER_QUICKSTART.md)
- 🖊️ Mermaid Template: [mermaid-template.md](./mermaid-template.md)
- 🔐 Auth & CI Strategy: [AUTH_CI_STRATEGY.md](./AUTH_CI_STRATEGY.md)
- 🔒 Secrets & Config: [SECRETS_AND_CONFIG.md](./SECRETS_AND_CONFIG.md)
- 🛂 RBAC Cheat Sheet: [RBAC_CHEATSHEET.md](./RBAC_CHEATSHEET.md)

### One-Pagers & Checklists

- 🧾 Production SaaS Checklist: [one-pagers/production-saas-checklist.md](./one-pagers/production-saas-checklist.md)
- 💼 Executive Brief: [one-pagers/executive-brief-cio.md](./one-pagers/executive-brief-cio.md)

### Whitepapers

- 🧠 Concept Whitepaper: [Azure_Stamps_Pattern_Analysis_WhitePaper.md](./Azure_Stamps_Pattern_Analysis_WhitePaper.md)

### Reference & Support

- 📖 Glossary: [GLOSSARY.md](./GLOSSARY.md)
- 🧰 Known Issues: [KNOWN_ISSUES.md](./KNOWN_ISSUES.md)
- 📰 Release Notes: [releases/](./releases)

## 📚 Quick Start Paths by Experience Level

### 🆕 New to Azure Multi-Tenancy (2-3 hours)

**Recommended Path:**
1. [README.md](../README.md) - Project overview and prerequisites (10 minutes)
2. [GLOSSARY.md](./GLOSSARY.md) - Key concepts and terminology (15 minutes)
3. [ARCHITECTURE_GUIDE.md](./ARCHITECTURE_GUIDE.md) - System design and components (45 minutes)
4. [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Simple deployment walkthrough (60 minutes)

### 👨‍💻 Experienced Developer (1.5-2.5 hours)

**Recommended Path:**
1. [README.md](../README.md) - Quick start and prerequisites (10 minutes)
2. [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Step-by-step deployment (45 minutes)
3. [DEVELOPER_SECURITY_GUIDE.md](./DEVELOPER_SECURITY_GUIDE.md) - Security implementation patterns (30 minutes)
4. [KNOWN_ISSUES.md](./KNOWN_ISSUES.md) - Troubleshooting reference (as needed)

### 👨‍💼 IT Leadership (30-45 minutes)

**Recommended Path:**
1. [README.md](../README.md) - Business value and ROI (10 minutes)
2. [one-pagers/executive-brief-cio.md](./one-pagers/executive-brief-cio.md) - Executive summary (10 minutes)
3. [CAF_WAF_COMPLIANCE_ANALYSIS.md](./CAF_WAF_COMPLIANCE_ANALYSIS.md) - Compliance scorecard (15 minutes)

### 🏗️ Solution Architect (2-3 hours)

**Recommended Path:**
1. [ARCHITECTURE_GUIDE.md](./ARCHITECTURE_GUIDE.md) - Technical deep-dive (45 minutes)
2. [SECURITY_GUIDE.md](./SECURITY_GUIDE.md) - Zero-trust security model (30 minutes)
3. [OPERATIONS_GUIDE.md](./OPERATIONS_GUIDE.md) - Operational excellence (30 minutes)
4. [COST_OPTIMIZATION_GUIDE.md](./COST_OPTIMIZATION_GUIDE.md) - Cost management (15 minutes)

## 🔍 Quick Reference & Common Tasks

### 🚀 Deployment Quick Links

| Task | Documentation | Time Required |
|------|---------------|---------------|
| 📐 Choose Deployment Pattern | [DEPLOYMENT_ARCHITECTURE_GUIDE](./DEPLOYMENT_ARCHITECTURE_GUIDE.md) | 10 minutes |
| 🌟 Simple 2-Region Setup | [DEPLOYMENT_GUIDE - Option 1](./DEPLOYMENT_GUIDE.md) | 45 minutes |
| 🌍 Enterprise Multi-GEO | [DEPLOYMENT_GUIDE - Option 2](./DEPLOYMENT_GUIDE.md) | 2-3 hours |
| 🔧 Automation Setup | [DEPLOYMENT_GUIDE - Methods](./DEPLOYMENT_GUIDE.md) | 30 minutes |
| 👩‍💻 Run Locally (Dev) | [DEVELOPER_QUICKSTART](./DEVELOPER_QUICKSTART.md) | 10-15 minutes |

### ⚙️ Operations Quick Links

| Task | Documentation | Time Required |
|------|---------------|---------------|
| 🏠 Add New Tenant (CELL) | [OPERATIONS_GUIDE - Tenant Management](./OPERATIONS_GUIDE.md) | 20 minutes |
| 🗂️ Management Portal | [MANAGEMENT_PORTAL_USER_GUIDE](./MANAGEMENT_PORTAL_USER_GUIDE.md) | 15-30 minutes |
| 🚨 Incident Response | [OPERATIONS_GUIDE - Incident Response](./OPERATIONS_GUIDE.md) | 15 minutes |
| 📊 Monitoring Setup | [OPERATIONS_GUIDE - Monitoring](./OPERATIONS_GUIDE.md) | 30 minutes |
| 🔧 Troubleshooting | [KNOWN_ISSUES](./KNOWN_ISSUES.md) | Variable |

### 🛡️ Security Quick Links

| Task | Documentation | Time Required |
|------|---------------|---------------|
| ✅ Security Baseline | [SECURITY_GUIDE - Overview](./SECURITY_GUIDE.md) | 30 minutes |
| 🔐 Identity Setup | [SECURITY_GUIDE - Identity](./SECURITY_GUIDE.md) | 45 minutes |
| 📋 Compliance Checklist | [SECURITY_GUIDE - Compliance](./SECURITY_GUIDE.md) | 20 minutes |

### 🏗️ Architecture Reference

#### System Layers

```
🌍 Global Layer    → DNS, Traffic Manager, Front Door, Global Functions
🚪 Geodes Layer    → API Management (APIM), Global Control Plane Cosmos DB
🏢 Regional Layer  → Application Gateway, Key Vault, Automation Account
🏠 CELL Layer      → Flexible: Shared (10-100 tenants) or Dedicated (1 tenant)
```

#### Traffic Flow

```
User → Front Door → Traffic Manager → APIM Gateway → App Gateway → CELL (Shared/Dedicated) → SQL/Storage
```

#### Tenancy Models

- **Shared CELL**: 10-100 small tenants, cost-optimized, application-level isolation
- **Dedicated CELL**: Single enterprise tenant, compliance-ready, infrastructure-level isolation
- **Mixed Deployment**: Optimize costs with tenant segmentation strategy

#### Key Metrics

- **Availability Target**: 99.95% global uptime
- **Performance Target**: <100ms global response time
- **Scale Target**: Unlimited tenants per region (shared or dedicated)
- **Cost Efficiency**: $16/tenant (shared) to $3,200/tenant (dedicated)
- **Security Target**: Zero-trust architecture with flexible isolation levels

## 🤝 Getting Help

### 📝 Documentation Feedback

If you find gaps or areas for improvement in this documentation:

1. Review the specific guide for detailed information
2. Check the troubleshooting sections for common issues
3. Refer to the architecture guide for technical context

### 🔧 Implementation Support

- **Architecture Questions**: [ARCHITECTURE_GUIDE.md](./ARCHITECTURE_GUIDE.md)
- **Deployment Issues**: [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- **Operations Problems**: [OPERATIONS_GUIDE.md](./OPERATIONS_GUIDE.md)
- **Security Concerns**: [SECURITY_GUIDE.md](./SECURITY_GUIDE.md)

### 📚 Additional Resources

- **Azure Documentation**: <a href="https://learn.microsoft.com/azure/architecture/" target="_blank" rel="noopener">Azure Architecture Center</a> ↗
- **Azure Stamps Pattern**: <a href="https://learn.microsoft.com/azure/architecture/guide/" target="_blank" rel="noopener">Azure Application Architecture Guide</a> ↗
- **Multi-Tenant SaaS**: <a href="https://learn.microsoft.com/azure/architecture/solution-ideas/articles/saas-multitenant-database-sharding-pattern" target="_blank" rel="noopener">SaaS architecture and patterns</a> ↗
- **Azure Landing Zones**: <a href="https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/" target="_blank" rel="noopener">Landing Zones overview</a> ↗

---

**🎯 Start Here**: Begin with [README.md](../README.md)

**⚡ Quick Deploy**: Ready to deploy? Jump to [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)

**🏗️ Deep Dive**: Want technical details? Explore [ARCHITECTURE_GUIDE.md](./ARCHITECTURE_GUIDE.md)

**🤝 Contribution Guidelines**: See [CONTRIBUTING.md](../CONTRIBUTING.md) for how to contribute, report issues, or suggest improvements.

---

**📝 Document Information**
- **Version**: 1.3.0
- **Last Updated**: 2025-08-18 00:55:39 UTC  
- **Status**: Current
- **Next Review**: 2025-11

---

*Part of the [Azure Stamps Pattern](../README.md) documentation suite*
---

**📝 Document Information**
- **Version**: 
- **Last Updated**: 2025-08-18 00:58:22 UTC  
- **Status**: Current
- **Next Review**: 2025-11

---

*Part of the [Azure Stamps Pattern](../README.md) documentation suite*
---

**📝 Document Information**
- **Version**: 1.3.0
- **Last Updated**: 2025-08-18 00:58:44 UTC  
- **Status**: Current
- **Next Review**: 2025-11

---

*Part of the [Azure Stamps Pattern](../README.md) documentation suite*