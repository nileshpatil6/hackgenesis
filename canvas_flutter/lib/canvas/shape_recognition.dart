import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/component_data.dart';

/// The tools offered by the drawing toolbar.
///
/// [DrawingTool.freehand] is the only one that guesses: the player draws a
/// stroke and the recogniser decides what it was. Every other tool states its
/// shape up front and only asks where to put it.
enum DrawingTool { freehand, rectangle, circle, triangle, line, arrow }

/// A shape the recogniser can name.
///
/// [ShapeKind.arrow] is never produced by [ShapeRecognizer]. A stroke drawn as
/// an arrow reads as a line, and the arrowhead is too small a feature to
/// separate the two reliably. Arrows come from the arrow tool instead.
enum ShapeKind { rectangle, circle, triangle, line, arrow, unknown }

/// The category id given to every node created by drawing.
///
/// Deliberately distinct from the built-in library categories so that drawn
/// blocks are visually identifiable, and so the analysis prompt can tell that
/// the player named this part rather than picking it off a shelf.
const String kDrawingCategory = 'drawing';

/// The category id given to nodes created through the custom-block dialog.
const String kCustomCategory = 'custom';

/// Minimum number of raw points before a stroke is worth analysing.
const int kMinStrokePoints = 5;

/// Confidence a match must beat to be accepted.
///
/// Below this the stroke is reported as [ShapeKind.unknown] and the player is
/// asked to draw again, which is far better than silently dropping a shape
/// they did not intend onto the canvas.
const double kRecognitionThreshold = 0.6;

/// Extent of a shape placed by tapping rather than dragging, in world units.
const double kTapShapeSize = 120;

/// The smallest drag that counts as defining a shape's bounds.
///
/// Anything under this is treated as a tap, so a slightly shaky finger still
/// gets a usable shape instead of a sliver.
const double kMinDragExtent = 24;

/// The outcome of analysing a stroke.
@immutable
class ShapeAnalysis {
  const ShapeAnalysis({
    required this.kind,
    required this.confidence,
    required this.bounds,
    required this.points,
  });

  /// What the stroke was judged to be.
  final ShapeKind kind;

  /// How sure the recogniser is, in 0..1.
  final double confidence;

  /// The axis-aligned box the stroke occupies.
  final Rect bounds;

  /// The idealised outline, ready to paint. For an unrecognised stroke this is
  /// the raw input instead.
  final List<Offset> points;

  /// Whether this analysis named a shape.
  bool get isRecognised => kind != ShapeKind.unknown;
}

/// Turns a hand-drawn stroke into a named shape.
///
/// A direct port of `canvas/src/utils/shapeRecognition.ts` so that the web
/// sandbox and this app accept the same drawings. The scoring constants are
/// deliberately identical; where the TypeScript could divide by zero this
/// version returns a zero score instead, because a NaN would propagate through
/// the comparison and pick a shape at random.
class ShapeRecognizer {
  const ShapeRecognizer();

  /// Straightness cut-off: a stroke wider than this fraction of its length is
  /// not a line.
  static const double _lineThreshold = 0.15;

  /// Names the shape [rawPoints] traces.
  ShapeAnalysis recognise(List<Offset> rawPoints) {
    if (rawPoints.length < kMinStrokePoints) {
      return _unknown(rawPoints);
    }

    final List<Offset> simplified = simplify(rawPoints);
    final Rect bounds = boundsOf(simplified);

    // A stroke with no extent in either direction cannot be scored: every
    // ratio below would divide by zero.
    if (bounds.width <= 0 && bounds.height <= 0) {
      return _unknown(rawPoints);
    }

    final List<({ShapeKind kind, double score})> scores =
        <({ShapeKind kind, double score})>[
          (kind: ShapeKind.line, score: _lineScore(simplified, bounds)),
          (kind: ShapeKind.circle, score: _circleScore(simplified, bounds)),
          (
            kind: ShapeKind.rectangle,
            score: _rectangleScore(simplified, bounds),
          ),
          (kind: ShapeKind.triangle, score: _triangleScore(simplified)),
        ];

    ({ShapeKind kind, double score}) best = scores.first;
    for (final ({ShapeKind kind, double score}) candidate in scores.skip(1)) {
      if (candidate.score > best.score) best = candidate;
    }

    if (best.score > kRecognitionThreshold) {
      return ShapeAnalysis(
        kind: best.kind,
        confidence: best.score,
        bounds: bounds,
        points: perfectShape(best.kind, bounds),
      );
    }

    return _unknown(rawPoints);
  }

