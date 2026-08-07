import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/experiment.dart';
import '../theme/app_theme.dart';
import 'node_card.dart' show nodeInputPort, nodeOutputPort;

/// Minimum horizontal offset applied to a connection's bezier control points.
const double kEdgeCurveMin = 40;

/// Builds the world-space cubic bezier that represents one connection.
///
/// [from] is the source node's output port, [to] the target's input port. The
/// control points are pushed horizontally by half the horizontal distance
/// (at least [kEdgeCurveMin]) which gives the familiar node-editor S-curve.
Path buildEdgePath(Offset from, Offset to) {
  final double control = math.max(kEdgeCurveMin, (to.dx - from.dx).abs() * 0.5);
  return Path()
    ..moveTo(from.dx, from.dy)
    ..cubicTo(from.dx + control, from.dy, to.dx - control, to.dy, to.dx, to.dy);
}

/// Returns the id of the edge whose curve passes within [tolerance] of
/// [worldPoint], or `null` when the point misses every edge.
///
/// All arguments are in **world** coordinates, so callers should scale their
/// pixel tolerance by `1 / controller.scale` before calling.
///
/// When several edges overlap, the one drawn last (topmost) wins.
String? edgeAtPoint({
  required List<ExperimentNode> nodes,
  required List<ExperimentEdge> edges,
  required Offset worldPoint,
  double tolerance = 12,
}) {
  if (edges.isEmpty) return null;
  final Map<String, ExperimentNode> byId = <String, ExperimentNode>{
    for (final ExperimentNode node in nodes) node.id: node,
  };

  final double toleranceSq = tolerance * tolerance;
  for (int i = edges.length - 1; i >= 0; i--) {
    final ExperimentEdge edge = edges[i];
    final ExperimentNode? source = byId[edge.source];
    final ExperimentNode? target = byId[edge.target];
    if (source == null || target == null) continue;

    final Path path = buildEdgePath(
      nodeOutputPort(source),
      nodeInputPort(target),
    );
    for (final ui.PathMetric metric in path.computeMetrics()) {
      final double length = metric.length;
      if (length <= 0) continue;
      final int samples = math.max(12, (length / 8).ceil());
      for (int s = 0; s <= samples; s++) {
        final ui.Tangent? tangent = metric.getTangentForOffset(
          length * s / samples,
        );
        if (tangent == null) continue;
        if ((tangent.position - worldPoint).distanceSquared <= toleranceSq) {
          return edge.id;
        }
      }
    }
  }
  return null;
}

/// Paints every connection beneath the node layer.
///
/// The painter receives world-space geometry plus the viewport transform and
/// maps the curves itself, which keeps stroke widths, arrowheads and label
/// chips at a constant pixel size regardless of zoom.
class EdgePainter extends CustomPainter {
  /// Creates a painter for the given graph and viewport.
  const EdgePainter({
    required this.nodes,
    required this.edges,
    required this.scale,
    required this.panOffset,
    required this.phase,
    this.connectingFrom,
    this.connectingCursor,
    this.highlightedEdgeId,
  });

  /// Every node on the canvas — used to resolve edge endpoints.
  final List<ExperimentNode> nodes;

  /// Every edge to draw.
  final List<ExperimentEdge> edges;

  /// Current canvas zoom.
  final double scale;

  /// Current canvas pan (world origin in screen space).
  final Offset panOffset;

  /// Animation phase in `0..1` driving the travelling flow highlight.
  final double phase;

  /// Source node of the connection currently being dragged, if any.
  final ExperimentNode? connectingFrom;

  /// World-space cursor of the connection currently being dragged, if any.
  final Offset? connectingCursor;

  /// Edge rendered in the highlight colour (selected or hovered).
  final String? highlightedEdgeId;

  Matrix4 get _transform => Matrix4.identity()
    ..setEntry(0, 0, scale)
    ..setEntry(1, 1, scale)
    ..setEntry(0, 3, panOffset.dx)
    ..setEntry(1, 3, panOffset.dy);

  @override
  void paint(Canvas canvas, Size size) {
    final Matrix4 matrix = _transform;
    final Map<String, ExperimentNode> byId = <String, ExperimentNode>{
      for (final ExperimentNode node in nodes) node.id: node,
    };

    for (final ExperimentEdge edge in edges) {
      final ExperimentNode? source = byId[edge.source];
      final ExperimentNode? target = byId[edge.target];
      if (source == null || target == null) continue;

      final Path screenPath = buildEdgePath(
        nodeOutputPort(source),
        nodeInputPort(target),
      ).transform(matrix.storage);

      final bool highlighted = edge.id == highlightedEdgeId;
      _drawEdge(canvas, screenPath, highlighted: highlighted);
      if (edge.label != null && edge.label!.trim().isNotEmpty) {
        _drawLabel(canvas, screenPath, edge.label!.trim());
      }
    }

    _drawPendingConnection(canvas, matrix);
  }

