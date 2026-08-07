import 'dart:math' as math;
import 'dart:ui' as ui show PointMode;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/component_data.dart';
import '../models/experiment.dart';
import '../theme/app_theme.dart';
import 'canvas_controller.dart';
import 'edge_painter.dart';
import 'node_card.dart';

/// Spacing of the background grid dots, in world units.
const double kGridSpacing = 26;

/// The interactive node-graph surface.
///
/// Composes the dotted background, the edge layer, the node layer and every
/// gesture (pan, zoom, drop, node drag, connection drag, selection, delete) on
/// top of a [CanvasController]. The widget keeps no graph state of its own.
class CanvasView extends StatefulWidget {
  /// Creates a canvas bound to [controller].
  const CanvasView({
    super.key,
    required this.controller,
    required this.onRequestEdgeLabel,
    this.onEmptyTap,
  });

  /// The graph + viewport state this view renders and mutates.
  final CanvasController controller;

  /// Asks the host to prompt for an edge label.
  ///
  /// Receives the edge's current label and should resolve to the new label, or
  /// to `null` when the user cancels (in which case nothing changes).
  final Future<String?> Function(String? current) onRequestEdgeLabel;

  /// Fired when empty canvas space is tapped (useful to dismiss panels).
  final VoidCallback? onEmptyTap;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  )..repeat();

  final FocusNode _focusNode = FocusNode(debugLabel: 'CanvasView');

  Offset _lastFocalPoint = Offset.zero;
  double _gestureStartScale = 1;

  CanvasController get _controller => widget.controller;

  @override
  void dispose() {
    _flow.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Coordinate helpers
  // ---------------------------------------------------------------------

  Offset? _toLocal(Offset globalPosition) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    return object.globalToLocal(globalPosition);
  }

  ExperimentNode? _nodeAtWorld(Offset worldPoint) {
    final List<ExperimentNode> nodes = _controller.nodes;
    for (int i = nodes.length - 1; i >= 0; i--) {
      if (nodeRect(nodes[i]).contains(worldPoint)) return nodes[i];
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Viewport gestures
  // ---------------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    _focusNode.requestFocus();
    _lastFocalPoint = details.localFocalPoint;
    _gestureStartScale = _controller.scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // Pin the world point that sat under the previous focal point to the new
    // focal point, so pan and pinch-zoom resolve as one operation.
    final Offset anchorWorld = _controller.screenToWorld(_lastFocalPoint);
    _controller.setScale(_gestureStartScale * details.scale);
    final Offset anchorScreen = _controller.worldToScreen(anchorWorld);
    _controller.panBy(details.localFocalPoint - anchorScreen);
    _lastFocalPoint = details.localFocalPoint;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.scrollDelta.dy == 0) return;
    final Offset local = event.localPosition;
    final Offset anchorWorld = _controller.screenToWorld(local);
    final double factor = event.scrollDelta.dy > 0 ? 1 / 1.12 : 1.12;
    _controller.setScale(_controller.scale * factor);
    final Offset anchorScreen = _controller.worldToScreen(anchorWorld);
    _controller.panBy(local - anchorScreen);
  }

  // ---------------------------------------------------------------------
  // Connection dragging
  // ---------------------------------------------------------------------

  void _onPointerMove(PointerMoveEvent event) {
    if (_controller.connectingFromId == null) return;
    _controller.updateConnection(
      _controller.screenToWorld(event.localPosition),
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_controller.connectingFromId == null) return;
    final Offset world = _controller.screenToWorld(event.localPosition);
    _controller.endConnection(_nodeAtWorld(world)?.id);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_controller.connectingFromId == null) return;
    _controller.cancelConnection();
  }

  // ---------------------------------------------------------------------
  // Taps, drops, keyboard
  // ---------------------------------------------------------------------

  Future<void> _onBackgroundTapUp(TapUpDetails details) async {
    _focusNode.requestFocus();
    final Offset world = _controller.screenToWorld(details.localPosition);

    final String? edgeId = edgeAtPoint(
      nodes: _controller.nodes,
      edges: _controller.edges,
      worldPoint: world,
      tolerance: 14 / _controller.scale,
    );

    if (edgeId != null) {
      final ExperimentEdge? edge = _controller.edgeById(edgeId);
      final String? label = await widget.onRequestEdgeLabel(edge?.label);
      if (!mounted || label == null) return;
      _controller.setEdgeLabel(edgeId, label);
      return;
    }

    _controller.selectNode(null);
    widget.onEmptyTap?.call();
  }

  void _onAcceptDrop(DragTargetDetails<ComponentData> details) {
    final Offset? local = _toLocal(details.offset);
    if (local == null) return;
    final Offset world = _controller.screenToWorld(local);
    _controller.addComponent(
      details.data,
      world - const Offset(kNodeWidth / 2, kNodeHeight / 2),
    );
    _focusNode.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final bool isDelete =
        event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace;
    if (!isDelete) return KeyEventResult.ignored;

    final String? selected = _controller.selectedNodeId;
    if (selected == null) return KeyEventResult.ignored;
    _controller.deleteNode(selected);
    return KeyEventResult.handled;
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: DragTarget<ComponentData>(
        onAcceptWithDetails: _onAcceptDrop,
        builder:
            (
              BuildContext context,
              List<ComponentData?> candidate,
              List<dynamic> rejected,
            ) {
              return Listener(
                onPointerSignal: _onPointerSignal,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_controller, _flow]),
                  builder: (BuildContext context, Widget? child) =>
                      _buildLayers(isDropTarget: candidate.isNotEmpty),
                ),
              );
            },
      ),
    );
  }

  Widget _buildLayers({required bool isDropTarget}) {
    final List<ExperimentNode> nodes = _controller.nodes;
    final double scale = _controller.scale;
    final Offset pan = _controller.panOffset;
    final String? connectingId = _controller.connectingFromId;

    return Stack(
      // Cards near the viewport edge must not bleed over neighbouring panels.
      clipBehavior: Clip.hardEdge,
      children: <Widget>[
        // 1. Background grid, viewport gestures and empty-space taps.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onBackgroundTapUp,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GridPainter(
                  scale: scale,
                  panOffset: pan,
                  highlight: isDropTarget,
                ),
              ),
            ),
          ),
        ),

        // 2. Edge layer.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: EdgePainter(
                  nodes: nodes,
                  edges: _controller.edges,
                  scale: scale,
                  panOffset: pan,
                  phase: _flow.value,
                  connectingFrom: connectingId == null
                      ? null
                      : _controller.nodeById(connectingId),
                  connectingCursor: _controller.connectingCursor,
                ),
              ),
            ),
          ),
        ),

        // 3. Node layer.
        for (final ExperimentNode node in nodes)
          Positioned(
            left: (node.position.dx - kNodePadding) * scale + pan.dx,
            top: (node.position.dy - kNodePadding) * scale + pan.dy,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              // Pointer deltas inside this transform arrive in world units,
              // which is exactly what NodeCard.onDrag documents.
              child: RepaintBoundary(
                child: NodeCard(
                  key: ValueKey<String>(node.id),
                  node: node,
                  isSelected: _controller.selectedNodeId == node.id,
                  isConnecting:
                      connectingId != null && connectingId != node.id,
                  onTap: () {
                    _focusNode.requestFocus();
                    _controller.selectNode(node.id);
                  },
                  onDelete: () => _controller.deleteNode(node.id),
                  onStartConnection: () {
                    _controller.selectNode(node.id);
                    _controller.startConnection(node.id);
                  },
                  onDragStart: () {
                    _focusNode.requestFocus();
                    _controller.selectNode(node.id);
                    _controller.beginNodeDrag(node.id);
                  },
                  onDrag: (Offset delta) {
                    final ExperimentNode? current = _controller.nodeById(
                      node.id,
                    );
                    if (current == null) return;
                    _controller.moveNode(node.id, current.position + delta);
                  },
                ),
              ),
            ),
          ),

        // 4. Empty-state hint.
        if (_controller.isEmpty)
          const Positioned.fill(child: IgnorePointer(child: _EmptyHint())),
      ],
    );
  }
}

