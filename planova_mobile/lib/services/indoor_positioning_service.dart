import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:planova_mobile/models/route_model.dart';
import 'package:planova_mobile/models/grid_model.dart';

class IndoorPositioningService {
  // Current state
  GridPoint? _currentPosition;
  double _currentHeading = 0; // 0-360 degrees, 0 = North
  int _initialStepCount = 0;
  int _currentStepCount = 0;

  // Configuration
  int cellSize = 20;
  double stepLength = 0.75; // meters per step
  GridModel? gridModel;

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription;

  // Movement tracking
  bool _isMoving = false;
  DateTime _lastStepTime = DateTime.now();

  // Callbacks
  final void Function(GridPoint position)? onPositionUpdate;
  final void Function(double heading)? onHeadingUpdate;
  final void Function(bool isMoving)? onMovementUpdate;

  IndoorPositioningService({
    this.onPositionUpdate,
    this.onHeadingUpdate,
    this.onMovementUpdate,
  });

  /// Initialize positioning system
  Future<void> initialize({
    required GridPoint startPosition,
    required GridModel grid,
    required int cellSize,
  }) async {
    print('🔵 [POSITIONING] Initializing...');

    _currentPosition = startPosition;
    this.cellSize = cellSize;
    this.gridModel = grid;
    _initialStepCount = 0;
    _currentStepCount = 0;

    print('✅ [POSITIONING] Start position: $startPosition');
    print('✅ [POSITIONING] Cell size: $cellSize px');
    print('✅ [POSITIONING] Grid: ${grid.width}x${grid.height}');

    // Start sensor listeners
    await _startSensors();
  }

  /// Start all sensor listeners
  Future<void> _startSensors() async {
    // 1. Start accelerometer for movement detection
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _detectMovement(event);
    });

    // 2. Start pedometer for step counting
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _onStepDetected(event.steps);
        },
        onError: (error) {
          print('⚠️ [POSITIONING] Pedometer error: $error');
        },
      );
      print('✅ [POSITIONING] Pedometer started');
    } catch (e) {
      print('❌ [POSITIONING] Pedometer unavailable: $e');
    }

    // 3. Start compass for direction
    try {
      _compassSubscription = FlutterCompass.events?.listen((
        CompassEvent event,
      ) {
        if (event.heading != null) {
          _currentHeading = event.heading!;
          onHeadingUpdate?.call(_currentHeading);
        }
      });
      print('✅ [POSITIONING] Compass started');
    } catch (e) {
      print('⚠️ [POSITIONING] Compass unavailable: $e');
    }
  }

  /// Detect movement from accelerometer
  void _detectMovement(AccelerometerEvent event) {
    // Calculate movement magnitude
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Threshold for movement detection
    final wasMoving = _isMoving;
    _isMoving = magnitude > 11.0;

    // Notify if movement state changed
    if (wasMoving != _isMoving) {
      onMovementUpdate?.call(_isMoving);

      if (_isMoving) {
        print('🚶 [POSITIONING] Movement detected');
      } else {
        print('🛑 [POSITIONING] Movement stopped');
      }
    }
  }

  /// Handle step detection
  void _onStepDetected(int totalSteps) {
    if (_currentPosition == null || gridModel == null) return;

    // Initialize step count on first detection
    if (_initialStepCount == 0) {
      _initialStepCount = totalSteps;
      _currentStepCount = totalSteps;
      print('🔵 [POSITIONING] Initial step count: $totalSteps');
      return;
    }

    // Calculate steps since last update
    final stepsSinceLastUpdate = totalSteps - _currentStepCount;
    if (stepsSinceLastUpdate <= 0) return;

    _currentStepCount = totalSteps;
    _lastStepTime = DateTime.now();

    print(
      '👣 [POSITIONING] Step detected (#${totalSteps - _initialStepCount})',
    );

    // Update position based on steps
    _updatePositionFromSteps(stepsSinceLastUpdate);
  }

  /// Update position based on step count and heading
  void _updatePositionFromSteps(int steps) {
    if (_currentPosition == null || gridModel == null) return;

    // Calculate distance moved (in meters)
    final distanceMeters = steps * stepLength;

    // Convert to grid cells
    // Assuming 1 pixel = 0.5 meters
    final pixelsMoved = distanceMeters / 0.5;
    final cellsMoved = pixelsMoved / cellSize;

    // Calculate direction components
    // Heading: 0° = North, 90° = East, 180° = South, 270° = West
    final headingRad = _currentHeading * (pi / 180);

    // Calculate grid deltas
    // North = negative row, South = positive row
    // East = positive col, West = negative col
    final deltaRow = -(cellsMoved * cos(headingRad));
    final deltaCol = (cellsMoved * sin(headingRad));

    // Calculate new position
    final newRow = (_currentPosition!.row + deltaRow.round()).clamp(
      0,
      gridModel!.height - 1,
    );
    final newCol = (_currentPosition!.col + deltaCol.round()).clamp(
      0,
      gridModel!.width - 1,
    );

    final newPosition = GridPoint(newRow, newCol);

    // Check if new position is valid (not a wall)
    if (gridModel!.grid[newRow][newCol] == 1) {
      print('🚧 [POSITIONING] Wall detected, position not updated');
      return;
    }

    print('📍 [POSITIONING] Position update:');
    print('   Old: $_currentPosition');
    print('   New: $newPosition');
    print('   Heading: ${_currentHeading.toStringAsFixed(0)}°');
    print('   Distance: ${distanceMeters.toStringAsFixed(2)}m');

    _currentPosition = newPosition;
    onPositionUpdate?.call(newPosition);
  }

  /// Manually set position (for recalibration)
  void setPosition(GridPoint position) {
    _currentPosition = position;
    onPositionUpdate?.call(position);
    print('📍 [POSITIONING] Position manually set to: $position');
  }

  /// Get current position
  GridPoint? get currentPosition => _currentPosition;

  /// Get current heading in degrees
  double get currentHeading => _currentHeading;

  /// Check if user is moving
  bool get isMoving => _isMoving;

  /// Get total steps taken
  int get totalSteps => _currentStepCount - _initialStepCount;

  /// Stop all sensors
  void dispose() {
    _accelerometerSubscription?.cancel();
    _stepSubscription?.cancel();
    _compassSubscription?.cancel();
    print('🔵 [POSITIONING] Service stopped');
  }
}
