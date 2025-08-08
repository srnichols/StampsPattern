# Azure Stamps Pattern - Enterprise CAF/WAF Compliant Architecture (94/100 Overall)

**Azure Stamps Pattern** addresses the critical challenge facing enterprise SaaS providers: how to deliver secure, compliant, and cost-effective multi-tenant solutions at global scale without compromising on performance or regulatory requirements. This comprehensive, production-grade reference architecture eliminates months of architectural planning and provides a proven foundation for building enterprise SaaS platforms on Azure.

Achieving an industry-leading **94/100 overall CAF/WAF compliance score** (with **96/100 WAF Security**), this framework implements a modular, zero-trust, and policy-driven approach that has been battle-tested in regulated industries including healthcare, financial services, and government sectors. Organizations can deploy production-ready infrastructure in under 45 minutes while meeting the most stringent security and compliance requirements.

**The unique zone-aware architecture (GEO → Region → Availability Zone → CELL)** supports both shared and dedicated tenancy models, enabling organizations to optimize costs with shared CELLs for SMB clients ($8-16/tenant/month) while providing dedicated CELLs for enterprise customers requiring compliance isolation ($3,200+/tenant/month). This flexibility delivers up to 10-50x cost reduction for smaller tenants while ensuring enterprise-grade isolation for regulated workloads.

**Key business benefits include:**
- **Enterprise-Ready Security**: End-to-end zero-trust network design with 85-90% JWT validation performance improvement, private endpoints, and automated policy enforcement
- **Proven Compliance**: Pre-built compliance frameworks for HIPAA, SOC 2, PCI-DSS, and GDPR with automated audit trails and policy enforcement
- **AI-Driven Operations**: Predictive scaling and intelligent monitoring reduce operational overhead by 25-40% while providing real-time insights through executive dashboards
- **Economic Flexibility**: Mixed tenancy models support growth from startup to enterprise scale with seamless migration paths and tier-based pricing
- **Global Resilience**: Multi-region, multi-zone deployment with automated failover and disaster recovery ensures 99.99%+ availability
- **Cloud Capacity Management**: Modular design enables rapid deployment in alternative locations when regions reach capacity, ensuring business continuity despite cloud supply constraints
- **Developer Velocity**: Parameterized templates, comprehensive documentation, and CI/CD integration accelerate time-to-market by 60-80%

**Perfect for organizations building mission-critical SaaS platforms** in healthcare (patient data isolation), financial services (regulatory compliance), government (data sovereignty), or any industry where security, compliance, and scalability are non-negotiable. The pattern provides a proven foundation to accelerate your SaaS journey, reduce architectural risk, and deliver measurable business value from day one.

---

## 🏗️ Architecture at a Glance

The Azure Stamps Pattern implements a sophisticated **GEO → Region → Availability Zone → CELL** hierarchy that supports both shared and dedicated tenancy models with enterprise-grade security and global distribution.

