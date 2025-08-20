# Infrastructure Discovery - Management Portal Integration

## Overview

This guide provides the components needed to integrate the Infrastructure Discovery Function with the existing management portal, enabling real-time visualization and management of stamp infrastructure.

## Portal Component Architecture

```
management-portal/src/
├── components/
│   ├── infrastructure/
│   │   ├── InfrastructureDiscoveryDashboard.tsx
│   │   ├── StampVisualization.tsx
│   │   ├── RegionalOverview.tsx
│   │   ├── CellStatusMatrix.tsx
│   │   ├── CapacityAnalytics.tsx
│   │   └── DiscoveryControls.tsx
│   └── shared/
├── services/
│   ├── infrastructureDiscoveryService.ts
│   ├── cacheService.ts
│   └── types/
│       └── infrastructure.types.ts
├── hooks/
│   ├── useInfrastructureDiscovery.ts
│   ├── useRealTimeUpdates.ts
│   └── useCapacityMetrics.ts
└── pages/
    └── infrastructure/
        └── discovery.tsx
```

## TypeScript Types and Interfaces

### infrastructure.types.ts
```typescript
// Core infrastructure types
export interface DiscoveryResponse {
  discoveryId: string;
  timestamp: string;
  mode: 'simulated' | 'azure';
  stamps: Stamp[];
  globalMetrics: GlobalMetrics;
  performance: PerformanceMetrics;
  cacheInfo?: CacheInfo;
}

export interface Stamp {
  id: string;
  name: string;
  region: string;
  cell: string;
  status: StampStatus;
  resources: StampResource[];
  capacity: CapacityMetrics;
  healthScore: number;
  lastUpdated: string;
  endpoints: StampEndpoint[];
  configuration: StampConfiguration;
}

export interface StampResource {
  id: string;
  name: string;
  type: string;
  resourceGroup: string;
  status: ResourceStatus;
  sku?: string;
  capacity?: ResourceCapacity;
  metrics?: ResourceMetrics;
  tags: Record<string, string>;
}

export interface CapacityMetrics {
  compute: {
    current: number;
    maximum: number;
    utilizationPercent: number;
    scalingTriggers: ScalingTrigger[];
  };
  storage: {
    used: number;
    available: number;
    utilizationPercent: number;
  };
  network: {
    bandwidth: number;
    connections: number;
    latency: number;
  };
  cost: {
    daily: number;
    monthly: number;
    projected: number;
  };
}

export interface GlobalMetrics {
  totalStamps: number;
  healthyStamps: number;
  totalCapacity: CapacityMetrics;
  globalHealthScore: number;
  regionalDistribution: RegionalDistribution[];
  trends: MetricTrend[];
}

export interface PerformanceMetrics {
  discoveryDuration: number;
  resourceCount: number;
  cacheHitRate?: number;
  operationTimings: Record<string, number>;
}

export interface CacheInfo {
  hitRate: number;
  entries: number;
  lastRefresh: string;
  nextRefresh: string;
}

export type StampStatus = 'healthy' | 'degraded' | 'unhealthy' | 'unknown';
export type ResourceStatus = 'running' | 'stopped' | 'error' | 'provisioning';

// Discovery configuration
export interface DiscoveryConfiguration {
  mode: 'simulated' | 'azure';
  refreshInterval: number;
  enableRealTime: boolean;
  regions: string[];
  resourceTypes: string[];
  includeMetrics: boolean;
  cacheTtl: number;
}

// UI State interfaces
export interface DiscoveryViewState {
  loading: boolean;
  error: string | null;
  data: DiscoveryResponse | null;
  selectedStamp: string | null;
  viewMode: 'grid' | 'list' | 'topology';
  filters: DiscoveryFilters;
}

export interface DiscoveryFilters {
  regions: string[];
  status: StampStatus[];
  healthScore: { min: number; max: number };
  resourceTypes: string[];
  searchTerm: string;
}
```

## Service Layer

