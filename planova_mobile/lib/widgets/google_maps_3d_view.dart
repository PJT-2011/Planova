import 'dart:math';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/models/route_model.dart';

/// Indoor navigation map view.
/// - Pan, pinch-zoom, two-finger rotate: always available.
/// - When [autoFollow] is true the map rotates to keep [heading] pointing UP,
///   then re-centres on [currentPosition].
/// - When [topDownMode] is true the floorplan stays fixed (north-up) and only
///   the blue arrow rotates to match the live heading.
/// - User can pan freely; auto-follow re-centres after 3 s of no interaction.
class GoogleMaps3DView extends StatefulWidget {
  final GridModel gridModel;
  final RouteModel? route;
  final GridPoint? currentPosition;
  final GridPoint? startPoint;
  final GridPoint? endPoint;
  final double Function(int col) getScreenX;
  final double Function(int row) getScreenY;
  final bool autoFollow;

  /// Compass/route heading in degrees (0 = up on floorplan).
  final double heading;

  /// When true the map does NOT rotate — only the arrow rotates.
  final bool topDownMode;

  /// The floorplan image widget (passed in so this widget stays image-agnostic).
  final Widget mapChild;

  final VoidCallback? onUserPanned;
  final void Function(VoidCallback)? onRecenterReady;

  const GoogleMaps3DView({
    Key? key,
    required this.gridModel,
    this.route,
    this.currentPosition,
    this.startPoint,
    this.endPoint,
    required this.getScreenX,
    required this.getScreenY,
    this.autoFollow = false,
    this.heading = 0.0,
    this.topDownMode = false,
    required this.mapChild,
    this.onUserPanned,
    this.onRecenterReady,
  }) : super(key: key);

  @override
  State<GoogleMaps3DView> createState() => _GoogleMaps3DViewState();
}

