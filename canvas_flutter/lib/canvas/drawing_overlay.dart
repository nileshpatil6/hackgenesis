import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'shape_recognition.dart';

/// How long the snapped shape is shown before the label prompt opens.
///
/// Long enough to see that the stroke was understood, short enough that it
/// never feels like waiting.
const Duration kSnapPreviewDuration = Duration(milliseconds: 420);

/// Ignore pointer samples closer together than this, in logical pixels.
///
/// A finger dragged slowly emits hundreds of near-identical points. Keeping
/// them all costs memory and makes the simplifier recurse far deeper than the
/// shape warrants, without changing the result.
const double kMinPointSpacing = 2.5;

/// Full-bleed drawing surface placed above the canvas.
///
/// Mounted only while a tool is active. It sits on top of [CanvasView] as an
/// opaque hit-test target, so pan and pinch never reach the canvas underneath
/// and a stroke cannot accidentally scroll the board it is being drawn on.
///
/// The overlay reports positions in its **own local space**, which matches the
/// canvas viewport. The host converts them to world coordinates, so drawing
/// stays correct at any pan and zoom.
class DrawingOverlay extends StatefulWidget {
  const DrawingOverlay({
    super.key,
    required this.tool,
    required this.onShapeDrawn,
    required this.onUnrecognised,
    required this.onCancel,
  });

  /// The active tool. The overlay is never built with a null tool.
  final DrawingTool tool;

  /// Fired once a shape has been settled on, with its bounds in local space.
  final void Function(ShapeKind kind, Rect bounds) onShapeDrawn;

  /// Fired when a freehand stroke could not be named.
  final VoidCallback onUnrecognised;

  /// Fired when the player backs out of drawing.
  final VoidCallback onCancel;

  @override
  State<DrawingOverlay> createState() => _DrawingOverlayState();
}

class _DrawingOverlayState extends State<DrawingOverlay> {
  /// The raw stroke, in local coordinates.
  final List<Offset> _points = <Offset>[];

  /// Where a shape-tool drag began, or null when no drag is in flight.
  Offset? _dragOrigin;

  /// The current shape-tool drag position.
  Offset? _dragCurrent;

  /// The snapped outline held on screen between recognition and the prompt.
  List<Offset>? _preview;

  Timer? _previewTimer;

  bool get _isFreehand => widget.tool == DrawingTool.freehand;

  @override
  void didUpdateWidget(DrawingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching tools mid-stroke must not carry the half-drawn stroke over.
    if (oldWidget.tool != widget.tool) _reset();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    _previewTimer?.cancel();
    _previewTimer = null;
    _points.clear();
    _dragOrigin = null;
    _dragCurrent = null;
    _preview = null;
  }

  // ------------------------------------------------------------- gestures

