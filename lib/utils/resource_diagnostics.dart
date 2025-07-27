import 'dart:developer' as developer;
import 'dart:async';

class ResourceDiagnostics {
  static final ResourceDiagnostics _instance = ResourceDiagnostics._internal();
  factory ResourceDiagnostics() => _instance;
  ResourceDiagnostics._internal();

  // Active resource tracking
  final Map<String, Timer> _activeTimers = {};
  final Map<String, int> _serviceInstanceCounts = {};
  final Map<String, StreamController> _activeStreamControllers = {};
  final List<String> _memoryPressureEvents = [];

  // Diagnostic counters
  int _totalTimersCreated = 0;
  int _totalTimersDisposed = 0;
  int _totalServicesCreated = 0;
  int _totalServicesDisposed = 0;
  int _totalStreamControllersCreated = 0;
  int _totalStreamControllersDisposed = 0;

  /// Register a timer when it starts
  void registerTimer(String serviceName, String timerName, Timer timer) {
    final key = '${serviceName}_$timerName';
    
    // Cancel existing timer if it exists (shouldn't happen but safety check)
    if (_activeTimers.containsKey(key)) {
      developer.log('⚠️ DIAGNOSTIC: Timer already exists for $key - cancelling old one', 
                   name: 'dyslexic_ai.resource_diagnostics');
      _activeTimers[key]?.cancel();
    }
    
    _activeTimers[key] = timer;
    _totalTimersCreated++;
    
    developer.log('⏰ DIAGNOSTIC: Timer registered - $key (Active: ${_activeTimers.length}, Total Created: $_totalTimersCreated)', 
                 name: 'dyslexic_ai.resource_diagnostics');
    
    _logResourceSummary();
  }

  /// Unregister a timer when it stops
  void unregisterTimer(String serviceName, String timerName) {
    final key = '${serviceName}_$timerName';
    
    if (_activeTimers.containsKey(key)) {
      _activeTimers.remove(key);
      _totalTimersDisposed++;
      
      developer.log('⏰ DIAGNOSTIC: Timer unregistered - $key (Active: ${_activeTimers.length}, Total Disposed: $_totalTimersDisposed)', 
                   name: 'dyslexic_ai.resource_diagnostics');
    } else {
      developer.log('⚠️ DIAGNOSTIC: Attempted to unregister non-existent timer - $key', 
                   name: 'dyslexic_ai.resource_diagnostics');
    }
    
    _logResourceSummary();
  }

  /// Register a service instance when created
  void registerServiceInstance(String serviceName) {
    _serviceInstanceCounts[serviceName] = (_serviceInstanceCounts[serviceName] ?? 0) + 1;
    _totalServicesCreated++;
    
    developer.log('🏭 DIAGNOSTIC: Service instance created - $serviceName (Count: ${_serviceInstanceCounts[serviceName]}, Total Created: $_totalServicesCreated)', 
                 name: 'dyslexic_ai.resource_diagnostics');
    
    _logResourceSummary();
  }

  /// Unregister a service instance when disposed
  void unregisterServiceInstance(String serviceName) {
    if (_serviceInstanceCounts.containsKey(serviceName) && _serviceInstanceCounts[serviceName]! > 0) {
      _serviceInstanceCounts[serviceName] = _serviceInstanceCounts[serviceName]! - 1;
      _totalServicesDisposed++;
      
      developer.log('🏭 DIAGNOSTIC: Service instance disposed - $serviceName (Count: ${_serviceInstanceCounts[serviceName]}, Total Disposed: $_totalServicesDisposed)', 
                   name: 'dyslexic_ai.resource_diagnostics');
      
      if (_serviceInstanceCounts[serviceName] == 0) {
        _serviceInstanceCounts.remove(serviceName);
      }
    } else {
      developer.log('⚠️ DIAGNOSTIC: Attempted to dispose non-existent service instance - $serviceName', 
                   name: 'dyslexic_ai.resource_diagnostics');
    }
    
    _logResourceSummary();
  }

  /// Register a StreamController when created
  void registerStreamController(String serviceName, String controllerName, StreamController controller) {
    final key = '${serviceName}_$controllerName';
    _activeStreamControllers[key] = controller;
    _totalStreamControllersCreated++;
    
    developer.log('📡 DIAGNOSTIC: StreamController registered - $key (Active: ${_activeStreamControllers.length}, Total Created: $_totalStreamControllersCreated)', 
                 name: 'dyslexic_ai.resource_diagnostics');
  }

  /// Unregister a StreamController when disposed
  void unregisterStreamController(String serviceName, String controllerName) {
    final key = '${serviceName}_$controllerName';
    
    if (_activeStreamControllers.containsKey(key)) {
      _activeStreamControllers.remove(key);
      _totalStreamControllersDisposed++;
      
      developer.log('📡 DIAGNOSTIC: StreamController unregistered - $key (Active: ${_activeStreamControllers.length}, Total Disposed: $_totalStreamControllersDisposed)', 
                   name: 'dyslexic_ai.resource_diagnostics');
    } else {
      developer.log('⚠️ DIAGNOSTIC: Attempted to unregister non-existent StreamController - $key', 
                   name: 'dyslexic_ai.resource_diagnostics');
    }
  }