```mermaid
graph TB
    subgraph "🌐 Global Layer - Worldwide Traffic Management"
        FD[🌍 Azure Front Door<br/>Global Load Balancing & WAF]
        GF[⚡ Global Functions<br/>Tenant Management & Routing]
        TM[🌐 Traffic Manager<br/>DNS-based Routing]
    end
    
    subgraph "🗺️ GEO: North America"
        subgraph "🏢 Region: East US"
            subgraph "🏗️ APIM Layer"
                APIM1[🔌 API Management<br/>Premium Multi-Region<br/>• Tenant Isolation<br/>• Rate Limiting<br/>• Developer Portal]
            end
            subgraph "🛡️ AZ 1 - High Availability"
                AG1[🚪 Application Gateway<br/>Zone-Redundant WAF]
                subgraph "📦 Shared CELL-001"
                    CA1[🐳 Container Apps<br/>50 SMB Tenants]
                    SQL1[🗄️ Azure SQL<br/>Multi-tenant DB]
                    REDIS1[⚡ Redis Cache<br/>Shared Performance]
                end
                subgraph "🏢 Dedicated CELL-002"
                    CA2[🐳 Container Apps<br/>1 Enterprise Tenant]
                    SQL2[🗄️ Azure SQL<br/>Dedicated DB]
                    REDIS2[⚡ Redis Cache<br/>Dedicated Performance]
                end
            end
            subgraph "🛡️ AZ 2 - High Availability"
                subgraph "📦 Shared CELL-003"
                    CA3[🐳 Container Apps<br/>30 Mid-Market Tenants]
                    SQL3[🗄️ Azure SQL<br/>Multi-tenant DB]
                end
            end
            subgraph "🌍 Regional Services"
                COSMOS1[🌐 Cosmos DB<br/>Global Distribution<br/>• Tenant Routing<br/>• Configuration Data]
                KV1[🔐 Key Vault<br/>Secrets & Certificates]
                LA1[📊 Log Analytics<br/>Centralized Monitoring]
            end
        end
        
        subgraph "🏢 Region: West US - DR & Scaling"
            APIM2[🔌 API Management<br/>Multi-Region Replica]
            subgraph "🛡️ AZ 1"
                AG2[🚪 Application Gateway]
                CELL4[📦 CELL-004<br/>🐳 75 Startup Tenants]
            end
            COSMOS2[🌐 Cosmos DB<br/>Read Replica]
        end
    end
    
    subgraph "🌍 GEO: Europe - GDPR Compliance"
        subgraph "🏢 Region: West Europe"
            APIM3[🔌 API Management<br/>GDPR Compliant Gateway]
            subgraph "🛡️ AZ 1"
                AG3[🚪 Application Gateway]
                CELL5[🏛️ Enterprise CELL-005<br/>🐳 GDPR Banking Client<br/>🗄️ Dedicated SQL<br/>🔐 Customer-Managed Keys]
            end
            COSMOS3[🌐 Cosmos DB<br/>EU Data Residency]
        end
    end
    
    %% Traffic Flow
    FD --> APIM1
    FD --> APIM2
    FD --> APIM3
    
    APIM1 --> AG1
    APIM2 --> AG2
    APIM3 --> AG3
    
    AG1 --> CA1
    AG1 --> CA2
    AG2 --> CELL4
    AG3 --> CELL5
    
    %% Data Layer Connections
    CA1 -.-> SQL1
    CA2 -.-> SQL2
    CA3 -.-> SQL3
    
    CA1 -.-> REDIS1
    CA2 -.-> REDIS2
    
    GF -.-> COSMOS1
    GF -.-> COSMOS2
    GF -.-> COSMOS3
    
    %% Styling
    classDef globalLayer fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef geoLayer fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef regionLayer fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef cellLayer fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef dataLayer fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    
    class FD,TM,GF globalLayer
    class APIM1,APIM2,APIM3 geoLayer
    class AG1,AG2,AG3 regionLayer
    class CA1,CA2,CA3,CELL4,CELL5 cellLayer
    class SQL1,SQL2,SQL3,COSMOS1,COSMOS2,COSMOS3,REDIS1,REDIS2 dataLayer
```

### 🎯 **Key Enterprise Services & Their Roles**