### infrastructureDiscoveryService.ts
```typescript
import { DiscoveryResponse, DiscoveryConfiguration, Stamp } from '../types/infrastructure.types';

export class InfrastructureDiscoveryService {
  private baseUrl: string;
  private cache: Map<string, { data: any; timestamp: number; ttl: number }>;
  private subscribers: Map<string, ((data: DiscoveryResponse) => void)[]>;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
    this.cache = new Map();
    this.subscribers = new Map();
  }

  /**
   * Discover infrastructure using the Azure Function
   */
  async discoverInfrastructure(config: DiscoveryConfiguration): Promise<DiscoveryResponse> {
    const cacheKey = this.generateCacheKey(config);
    
    // Check cache first
    if (this.isCacheValid(cacheKey)) {
      const cached = this.cache.get(cacheKey);
      if (cached) {
        return cached.data;
      }
    }

    try {
      const queryParams = new URLSearchParams({
        mode: config.mode,
        includeMetrics: config.includeMetrics.toString(),
        regions: config.regions.join(','),
        resourceTypes: config.resourceTypes.join(','),
      });

      const response = await fetch(`${this.baseUrl}/api/infrastructure/discover?${queryParams}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error(`Discovery failed: ${response.status} ${response.statusText}`);
      }

      const data: DiscoveryResponse = await response.json();
      
      // Cache the result
      this.cacheResult(cacheKey, data, config.cacheTtl);
      
      // Notify subscribers
      this.notifySubscribers(cacheKey, data);
      
      return data;
    } catch (error) {
      console.error('Infrastructure discovery error:', error);
      throw new Error(`Failed to discover infrastructure: ${error}`);
    }
  }

  /**
   * Get specific stamp details
   */
  async getStampDetails(stampId: string): Promise<Stamp> {
    try {
      const response = await fetch(`${this.baseUrl}/api/infrastructure/stamps/${stampId}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to get stamp details: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error('Get stamp details error:', error);
      throw error;
    }
  }

  /**
   * Subscribe to real-time updates
   */
  subscribe(config: DiscoveryConfiguration, callback: (data: DiscoveryResponse) => void): () => void {
    const key = this.generateCacheKey(config);
    
    if (!this.subscribers.has(key)) {
      this.subscribers.set(key, []);
    }
    
    this.subscribers.get(key)!.push(callback);
    
    // Start polling if enabled
    if (config.enableRealTime) {
      this.startPolling(config);
    }
    
    // Return unsubscribe function
    return () => {
      const callbacks = this.subscribers.get(key);
      if (callbacks) {
        const index = callbacks.indexOf(callback);
        if (index > -1) {
          callbacks.splice(index, 1);
        }
      }
    };
  }

  /**
   * Force refresh cache for specific configuration
   */
  async forceRefresh(config: DiscoveryConfiguration): Promise<DiscoveryResponse> {
    const cacheKey = this.generateCacheKey(config);
    this.cache.delete(cacheKey);
    return this.discoverInfrastructure(config);
  }

  /**
   * Get cache statistics
   */
  getCacheStats(): { entries: number; hitRate: number; totalSize: number } {
    return {
      entries: this.cache.size,
      hitRate: this.calculateCacheHitRate(),
      totalSize: this.calculateCacheSize(),
    };
  }

  private generateCacheKey(config: DiscoveryConfiguration): string {
    return `discovery:${config.mode}:${config.regions.sort().join(',')}:${config.resourceTypes.sort().join(',')}:${config.includeMetrics}`;
  }

  private isCacheValid(key: string): boolean {
    const cached = this.cache.get(key);
    if (!cached) return false;
    return Date.now() - cached.timestamp < cached.ttl;
  }

  private cacheResult(key: string, data: DiscoveryResponse, ttl: number): void {
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      ttl: ttl * 1000, // Convert to milliseconds
    });
  }

  private notifySubscribers(key: string, data: DiscoveryResponse): void {
    const callbacks = this.subscribers.get(key);
    if (callbacks) {
      callbacks.forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error('Subscriber notification error:', error);
        }
      });
    }
  }

  private async startPolling(config: DiscoveryConfiguration): Promise<void> {
    const poll = async () => {
      try {
        await this.discoverInfrastructure(config);
      } catch (error) {
        console.error('Polling error:', error);
      }
      
      setTimeout(poll, config.refreshInterval * 1000);
    };
    
    setTimeout(poll, config.refreshInterval * 1000);
  }

  private calculateCacheHitRate(): number {
    // Implementation would track hits/misses
    return 0.85; // Placeholder
  }

  private calculateCacheSize(): number {
    let size = 0;
    this.cache.forEach(entry => {
      size += JSON.stringify(entry.data).length;
    });
    return size;
  }
}

// Singleton instance
export const infrastructureDiscoveryService = new InfrastructureDiscoveryService(
  process.env.NEXT_PUBLIC_FUNCTIONS_URL || 'https://func-stamps-discovery.azurewebsites.net'
);
```

## React Hooks

### useInfrastructureDiscovery.ts
```typescript
import { useState, useEffect, useCallback, useRef } from 'react';
import { DiscoveryResponse, DiscoveryConfiguration, DiscoveryViewState } from '../types/infrastructure.types';
import { infrastructureDiscoveryService } from '../services/infrastructureDiscoveryService';

export function useInfrastructureDiscovery(initialConfig: DiscoveryConfiguration) {
  const [state, setState] = useState<DiscoveryViewState>({
    loading: false,
    error: null,
    data: null,
    selectedStamp: null,
    viewMode: 'grid',
    filters: {
      regions: [],
      status: [],
      healthScore: { min: 0, max: 100 },
      resourceTypes: [],
      searchTerm: '',
    },
  });

  const [config, setConfig] = useState<DiscoveryConfiguration>(initialConfig);
  const unsubscribeRef = useRef<(() => void) | null>(null);

  const discover = useCallback(async (forceRefresh = false) => {
    setState(prev => ({ ...prev, loading: true, error: null }));

    try {
      const data = forceRefresh 
        ? await infrastructureDiscoveryService.forceRefresh(config)
        : await infrastructureDiscoveryService.discoverInfrastructure(config);

      setState(prev => ({
        ...prev,
        loading: false,
        data,
        error: null,
      }));
    } catch (error) {
      setState(prev => ({
        ...prev,
        loading: false,
        error: error instanceof Error ? error.message : 'Unknown error occurred',
      }));
    }
  }, [config]);

  const updateConfig = useCallback((newConfig: Partial<DiscoveryConfiguration>) => {
    setConfig(prev => ({ ...prev, ...newConfig }));
  }, []);

  const setFilters = useCallback((filters: Partial<typeof state.filters>) => {
    setState(prev => ({
      ...prev,
      filters: { ...prev.filters, ...filters },
    }));
  }, []);

  const selectStamp = useCallback((stampId: string | null) => {
    setState(prev => ({ ...prev, selectedStamp: stampId }));
  }, []);

  const setViewMode = useCallback((mode: 'grid' | 'list' | 'topology') => {
    setState(prev => ({ ...prev, viewMode: mode }));
  }, []);

  // Set up subscription for real-time updates
  useEffect(() => {
    if (config.enableRealTime) {
      unsubscribeRef.current = infrastructureDiscoveryService.subscribe(
        config,
        (data: DiscoveryResponse) => {
          setState(prev => ({ ...prev, data }));
        }
      );
    }

    return () => {
      if (unsubscribeRef.current) {
        unsubscribeRef.current();
      }
    };
  }, [config]);

  // Initial discovery
  useEffect(() => {
    discover();
  }, [discover]);

  return {
    state,
    config,
    actions: {
      discover,
      forceRefresh: () => discover(true),
      updateConfig,
      setFilters,
      selectStamp,
      setViewMode,
    },
  };
}
```

### useRealTimeUpdates.ts
```typescript
import { useEffect, useRef, useState } from 'react';
import { DiscoveryResponse } from '../types/infrastructure.types';

export function useRealTimeUpdates(enabled: boolean, interval: number = 30000) {
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());
  const [updateCount, setUpdateCount] = useState(0);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    if (!enabled) {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
      return;
    }

    intervalRef.current = setInterval(() => {
      setLastUpdate(new Date());
      setUpdateCount(prev => prev + 1);
    }, interval);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    };
  }, [enabled, interval]);

  return {
    lastUpdate,
    updateCount,
    isEnabled: enabled,
  };
}
```

## React Components

### InfrastructureDiscoveryDashboard.tsx
```typescript
import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { RefreshCw, Settings, Download, Eye } from 'lucide-react';
import { useInfrastructureDiscovery } from '../../hooks/useInfrastructureDiscovery';
import { useRealTimeUpdates } from '../../hooks/useRealTimeUpdates';
import { StampVisualization } from './StampVisualization';
import { RegionalOverview } from './RegionalOverview';
import { CapacityAnalytics } from './CapacityAnalytics';
import { DiscoveryControls } from './DiscoveryControls';

const defaultConfig = {
  mode: 'simulated' as const,
  refreshInterval: 30,
  enableRealTime: true,
  regions: ['eastus', 'westus'],
  resourceTypes: [],
  includeMetrics: true,
  cacheTtl: 300,
};

export function InfrastructureDiscoveryDashboard() {
  const { state, config, actions } = useInfrastructureDiscovery(defaultConfig);
  const realTimeUpdates = useRealTimeUpdates(config.enableRealTime, config.refreshInterval * 1000);

  const handleExportData = () => {
    if (state.data) {
      const dataStr = JSON.stringify(state.data, null, 2);
      const dataBlob = new Blob([dataStr], { type: 'application/json' });
      const url = URL.createObjectURL(dataBlob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `infrastructure-discovery-${new Date().toISOString()}.json`;
      link.click();
      URL.revokeObjectURL(url);
    }
  };

  const formatLastUpdate = (timestamp: string) => {
    return new Date(timestamp).toLocaleString();
  };

  return (
    <div className="space-y-6 p-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Infrastructure Discovery</h1>
          <p className="text-muted-foreground">
            Real-time view of your stamp infrastructure across all regions
          </p>
        </div>
        
        <div className="flex items-center gap-2">
          {state.data && (
            <Badge variant="outline" className="gap-1">
              <Eye className="h-3 w-3" />
              {state.data.mode} mode
            </Badge>
          )}
          
          {config.enableRealTime && (
            <Badge variant="secondary" className="gap-1">
              <div className="h-2 w-2 bg-green-500 rounded-full animate-pulse" />
              Live
            </Badge>
          )}
          
          <Button
            variant="outline"
            size="sm"
            onClick={() => actions.forceRefresh()}
            disabled={state.loading}
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${state.loading ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          
          <Button
            variant="outline"
            size="sm"
            onClick={handleExportData}
            disabled={!state.data}
          >
            <Download className="h-4 w-4 mr-2" />
            Export
          </Button>
        </div>
      </div>

      {/* Controls */}
      <DiscoveryControls
        config={config}
        onConfigChange={actions.updateConfig}
        filters={state.filters}
        onFiltersChange={actions.setFilters}
        viewMode={state.viewMode}
        onViewModeChange={actions.setViewMode}
      />

      {/* Error State */}
      {state.error && (
        <Card className="border-destructive">
          <CardContent className="pt-6">
            <div className="flex items-center gap-2 text-destructive">
              <span className="font-medium">Discovery Error:</span>
              <span>{state.error}</span>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Loading State */}
      {state.loading && !state.data && (
        <Card>
          <CardContent className="pt-6">
            <div className="flex items-center justify-center py-12">
              <RefreshCw className="h-8 w-8 animate-spin mr-3" />
              <span className="text-lg">Discovering infrastructure...</span>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Main Content */}
      {state.data && (
        <>
          {/* Summary Cards */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  Total Stamps
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">{state.data.globalMetrics.totalStamps}</div>
                <div className="text-sm text-muted-foreground">
                  {state.data.globalMetrics.healthyStamps} healthy
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  Global Health
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {Math.round(state.data.globalMetrics.globalHealthScore)}%
                </div>
                <div className="text-sm text-muted-foreground">
                  Overall system health
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  Cache Performance
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {state.data.cacheInfo ? Math.round(state.data.cacheInfo.hitRate * 100) : 0}%
                </div>
                <div className="text-sm text-muted-foreground">
                  Hit rate
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium text-muted-foreground">
                  Discovery Time
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {Math.round(state.data.performance.discoveryDuration)}ms
                </div>
                <div className="text-sm text-muted-foreground">
                  Last update: {formatLastUpdate(state.data.timestamp)}
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Regional Overview */}
          <RegionalOverview
            stamps={state.data.stamps}
            globalMetrics={state.data.globalMetrics}
            filters={state.filters}
          />

          {/* Stamp Visualization */}
          <StampVisualization
            stamps={state.data.stamps}
            viewMode={state.viewMode}
            selectedStamp={state.selectedStamp}
            onStampSelect={actions.selectStamp}
            filters={state.filters}
          />

          {/* Capacity Analytics */}
          <CapacityAnalytics
            stamps={state.data.stamps}
            globalMetrics={state.data.globalMetrics}
          />
        </>
      )}
    </div>
  );
}
```

### StampVisualization.tsx
```typescript
import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Server, Database, Globe, TrendingUp } from 'lucide-react';
import { Stamp, DiscoveryFilters } from '../../types/infrastructure.types';

interface StampVisualizationProps {
  stamps: Stamp[];
  viewMode: 'grid' | 'list' | 'topology';
  selectedStamp: string | null;
  onStampSelect: (stampId: string | null) => void;
  filters: DiscoveryFilters;
}

export function StampVisualization({
  stamps,
  viewMode,
  selectedStamp,
  onStampSelect,
  filters,
}: StampVisualizationProps) {
  const filteredStamps = stamps.filter(stamp => {
    // Apply filters
    if (filters.regions.length > 0 && !filters.regions.includes(stamp.region)) {
      return false;
    }
    
    if (filters.status.length > 0 && !filters.status.includes(stamp.status)) {
      return false;
    }
    
    if (stamp.healthScore < filters.healthScore.min || stamp.healthScore > filters.healthScore.max) {
      return false;
    }
    
    if (filters.searchTerm && !stamp.name.toLowerCase().includes(filters.searchTerm.toLowerCase())) {
      return false;
    }
    
    return true;
  });

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'healthy': return 'bg-green-500';
      case 'degraded': return 'bg-yellow-500';
      case 'unhealthy': return 'bg-red-500';
      default: return 'bg-gray-500';
    }
  };

  const getStatusVariant = (status: string) => {
    switch (status) {
      case 'healthy': return 'default';
      case 'degraded': return 'secondary';
      case 'unhealthy': return 'destructive';
      default: return 'outline';
    }
  };

  if (viewMode === 'grid') {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Server className="h-5 w-5" />
            Stamps Overview ({filteredStamps.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {filteredStamps.map(stamp => (
              <Card
                key={stamp.id}
                className={`cursor-pointer transition-all hover:shadow-md ${
                  selectedStamp === stamp.id ? 'ring-2 ring-primary' : ''
                }`}
                onClick={() => onStampSelect(stamp.id)}
              >
                <CardContent className="p-4">
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <h3 className="font-medium truncate">{stamp.name}</h3>
                      <div className={`h-2 w-2 rounded-full ${getStatusColor(stamp.status)}`} />
                    </div>
                    
                    <div className="flex items-center gap-2 text-sm text-muted-foreground">
                      <Globe className="h-3 w-3" />
                      {stamp.region} • {stamp.cell}
                    </div>
                    
                    <div className="flex items-center justify-between">
                      <Badge variant={getStatusVariant(stamp.status)} className="text-xs">
                        {stamp.status}
                      </Badge>
                      <span className="text-sm font-medium">
                        {Math.round(stamp.healthScore)}%
                      </span>
                    </div>
                    
                    <div className="text-xs text-muted-foreground">
                      {stamp.resources.length} resources
                    </div>
                    
                    <div className="flex items-center gap-1 text-xs text-muted-foreground">
                      <TrendingUp className="h-3 w-3" />
                      {Math.round(stamp.capacity.compute.utilizationPercent)}% CPU
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  if (viewMode === 'list') {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Server className="h-5 w-5" />
            Stamps List ({filteredStamps.length})
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {filteredStamps.map(stamp => (
              <div
                key={stamp.id}
                className={`flex items-center justify-between p-4 rounded-lg border cursor-pointer transition-all hover:bg-accent ${
                  selectedStamp === stamp.id ? 'bg-accent' : ''
                }`}
                onClick={() => onStampSelect(stamp.id)}
              >
                <div className="flex items-center gap-4">
                  <div className={`h-3 w-3 rounded-full ${getStatusColor(stamp.status)}`} />
                  <div>
                    <h3 className="font-medium">{stamp.name}</h3>
                    <div className="text-sm text-muted-foreground">
                      {stamp.region} • {stamp.cell} • {stamp.resources.length} resources
                    </div>
                  </div>
                </div>
                
                <div className="flex items-center gap-4">
                  <Badge variant={getStatusVariant(stamp.status)}>
                    {stamp.status}
                  </Badge>
                  <div className="text-right">
                    <div className="font-medium">{Math.round(stamp.healthScore)}%</div>
                    <div className="text-sm text-muted-foreground">health</div>
                  </div>
                  <div className="text-right">
                    <div className="font-medium">{Math.round(stamp.capacity.compute.utilizationPercent)}%</div>
                    <div className="text-sm text-muted-foreground">CPU</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  // Topology view would be more complex - simplified version here
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Server className="h-5 w-5" />
          Network Topology ({filteredStamps.length})
        </CardTitle>
      </CardHeader>
      <CardContent>
        <div className="h-96 flex items-center justify-center bg-muted rounded-lg">
          <div className="text-center">
            <Server className="h-12 w-12 mx-auto mb-2 text-muted-foreground" />
            <h3 className="font-medium">Topology View</h3>
            <p className="text-sm text-muted-foreground">
              Interactive network diagram would be implemented here
            </p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
```

## Next.js Page Integration

### pages/infrastructure/discovery.tsx
```typescript
import { NextPage } from 'next';
import { InfrastructureDiscoveryDashboard } from '../../components/infrastructure/InfrastructureDiscoveryDashboard';
import Layout from '../../components/Layout';

const InfrastructureDiscoveryPage: NextPage = () => {
  return (
    <Layout title="Infrastructure Discovery" description="Discover and manage stamp infrastructure">
      <InfrastructureDiscoveryDashboard />
    </Layout>
  );
};

export default InfrastructureDiscoveryPage;
```

## Environment Configuration

### .env.local
```bash
# Azure Function endpoints
NEXT_PUBLIC_FUNCTIONS_URL=https://func-stamps-discovery.azurewebsites.net
NEXT_PUBLIC_FUNCTIONS_KEY=your-function-key-here

# Real-time configuration
NEXT_PUBLIC_REALTIME_ENABLED=true
NEXT_PUBLIC_DEFAULT_REFRESH_INTERVAL=30

# Cache configuration
NEXT_PUBLIC_CACHE_TTL=300
NEXT_PUBLIC_ENABLE_SERVICE_WORKER_CACHE=true

# Feature flags
NEXT_PUBLIC_ENABLE_TOPOLOGY_VIEW=false
NEXT_PUBLIC_ENABLE_ADVANCED_METRICS=true
NEXT_PUBLIC_ENABLE_COST_ANALYTICS=true
```

## Installation and Setup

### Package Dependencies
```json
{
  "dependencies": {
    "@radix-ui/react-badge": "^1.0.0",
    "@radix-ui/react-card": "^1.0.0",
    "@radix-ui/react-button": "^1.0.0",
    "@radix-ui/react-select": "^1.0.0",
    "lucide-react": "^0.300.0",
    "recharts": "^2.8.0",
    "date-fns": "^2.30.0",
    "lodash": "^4.17.21"
  },
  "devDependencies": {
    "@types/lodash": "^4.14.0"
  }
}
```

### Setup Instructions
```bash
# Install dependencies
npm install

# Add environment variables
cp .env.example .env.local
# Edit .env.local with your Azure Function URL

# Run development server
npm run dev

# Build for production
npm run build
```

This integration provides a comprehensive React-based dashboard for the Infrastructure Discovery Function, enabling real-time monitoring and management of stamp infrastructure through an intuitive web interface.
