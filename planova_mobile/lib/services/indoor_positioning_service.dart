import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/models/grid_model.dart';

class IndoorPositioningService {
  int _currentRouteIndex = 0;
  List<GridPoint>? _routePath;
  double _currentHeading = 0;
  int _stepCount = 0;

  double _lastMagnitude = 0;
  bool _stepPeakDetected = false;
  DateTime _lastStepTime = DateTime.now();

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  bool _isMoving = false;

  final void Function(GridPoint position)? onPositionUpdate;
  final void Function(double heading)? onHeadingUpdate;
  final void Function(bool isMoving)? onMovementUpdate;

  IndoorPositioningService({
    this.onPositionUpdate,
    this.onHeadingUpdate,
    this.onMovementUpdate,
  });

  Future<void> initialize({
    required GridPoint startPosition,
    required GridModel grid,
    required int cellSize,
    List<GridPoint>? routePath,
  }) async {
    print('🔵 [POS] Initializing...');
    print('   Start: $startPosition');
    print('   Route points: ${routePath?.length ?? 0}');

    _currentRouteIndex = 0;
    _routePath = routePath;
    _stepCount = 0;

    _startSensors();
  }

  void _startSensors() {
    _accelSubscription = accelerometerEvents.listen((event) {
      _detectSteps(event);
      _detectMovement(event);
    });

    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        _currentHeading = event.heading!;
        onHeadingUpdate?.call(_currentHeading);
      }
    });

    print('✅ [POS] Sensors started');
  }

  void _detectSteps(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final now = DateTime.now();
    final timeSinceLastStep = now.difference(_lastStepTime).inMilliseconds;

    // CRITICAL: Very sensitive step detection
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

  void _detectMovement(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final wasMoving = _isMoving;
    _isMoving = magnitude > 11.0;

    if (wasMoving != _isMoving) {
      onMovementUpdate?.call(_isMoving);
    }
  }

  void _advanceAlongRoute() {
    if (_routePath == null || _routePath!.isEmpty) {
      print('⚠️ [POS] No route path');
      return;
    }

    // CRITICAL: Move VERY SLOWLY - 8 steps per cell
    if (_stepCount % 8 == 0 && _currentRouteIndex < _routePath!.length - 1) {
      _currentRouteIndex++;
      final newPosition = _routePath![_currentRouteIndex];

      final progress = ((_currentRouteIndex / _routePath!.length) * 100)
          .toStringAsFixed(0);
      print(
        '📍 [POS] Moving to point $_currentRouteIndex/${_routePath!.length} ($progress%) - $newPosition',
      );

      onPositionUpdate?.call(newPosition);
    }
  }

  GridPoint? get currentPosition =>
      _routePath != null && _currentRouteIndex < _routePath!.length
      ? _routePath![_currentRouteIndex]
      : null;

  double get currentHeading => _currentHeading;
  bool get isMoving => _isMoving;
  int get totalSteps => _stepCount;

  void dispose() {
    _accelSubscription?.cancel();
    _compassSubscription?.cancel();
    print('🔵 [POS] Disposed');
  }
}