/// Centred prompt shown while the canvas holds no nodes.
class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('🧪', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your lab bench is empty',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const SizedBox(
            width: 280,
            child: Text(
              'Drag a component from the library onto the canvas, '
              'then link the green output port to another block.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the infinite dotted background, honouring pan and zoom.
class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.scale,
    required this.panOffset,
    required this.highlight,
  });

  final double scale;
  final Offset panOffset;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);

    // Coarsen the grid when zoomed far out so the dot count stays bounded.
    double step = kGridSpacing * scale;
    if (!step.isFinite || step <= 0) return;
    while (step < 12) {
      step *= 2;
    }

    final double startX = panOffset.dx % step;
    final double startY = panOffset.dy % step;
    final double radius = math.min(1.6, math.max(0.8, 1.1 * scale));

    final List<Offset> dots = <Offset>[];
    for (double x = startX - step; x <= size.width + step; x += step) {
      for (double y = startY - step; y <= size.height + step; y += step) {
        dots.add(Offset(x, y));
      }
    }

    canvas.drawPoints(
      ui.PointMode.points,
      dots,
      Paint()
        ..color = AppColors.grid.withValues(alpha: highlight ? 0.95 : 0.7)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = radius * 2,
    );

    if (highlight) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = AppColors.primary.withValues(alpha: 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.scale != scale ||
      oldDelegate.panOffset != panOffset ||
      oldDelegate.highlight != highlight;
}
