import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:canvas_lab/canvas/canvas_controller.dart';
import 'package:canvas_lab/canvas/canvas_view.dart';
import 'package:canvas_lab/canvas/drawing_overlay.dart';
import 'package:canvas_lab/canvas/shape_recognition.dart';

/// Points around a circle, optionally wobbled to imitate a real finger.
List<Offset> circleStroke({
  Offset centre = const Offset(200, 200),
  double radius = 80,
  int samples = 48,
  double wobble = 0,
}) {
  return <Offset>[
    for (int i = 0; i <= samples; i++)
      () {
        final double angle = (i / samples) * 2 * math.pi;
        // Deterministic wobble: a fixed ripple rather than a random one, so a
        // failure is always reproducible.
        final double r = radius + math.sin(angle * 5) * wobble;
        return Offset(
          centre.dx + r * math.cos(angle),
          centre.dy + r * math.sin(angle),
        );
      }(),
  ];
}

/// Points walked around a rectangle's perimeter.
List<Offset> rectangleStroke({
  Rect rect = const Rect.fromLTWH(100, 100, 200, 140),
  int perSide = 14,
}) {
  final List<Offset> corners = <Offset>[
    rect.topLeft,
    rect.topRight,
    rect.bottomRight,
    rect.bottomLeft,
    rect.topLeft,
  ];

  final List<Offset> points = <Offset>[];
  for (int side = 0; side < corners.length - 1; side++) {
    for (int step = 0; step < perSide; step++) {
      points.add(
        Offset.lerp(corners[side], corners[side + 1], step / perSide)!,
      );
    }
  }
  points.add(corners.last);
  return points;
}

/// Points walked around a triangle's perimeter.
List<Offset> triangleStroke({int perSide = 16}) {
  const List<Offset> corners = <Offset>[
    Offset(200, 100),
    Offset(300, 260),
    Offset(100, 260),
    Offset(200, 100),
  ];

  final List<Offset> points = <Offset>[];
  for (int side = 0; side < corners.length - 1; side++) {
    for (int step = 0; step < perSide; step++) {
      points.add(
        Offset.lerp(corners[side], corners[side + 1], step / perSide)!,
      );
    }
  }
  points.add(corners.last);
  return points;
}

/// A straight, slightly imperfect horizontal stroke.
List<Offset> lineStroke({int samples = 30}) {
  return <Offset>[
    for (int i = 0; i <= samples; i++)
      Offset(100 + i * 8.0, 200 + math.sin(i.toDouble()) * 1.2),
  ];
}

