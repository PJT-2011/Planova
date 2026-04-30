# Planova Architecture Documentation

## Overview
Indoor navigation app using image-based pathfinding.

## Tech Stack
- **Frontend:** Flutter 3.x
- **Language:** Dart
- **Storage:** Mock local storage (production: Firebase)
- **Sensors:** Accelerometer, Compass
- **Platform:** Android (iOS ready)

## Project Structure

lib/
├── main.dart                      # App entry point
├── models/
│   ├── floorplan_model.dart      # Floorplan data structure
│   ├── grid_model.dart           # Navigation grid
│   └── route_model.dart          # Calculated route
├── screens/
│   ├── home_screen.dart          # Floorplan list
│   ├── upload_screen.dart        # Upload flow
│   └── navigation_screen.dart    # Main navigation UI
└── services/
├── grid_processor.dart        # Image → Grid conversion
├── pathfinding_service.dart   # A* pathfinding
├── indoor_positioning.dart    # Sensor fusion
└── floorplan_service.dart     # Data management

## Data Flow

1. **Upload:**
   User → Image → MockStorage → Firestore

2. **Processing:**
   Image → GridProcessor → Navigation Grid (2D array)

3. **Pathfinding:**
   Start/End Points → A* Algorithm → Route Path

4. **Navigation:**
   Sensors → Position Updates → UI Rendering

## Key Algorithms

### Grid Processing
- Converts image to 2D grid (0=walkable, 1=wall)
- Threshold-based wall detection
- Cell size: 15 pixels

### Pathfinding (A*)
- Heuristic: Euclidean distance
- Movement: 8-directional
- Cost: 1.0 (cardinal), 1.414 (diagonal)

### Indoor Positioning
- Step detection: Accelerometer magnitude > 13.5
- Movement: 8 steps = 1 grid cell
- Heading: Compass (0-360°)

## Performance

### Grid Processing
- Time: 0.5-2 seconds
- Grid size: ~90x60 cells
- Memory: ~5 MB per floorplan

### Pathfinding
- Time: <100ms for typical routes
- Algorithm: A* with priority queue
- Optimized: Path smoothing applied

### Navigation
- Update rate: Per step detected (~2 Hz)
- Battery impact: Low (sensor polling only)
- Accuracy: ±2 cells (±0.3m)

## Known Limitations
- Single floor only
- Requires uploaded floorplan
- GPS not used (indoor only)
- No real-time position correction