  /// Log memory pressure event
  void logMemoryPressureEvent(String event, String context) {
    final timestamp = DateTime.now().toIso8601String();
    final eventString = '$timestamp: $event ($context)';
    _memoryPressureEvents.add(eventString);
    
    // Keep only last 20 events
    if (_memoryPressureEvents.length > 20) {
      _memoryPressureEvents.removeAt(0);
    }
    
    developer.log('💾 DIAGNOSTIC: Memory pressure event - $event in $context', 
                 name: 'dyslexic_ai.resource_diagnostics');
    
    _logResourceSummary();
  }

  /// Log current resource summary
  void _logResourceSummary() {
    developer.log('''
🔍 RESOURCE SUMMARY:
┌─ Timers: ${_activeTimers.length} active (Created: $_totalTimersCreated, Disposed: $_totalTimersDisposed)
├─ Services: ${_serviceInstanceCounts.values.fold(0, (a, b) => a + b)} active (Created: $_totalServicesCreated, Disposed: $_totalServicesDisposed)  
├─ StreamControllers: ${_activeStreamControllers.length} active (Created: $_totalStreamControllersCreated, Disposed: $_totalStreamControllersDisposed)
└─ Memory Events: ${_memoryPressureEvents.length} logged
''', name: 'dyslexic_ai.resource_diagnostics');
  }

  /// Get detailed resource report
  String getDetailedReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== DETAILED RESOURCE REPORT ===');
    buffer.writeln('');
    
    buffer.writeln('ACTIVE TIMERS (${_activeTimers.length}):');
    if (_activeTimers.isEmpty) {
      buffer.writeln('  (none)');
    } else {
      _activeTimers.keys.forEach((key) {
        buffer.writeln('  - $key');
      });
    }
    buffer.writeln('');
    
    buffer.writeln('SERVICE INSTANCES:');
    if (_serviceInstanceCounts.isEmpty) {
      buffer.writeln('  (none)');
    } else {
      _serviceInstanceCounts.forEach((service, count) {
        buffer.writeln('  - $service: $count instances');
      });
    }
    buffer.writeln('');
    
    buffer.writeln('ACTIVE STREAM CONTROLLERS (${_activeStreamControllers.length}):');
    if (_activeStreamControllers.isEmpty) {
      buffer.writeln('  (none)');
    } else {
      _activeStreamControllers.keys.forEach((key) {
        buffer.writeln('  - $key');
      });
    }
    buffer.writeln('');
    
    buffer.writeln('RECENT MEMORY PRESSURE EVENTS:');
    if (_memoryPressureEvents.isEmpty) {
      buffer.writeln('  (none)');
    } else {
      _memoryPressureEvents.forEach((event) {
        buffer.writeln('  - $event');
      });
    }
    buffer.writeln('');
    
    buffer.writeln('TOTALS:');
    buffer.writeln('  - Timers: Created $_totalTimersCreated, Disposed $_totalTimersDisposed, Leaked ${_totalTimersCreated - _totalTimersDisposed}');
    buffer.writeln('  - Services: Created $_totalServicesCreated, Disposed $_totalServicesDisposed, Leaked ${_totalServicesCreated - _totalServicesDisposed}');
    buffer.writeln('  - StreamControllers: Created $_totalStreamControllersCreated, Disposed $_totalStreamControllersDisposed, Leaked ${_totalStreamControllersCreated - _totalStreamControllersDisposed}');
    
    return buffer.toString();
  }

  /// Log detailed report to console
  void logDetailedReport() {
    developer.log(getDetailedReport(), name: 'dyslexic_ai.resource_diagnostics');
  }

  /// Check for potential resource leaks
  void checkForLeaks() {
    final timerLeaks = _totalTimersCreated - _totalTimersDisposed;
    final serviceLeaks = _totalServicesCreated - _totalServicesDisposed;
    final streamLeaks = _totalStreamControllersCreated - _totalStreamControllersDisposed;
    
    if (timerLeaks > 0 || serviceLeaks > 0 || streamLeaks > 0) {
      developer.log('🚨 POTENTIAL RESOURCE LEAKS DETECTED:', name: 'dyslexic_ai.resource_diagnostics');
      if (timerLeaks > 0) {
        developer.log('  - Timer leaks: $timerLeaks (${_activeTimers.keys.join(", ")})', name: 'dyslexic_ai.resource_diagnostics');
      }
      if (serviceLeaks > 0) {
        developer.log('  - Service leaks: $serviceLeaks', name: 'dyslexic_ai.resource_diagnostics');
      }
      if (streamLeaks > 0) {
        developer.log('  - StreamController leaks: $streamLeaks (${_activeStreamControllers.keys.join(", ")})', name: 'dyslexic_ai.resource_diagnostics');
      }
    } else {
      developer.log('✅ No resource leaks detected', name: 'dyslexic_ai.resource_diagnostics');
    }
  }

  /// Reset all diagnostics (for testing)
  void reset() {
    _activeTimers.clear();
    _serviceInstanceCounts.clear();
    _activeStreamControllers.clear();
    _memoryPressureEvents.clear();
    _totalTimersCreated = 0;
    _totalTimersDisposed = 0;
    _totalServicesCreated = 0;
    _totalServicesDisposed = 0;
    _totalStreamControllersCreated = 0;
    _totalStreamControllersDisposed = 0;
    
    developer.log('🔄 Resource diagnostics reset', name: 'dyslexic_ai.resource_diagnostics');
  }
} 