class _GoogleMaps3DViewState extends State<GoogleMaps3DView>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _cameraController;

  // Live camera values
  double _zoom = 1.0;
  double _rotation = 0.0; // degrees — map rotation
  Offset _pan = Offset.zero;
  bool _userInteracting = false;

  // Gesture snapshots
  double _gsZoom = 1.0;
  double _gsRotation = 0.0;
  Offset _gsFocal = Offset.zero;
  Offset _gsPan = Offset.zero;

  // Animation from/to
  double _fromRot = 0, _rotDelta = 0;
  double _fromZoom = 1, _toZoom = 1;

  // Re-follow timer after user pans
  DateTime? _lastInteraction;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _cameraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(_onCamTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onRecenterReady?.call(recenter);
    });
  }

  void _onCamTick() {
    if (!mounted) return;
    final t = CurvedAnimation(
      parent: _cameraController,
      curve: Curves.easeOutCubic,
    ).value;
    setState(() {
      _zoom = _fromZoom + (_toZoom - _fromZoom) * t;
      _rotation = (_fromRot + _rotDelta * t + 360) % 360;
    });
  }

  void _animateTo({
    required double rotation,
    required double zoom,
    Duration duration = const Duration(milliseconds: 450),
  }) {
    _fromZoom = _zoom;
    _fromRot = _rotation;
    _toZoom = zoom;
    _rotDelta = ((rotation - _rotation) + 540) % 360 - 180;
    _cameraController.duration = duration;
    _cameraController.forward(from: 0);
  }

  @override
  void didUpdateWidget(GoogleMaps3DView old) {
    super.didUpdateWidget(old);

    // ── Handle topDownMode toggle ─────────────────────────────────────────
    if (widget.topDownMode && !old.topDownMode) {
      // Switching TO top-down: snap map back to north-up (rotation = 0)
      _animateTo(rotation: 0.0, zoom: _zoom);
      return;
    }
    if (!widget.topDownMode && old.topDownMode) {
      // Switching FROM top-down: re-engage heading-follow immediately
      if (widget.autoFollow) {
        _animateTo(rotation: widget.heading, zoom: _zoom);
      }
      return;
    }

    // ── Normal heading-follow (only when NOT in top-down mode) ───────────
    if (!widget.topDownMode) {
      if (widget.autoFollow && !old.autoFollow) {
        _animateTo(rotation: widget.heading, zoom: 1.8);
      } else if (!widget.autoFollow && old.autoFollow) {
        _animateTo(rotation: 0.0, zoom: 1.0);
      } else if (widget.autoFollow && !_userInteracting) {
        final headingChanged = (widget.heading - old.heading).abs() > 1.0;
        final posChanged = widget.currentPosition != old.currentPosition;
        if (headingChanged || posChanged) {
          _animateTo(
            rotation: widget.heading,
            zoom: _zoom,
            duration: const Duration(milliseconds: 300),
          );
        }
      }
    }
  }

  void recenter() {
    setState(() {
      _pan = Offset.zero;
      _userInteracting = false;
    });
    if (widget.autoFollow && !widget.topDownMode) {
      _animateTo(rotation: widget.heading, zoom: _zoom);
    }
  }

  // ── Gestures ──────────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _gsZoom = _zoom;
    _gsRotation = _rotation;
    _gsFocal = d.focalPoint;
    _gsPan = _pan;
    _userInteracting = true;
    _cameraController.stop();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      final delta = d.focalPoint - _gsFocal;
      _pan = _gsPan + delta;

      if (d.pointerCount >= 2) {
        _zoom = (_gsZoom * d.scale).clamp(0.4, 8.0);
        // Two-finger rotate is always allowed; in top-down it just manually
        // rotates the map (user override).
        _rotation = (_gsRotation + d.rotation * 180 / pi) % 360;
      }

      if (delta.distance > 8 && widget.autoFollow) {
        widget.onUserPanned?.call();
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _lastInteraction = DateTime.now();
    // Re-engage auto-follow after 3 seconds of inactivity (only in follow mode)
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_lastInteraction!);
      if (elapsed.inSeconds >= 3 && widget.autoFollow && !widget.topDownMode) {
        setState(() => _userInteracting = false);
        _animateTo(rotation: widget.heading, zoom: _zoom);
      }
    });
  }

  // ── Camera matrix ─────────────────────────────────────────────────────────

  Matrix4 _buildMatrix(Size size) {
    final Offset focus;
    if (widget.autoFollow && widget.currentPosition != null) {
      focus = Offset(
        widget.getScreenX(widget.currentPosition!.col),
        widget.getScreenY(widget.currentPosition!.row),
      );
    } else {
      focus = Offset(
        widget.getScreenX(widget.gridModel.width ~/ 2),
        widget.getScreenY(widget.gridModel.height ~/ 2),
      );
    }

    final pivotY = widget.autoFollow
        ? size.height * 0.62 + _pan.dy
        : size.height / 2 + _pan.dy;

    final cx = size.width / 2 + _pan.dx;
    final cy = pivotY;

    // In top-down mode the map matrix uses rotation = 0 (north-up).
    // The effective map rotation is still stored in _rotation so the user can
    // manually rotate with two fingers, but auto-heading does not touch it.
    final mapRotation = widget.topDownMode ? 0.0 : _rotation;

    final m = Matrix4.identity()
      ..translate(cx, cy)
      ..rotateZ(mapRotation * pi / 180)
      ..scale(_zoom)
      ..translate(-focus.dx, -focus.dy);

    return m;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: ClipRect(
            child: Transform(
              transform: _buildMatrix(size),
              child: Stack(
                children: [
                  // ① Floorplan image
                  widget.mapChild,

                  // ② Route + markers + user arrow
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => CustomPaint(
                      painter: _OverlayPainter(
                        route: widget.route,
                        currentPosition: widget.currentPosition,
                        startPoint: widget.startPoint,
                        endPoint: widget.endPoint,
                        getScreenX: widget.getScreenX,
                        getScreenY: widget.getScreenY,
                        pulseValue: _pulseController.value,
                        heading: widget.heading,
                        // When in top-down mode the map isn't rotated, so the
                        // arrow must use the full raw heading.
                        // When the map IS rotated, the arrow lives inside the
                        // rotated canvas, so its own angle is just heading - mapRot
                        // which equals 0 (the arrow naturally points "up" in the
                        // rotated frame). We still pass the raw heading and let
                        // the painter handle it — the painter is inside the
                        // transformed canvas, so in follow mode the map already
                        // compensates by rotating everything.  We pass
                        // mapRotation so the painter can subtract it in top-down.
                        mapRotation: widget.topDownMode ? 0.0 : _rotation,
                        topDownMode: widget.topDownMode,
                      ),
                      size: size,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overlay painter — route, pins, user arrow
// ─────────────────────────────────────────────────────────────────────────────

class _OverlayPainter extends CustomPainter {
  final RouteModel? route;
  final GridPoint? currentPosition;
  final GridPoint? startPoint;
  final GridPoint? endPoint;
  final double Function(int) getScreenX;
  final double Function(int) getScreenY;
  final double pulseValue;
  final double heading; // live gyro/compass heading in degrees (0 = up)
  final double mapRotation; // current map rotation in degrees
  final bool topDownMode;

  const _OverlayPainter({
    this.route,
    this.currentPosition,
    this.startPoint,
    this.endPoint,
    required this.getScreenX,
    required this.getScreenY,
    required this.pulseValue,
    this.heading = 0.0,
    this.mapRotation = 0.0,
    this.topDownMode = false,
  });

  Offset _pt(int col, int row) => Offset(getScreenX(col), getScreenY(row));

  @override
  void paint(Canvas canvas, Size size) {
    if (route != null) _drawRoute(canvas);
    if (startPoint != null) _drawPin(canvas, startPoint!, Colors.green);
    if (endPoint != null) _drawPin(canvas, endPoint!, const Color(0xFFE53935));
    if (currentPosition != null) _drawUserArrow(canvas, currentPosition!);
  }

  // ── Route ──────────────────────────────────────────────────────────────────

  Path _buildRoutePath() {
    final p = Path();
    for (int i = 0; i < route!.path.length; i++) {
      final sp = _pt(route!.path[i].col, route!.path[i].row);
      i == 0 ? p.moveTo(sp.dx, sp.dy) : p.lineTo(sp.dx, sp.dy);
    }
    return p;
  }

  void _drawRoute(Canvas canvas) {
    if (route!.path.length < 2) return;

    final rp = _buildRoutePath();

    // Soft glow
    canvas.drawPath(
      rp,
      Paint()
        ..color = const Color(0xFF1A73E8).withOpacity(0.18)
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // White border
    canvas.drawPath(
      rp,
      Paint()
        ..color = Colors.white.withOpacity(0.70)
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Google-blue line
    canvas.drawPath(
      rp,
      Paint()
        ..color = const Color(0xFF1A73E8)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Travelled portion
    if (currentPosition != null) {
      final idx = route!.path.indexWhere(
        (pt) =>
            pt.row == currentPosition!.row && pt.col == currentPosition!.col,
      );
      if (idx > 0) {
        final tp = Path();
        for (int i = 0; i <= idx; i++) {
          final sp = _pt(route!.path[i].col, route!.path[i].row);
          i == 0 ? tp.moveTo(sp.dx, sp.dy) : tp.lineTo(sp.dx, sp.dy);
        }
        canvas.drawPath(
          tp,
          Paint()
            ..color = Colors.grey.withOpacity(0.55)
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      }
    }

    _drawChevrons(canvas);
  }

  void _drawChevrons(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const step = 10;
    for (int i = step; i < route!.path.length - 1; i += step) {
      final sp = _pt(route!.path[i].col, route!.path[i].row);
      final np = _pt(route!.path[i + 1].col, route!.path[i + 1].row);
      final a = atan2(np.dy - sp.dy, np.dx - sp.dx);
      const L = 5.5;
      final tip = Offset(sp.dx + L * 1.6 * cos(a), sp.dy + L * 1.6 * sin(a));
      canvas.drawLine(
        Offset(sp.dx + L * cos(a + 2.4), sp.dy + L * sin(a + 2.4)),
        tip,
        paint,
      );
      canvas.drawLine(
        Offset(sp.dx + L * cos(a - 2.4), sp.dy + L * sin(a - 2.4)),
        tip,
        paint,
      );
    }
  }

  // ── Pin ────────────────────────────────────────────────────────────────────

  void _drawPin(Canvas canvas, GridPoint point, Color color) {
    final sp = _pt(point.col, point.row);
    canvas.drawCircle(
      sp + const Offset(2, 3),
      13,
      Paint()..color = Colors.black.withOpacity(0.20),
    );
    canvas.drawCircle(sp, 13, Paint()..color = color);
    canvas.drawCircle(
      sp,
      13,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      sp + const Offset(-3, -3),
      4,
      Paint()..color = Colors.white.withOpacity(0.40),
    );
  }

  // ── User arrow ─────────────────────────────────────────────────────────────

  void _drawUserArrow(Canvas canvas, GridPoint point) {
    final sp = _pt(point.col, point.row);
    final pulse = (sin(pulseValue * 2 * pi) + 1) / 2;

    // Pulse ring
    canvas.drawCircle(
      sp,
      24 + pulse * 10,
      Paint()
        ..color = const Color(0xFF4285F4).withOpacity(0.12 * (1 - pulse))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // In follow mode the whole canvas is already rotated by _rotation (= heading),
    // so the arrow just needs its base offset (pi/2).
    //
    // In top-down mode the canvas is NOT rotated, so the arrow must rotate by
    // the full heading.  We compute the effective arrow angle accordingly:
    //
    //   follow mode  → arrowAngle = heading - heading = 0  (canvas already turned)
    //   top-down     → arrowAngle = heading              (canvas is north-up)
    //
    // Compass-to-canvas conversion:  canvasAngle = degrees * pi/180 - pi/2
    final double effectiveDeg = topDownMode
        ? heading // full heading; canvas is north-up
        : 0.0; // canvas already rotated; arrow stays "up"

    final angle = effectiveDeg * pi / 180 - pi / 2;

    // White halo
    canvas.drawCircle(
      sp,
      16,
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.save();
    canvas.translate(sp.dx, sp.dy);
    canvas.rotate(angle + pi / 2);

    const sz = 18.0;
    final tri = Path()
      ..moveTo(0, -sz)
      ..lineTo(sz * 0.60, sz * 0.50)
      ..lineTo(0, sz * 0.18)
      ..lineTo(-sz * 0.60, sz * 0.50)
      ..close();

    canvas.drawPath(
      tri,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawPath(
      tri,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.fill,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => true;
}