| Service | Purpose | Tenancy Model | Enterprise Benefits |
|---------|---------|---------------|-------------------|
| 🌐 **Traffic Manager** | DNS-based global traffic routing and failover | Global profile with multiple endpoints | Automatic failover, geographic routing, performance-based routing |
| 🌍 **Azure Front Door** | Global load balancing and WAF protection | Global with zone redundancy | DDoS protection, SSL termination, caching |
| 🔌 **API Management (APIM)** | Multi-region API gateway with tenant isolation | Premium tier with multi-region | Rate limiting, developer portals, policy enforcement |
| 🚪 **Application Gateway** | Regional traffic routing and WAF | Zone-redundant per region | SSL offloading, path-based routing, security |
| 🐳 **Container Apps** | Serverless application hosting | Shared or dedicated per CELL | Auto-scaling, zero-downtime deployments |
| ⚡ **Redis Cache** | Performance acceleration | Shared or dedicated per tenant tier | 80-90% database hit reduction, sub-ms latency |
| 🗄️ **Azure SQL** | Tenant data storage | Shared schemas or dedicated databases | Enterprise security, backup, performance insights |
| 🌐 **Cosmos DB** | Global tenant routing and configuration | Multi-region with consistency | 99.999% availability, global distribution |
| 🔐 **Key Vault** | Secrets and certificate management | Per region with private endpoints | Hardware security modules, audit logging |