void main() {
  group('ShapeRecognizer.recognise', () {
    test('names a clean circle', () {
      final ShapeAnalysis analysis = shapeRecognizer.recognise(circleStroke());
      expect(analysis.kind, ShapeKind.circle);
      expect(analysis.confidence, greaterThan(kRecognitionThreshold));
    });

    test('still names a wobbly circle, since nobody draws a clean one', () {
      final ShapeAnalysis analysis = shapeRecognizer.recognise(
        circleStroke(wobble: 5),
      );
      expect(analysis.kind, ShapeKind.circle);
    });

    test('names a rectangle', () {
      expect(
        shapeRecognizer.recognise(rectangleStroke()).kind,
        ShapeKind.rectangle,
      );
    });

    test('names a triangle', () {
      expect(
        shapeRecognizer.recognise(triangleStroke()).kind,
        ShapeKind.triangle,
      );
    });

    test('names a line', () {
      expect(shapeRecognizer.recognise(lineStroke()).kind, ShapeKind.line);
    });

    test('reports the box the stroke actually occupied', () {
      const Rect drawn = Rect.fromLTWH(40, 60, 180, 120);
      final ShapeAnalysis analysis = shapeRecognizer.recognise(
        rectangleStroke(rect: drawn),
      );
      // Where the shape lands on the canvas comes straight from these bounds,
      // so a drift here puts every drawn block in the wrong place.
      expect(analysis.bounds.left, closeTo(drawn.left, 1));
      expect(analysis.bounds.top, closeTo(drawn.top, 1));
      expect(analysis.bounds.width, closeTo(drawn.width, 1));
      expect(analysis.bounds.height, closeTo(drawn.height, 1));
    });

    test('refuses a stroke too short to judge', () {
      final ShapeAnalysis analysis = shapeRecognizer.recognise(<Offset>[
        const Offset(0, 0),
        const Offset(5, 5),
      ]);
      expect(analysis.kind, ShapeKind.unknown);
    });

    test('survives a stroke with no extent instead of scoring NaN', () {
      // Every scorer divides by some measure of the stroke's size. A pointer
      // held still emits many identical points, which used to reach those
      // divisions with a zero denominator; NaN then loses no comparison and
      // an arbitrary shape wins.
      final ShapeAnalysis analysis = shapeRecognizer.recognise(
        List<Offset>.filled(30, const Offset(50, 50)),
      );
      expect(analysis.kind, ShapeKind.unknown);
      expect(analysis.confidence.isNaN, isFalse);
    });

    test('rejects a scribble rather than guessing', () {
      // A dense zig-zag: not straight, not round, not closed.
      final List<Offset> scribble = <Offset>[
        for (int i = 0; i < 40; i++)
          Offset(100 + i * 6.0, 200 + (i.isEven ? -55.0 : 55.0)),
      ];
      expect(shapeRecognizer.recognise(scribble).kind, ShapeKind.unknown);
    });
  });

  group('ShapeRecognizer.simplify', () {
    test('collapses a straight run to its endpoints', () {
      final List<Offset> straight = <Offset>[
        for (int i = 0; i <= 20; i++) Offset(i * 10.0, 0),
      ];
      expect(shapeRecognizer.simplify(straight), hasLength(2));
    });

    test('keeps a corner', () {
      final List<Offset> bent = <Offset>[
        for (int i = 0; i <= 10; i++) Offset(i * 10.0, 0),
        for (int i = 1; i <= 10; i++) Offset(100, i * 10.0),
      ];
      final List<Offset> simplified = shapeRecognizer.simplify(bent);
      expect(simplified.length, greaterThanOrEqualTo(3));
      expect(
        simplified,
        contains(const Offset(100, 0)),
        reason: 'the corner is the one point that must survive',
      );
    });

    test('leaves a two-point stroke alone', () {
      final List<Offset> pair = <Offset>[Offset.zero, const Offset(10, 10)];
      expect(shapeRecognizer.simplify(pair), pair);
    });
  });

  group('ShapeRecognizer.perfectShape', () {
    const Rect bounds = Rect.fromLTWH(10, 20, 100, 60);

    test('closes a rectangle back on its first corner', () {
      final List<Offset> points = shapeRecognizer.perfectShape(
        ShapeKind.rectangle,
        bounds,
      );
      expect(points.first, points.last);
      expect(points, hasLength(5));
    });

    test('closes a triangle back on its apex', () {
      final List<Offset> points = shapeRecognizer.perfectShape(
        ShapeKind.triangle,
        bounds,
      );
      expect(points.first, points.last);
    });

    test('draws a line across the middle of its box', () {
      final List<Offset> points = shapeRecognizer.perfectShape(
        ShapeKind.line,
        bounds,
      );
      expect(points, hasLength(2));
      expect(points.first.dy, bounds.center.dy);
      expect(points.last.dy, bounds.center.dy);
      expect(points.first.dx, bounds.left);
      expect(points.last.dx, bounds.right);
    });

    test('gives an arrow a head, so it is not just a line', () {
      final List<Offset> line = shapeRecognizer.perfectShape(
        ShapeKind.line,
        bounds,
      );
      final List<Offset> arrow = shapeRecognizer.perfectShape(
        ShapeKind.arrow,
        bounds,
      );
      expect(arrow.length, greaterThan(line.length));
    });

    test('keeps every point of a circle inside its box', () {
      final List<Offset> points = shapeRecognizer.perfectShape(
        ShapeKind.circle,
        const Rect.fromLTWH(0, 0, 100, 100),
      );
      for (final Offset point in points) {
        expect(point.dx, inInclusiveRange(-0.01, 100.01));
        expect(point.dy, inInclusiveRange(-0.01, 100.01));
      }
    });
  });

  group('tool mapping', () {
    test('freehand has no shape until the stroke is read', () {
      expect(shapeForTool(DrawingTool.freehand), isNull);
    });

    test('every other tool names its shape up front', () {
      for (final DrawingTool tool in DrawingTool.values) {
        if (tool == DrawingTool.freehand) continue;
        expect(
          shapeForTool(tool),
          isNotNull,
          reason: '$tool must map to a shape',
        );
      }
    });

    test('every shape has a name for the prompt', () {
      for (final ShapeKind kind in ShapeKind.values) {
        expect(shapeName(kind), isNotEmpty);
      }
    });
  });

  group('drawnComponent', () {
    test('keeps the label the player typed', () {
      final component = drawnComponent(
        kind: ShapeKind.circle,
        label: 'Petri dish',
      );
      expect(component.label, 'Petri dish');
      expect(component.category, kDrawingCategory);
    });

    test('describes what was drawn, not what it was called', () {
      final component = drawnComponent(
        kind: ShapeKind.triangle,
        label: 'Prism',
      );
      expect(component.description, contains('triangle'));
    });
  });

  group('DrawingOverlay', () {
    /// Mounts the overlay over a sibling that records whether it was dragged,
    /// mirroring how the canvas sits underneath it on the real screen.
    Future<void> pump(
      WidgetTester tester, {
      required DrawingTool tool,
      required void Function(ShapeKind, Rect) onShapeDrawn,
      VoidCallback? onUnrecognised,
      VoidCallback? onCancel,
      VoidCallback? onCanvasDrag,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (_) => onCanvasDrag?.call(),
                    child: const ColoredBox(color: Color(0xFFEEEEEE)),
                  ),
                ),
                Positioned.fill(
                  child: DrawingOverlay(
                    tool: tool,
                    onShapeDrawn: onShapeDrawn,
                    onUnrecognised: onUnrecognised ?? () {},
                    onCancel: onCancel ?? () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('a drag with a shape tool reports the box it covered', (
      tester,
    ) async {
      ShapeKind? kind;
      Rect? bounds;
      await pump(
        tester,
        tool: DrawingTool.rectangle,
        onShapeDrawn: (k, b) {
          kind = k;
          bounds = b;
        },
      );

      await tester.dragFrom(const Offset(120, 140), const Offset(180, 90));
      await tester.pumpAndSettle();

      expect(kind, ShapeKind.rectangle);
      expect(bounds!.left, closeTo(120, 1));
      expect(bounds!.top, closeTo(140, 1));
      expect(bounds!.width, closeTo(180, 1));
      expect(bounds!.height, closeTo(90, 1));
    });

    testWidgets('a drag reports the same box when drawn backwards', (
      tester,
    ) async {
      Rect? bounds;
      await pump(
        tester,
        tool: DrawingTool.circle,
        onShapeDrawn: (_, b) => bounds = b,
      );

      // Dragging up and to the left must not produce a negative-size box,
      // which would place the node off in the opposite direction.
      await tester.dragFrom(const Offset(300, 300), const Offset(-160, -120));
      await tester.pumpAndSettle();

      expect(bounds!.width, closeTo(160, 1));
      expect(bounds!.height, closeTo(120, 1));
      expect(bounds!.left, closeTo(140, 1));
      expect(bounds!.top, closeTo(180, 1));
    });

    testWidgets('a tap drops a default-sized shape where it was tapped', (
      tester,
    ) async {
      Rect? bounds;
      await pump(
        tester,
        tool: DrawingTool.rectangle,
        onShapeDrawn: (_, b) => bounds = b,
      );

      // A tiny drag counts as a tap: a finger is never perfectly still.
      await tester.dragFrom(const Offset(200, 250), const Offset(4, 3));
      await tester.pumpAndSettle();

      expect(bounds!.width, kTapShapeSize);
      expect(bounds!.height, kTapShapeSize);
      expect(bounds!.center.dx, closeTo(200, 1));
      expect(bounds!.center.dy, closeTo(250, 1));
    });

    testWidgets('a tapped line is wider than it is tall', (tester) async {
      Rect? bounds;
      await pump(
        tester,
        tool: DrawingTool.line,
        onShapeDrawn: (_, b) => bounds = b,
      );

      await tester.dragFrom(const Offset(200, 250), const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(bounds!.width, greaterThan(bounds!.height));
    });

    testWidgets('a recognised freehand stroke reports its shape', (
      tester,
    ) async {
      ShapeKind? kind;
      await pump(
        tester,
        tool: DrawingTool.freehand,
        onShapeDrawn: (k, _) => kind = k,
      );

      final TestGesture gesture = await tester.startGesture(
        circleStroke(centre: const Offset(300, 250), radius: 90).first,
      );
      for (final Offset point in circleStroke(
        centre: const Offset(300, 250),
        radius: 90,
      ).skip(1)) {
        await gesture.moveTo(point);
      }
      await gesture.up();

      // The snapped outline is held on screen before the shape is handed over.
      expect(kind, isNull, reason: 'the snap preview should come first');
      await tester.pump(kSnapPreviewDuration + const Duration(milliseconds: 1));

      expect(kind, ShapeKind.circle);
    });

    testWidgets('an unreadable freehand stroke asks for another try', (
      tester,
    ) async {
      bool asked = false;
      ShapeKind? kind;
      await pump(
        tester,
        tool: DrawingTool.freehand,
        onShapeDrawn: (k, _) => kind = k,
        onUnrecognised: () => asked = true,
      );

      final TestGesture gesture = await tester.startGesture(
        const Offset(100, 200),
      );
      for (int i = 0; i < 40; i++) {
        await gesture.moveTo(
          Offset(100 + i * 6.0, 200 + (i.isEven ? -55.0 : 55.0)),
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(asked, isTrue);
      expect(kind, isNull, reason: 'nothing should land on the canvas');
    });

    testWidgets('swallows the gesture so the real canvas cannot pan', (
      tester,
    ) async {
      // Deliberately built against CanvasView rather than a stand-in. The
      // canvas pans through a *scale* recogniser, and whether a sibling drag
      // recogniser beats it is exactly the detail a stand-in would get wrong.
      final CanvasController controller = CanvasController();
      addTearDown(controller.dispose);

      Future<void> pumpWithCanvas({required bool drawing}) {
        return tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CanvasView(
                      controller: controller,
                      onRequestEdgeLabel: (_) async => null,
                    ),
                  ),
                  if (drawing)
                    Positioned.fill(
                      child: DrawingOverlay(
                        tool: DrawingTool.rectangle,
                        onShapeDrawn: (_, _) {},
                        onUnrecognised: () {},
                        onCancel: () {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }

      // Without the overlay the same drag pans the canvas. This half is what
      // keeps the assertion below from passing for the wrong reason.
      await pumpWithCanvas(drawing: false);
      await tester.dragFrom(const Offset(200, 200), const Offset(120, 80));
      // pump, not pumpAndSettle: CanvasView animates its edge flow forever, so
      // there is no settled frame to wait for.
      await tester.pump();
      expect(
        controller.panOffset,
        isNot(Offset.zero),
        reason: 'the canvas should pan when nothing is covering it',
      );

      controller.resetView();
      await pumpWithCanvas(drawing: true);
      await tester.dragFrom(const Offset(200, 200), const Offset(120, 80));
      await tester.pump();

      expect(
        controller.panOffset,
        Offset.zero,
        reason: 'drawing must not scroll the board it is drawn on',
      );
    });

    testWidgets('switching tools abandons a half-drawn stroke', (tester) async {
      ShapeKind? kind;
      await pump(
        tester,
        tool: DrawingTool.freehand,
        onShapeDrawn: (k, _) => kind = k,
      );

      final TestGesture gesture = await tester.startGesture(
        const Offset(150, 150),
      );
      await gesture.moveTo(const Offset(200, 150));
      await gesture.moveTo(const Offset(200, 200));

      // Re-arm with a different tool mid-stroke.
      await pump(
        tester,
        tool: DrawingTool.circle,
        onShapeDrawn: (k, _) => kind = k,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(kind, isNull);
    });
  });
}
