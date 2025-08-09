
# 📖 Azure Stamps Pattern - Glossary of Key Terms

Key terminology for the Azure Stamps Pattern with plain-language explanations and analogies to speed up onboarding and reduce ambiguity.

- What’s inside: Architecture, tenancy, security, ops, and compliance terms
- Best for: Newcomers, engineers/DevOps, architects, and business/IT leaders
- Outcomes: Shared vocabulary that improves collaboration and decision-making

## 👤 Who Should Read This Guide?

- **Newcomers:** Get up to speed on Azure Stamps Pattern terminology
- **Engineers/DevOps:** Clarify technical terms and acronyms
- **Solution Architects:** Reference for design and documentation
- **Business/IT Leaders:** Understand key concepts for decision-making

---

## 🧭 Quick Navigation

| Section | Focus Area | Best for |
|---------|------------|----------|
| [🏗️ Architectural Terms](#-architectural-terms) | Core Stamps concepts | All readers |
| [🏠 Tenancy Models](#-tenancy-models) | Multi-tenancy, assignment | Architects, DevOps |
| [🔒 Security Terms](#-security-terms) | Security, identity, endpoints | Security, DevOps |
| [⚡ Performance & Scaling](#-performance--scaling-terms) | Caching, scaling, load balancing | DevOps |
| [🗄️ Data & Storage](#-data--storage-terms) | Cosmos DB, partitioning, TTL | Architects, Devs |
| [🌐 Networking & Routing](#-networking--routing-terms) | Global vs regional routing, private connectivity | Architects, DevOps |
| [🔗 Integration & Messaging](#-integration--messaging-terms) | Queues and messaging patterns | Devs, DevOps |
| [�️ Infrastructure & DevOps](#-infrastructure--devops-terms) | IaC, Bicep, CI/CD | DevOps |
| [📊 Monitoring & Operations](#-monitoring--operations-terms) | Observability, metrics | Operations |
| [�️ Infrastructure & DevOps](#-infrastructure--devops-terms) | IaC, Bicep, CI/CD | DevOps |
| [�💰 Cost & Business](#-cost--business-terms) | TCO, optimization | IT Leaders |
| [🏛️ Compliance & Governance](#-compliance--governance-terms) | CAF, WAF, standards | Compliance |
| [🚀 Getting Started Tips](#-getting-started-tips) | Learning path, resources | Newcomers |
| [📞 Need Help?](#-need-help) | Support, troubleshooting | All readers |

---

## 📚 For Newcomers to the Azure Stamps Pattern Glossary

**What is the Glossary for?**
> The glossary is your quick reference for all the terms, acronyms, and concepts used in the Azure Stamps Pattern documentation. If you’re new to Azure, multi-tenancy, or cloud architecture, start here to build your foundation.

**Why is this important?**
> - **Clarity:** Demystifies technical jargon and acronyms
> - **Onboarding:** Accelerates learning for new team members
> - **Reference:** Supports documentation, design, and troubleshooting

---

## 🏗️ **Architectural Terms**

### **Azure Stamps Pattern**
An Azure architectural pattern that deploys identical "stamps" of infrastructure globally for scalability and isolation.
- **Analogy**: Like franchise restaurants - each location (stamp) has the same setup but serves different customers (tenants)
- **Benefits**: Predictable performance, easier troubleshooting, horizontal scaling
- **Example**: Netflix uses a similar pattern to serve different regions with identical infrastructure


### **GEO → Region → Availability Zone → CELL Hierarchy**
The four-tier architecture structure of the Azure Stamps Pattern:
- **GEO**: Geographic area (e.g., North America, Europe) - highest level routing
- **Region**: Azure region within a GEO (e.g., East US, West Europe) - regional services
- **Availability Zone (AZ)**: Physically separate datacenters within a region, providing high availability and fault tolerance. Each CELL can be deployed in 0, 1, 2, or 3 zones depending on business and SLA requirements.
- **CELL**: Individual application instance within a zone - tenant hosting and logical isolation

**Visual Representation:**
```
🌍 North America GEO
├── 🏢 East US Region
│   ├── 🗂️ AZ 1
│   │   ├── 🏠 CELL-001 (Shared: 50 tenants)
│   │   └── 🏠 CELL-002 (Dedicated: 1 enterprise tenant)
│   └── 🗂️ AZ 2
│       └── 🏠 CELL-003 (Shared: 30 tenants)
└── 🏢 West US Region
    ├── 🗂️ AZ 1
    │   └── 🏠 CELL-004 (Shared: 75 tenants)
    └── 🗂️ AZ 2
        └── 🏠 CELL-005 (Dedicated: 1 enterprise tenant)
```

**Why Availability Zones Matter:**
- **High Availability (HA):** Deploying CELLs across multiple AZs protects against datacenter failures.
- **Disaster Recovery (DR):** AZs enable rapid failover and business continuity.
- **Flexible Cost/SLA:** You can choose the number of AZs per CELL to balance cost and durability for each tenant or workload.


### **CELL (Compute Environment for Logical Isolation)**
An isolated application instance that hosts one or more tenants.
- **Shared CELL**: Multi-tenant, cost-optimized (10-100 tenants per CELL)
- **Dedicated CELL**: Single-tenant, compliance-focused (1 tenant per CELL)
- **Analogy**: Shared CELL = apartment building; Dedicated CELL = private house

### **Azure Container Apps (ACA)**
Serverless container hosting for microservices and background processing.
- **Use Cases**: Frontends, APIs, background workers in stamps
- **Scale**: KEDA-based scale to zero and event-driven scale out
- **Docs**: <a href="https://learn.microsoft.com/azure/container-apps/overview" target="_blank" rel="noopener">Azure Container Apps overview</a>

### **Azure Functions**
Event-driven, serverless compute for background tasks and APIs.
- **Use Cases**: Control-plane operations (e.g., tenant provisioning)
- **Bindings**: Triggers for HTTP, Timer, Queue, Service Bus, etc.
- **Docs**: <a href="https://learn.microsoft.com/azure/azure-functions/functions-overview" target="_blank" rel="noopener">Azure Functions overview</a>

### **Azure API Management (APIM)**
Unified gateway for APIs with policy-based controls.
- **Use Cases**: Routing, auth, rate limiting, observability across stamps
- **Policies**: JWT validation, header transforms, CORS, caching
- **Docs**: <a href="https://learn.microsoft.com/azure/api-management/api-management-key-concepts" target="_blank" rel="noopener">API Management key concepts</a>

### **Azure Key Vault**
Secure store for secrets, keys, and certificates.
- **Integration**: Managed identity; reference secrets in app settings and Bicep
- **Docs**: <a href="https://learn.microsoft.com/azure/key-vault/general/overview" target="_blank" rel="noopener">Key Vault overview</a>

### **Data API Builder (DAB)**
Runtime that exposes databases as REST/GraphQL with role-based access.
- **Use Cases**: Data plane for the Management Portal with Easy Auth headers
- **Docs**: <a href="https://learn.microsoft.com/azure/data-api-builder/overview" target="_blank" rel="noopener">Data API Builder overview</a>


## 🏠 **Tenancy Models**

### **Multi-Tenancy**
Architecture where multiple customers (tenants) share the same application instance and infrastructure.
- **Benefits**: Cost efficiency, easier maintenance, resource optimization
- **Challenges**: Isolation, customization, performance consistency

### **Flexible Tenancy**
The ability to support different tenancy models within the same architecture.
- **Business Value**: Mix and match based on customer needs and budget
- **Example**: SMB customers → Shared CELLs; Enterprise customers → Dedicated CELLs

### **Tenant**
A customer or organization using your SaaS application.
- **Examples**: A company, department, or user group
- **Isolation**: Each tenant's data and configuration are separated from others

### **Tenant Assignment**
The process of determining which CELL will host a specific tenant.
- **Factors**: Compliance requirements, performance needs, cost considerations
- **Automation**: Intelligent algorithms can auto-assign based on predefined rules

---

## 🔒 **Security Terms**

### **Zero-Trust Security**
Security model that assumes no implicit trust - everything must be verified.
- **Principles**: "Never trust, always verify"
- **Implementation**: Private endpoints, managed identities, continuous verification
- **Analogy**: Like airport security - everyone gets checked, regardless of who they are

### **Private Endpoints**
Azure feature that provides secure connectivity to services over a private network.
- **Benefit**: Eliminates exposure to public internet
- **Example**: Database only accessible via private network, not public IP
 - **Docs**: <a href="https://learn.microsoft.com/azure/private-link/private-endpoint-overview" target="_blank" rel="noopener">Azure Private Endpoint overview</a>

### **Managed Identity**
Azure feature that provides applications with an automatically managed identity in Azure AD.
- **Benefit**: No need to store credentials in code
- **Types**: System-assigned (tied to resource) or User-assigned (shared across resources)
 - **Docs**: <a href="https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview" target="_blank" rel="noopener">Managed identities for Azure resources</a>

### **JWT (JSON Web Token)**
A secure way to transmit information between parties as a JSON object.
- **Use Case**: Authentication and authorization
- **Performance**: Enhanced with caching (85-90% improvement in this implementation)

### **Microsoft Entra ID (formerly Azure AD)**
Cloud-based identity and access management.
- **Use Cases**: Workforce identities, service principals, app registrations
- **Docs**: <a href="https://learn.microsoft.com/entra/fundamentals/whatis" target="_blank" rel="noopener">What is Microsoft Entra ID?</a>

### **Microsoft Entra External ID (B2C)**
Customer identity and access management for external users.
- **Use Cases**: Public-facing apps with social and local accounts
- **Docs**: <a href="https://learn.microsoft.com/entra/external-id/customers/overview" target="_blank" rel="noopener">What is External ID for customers?</a>

---

## ⚡ **Performance & Scaling Terms**

### **Caching**
Storing frequently accessed data in fast storage for quick retrieval.
- **Types**: Redis (distributed), In-memory (local)
- **Benefit**: Reduces database load and improves response times
- **Monitoring**: Cache hit ratio should be >80%

### **Auto-Scaling**
Automatic adjustment of resources based on demand.
- **Horizontal**: Add more instances (scale out)
- **Vertical**: Increase instance size (scale up)
- **Triggers**: CPU usage, memory usage, request count

### **Load Balancing**
Distributing incoming requests across multiple servers.
- **Benefits**: High availability, better performance, fault tolerance
- **Implementation**: Azure Application Gateway, Azure Load Balancer

---

## �️ **Data & Storage Terms**

### **Azure Cosmos DB (NoSQL)**
Globally distributed, multi-model database used for the control-plane in this repo.
- **Benefits**: Low latency, elastic scale, multi-region replication
- **Docs**: <a href="https://learn.microsoft.com/azure/cosmos-db/nosql/overview" target="_blank" rel="noopener">Cosmos DB for NoSQL overview</a>

## 🌐 **Networking & Routing Terms**

### **Azure Front Door (AFD)**
Global layer 7 entry point for HTTP(S) with CDN, WAF, and path-based routing.
- **Use Cases**: Global routing across GEOs/regions; edge caching; WAF at the edge
- **Docs**: <a href="https://learn.microsoft.com/azure/frontdoor/front-door-overview" target="_blank" rel="noopener">Azure Front Door overview</a>

### **Application Gateway (AppGW)**
Regional layer 7 load balancer with WAF and policy-based routing.
- **Use Cases**: In-region traffic, mTLS, header rewrites, per-stamp routing
- **Docs**: <a href="https://learn.microsoft.com/azure/application-gateway/overview" target="_blank" rel="noopener">Application Gateway overview</a>

### **Private Link and Private DNS Zones**
Service endpoints mapped into your VNET with private DNS for name resolution.
- **Use Cases**: Private connectivity to PaaS (Cosmos, Key Vault, etc.)
- **Docs**: <a href="https://learn.microsoft.com/azure/private-link/private-link-overview" target="_blank" rel="noopener">Private Link overview</a> · <a href="https://learn.microsoft.com/azure/dns/private-dns-privatednszone" target="_blank" rel="noopener">Private DNS zones</a>

### **Container (Cosmos DB)**
The unit of scalability and distribution; holds JSON items with a partition key.
- **Design**: Model by access patterns; avoid cross-partition hot keys
- **Docs**: <a href="https://learn.microsoft.com/azure/cosmos-db/nosql/best-practice-modeling" target="_blank" rel="noopener">Data modeling best practices</a>

### **Partition Key**
Attribute used to distribute items across logical partitions.
- **In This Repo**: /tenantId, /cellId, or /type based on entity
- **Docs**: <a href="https://learn.microsoft.com/azure/cosmos-db/nosql/partitioning-overview" target="_blank" rel="noopener">Partitioning overview</a>

### **Time to Live (TTL)**
Automatic expiration for items after a configured duration.
- **Use Case**: Operations/logs lifecycle management
- **Docs**: <a href="https://learn.microsoft.com/azure/cosmos-db/nosql/time-to-live" target="_blank" rel="noopener">TTL in Azure Cosmos DB</a>

### **Composite Indexes**
Indexes on multiple properties to optimize complex queries.
- **In This Repo**: Used for common filters/sorts in the portal
- **Docs**: <a href="https://learn.microsoft.com/azure/cosmos-db/nosql/index-policy#composite-indexes" target="_blank" rel="noopener">Composite indexes</a>

### **Throughput (RU/s)**
Provisioned request units per second for predictable performance.
- **Modes**: Standard, Autoscale
- **Docs**: <a href="https://learn.microsoft.com/azure/cosmos-db/nosql/set-throughput" target="_blank" rel="noopener">Set throughput on containers and databases</a>

---

## �🛠️ **Infrastructure & DevOps Terms**

### **Infrastructure as Code (IaC)**
Managing infrastructure through machine-readable definition files.
- **Tools**: Bicep, ARM Templates, Terraform
- **Benefits**: Version control, repeatability, consistency

### **Bicep**
Azure's domain-specific language for deploying Azure resources.
- **Advantage**: Simpler than ARM templates, compiles to JSON
- **Example**: Declarative syntax for defining Azure resources
 - **Docs**: <a href="https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview" target="_blank" rel="noopener">Bicep overview</a>

### **CI/CD (Continuous Integration/Continuous Deployment)**
Automated practices for building, testing, and deploying code.
- **CI**: Automatically test code changes
- **CD**: Automatically deploy tested changes
- **Tools**: GitHub Actions, Azure DevOps
 - **Docs**: <a href="https://learn.microsoft.com/devops/what-is-devops" target="_blank" rel="noopener">What is DevOps?</a>

### **Azure Resource Manager (ARM)**
Azure's deployment and management service.
- **Function**: Provides management layer for creating, updating, deleting resources
- **Templates**: JSON files that define infrastructure
 - **Docs**: <a href="https://learn.microsoft.com/azure/azure-resource-manager/management/overview" target="_blank" rel="noopener">ARM overview</a>

### **Azure Container Registry (ACR)**
Private registry for container images and OCI artifacts.
- **Use Cases**: Supply chain for ACA/Functions containers; content trust, scanning
- **Docs**: <a href="https://learn.microsoft.com/azure/container-registry/container-registry-intro" target="_blank" rel="noopener">Azure Container Registry overview</a>

### **Azure Policy and Defender for Cloud**
Governance and security posture management.
- **Use Cases**: Compliance, drift detection, secure scores, recommendations
- **Docs**: <a href="https://learn.microsoft.com/azure/governance/policy/overview" target="_blank" rel="noopener">Azure Policy</a> · <a href="https://learn.microsoft.com/azure/defender-for-cloud/defender-for-cloud-introduction" target="_blank" rel="noopener">Defender for Cloud</a>

### **KEDA-based autoscaling**
Event-driven autoscaling for containers and serverless workloads.
- **Use Cases**: Scale on queue length, HTTP RPS, CPU, custom metrics
- **Docs**: <a href="https://learn.microsoft.com/azure/container-apps/scale-app#scale-rules" target="_blank" rel="noopener">Scale rules in ACA (KEDA)</a>

---

## 📊 **Monitoring & Operations Terms**

### **Observability**
The ability to measure system's internal state by examining its outputs.
- **Three Pillars**: Logs, Metrics, Traces
- **Tools**: Application Insights, Log Analytics, Azure Monitor
 - **Docs**: <a href="https://learn.microsoft.com/azure/azure-monitor/overview" target="_blank" rel="noopener">Azure Monitor overview</a>

### **Application Insights**
Azure's application performance monitoring service.
- **Capabilities**: Request tracking, dependency monitoring, exception tracking
- **Integration**: SDKs for various programming languages
 - **Docs**: <a href="https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview" target="_blank" rel="noopener">Application Insights overview</a>

### **Log Analytics**
Azure service for collecting and analyzing log data.
- **Query Language**: KQL (Kusto Query Language)
- **Use Cases**: Troubleshooting, performance analysis, security monitoring
 - **Docs**: <a href="https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview" target="_blank" rel="noopener">Log Analytics workspace</a>

### **SLA/SLO/SLI**
- **SLA**: Service Level Agreement (what you promise customers)
- **SLO**: Service Level Objective (what you aim to achieve)
- **SLI**: Service Level Indicator (what you actually measure)

---

## 🔗 **Integration & Messaging Terms**

### **Azure Service Bus**
Enterprise messaging with queues and topics (pub/sub).
- **Use Cases**: Decoupling services, retry/poison handling, FIFO with sessions
- **Docs**: <a href="https://learn.microsoft.com/azure/service-bus-messaging/service-bus-messaging-overview" target="_blank" rel="noopener">Service Bus overview</a>

### **Azure Storage Queues**
Simple queueing service built on Azure Storage.
- **Use Cases**: Lightweight background processing; cost-effective queues
- **Docs**: <a href="https://learn.microsoft.com/azure/storage/queues/storage-queues-introduction" target="_blank" rel="noopener">Storage Queues introduction</a>

## 💰 **Cost & Business Terms**

### **TCO (Total Cost of Ownership)**
Complete cost of owning and operating a solution over its lifetime.
- **Includes**: Infrastructure, operations, maintenance, support
- **Optimization**: Right-sizing, reserved instances, automation

### **Reserved Instances**
Pre-purchased compute capacity for significant discounts.
- **Discount**: Up to 72% compared to pay-as-you-go pricing
- **Terms**: 1-year or 3-year commitments

### **Cost Optimization**
Practices to reduce expenses while maintaining performance and functionality.
- **Strategies**: Auto-scaling, reserved instances, right-sizing, lifecycle management

---

## 🏛️ **Compliance & Governance Terms**

### **CAF (Cloud Adoption Framework)**
Microsoft's guidance for cloud adoption journey.
- **Areas**: Strategy, Plan, Ready, Adopt, Govern, Manage

See also: [CAF/WAF Compliance Analysis](./CAF_WAF_COMPLIANCE_ANALYSIS.md)

> Related: To implement CAF-aligned platform landing zones, see the [Azure Landing Zones Guide](./LANDING_ZONES_GUIDE.md).

### **WAF (Well-Architected Framework)**
Azure's framework for building reliable, secure, efficient applications.
- **Pillars**: Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency
- **Assessment**: Regular reviews to identify improvements

See also: [CAF/WAF Compliance Analysis](./CAF_WAF_COMPLIANCE_ANALYSIS.md)

> Related: Pair WAF reviews with enterprise landing zones for durable enforcement. Start with the [Azure Landing Zones Guide](./LANDING_ZONES_GUIDE.md).

### **GDPR/HIPAA/SOC 2**
Compliance standards for data protection and security.
- **GDPR**: EU data protection regulation
- **HIPAA**: US healthcare data protection
- **SOC 2**: Security, availability, processing integrity standards

---

## 🚀 **Getting Started Tips**

### **Where to Start**
1. **Business Users**: Read README.md for overview and business value
2. **Architects**: Start with ARCHITECTURE_GUIDE.md for technical details
3. **Developers**: Begin with DEPLOYMENT_GUIDE.md for hands-on implementation
4. **Operations**: Focus on OPERATIONS_GUIDE.md and KNOWN_ISSUES.md

### **Common Learning Path**
```
Overview → Architecture → Deployment → Security → Operations → Troubleshooting
   ↓          ↓            ↓           ↓          ↓            ↓
README → ARCHITECTURE → DEPLOYMENT → SECURITY → OPERATIONS → KNOWN_ISSUES
```

### **Key Resources**
- **Documentation Hub**: [DOCS.md](./DOCS.md) - Central navigation
- **Quick Start**: [README.md](../README.md) - Project overview

---


## 📞 **Need Help?**

- **General Questions**: Start with [DOCS.md](./DOCS.md) sitemap
- **Technical Issues**: Check [KNOWN_ISSUES.md](./KNOWN_ISSUES.md) troubleshooting guide
- **Architecture Understanding**: Review [ARCHITECTURE_GUIDE.md](./ARCHITECTURE_GUIDE.md)

---

*This glossary is maintained alongside the documentation. Last updated: August 2025*

> Authoring tip: When code examples contain comments, use `jsonc` code fences. For diagrams, prefer the standard Mermaid template in `docs/mermaid-template.md`.
