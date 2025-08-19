using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading.Tasks;

namespace AzureArchitecture.Services
{
    /// <summary>
    /// Performance monitoring and metrics collection service
    /// </summary>
    public class PerformanceMonitoringService
    {
        private readonly ILogger<PerformanceMonitoringService> _logger;
        private readonly Dictionary<string, PerformanceMetrics> _metrics;
        private readonly object _lock = new object();

        public PerformanceMonitoringService(ILogger<PerformanceMonitoringService> logger)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _metrics = new Dictionary<string, PerformanceMetrics>();
        }

        /// <summary>
        /// Records the execution time and result of an operation
        /// </summary>
        public async Task<T> MeasureAsync<T>(string operationName, Func<Task<T>> operation)
        {
            var stopwatch = Stopwatch.StartNew();
            var startTime = DateTime.UtcNow;
            
            try
            {
                _logger.LogInformation("Starting operation: {OperationName}", operationName);
                
                var result = await operation();
                
                stopwatch.Stop();
                RecordSuccess(operationName, stopwatch.ElapsedMilliseconds, startTime);
                
                _logger.LogInformation("Completed operation: {OperationName} in {Duration}ms", 
                    operationName, stopwatch.ElapsedMilliseconds);
                
                return result;
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                RecordFailure(operationName, stopwatch.ElapsedMilliseconds, startTime, ex);
                
                _logger.LogError(ex, "Failed operation: {OperationName} after {Duration}ms", 
                    operationName, stopwatch.ElapsedMilliseconds);
                
                throw;
            }
        }

        /// <summary>
        /// Records the execution time and result of a synchronous operation
        /// </summary>
        public T Measure<T>(string operationName, Func<T> operation)
        {
            var stopwatch = Stopwatch.StartNew();
            var startTime = DateTime.UtcNow;
            
            try
            {
                _logger.LogInformation("Starting operation: {OperationName}", operationName);
                
                var result = operation();
                
                stopwatch.Stop();
                RecordSuccess(operationName, stopwatch.ElapsedMilliseconds, startTime);
                
                _logger.LogInformation("Completed operation: {OperationName} in {Duration}ms", 
                    operationName, stopwatch.ElapsedMilliseconds);
                
                return result;
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                RecordFailure(operationName, stopwatch.ElapsedMilliseconds, startTime, ex);
                
                _logger.LogError(ex, "Failed operation: {OperationName} after {Duration}ms", 
                    operationName, stopwatch.ElapsedMilliseconds);
                
                throw;
            }
        }

        /// <summary>
        /// Gets performance metrics for a specific operation
        /// </summary>
        public PerformanceMetrics GetMetrics(string operationName)
        {
            lock (_lock)
            {
                return _metrics.TryGetValue(operationName, out var metrics) 
                    ? metrics.Clone() 
                    : new PerformanceMetrics { OperationName = operationName };
            }
        }

        /// <summary>
        /// Gets all performance metrics
        /// </summary>
        public Dictionary<string, PerformanceMetrics> GetAllMetrics()
        {
            lock (_lock)
            {
                var result = new Dictionary<string, PerformanceMetrics>();
                foreach (var kvp in _metrics)
                {
                    result[kvp.Key] = kvp.Value.Clone();
                }
                return result;
            }
        }

        /// <summary>
        /// Resets metrics for a specific operation
        /// </summary>
        public void ResetMetrics(string? operationName = null)
        {
            lock (_lock)
            {
                if (operationName != null)
                {
                    _metrics.Remove(operationName);
                }
                else
                {
                    _metrics.Clear();
                }
            }
        }

        private void RecordSuccess(string operationName, long durationMs, DateTime startTime)
        {
            lock (_lock)
            {
                if (!_metrics.TryGetValue(operationName, out var metrics))
                {
                    metrics = new PerformanceMetrics { OperationName = operationName };
                    _metrics[operationName] = metrics;
                }

                metrics.TotalExecutions++;
                metrics.SuccessfulExecutions++;
                metrics.TotalDurationMs += durationMs;
                metrics.LastExecutionTime = startTime;
                metrics.LastDurationMs = durationMs;

                if (durationMs < metrics.MinDurationMs || metrics.MinDurationMs == 0)
                    metrics.MinDurationMs = durationMs;

                if (durationMs > metrics.MaxDurationMs)
                    metrics.MaxDurationMs = durationMs;

                metrics.AverageDurationMs = metrics.TotalDurationMs / metrics.TotalExecutions;
                metrics.SuccessRate = (double)metrics.SuccessfulExecutions / metrics.TotalExecutions;
            }
        }

        private void RecordFailure(string operationName, long durationMs, DateTime startTime, Exception exception)
        {
            lock (_lock)
            {
                if (!_metrics.TryGetValue(operationName, out var metrics))
                {
                    metrics = new PerformanceMetrics { OperationName = operationName };
                    _metrics[operationName] = metrics;
                }

                metrics.TotalExecutions++;
                metrics.FailedExecutions++;
                metrics.TotalDurationMs += durationMs;
                metrics.LastExecutionTime = startTime;
                metrics.LastDurationMs = durationMs;
                metrics.LastError = exception.Message;

                if (durationMs < metrics.MinDurationMs || metrics.MinDurationMs == 0)
                    metrics.MinDurationMs = durationMs;

                if (durationMs > metrics.MaxDurationMs)
                    metrics.MaxDurationMs = durationMs;

                metrics.AverageDurationMs = metrics.TotalDurationMs / metrics.TotalExecutions;
                metrics.SuccessRate = (double)metrics.SuccessfulExecutions / metrics.TotalExecutions;

                // Track error frequency
                if (!metrics.ErrorCounts.TryGetValue(exception.GetType().Name, out var count))
                {
                    count = 0;
                }
                metrics.ErrorCounts[exception.GetType().Name] = count + 1;
            }
        }
    }

    /// <summary>
    /// Performance metrics model
    /// </summary>
    public class PerformanceMetrics
    {
        public string OperationName { get; set; } = string.Empty;
        public long TotalExecutions { get; set; }
        public long SuccessfulExecutions { get; set; }
        public long FailedExecutions { get; set; }
        public double SuccessRate { get; set; }
        public long TotalDurationMs { get; set; }
        public long AverageDurationMs { get; set; }
        public long MinDurationMs { get; set; }
        public long MaxDurationMs { get; set; }
        public long LastDurationMs { get; set; }
        public DateTime LastExecutionTime { get; set; }
        public string LastError { get; set; } = string.Empty;
        public Dictionary<string, int> ErrorCounts { get; set; } = new Dictionary<string, int>();

        public PerformanceMetrics Clone()
        {
            return new PerformanceMetrics
            {
                OperationName = OperationName,
                TotalExecutions = TotalExecutions,
                SuccessfulExecutions = SuccessfulExecutions,
                FailedExecutions = FailedExecutions,
                SuccessRate = SuccessRate,
                TotalDurationMs = TotalDurationMs,
                AverageDurationMs = AverageDurationMs,
                MinDurationMs = MinDurationMs,
                MaxDurationMs = MaxDurationMs,
                LastDurationMs = LastDurationMs,
                LastExecutionTime = LastExecutionTime,
                LastError = LastError,
                ErrorCounts = new Dictionary<string, int>(ErrorCounts)
            };
        }
    }
}