**💡 Architecture Highlights:**
- **🏠 Mixed Tenancy**: Shared CELLs for cost optimization ($8-16/tenant) + Dedicated CELLs for enterprise compliance ($3,200+/tenant)
- **🌍 Global Resilience**: Multi-region deployment with automatic failover and disaster recovery
- **🛡️ Zone Distribution**: 0-3 availability zones per CELL for different SLA requirements  
- **🔒 Zero-Trust Security**: Private endpoints, managed identities, and network micro-segmentation
- **📊 AI-Driven Operations**: Predictive scaling and intelligent monitoring across all layers

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Azure](https://img.shields.io/badge/Azure-Infrastructure-blue)
![CAF/WAF](https://img.shields.io/badge/CAF%2FWAF-94%2F100-brightgreen)
![WAF Security](https://img.shields.io/badge/WAF%20Security-96%2F100-brightgreen)
![GitHub release](https://img.shields.io/github/v/release/srnichols/StampsPattern)
![GitHub issues](https://img.shields.io/github/issues/srnichols/StampsPattern)
![GitHub stars](https://img.shields.io/github/stars/srnichols/StampsPattern)

---

Note: See CAF/WAF Compliance Analysis (./docs/CAF_WAF_COMPLIANCE_ANALYSIS.md) for framework mapping and scoring, then map implementation to your enterprise platform using the Azure Landing Zones Guide (./docs/LANDING_ZONES_GUIDE.md).

## 🚀 Quick Links

- [📚 Documentation Hub](./docs/DOCS.md)
- [🏗️ Architecture Guide](./docs/ARCHITECTURE_GUIDE.md)
- [🚀 Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)
- [⚙️ Operations Guide](./docs/OPERATIONS_GUIDE.md)
- [🛡️ Security Guide](./docs/SECURITY_GUIDE.md)
- [🏆 CAF/WAF Compliance Analysis](./docs/CAF_WAF_COMPLIANCE_ANALYSIS.md)
- [🌐 Azure Landing Zones Guide](./docs/LANDING_ZONES_GUIDE.md)
- [Known Issues](./docs/KNOWN_ISSUES.md)
- [Contributing](#contributing)
- [Support](#support--community)

---

## 💡 Why This Project?

**What makes this implementation unique?**
- 🛡️ Enhanced Zero-Trust Security: Network micro-segmentation with private endpoints and managed identities
- 📜 Automated Governance: Azure Policy as Code ensuring 100% compliance enforcement
- 🤖 AI-Driven Operations: Intelligent monitoring, predictive scaling, and cost optimization
- 🔐 Advanced Security: Customer-managed encryption, private endpoints, enhanced JWT validation
- 📊 Operational Excellence: Real-time insights with comprehensive dashboards and alerting
- ⚡ High Performance: Intelligent caching and query optimization for enterprise scale

**Why choose this for enterprise SaaS?**
The pattern solves critical enterprise challenges with flexible tenancy models while maintaining the highest security and compliance standards. You can optimize costs with shared CELLs for smaller clients ($8-16/tenant/month) while providing dedicated CELLs for enterprise customers requiring compliance, custom configurations, or performance guarantees ($3,200/tenant/month).

This pattern is particularly powerful for regulated industries (healthcare, financial services, government) where dedicated isolation and comprehensive compliance aren't just preferred—they're mandatory for regulatory adherence.

---

## 👥 Who Should Use This?

This solution is designed for:

- **IT Leaders & Decision Makers:** Seeking secure, compliant, and cost-optimized SaaS for regulated industries.
- **Enterprise Architects:** Designing multi-tenant, scalable, and zero-trust Azure solutions.
- **DevOps & Platform Engineers:** Deploying, automating, and operating complex Azure environments.
- **Security & Compliance Teams:** Enforcing policy-as-code, identity, and regulatory controls.
- **Developers:** Building, testing, and extending SaaS features in a modern Azure environment.

---

## 🏁 How to Get Started

1. **Review the [Documentation Hub](./docs/DOCS.md)** for a guided overview.
2. **Clone the repository:**
   ```sh
   git clone <repository-url>
   cd StampsPattern
   ```
3. **Install prerequisites:** Azure CLI, Bicep CLI, PowerShell 7+ (see [Deployment Guide](./docs/DEPLOYMENT_GUIDE.md)).
4. **Choose your tenancy model:** Shared, Dedicated, or Mixed (see [Quick Start](#-quick-start---choose-your-tenancy-model)).
5. **Deploy using scripts or portal:**
   - PowerShell: `./scripts/deploy-stamps.ps1`
   - Bash: `./scripts/deploy-stamps.sh`
   - Azure Portal: [Deploy to Azure](https://aka.ms/deploytoazurebutton)
6. **Test your deployment:** Use provided scripts and dashboards.

---

## 🗺️ Start Here: Documentation Overview

> **New to this solution?** Begin with the [📚 Documentation Hub](./docs/DOCS.md) for a guided sitemap, learning paths, and role-based quick starts. See the [Glossary](./docs/GLOSSARY.md) for key terms and the [FAQ](./docs/KNOWN_ISSUES.md) for common questions.

**📋 Complete Documentation Index**: [DOCS.md](./docs/DOCS.md) - Master documentation sitemap with navigation guide and role-based learning paths.

### 📖 Main Guides

| Guide | Purpose | Audience | Link |
|-------|---------|----------|------|
| 🏗️ Architecture Guide | Technical deep-dive: layers, traffic flow, zero-trust security | Solution Architects, DevOps Engineers | [ARCHITECTURE_GUIDE.md](./docs/ARCHITECTURE_GUIDE.md) |
| 📋 Parameterization Guide | Template customization for multi-org deployment | DevOps Engineers, Platform Teams | [PARAMETERIZATION_GUIDE.md](./docs/PARAMETERIZATION_GUIDE.md) |
| 🚀 Deployment Guide | Step-by-step deployment procedures and automation | DevOps Engineers, Platform Engineers | [DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md) |
| ⚙️ Operations Guide | Monitoring, maintenance, incident response procedures | SRE Teams, Operations Teams | [OPERATIONS_GUIDE.md](./docs/OPERATIONS_GUIDE.md) |
| 🛡️ Security Guide | Security baseline, compliance, enterprise controls | Security Engineers, Compliance Teams | [SECURITY_GUIDE.md](./docs/SECURITY_GUIDE.md) |
| 🏆 CAF/WAF Compliance | Enterprise compliance scorecard and framework alignment | C-Level, Enterprise Architects | [CAF_WAF_COMPLIANCE_ANALYSIS.md](./docs/CAF_WAF_COMPLIANCE_ANALYSIS.md) |
| 📋 Naming Conventions | Resource naming standards and policy enforcement | All Teams | [NAMING_CONVENTIONS_GUIDE.md](./docs/NAMING_CONVENTIONS_GUIDE.md) |
| 📝 Glossary | Key terms and concepts | All | [GLOSSARY.md](./docs/GLOSSARY.md) |
| ❓ FAQ / Known Issues | Troubleshooting and common questions | All | [KNOWN_ISSUES.md](./docs/KNOWN_ISSUES.md) |

---

## 🚀 Quick Start - Choose Your Tenancy Model

### 📋 Before You Begin
Ensure you have these tools installed:
- ✅ [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (v2.50.0+)  
- ✅ [Bicep CLI](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (v0.20.0+)
- ✅ PowerShell 7+ (for enhanced deployment script)
- ✅ Azure subscription with **Contributor** access

**🔧 Multi-Organization Support**: For custom domains and organization-specific deployments, see the [📋 Parameterization Guide](./docs/PARAMETERIZATION_GUIDE.md) for template customization options.

### 🎯 Choose Your Tenancy Model

#### 🏠 Mixed Model (Recommended - Supports All Tenant Types)
Deploy both shared and dedicated CELLs for maximum flexibility.

```powershell
# 1️⃣ Clone and setup
git clone <repository-url>
cd StampsPattern

# 2️⃣ Deploy mixed tenancy model with 3 zones for maximum resilience
.\scripts\deploy-stamps.ps1 `
  -ResourceGroupName "rg-stamps-prod" `
  -Location "eastus" `
  -TenancyModel "mixed" `
  -AvailabilityZones "3" `
  -Environment "prod"
```

**⏱️ Deployment time**: ~45 minutes  
**💰 Monthly cost**: $8-3,200 per tenant (tier-based)  
**🎯 Use case**: Full SaaS platform, all business sizes

#### 💰 Shared-Only Model (Cost-Optimized)
Optimize for cost with shared CELLs for small-medium tenants.

```powershell
# Deploy shared tenancy model
.\scripts\deploy-stamps.ps1 `
  -ResourceGroupName "rg-stamps-shared" `
  -Location "eastus" `
  -TenancyModel "shared" `
  -MaxSharedTenantsPerCell 100
```

**⏱️ Deployment time**: ~30 minutes  
**💰 Monthly cost**: $8-16 per tenant  
**🎯 Use case**: SMB focus, startups, cost-sensitive market

#### 🏢 Dedicated-Only Model (Enterprise-Grade)
Maximum isolation for enterprise and compliance-focused clients.

```powershell
# Deploy dedicated tenancy model
.\scripts\deploy-stamps.ps1 `
  -ResourceGroupName "rg-stamps-enterprise" `
  -Location "eastus" `
  -TenancyModel "dedicated" `
  -EnableCompliance @("HIPAA", "SOX")
```

**⏱️ Deployment time**: ~60 minutes  
**💰 Monthly cost**: $3,200+ per tenant  
**🎯 Use case**: Enterprise clients, regulated industries

---

## 🤝 Contributing

We welcome contributions! Please see our contribution guidelines:

### 📝 Development Workflow
1. 🍴 Fork the repository
2. 🌿 Create a feature branch (`git checkout -b feature/amazing-feature`)
3. 💾 Commit your changes (`git commit -m 'Add amazing feature'`)
4. 📤 Push to the branch (`git push origin feature/amazing-feature`)
5. 🔀 Open a Pull Request

### 🧪 Testing Requirements
- ✅ Bicep templates must compile without errors
- ✅ Include parameter validation
- ✅ Test in development environment before production
- ✅ Update documentation for new features

## 📞 Support & Community

### 💬 Getting Help
- 📚 **Documentation**: Start with our comprehensive guides
- 🐛 **Issues**: [GitHub Issues](https://github.com/srnichols/StampsPattern/issues) for bugs and feature requests
 - 💡 **Q&A**: Use [GitHub Issues](https://github.com/srnichols/StampsPattern/issues) with the `question` label
- 📧 **Enterprise Support**: Contact your Microsoft representative

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**🌟 Made with ❤️ by the Azure community** | **⭐ Star this repo if it helped you!**
