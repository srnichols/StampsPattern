using System;
using System.Collections.Generic;

/// <summary>
/// Shared models and enums for the Azure Stamps Pattern flexible tenancy implementation
/// These models support both Shared CELL (multi-tenant) and Dedicated CELL (single-tenant) architectures
/// as documented in ARCHITECTURE_GUIDE.md
/// </summary>
namespace AzureStampsPattern.Models
{
    /// <summary>
    /// Cached representation of tenant routing details to speed up lookups
    /// </summary>
    public class CachedTenantRouting
    {
    public string TenantId { get; set; } = string.Empty;
    public string CellBackendPool { get; set; } = string.Empty;
    public string CellName { get; set; } = string.Empty;
    public string ErrorMessage { get; set; } = string.Empty;
    public string AssignmentReason { get; set; } = string.Empty;
    public string Region { get; set; } = string.Empty;
    public string Subdomain { get; set; } = string.Empty;
    public TenantTier TenantTier { get; set; } = TenantTier.Shared;
        public DateTime LastModified { get; set; } = DateTime.UtcNow;
        public TimeSpan CacheExpiry { get; set; } = TimeSpan.FromHours(1);
    }

    /// <summary>
    /// Enhanced tenant information supporting flexible tenancy models
    /// </summary>
    public class TenantInfo
    {
    public string tenantId { get; set; } = string.Empty;
    public string subdomain { get; set; } = string.Empty;
    public string cellBackendPool { get; set; } = string.Empty;
    public string cellName { get; set; } = string.Empty;
        public TenantTier? tenantTier { get; set; } = TenantTier.Shared;
    public string region { get; set; } = "eastus";
        public List<string> complianceRequirements { get; set; } = new List<string>();
        public TenantStatus status { get; set; } = TenantStatus.Active;
        public DateTime createdDate { get; set; }
        public DateTime? lastModifiedDate { get; set; }
        public int estimatedMonthlyApiCalls { get; set; } = 10000;
    public string contactEmail { get; set; } = string.Empty;
    public string organizationName { get; set; } = string.Empty;
    public string businessSegment { get; set; } = string.Empty; // Startup, SMB, Enterprise, Government
        public List<string> dataResidencyRequirements { get; set; } = new List<string>();
    public string slaLevel { get; set; } = "Standard"; // Basic, Standard, Premium, Enterprise
    }

    /// <summary>
    /// CELL information for capacity and assignment tracking
    /// </summary>
    public class CellInfo
    {
    public string cellId { get; set; } = string.Empty;
    public string cellName { get; set; } = string.Empty;
        public CellType cellType { get; set; }
    public string region { get; set; } = string.Empty;
    public string backendPool { get; set; } = string.Empty;
        public int maxTenantCount { get; set; }
        public int currentTenantCount { get; set; }
        public CellStatus status { get; set; }
        public List<string> complianceFeatures { get; set; } = new List<string>();
        public DateTime createdDate { get; set; }
        public DateTime? lastModifiedDate { get; set; }
        
        // Resource utilization metrics
        public double cpuUtilization { get; set; }
        public double memoryUtilization { get; set; }
        public double storageUtilization { get; set; }
        public double networkUtilization { get; set; }
        
        // Cost and billing information
        public string skuTier { get; set; } = "Standard";
        public double monthlyCostEstimate { get; set; }
        public string billingModel { get; set; } = "Shared"; // Shared, Dedicated, Reserved
        
        // Availability and SLA
        public double availabilityTarget { get; set; } = 99.9;
    public string maintenanceWindow { get; set; } = string.Empty;
        public bool autoScalingEnabled { get; set; } = true;
    }

    /// <summary>
    /// Result of CELL assignment operation
    /// </summary>
    public class CellAssignmentResult
    {
    public bool Success { get; set; }
    public string CellBackendPool { get; set; } = string.Empty;
    public string CellName { get; set; } = string.Empty;
    public string ErrorMessage { get; set; } = string.Empty;
    public TenantTier AssignedTier { get; set; }
    public string AssignmentReason { get; set; } = string.Empty;
    public DateTime AssignmentTimestamp { get; set; }
    }

    /// <summary>
    /// Tenant tier enumeration for flexible tenancy models
    /// Maps to cost structure: Startup ($8/mo), SMB ($16/mo), Shared ($16/mo), Enterprise ($3200/mo), Dedicated ($3200/mo)
    /// </summary>
    public enum TenantTier
    {
        /// <summary>
        /// Small startups, shared CELLs, basic features, cost-optimized (~$8/tenant/month)
        /// </summary>
        Startup,
        
        /// <summary>
        /// Small-medium business, shared CELLs, standard features (~$16/tenant/month)
        /// </summary>
        SMB,
        
        /// <summary>
        /// General shared tenancy model, shared CELLs (~$16/tenant/month)
        /// </summary>
        Shared,
        
        /// <summary>
        /// Large enterprise, dedicated CELLs, premium features (~$3200/tenant/month)
        /// </summary>
        Enterprise,
        
        /// <summary>
        /// Dedicated infrastructure, full isolation, compliance-ready (~$3200/tenant/month)
        /// </summary>
        Dedicated
    }

    /// <summary>
    /// CELL type enumeration supporting flexible tenancy architecture
    /// </summary>
    public enum CellType
    {
        /// <summary>
        /// Multi-tenant CELL supporting 10-100 tenants with application-level isolation
        /// </summary>
        Shared,
        
        /// <summary>
        /// Single-tenant CELL with complete infrastructure isolation for enterprise clients
        /// </summary>
        Dedicated
    }

    /// <summary>
    /// Tenant status enumeration for lifecycle management
    /// </summary>
    public enum TenantStatus
    {
        /// <summary>
        /// Tenant is active and operational
        /// </summary>
        Active,
        