  /// Ramer-Douglas-Peucker simplification.
  ///
  /// Drops points that sit within [tolerance] of the line between their
  /// neighbours, which turns a shaky stroke into the handful of corners the
  /// scorers below actually reason about.
  List<Offset> simplify(List<Offset> points, {double tolerance = 5}) {
    if (points.length < 3) return List<Offset>.of(points);

    final Offset first = points.first;
    final Offset last = points.last;

    double maxDistance = 0;
    int maxIndex = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final double distance = _perpendicularDistance(points[i], first, last);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    if (maxDistance > tolerance) {
      final List<Offset> left = simplify(
        points.sublist(0, maxIndex + 1),
        tolerance: tolerance,
      );
      final List<Offset> right = simplify(
        points.sublist(maxIndex),
        tolerance: tolerance,
      );
      return <Offset>[...left.sublist(0, left.length - 1), ...right];
    }

    return <Offset>[first, last];
  }

  /// The axis-aligned box containing every point.
  Rect boundsOf(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;

    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;

    for (final Offset point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// The idealised outline of [kind] filling [bounds].
  List<Offset> perfectShape(ShapeKind kind, Rect bounds) {
    final double x = bounds.left;
    final double y = bounds.top;
    final double width = bounds.width;
    final double height = bounds.height;
    final Offset centre = bounds.center;

    switch (kind) {
      case ShapeKind.line:
        return <Offset>[
          Offset(x, centre.dy),
          Offset(x + width, centre.dy),
        ];

      case ShapeKind.arrow:
        // The shaft plus a chevron, so an arrow reads as directional even
        // before it is labelled.
        final double head = math.max(8, width * 0.22);
        return <Offset>[
          Offset(x, centre.dy),
          Offset(x + width, centre.dy),
          Offset(x + width - head, centre.dy - head * 0.6),
          Offset(x + width, centre.dy),
          Offset(x + width - head, centre.dy + head * 0.6),
        ];

      case ShapeKind.circle:
        final double radius = math.max(width, height) / 2;
        return <Offset>[
          for (int i = 0; i <= 32; i++)
            Offset(
              centre.dx + radius * math.cos((i / 32) * 2 * math.pi),
              centre.dy + radius * math.sin((i / 32) * 2 * math.pi),
            ),
        ];

      case ShapeKind.rectangle:
        return <Offset>[
          Offset(x, y),
          Offset(x + width, y),
          Offset(x + width, y + height),
          Offset(x, y + height),
          Offset(x, y),
        ];

      case ShapeKind.triangle:
        return <Offset>[
          Offset(centre.dx, y),
          Offset(x + width, y + height),
          Offset(x, y + height),
          Offset(centre.dx, y),
        ];

      case ShapeKind.unknown:
        return const <Offset>[];
    }
  }

  // -------------------------------------------------------------- scoring

  double _lineScore(List<Offset> points, Rect bounds) {
    if (points.length < 2) return 0;

    final double longest = math.max(bounds.width, bounds.height);
    if (longest <= 0) return 0;
    final double aspect = math.min(bounds.width, bounds.height) / longest;
    if (aspect > _lineThreshold) return 0;

    final Offset first = points.first;
    final Offset last = points.last;
    final double length = (last - first).distance;
    // A closed stroke starts and ends in the same place, so there is no line
    // to deviate from. Without this the ratio below divides by zero.
    if (length <= 0) return 0;

    double totalDeviation = 0;
    for (final Offset point in points) {
      totalDeviation += _perpendicularDistance(point, first, last);
    }

    final double deviationRatio = (totalDeviation / points.length) / length;
    return math.max(0, 1 - deviationRatio * 10);
  }

  double _circleScore(List<Offset> points, Rect bounds) {
    final double longest = math.max(bounds.width, bounds.height);
    if (longest <= 0) return 0;
    final double aspect = math.min(bounds.width, bounds.height) / longest;
    if (aspect < 0.7) return 0;

    final double averageRadius = (bounds.width + bounds.height) / 4;
    if (averageRadius <= 0) return 0;

    final Offset centre = bounds.center;
    double totalDeviation = 0;
    for (final Offset point in points) {
      totalDeviation += ((point - centre).distance - averageRadius).abs();
    }

    final double deviationRatio =
        (totalDeviation / points.length) / averageRadius;
    return math.max(0, 1 - deviationRatio * 4);
  }

  double _rectangleScore(List<Offset> points, Rect bounds) {
    if (points.length < 4) return 0;

    final double longest = math.max(bounds.width, bounds.height);
    if (longest <= 0) return 0;
    final double aspect = math.min(bounds.width, bounds.height) / longest;

    final List<Offset> corners = simplify(points, tolerance: 10);
    if (corners.length < 4 || corners.length > 6) return 0.3;

    if (!_isClosed(corners)) return 0;

    // A closed outline ends where it started, so the repeated point does not
    // count: a rectangle simplifies to five entries and a triangle to four.
    //
    // The TypeScript this was ported from omits this check, and a triangle in
    // a squarish box therefore scores 0.76 as a rectangle against 0.75 as a
    // triangle, and comes out a rectangle. Counting corners settles it.
    if (corners.length - 1 < 4) return 0.35;

    return 0.7 + (1 - aspect) * 0.3;
  }

  double _triangleScore(List<Offset> points) {
    final List<Offset> corners = simplify(points, tolerance: 10);
    if (corners.length < 3 || corners.length > 5) return 0.2;

    if (!_isClosed(corners)) return 0;

    if (corners.length == 3 || corners.length == 4) return 0.75;
    return 0.4;
  }

  /// Whether a stroke returns close enough to where it started to count as a
  /// closed outline, measured relative to its own size so it holds at any zoom.
  bool _isClosed(List<Offset> points) {
    final double perimeter = _perimeter(points);
    if (perimeter <= 0) return false;
    return (points.last - points.first).distance / perimeter <= 0.15;
  }

  double _perimeter(List<Offset> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  double _perpendicularDistance(Offset point, Offset start, Offset end) {
    final double dx = end.dx - start.dx;
    final double dy = end.dy - start.dy;
    final double norm = math.sqrt(dx * dx + dy * dy);
    if (norm == 0) return (point - start).distance;

    return ((point.dx - start.dx) * dy - (point.dy - start.dy) * dx).abs() /
        norm;
  }

  ShapeAnalysis _unknown(List<Offset> points) => ShapeAnalysis(
    kind: ShapeKind.unknown,
    confidence: 0,
    bounds: boundsOf(points),
    points: List<Offset>.of(points),
  );
}

/// The shared recogniser. Stateless, so one instance serves the whole app.
const ShapeRecognizer shapeRecognizer = ShapeRecognizer();

/// The shape a non-freehand [tool] draws.
///
/// Returns `null` for [DrawingTool.freehand], which has no shape until the
/// recogniser has seen the stroke.
ShapeKind? shapeForTool(DrawingTool tool) {
  switch (tool) {
    case DrawingTool.freehand:
      return null;
    case DrawingTool.rectangle:
      return ShapeKind.rectangle;
    case DrawingTool.circle:
      return ShapeKind.circle;
    case DrawingTool.triangle:
      return ShapeKind.triangle;
    case DrawingTool.line:
      return ShapeKind.line;
    case DrawingTool.arrow:
      return ShapeKind.arrow;
  }
}

/// The human-readable name of [kind], used in prompts and labels.
String shapeName(ShapeKind kind) {
  switch (kind) {
    case ShapeKind.rectangle:
      return 'rectangle';
    case ShapeKind.circle:
      return 'circle';
    case ShapeKind.triangle:
      return 'triangle';
    case ShapeKind.line:
      return 'line';
    case ShapeKind.arrow:
      return 'arrow';
    case ShapeKind.unknown:
      return 'shape';
  }
}

/// Builds the component a drawn [kind] becomes once the player has named it.
///
/// The result is an ordinary [ComponentData], so a drawn block connects, runs,
/// exports and earns XP exactly like one dragged out of the library.
ComponentData drawnComponent({required ShapeKind kind, required String label}) {
  final String name = shapeName(kind);
  return ComponentData(
    id: 'drawn_$name',
    label: label,
    category: kDrawingCategory,
    description: 'Hand-drawn $name',
    icon: '✏️',
  );
}