  void _drawEdge(Canvas canvas, Path path, {required bool highlighted}) {
    final Color base = highlighted ? AppColors.accent : AppColors.primary;

    // Soft glow underneath.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = base.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // The connection itself.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 3 : 2.2
        ..strokeCap = StrokeCap.round
        ..color = base.withValues(alpha: 0.85),
    );

    _drawFlow(canvas, path, base);
    _drawArrowHead(canvas, path, base);
  }

  /// Renders short bright dashes travelling from source to target.
  void _drawFlow(Canvas canvas, Path path, Color base) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = base.withValues(alpha: 0.95);

    for (final ui.PathMetric metric in path.computeMetrics()) {
      final double length = metric.length;
      if (length < 24) continue;
      const double dash = 14;
      final int count = math.max(1, (length / 90).round());
      for (int i = 0; i < count; i++) {
        final double t = (phase + i / count) % 1.0;
        final double start = t * (length + dash) - dash;
        final double from = start.clamp(0.0, length);
        final double to = (start + dash).clamp(0.0, length);
        if (to - from <= 0.5) continue;
        canvas.drawPath(metric.extractPath(from, to), paint);
      }
    }
  }

  void _drawArrowHead(Canvas canvas, Path path, Color base) {
    for (final ui.PathMetric metric in path.computeMetrics()) {
      final double length = metric.length;
      if (length <= 1) continue;
      final ui.Tangent? tip = metric.getTangentForOffset(length);
      if (tip == null) continue;

      const double size = 9;
      final double angle = math.atan2(tip.vector.dy, tip.vector.dx);
      final Offset a = tip.position;
      final Offset b =
          a +
          Offset(
                math.cos(angle + math.pi - 0.45),
                math.sin(angle + math.pi - 0.45),
              ) *
              size;
      final Offset c =
          a +
          Offset(
                math.cos(angle + math.pi + 0.45),
                math.sin(angle + math.pi + 0.45),
              ) *
              size;

      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(b.dx, b.dy)
          ..lineTo(c.dx, c.dy)
          ..close(),
        Paint()
          ..style = PaintingStyle.fill
          ..color = base.withValues(alpha: 0.95),
      );
    }
  }

  void _drawLabel(Canvas canvas, Path path, String label) {
    final List<ui.PathMetric> metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final ui.PathMetric metric = metrics.first;
    final ui.Tangent? mid = metric.getTangentForOffset(metric.length / 2);
    if (mid == null) return;

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 140);

    const double padX = 7;
    const double padY = 4;
    final Rect chip = Rect.fromCenter(
      center: mid.position,
      width: painter.width + padX * 2,
      height: painter.height + padY * 2,
    );
    final RRect rrect = RRect.fromRectAndRadius(chip, const Radius.circular(7));

    canvas.drawRRect(
      rrect,
      Paint()..color = AppColors.surfaceAlt.withValues(alpha: 0.96),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.border,
    );
    painter.paint(canvas, Offset(chip.left + padX, chip.top + padY));
    painter.dispose();
  }

  void _drawPendingConnection(Canvas canvas, Matrix4 matrix) {
    final ExperimentNode? source = connectingFrom;
    final Offset? cursor = connectingCursor;
    if (source == null || cursor == null) return;

    final Path path = buildEdgePath(
      nodeOutputPort(source),
      cursor,
    ).transform(matrix.storage);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.success.withValues(alpha: 0.9);

    for (final ui.PathMetric metric in path.computeMetrics()) {
      final double length = metric.length;
      double offset = -(phase * 16);
      while (offset < length) {
        final double from = offset.clamp(0.0, length);
        final double to = (offset + 9).clamp(0.0, length);
        if (to - from > 0.5) {
          canvas.drawPath(metric.extractPath(from, to), paint);
        }
        offset += 16;
      }
    }

    final Offset tip = cursor * scale + panOffset;
    canvas.drawCircle(
      tip,
      5,
      Paint()..color = AppColors.success.withValues(alpha: 0.95),
    );
    canvas.drawCircle(
      tip,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.success.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant EdgePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.scale != scale ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.highlightedEdgeId != highlightedEdgeId ||
        oldDelegate.connectingFrom?.id != connectingFrom?.id ||
        oldDelegate.connectingCursor != connectingCursor ||
        oldDelegate.edges.length != edges.length ||
        oldDelegate.nodes.length != nodes.length ||
        !identical(oldDelegate.edges, edges) ||
        !identical(oldDelegate.nodes, nodes);
  }
}