        /// <summary>
        /// Tenant is temporarily inactive but resources are preserved
        /// </summary>
        Inactive,
        
        /// <summary>
        /// Tenant is suspended due to billing or compliance issues
        /// </summary>
        Suspended,
        
        /// <summary>
        /// Tenant is being migrated between CELLs
        /// </summary>
        Migrating,
        
        /// <summary>
        /// Tenant is in process of being onboarded
        /// </summary>
        Provisioning,
        
        /// <summary>
        /// Tenant is scheduled for deletion
        /// </summary>
        Deprovisioning
    }

    /// <summary>
    /// CELL status enumeration for operational management
    /// </summary>
    public enum CellStatus
    {
        /// <summary>
        /// CELL is active and accepting tenants
        /// </summary>
        Active,
        
        /// <summary>
        /// CELL is being provisioned and not yet ready
        /// </summary>
        Provisioning,
        
        /// <summary>
        /// CELL is under maintenance and not accepting new tenants
        /// </summary>
        Maintenance,
        
        /// <summary>
        /// CELL is deprecated and will be decommissioned
        /// </summary>
        Deprecated,
        
        /// <summary>
        /// CELL is at capacity and not accepting new tenants
        /// </summary>
        AtCapacity,
        
        /// <summary>
        /// CELL has failed and needs attention
        /// </summary>
        Failed
    }

    /// <summary>
    /// Compliance standards supported by the flexible tenancy model
    /// </summary>
    public static class ComplianceStandards
    {
        public const string HIPAA = "HIPAA";
        public const string SOX = "SOX";
        public const string PCI_DSS = "PCI-DSS";
        public const string GDPR = "GDPR";
        public const string ISO27001 = "ISO27001";
        public const string SOC2_TYPE2 = "SOC2-Type2";
        public const string FEDRAMP = "FedRAMP";
        public const string CCPA = "CCPA";
    }

    /// <summary>
    /// Business segments for tenant categorization
    /// </summary>
    public static class BusinessSegments
    {
        public const string STARTUP = "Startup";
        public const string SMB = "Small-Medium Business";
        public const string ENTERPRISE = "Enterprise";
        public const string GOVERNMENT = "Government";
        public const string HEALTHCARE = "Healthcare";
        public const string FINANCIAL = "Financial Services";
        public const string EDUCATION = "Education";
        public const string NONPROFIT = "Non-Profit";
    }

    /// <summary>
    /// SLA levels with corresponding availability targets
    /// </summary>
    public static class SlaLevels
    {
        public const string BASIC = "Basic";       // 99.5% uptime
        public const string STANDARD = "Standard"; // 99.9% uptime  
        public const string PREMIUM = "Premium";   // 99.95% uptime
        public const string ENTERPRISE = "Enterprise"; // 99.99% uptime
    }

    /// <summary>
    /// Cost models for different tenancy approaches
    /// </summary>
    public class TenancyCostModel
    {
        public static readonly Dictionary<TenantTier, decimal> MonthlyBaseCost = new Dictionary<TenantTier, decimal>
        {
            { TenantTier.Startup, 8m },      // $8/tenant/month in shared CELL
            { TenantTier.SMB, 16m },         // $16/tenant/month in shared CELL
            { TenantTier.Shared, 16m },      // $16/tenant/month in shared CELL
            { TenantTier.Enterprise, 3200m }, // $3200/tenant/month in dedicated CELL
            { TenantTier.Dedicated, 3200m }   // $3200/tenant/month in dedicated CELL
        };

        public static readonly Dictionary<string, decimal> CompliancePremium = new Dictionary<string, decimal>
        {
            { ComplianceStandards.HIPAA, 50m },      // +$50/month for HIPAA
            { ComplianceStandards.SOX, 100m },       // +$100/month for SOX
            { ComplianceStandards.PCI_DSS, 75m },    // +$75/month for PCI-DSS
            { ComplianceStandards.FEDRAMP, 200m },   // +$200/month for FedRAMP
            { ComplianceStandards.SOC2_TYPE2, 25m }  // +$25/month for SOC2
        };
    }

    /// <summary>
    /// Infrastructure resource discovered from Azure Resource Manager
    /// </summary>
    public class InfrastructureResource
    {
        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string Type { get; set; } = string.Empty;
        public string Location { get; set; } = string.Empty;
        public string ResourceGroup { get; set; } = string.Empty;
        public string Subscription { get; set; } = string.Empty;
        public Dictionary<string, string> Tags { get; set; } = new();
        public string Status { get; set; } = "unknown";
        public DateTime LastDiscovered { get; set; } = DateTime.UtcNow;
        public Dictionary<string, object> Properties { get; set; } = new();
    }

    /// <summary>
    /// Extended Cell model with infrastructure discovery data
    /// </summary>
    public class Cell
    {
        public string Id { get; set; } = string.Empty;
        public string CellId { get; set; } = string.Empty;
        public string Region { get; set; } = string.Empty;
        public string AvailabilityZone { get; set; } = "1";
        public string Status { get; set; } = "unknown";
        public int CapacityTotal { get; set; } = 100;
        public int CapacityUsed { get; set; } = 0;
        public string? ResourceGroup { get; set; }
        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;
        public List<string> ResourceTypes { get; set; } = new();
        public Dictionary<string, string> Tags { get; set; } = new();
        public bool IsDiscovered { get; set; } = false;
        
        // Computed properties
        public double UtilizationPercentage => CapacityTotal > 0 ? (double)CapacityUsed / CapacityTotal * 100 : 0;
        public bool IsHealthy => Status.Equals("healthy", StringComparison.OrdinalIgnoreCase);
        public bool HasCapacity => CapacityUsed < CapacityTotal;
    }
}