  void _onPanStart(DragStartDetails details) {
    // A new stroke supersedes whatever preview is still on screen.
    setState(() {
      _reset();
      if (_isFreehand) {
        _points.add(details.localPosition);
      } else {
        _dragOrigin = details.localPosition;
        _dragCurrent = details.localPosition;
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (_isFreehand) {
        final Offset position = details.localPosition;
        if (_points.isEmpty ||
            (position - _points.last).distance >= kMinPointSpacing) {
          _points.add(position);
        }
      } else {
        _dragCurrent = details.localPosition;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isFreehand) {
      _finishFreehand();
    } else {
      _finishShapeTool();
    }
  }

  /// A cancelled pan leaves no usable stroke, so drop it rather than analysing
  /// a partial one.
  void _onPanCancel() => setState(_reset);

  void _finishFreehand() {
    if (_points.length < kMinStrokePoints) {
      setState(_reset);
      return;
    }

    final ShapeAnalysis analysis = shapeRecognizer.recognise(_points);

    if (!analysis.isRecognised) {
      setState(_reset);
      widget.onUnrecognised();
      return;
    }

    // Show the idealised shape in place of the stroke, then hand over. The
    // stroke is cleared first so the two never overlap.
    setState(() {
      _points.clear();
      _preview = analysis.points;
    });

    _previewTimer = Timer(kSnapPreviewDuration, () {
      if (!mounted) return;
      setState(() => _preview = null);
      widget.onShapeDrawn(analysis.kind, analysis.bounds);
    });
  }

  void _finishShapeTool() {
    final Offset? origin = _dragOrigin;
    final Offset? current = _dragCurrent;
    if (origin == null || current == null) {
      setState(_reset);
      return;
    }

    final ShapeKind kind = shapeForTool(widget.tool)!;
    final Rect bounds = _boundsFor(origin, current);

    setState(_reset);
    widget.onShapeDrawn(kind, bounds);
  }

  /// The box a shape-tool drag defines.
  ///
  /// A drag shorter than [kMinDragExtent] in both directions is treated as a
  /// tap: the player wanted a shape *there*, not a sliver. Lines and arrows
  /// keep whatever height they were given, since a flat drag is exactly how
  /// you draw one.
  Rect _boundsFor(Offset origin, Offset current) {
    final Rect dragged = Rect.fromPoints(origin, current);
    final bool isTap =
        dragged.width < kMinDragExtent && dragged.height < kMinDragExtent;

    if (isTap) {
      return Rect.fromCenter(
        center: origin,
        width: kTapShapeSize,
        height: widget.tool == DrawingTool.line ||
                widget.tool == DrawingTool.arrow
            ? kTapShapeSize / 3
            : kTapShapeSize,
      );
    }

    return dragged;
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final Offset? origin = _dragOrigin;
    final Offset? current = _dragCurrent;

    // The live outline a shape tool is dragging out.
    List<Offset>? liveShape;
    if (!_isFreehand && origin != null && current != null) {
      final Rect bounds = Rect.fromPoints(origin, current);
      if (bounds.width > 0 || bounds.height > 0) {
        liveShape = shapeRecognizer.perfectShape(
          shapeForTool(widget.tool)!,
          bounds,
        );
      }
    }

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanCancel,
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              child: CustomPaint(
                painter: _StrokePainter(
                  stroke: _points,
                  snapped: _preview ?? liveShape,
                ),
              ),
            ),
          ),
        ),
        Positioned(top: 12, left: 0, right: 0, child: _buildBanner()),
      ],
    );
  }

  Widget _buildBanner() {
    return Center(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: AppColors.shadow, blurRadius: 16),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _isFreehand
                      ? 'Draw a shape'
                      : 'Place a ${shapeName(shapeForTool(widget.tool)!)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _isFreehand
                      ? 'Rectangle, circle, triangle or line'
                      : 'Drag to size it, or tap to drop one',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: widget.onCancel,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints the in-progress stroke and the idealised shape it resolved to.
class _StrokePainter extends CustomPainter {
  const _StrokePainter({required this.stroke, required this.snapped});

  /// The raw stroke, drawn in the "still deciding" colour.
  final List<Offset> stroke;

  /// The idealised outline, drawn in the "understood" colour.
  final List<Offset>? snapped;

  @override
  void paint(Canvas canvas, Size size) {
    if (stroke.isNotEmpty) {
      _drawPath(
        canvas,
        stroke,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
        // A single tap has no path to stroke, so show it as a dot.
        dotWhenSingle: true,
      );
    }

    final List<Offset>? outline = snapped;
    if (outline != null && outline.length > 1) {
      canvas.drawPath(
        _pathOf(outline),
        Paint()..color = AppColors.success.withValues(alpha: 0.12),
      );
      _drawPath(
        canvas,
        outline,
        Paint()
          ..color = AppColors.success
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawPath(
    Canvas canvas,
    List<Offset> points,
    Paint paint, {
    bool dotWhenSingle = false,
  }) {
    if (points.length == 1) {
      if (dotWhenSingle) {
        canvas.drawCircle(points.first, 2.5, Paint()..color = paint.color);
      }
      return;
    }
    canvas.drawPath(_pathOf(points), paint);
  }

  Path _pathOf(List<Offset> points) {
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path;
  }

  /// Always repaints.
  ///
  /// [stroke] is one long-lived list that the state mutates in place, so the
  /// old delegate and the new one hold the *same* object and every field
  /// comparison would report "unchanged" while the stroke grows under it. The
  /// painter is only rebuilt from a setState that a pointer event triggered,
  /// so repainting unconditionally costs nothing extra.
  @override
  bool shouldRepaint(covariant _StrokePainter oldDelegate) => true;
}
