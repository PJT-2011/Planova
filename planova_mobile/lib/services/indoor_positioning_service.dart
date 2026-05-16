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

  bool _stepPeakDetected = false;
  DateTime _lastStepTime = DateTime.now();

  // Smooth heading via low-pass filter (α = 0.15 → smooth, low lag)
  double _smoothedHeading = 0.0;
  static const double _alpha = 0.15;

  // Separate stream for heading so the map can consume it independently
  final StreamController<double> _headingController =
      StreamController<double>.broadcast();
  final StreamController<GridPoint> _positionController =
      StreamController<GridPoint>.broadcast();

  Stream<double> get headingStream => _headingController.stream;
  Stream<GridPoint> get positionStream => _positionController.stream;

  /// Starts navigation and returns the position stream.
  Stream<GridPoint> startNavigation(RouteModel route) {
    print('🔵 [POS] Starting navigation — ${route.path.length} waypoints');

    _currentRouteIndex = 0;
    _routePath = route.path;
    _stepCount = 0;

    // Seed heading from first route segment so the map tilts immediately
    if (route.path.length >= 2) {
      _smoothedHeading = _bearingBetween(route.path[0], route.path[1]);
      _headingController.add(_smoothedHeading);
    }

    _startSensors();
    return _positionController.stream;
  }

  void _startSensors() {
    _accelSubscription = accelerometerEvents.listen(_detectSteps);

    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading == null) return;
      _smoothedHeading = _lerpAngle(_smoothedHeading, event.heading!, _alpha);
      _headingController.add(_smoothedHeading);
    });

    print('✅ [POS] Sensors started');
  }

  void _detectSteps(AccelerometerEvent event) {
    final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final now = DateTime.now();
    final msSinceLastStep = now.difference(_lastStepTime).inMilliseconds;

    if (mag > 13.5 && !_stepPeakDetected) {
      _stepPeakDetected = true;
    } else if (mag < 13.5 && _stepPeakDetected && msSinceLastStep > 400) {
      _stepPeakDetected = false;
      _lastStepTime = now;
      _stepCount++;
      print('👣 [POS] Step #$_stepCount (mag: ${mag.toStringAsFixed(2)})');
      _advanceAlongRoute();
    }
  }

  void _advanceAlongRoute() {
    if (_routePath == null || _routePath!.isEmpty) return;

    // Advance one waypoint every 8 steps
    if (_stepCount % 8 == 0 && _currentRouteIndex < _routePath!.length - 1) {
      _currentRouteIndex++;
      final newPos = _routePath![_currentRouteIndex];

      // Update route-derived heading as fallback when compass is unreliable
      if (_currentRouteIndex < _routePath!.length - 1) {
        final routeHeading = _bearingBetween(
          newPos,
          _routePath![_currentRouteIndex + 1],
        );
        // Blend into smoothed heading only if compass isn't dominant
        _smoothedHeading = _lerpAngle(_smoothedHeading, routeHeading, 0.25);
        _headingController.add(_smoothedHeading);
      }

      final pct = ((_currentRouteIndex / _routePath!.length) * 100)
          .toStringAsFixed(0);
      print(
        '📍 [POS] Waypoint $_currentRouteIndex/${_routePath!.length} ($pct%) '
        '— heading ${_smoothedHeading.toStringAsFixed(1)}°',
      );

      _positionController.add(newPos);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Compass-style bearing (0 = up/north, 90 = right) between two grid points.
  double _bearingBetween(GridPoint from, GridPoint to) {
    final dx = (to.col - from.col).toDouble();
    final dy = (to.row - from.row).toDouble(); // row↓ = south
    final deg = atan2(dx, -dy) * 180 / pi;
    return (deg + 360) % 360;
  }

  /// Shortest-path angle lerp (handles 359 → 1 wrap-around).
  double _lerpAngle(double from, double to, double t) {
    final diff = ((to - from) + 540) % 360 - 180;
    return (from + diff * t + 360) % 360;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void stopNavigation() {
    _accelSubscription?.cancel();
    _compassSubscription?.cancel();
    _accelSubscription = null;
    _compassSubscription = null;
    print('🔵 [POS] Navigation stopped');
  }

  void dispose() {
    stopNavigation();
    _positionController.close();
    _headingController.close();
    print('🔵 [POS] Disposed');
  }
}
