import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/models/grid_model.dart';

class IndoorPositioningService {
  int _currentRouteIndex = 0;
  List<GridPoint>? _routePath;
  int _stepCount = 0;

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  double _lastMagnitude = 0;
  bool _stepPeakDetected = false;
  DateTime _lastStepTime = DateTime.now();

  // ✅ NEW: Stream controller for position updates
  final StreamController<GridPoint> _positionController =
      StreamController<GridPoint>.broadcast();

  Stream<GridPoint> startNavigation(RouteModel route) {
    print('🔵 [POS] Starting navigation...');
    print('   Route points: ${route.path.length}');

    _currentRouteIndex = 0;
    _routePath = route.path;
    _stepCount = 0;

    _startSensors();

    return _positionController.stream;
  }

  void _startSensors() {
    _accelSubscription = accelerometerEvents.listen((event) {
      _detectSteps(event);
    });

    _compassSubscription = FlutterCompass.events?.listen((event) {
      // Compass data if needed
    });

    print('✅ [POS] Sensors started');
  }

  void _detectSteps(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final now = DateTime.now();
    final timeSinceLastStep = now.difference(_lastStepTime).inMilliseconds;

    // Step detection
    if (magnitude > 13.5 && !_stepPeakDetected) {
      _stepPeakDetected = true;
    } else if (magnitude < 13.5 &&
        _stepPeakDetected &&
        timeSinceLastStep > 400) {
      _stepPeakDetected = false;
      _lastStepTime = now;
      _stepCount++;

      print(
        '👣 [POS] Step #$_stepCount (mag: ${magnitude.toStringAsFixed(2)})',
      );
      _advanceAlongRoute();
    }
  }

  void _advanceAlongRoute() {
    if (_routePath == null || _routePath!.isEmpty) {
      print('⚠️ [POS] No route path');
      return;
    }

    // Move every 8 steps
    if (_stepCount % 8 == 0 && _currentRouteIndex < _routePath!.length - 1) {
      _currentRouteIndex++;
      final newPosition = _routePath![_currentRouteIndex];

      final progress = ((_currentRouteIndex / _routePath!.length) * 100)
          .toStringAsFixed(0);
      print(
        '📍 [POS] Moving to point $_currentRouteIndex/${_routePath!.length} ($progress%) - $newPosition',
      );

      // Emit position update
      _positionController.add(newPosition);
    }
  }

  void stopNavigation() {
    _accelSubscription?.cancel();
    _compassSubscription?.cancel();
    print('🔵 [POS] Navigation stopped');
  }

  void dispose() {
    stopNavigation();
    _positionController.close();
    print('🔵 [POS] Disposed');
  }
}
