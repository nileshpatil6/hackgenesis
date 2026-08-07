import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/component_data.dart';
import '../models/experiment.dart';
import 'node_card.dart' show kNodeHeight, kNodeWidth;

/// Smallest allowed canvas zoom.
const double kMinScale = 0.25;

/// Largest allowed canvas zoom.
const double kMaxScale = 2.5;

/// Maximum number of undo (and redo) snapshots retained.
const int kMaxHistory = 50;

/// One point-in-time copy of the whole graph, used by undo/redo.
///
/// [ExperimentNode] and [ExperimentEdge] are immutable, so copying the two
/// lists is deep enough to restore positions and labels exactly.
@immutable
class _Snapshot {
  const _Snapshot(this.nodes, this.edges);

  final List<ExperimentNode> nodes;
  final List<ExperimentEdge> edges;
}

/// The single source of truth for the experiment canvas.
///
/// Owns the graph (nodes + edges), the selection, the in-progress connection,
/// the viewport (pan + zoom) and the undo/redo history. Every mutation calls
/// [notifyListeners], so widgets should rebuild off this object rather than
/// keeping their own copies of canvas state.
class CanvasController extends ChangeNotifier {
  /// Creates an empty canvas.
  CanvasController();

  final List<ExperimentNode> _nodes = <ExperimentNode>[];
  final List<ExperimentEdge> _edges = <ExperimentEdge>[];
  final List<_Snapshot> _undoStack = <_Snapshot>[];
  final List<_Snapshot> _redoStack = <_Snapshot>[];

  String? _selectedNodeId;
  String? _connectingFromId;
  Offset? _connectingCursor;

  /// Monotonic counter behind every generated id.
  ///
  /// A wall-clock timestamp is not enough on its own: `DateTime.now()` only has
  /// millisecond resolution on Windows, so two components added in the same
  /// millisecond would collide on the same id and corrupt the graph.
  int _idSeed = 0;

  double _scale = 1;
  Offset _panOffset = Offset.zero;

  // ---------------------------------------------------------------------
  // Graph state
  // ---------------------------------------------------------------------

  /// All nodes currently on the canvas, in insertion order.
  List<ExperimentNode> get nodes =>
      UnmodifiableListView<ExperimentNode>(_nodes);

  /// All edges currently on the canvas, in insertion order.
  List<ExperimentEdge> get edges =>
      UnmodifiableListView<ExperimentEdge>(_edges);

  /// The id of the selected node, or `null` when nothing is selected.
  String? get selectedNodeId => _selectedNodeId;

  /// The source node id while a new connection is being dragged.
  String? get connectingFromId => _connectingFromId;

  /// The world-space cursor position while a new connection is being dragged.
  Offset? get connectingCursor => _connectingCursor;

  /// The current zoom factor, always within [kMinScale]..[kMaxScale].
  double get scale => _scale;

  /// The current pan, i.e. the world-origin's position in screen space.
  Offset get panOffset => _panOffset;

  /// Whether the canvas holds no nodes at all.
  bool get isEmpty => _nodes.isEmpty;

  /// Returns a value that is unique for the lifetime of this controller.
  String _nextId() => '${DateTime.now().millisecondsSinceEpoch}_${_idSeed++}';

  /// Looks up a node by [id], or returns `null` when it no longer exists.
  ExperimentNode? nodeById(String id) {
    for (final ExperimentNode node in _nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// Looks up an edge by [id], or returns `null` when it no longer exists.
  ExperimentEdge? edgeById(String id) {
    for (final ExperimentEdge edge in _edges) {
      if (edge.id == id) return edge;
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------

  /// Adds [component] at [worldPosition] (the node's top-left corner).
  ///
  /// Pushes an undo snapshot and returns the id of the created node.
  String addComponent(ComponentData component, Offset worldPosition) {
    _pushSnapshot();
    final String id = '${component.id}_${_nextId()}';
    _nodes.add(
      ExperimentNode(
        id: id,
        position: worldPosition,
        component: component,
        label: component.label,
      ),
    );
    _selectedNodeId = id;
    notifyListeners();
    return id;
  }

  /// Moves the node [id] to [newPosition].
  ///
  /// Deliberately does **not** snapshot: this runs on every drag frame.
  /// Call [beginNodeDrag] once when the drag starts instead.
  void moveNode(String id, Offset newPosition) {
    final int index = _indexOfNode(id);
    if (index < 0) return;
    _nodes[index] = _nodes[index].copyWith(position: newPosition);
    notifyListeners();
  }

  /// Records an undo snapshot at the start of a node drag.
  void beginNodeDrag(String id) {
    if (_indexOfNode(id) < 0) return;
    _pushSnapshot();
  }

  /// Removes the node [id] together with every edge that references it.
  void deleteNode(String id) {
    final int index = _indexOfNode(id);
    if (index < 0) return;
    _pushSnapshot();
    _nodes.removeAt(index);
    _edges.removeWhere(
      (ExperimentEdge edge) => edge.source == id || edge.target == id,
    );
    if (_selectedNodeId == id) _selectedNodeId = null;
    if (_connectingFromId == id) {
      _connectingFromId = null;
      _connectingCursor = null;
    }
    notifyListeners();
  }

  /// Selects the node [id], or clears the selection when [id] is `null`.
  void selectNode(String? id) {
    if (_selectedNodeId == id) return;
    _selectedNodeId = id;
    notifyListeners();
  }

  /// Sets (or clears, when [text] is `null`) the user-authored note on a node.
  void setNodeCustomText(String id, String? text) {
    final int index = _indexOfNode(id);
    if (index < 0) return;
    _pushSnapshot();
    final ExperimentNode node = _nodes[index];
    _nodes[index] = ExperimentNode(
      id: node.id,
      position: node.position,
      component: node.component,
      label: node.label,
      customText: text,
      properties: node.properties,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Connections
  // ---------------------------------------------------------------------

  /// Begins dragging a new connection out of node [sourceId].
  void startConnection(String sourceId) {
    final ExperimentNode? source = nodeById(sourceId);
    if (source == null) return;
    _connectingFromId = sourceId;
    _connectingCursor = Offset(
      source.position.dx + kNodeWidth,
      source.position.dy + kNodeHeight / 2,
    );
    notifyListeners();
  }

  /// Updates the in-progress connection's cursor, in world coordinates.
  void updateConnection(Offset worldCursor) {
    if (_connectingFromId == null) return;
    _connectingCursor = worldCursor;
    notifyListeners();
  }

  /// Finishes the in-progress connection.
  ///
  /// Creates an edge (and an undo snapshot) when [targetId] names a real node
  /// that is neither the source itself nor already connected from it.
  /// Anything else silently cancels.
  void endConnection(String? targetId) {
    final String? sourceId = _connectingFromId;
    _connectingFromId = null;
    _connectingCursor = null;

    if (sourceId == null || targetId == null || targetId == sourceId) {
      notifyListeners();
      return;
    }
    if (nodeById(sourceId) == null || nodeById(targetId) == null) {
      notifyListeners();
      return;
    }
    final bool duplicate = _edges.any(
      (ExperimentEdge e) => e.source == sourceId && e.target == targetId,
    );
    if (duplicate) {
      notifyListeners();
      return;
    }

    _pushSnapshot();
    _edges.add(
      ExperimentEdge(
        id: 'e_${sourceId}_${targetId}_${_nextId()}',
        source: sourceId,
        target: targetId,
      ),
    );
    notifyListeners();
  }

  /// Abandons the in-progress connection without creating an edge.
  void cancelConnection() {
    if (_connectingFromId == null && _connectingCursor == null) return;
    _connectingFromId = null;
    _connectingCursor = null;
    notifyListeners();
  }

  /// Removes the edge [id].
  void deleteEdge(String id) {
    final int index = _edges.indexWhere((ExperimentEdge e) => e.id == id);
    if (index < 0) return;
    _pushSnapshot();
    _edges.removeAt(index);
    notifyListeners();
  }

  /// Sets (or clears, when [label] is `null`) the label on edge [edgeId].
  void setEdgeLabel(String edgeId, String? label) {
    final int index = _edges.indexWhere((ExperimentEdge e) => e.id == edgeId);
    if (index < 0) return;
    _pushSnapshot();
    final ExperimentEdge edge = _edges[index];
    final String? normalised = (label != null && label.trim().isEmpty)
        ? null
        : label;
    _edges[index] = ExperimentEdge(
      id: edge.id,
      source: edge.source,
      target: edge.target,
      label: normalised,
      condition: edge.condition,
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Bulk operations
  // ---------------------------------------------------------------------

  /// Removes every node and edge.
  void clear() {
    if (_nodes.isEmpty && _edges.isEmpty) return;
    _pushSnapshot();
    _nodes.clear();
    _edges.clear();
    _selectedNodeId = null;
    _connectingFromId = null;
    _connectingCursor = null;
    notifyListeners();
  }

  /// Replaces the whole graph with [experiment].
  void loadExperiment(ExperimentJson experiment) {
    _pushSnapshot();
    _nodes
      ..clear()
      ..addAll(experiment.nodes);
    _edges
      ..clear()
      ..addAll(experiment.edges);
    _selectedNodeId = null;
    _connectingFromId = null;
    _connectingCursor = null;
    notifyListeners();
  }

  /// Snapshots the current graph as a serialisable [ExperimentJson].
  ExperimentJson toExperiment({
    String title = 'Untitled Experiment',
    String description = '',
  }) {
    return ExperimentJson(
      nodes: List<ExperimentNode>.of(_nodes),
      edges: List<ExperimentEdge>.of(_edges),
      title: title,
      description: description,
      created: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------
  // Undo / redo
  // ---------------------------------------------------------------------

  /// Whether [undo] would do anything.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether [redo] would do anything.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Restores the previous graph state.
  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_currentSnapshot());
    if (_redoStack.length > kMaxHistory) _redoStack.removeAt(0);
    _restore(_undoStack.removeLast());
  }

  /// Re-applies a state that was rolled back by [undo].
  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_currentSnapshot());
    if (_undoStack.length > kMaxHistory) _undoStack.removeAt(0);
    _restore(_redoStack.removeLast());
  }

  // ---------------------------------------------------------------------
  // Viewport
  // ---------------------------------------------------------------------

  /// Sets the zoom, clamped to [kMinScale]..[kMaxScale].
  void setScale(double value) {
    final double next = value.clamp(kMinScale, kMaxScale);
    if (next == _scale) return;
    _scale = next;
    notifyListeners();
  }

  /// Zooms in one step (20%).
  void zoomIn() => setScale(_scale * 1.2);

  /// Zooms out one step (20%).
  void zoomOut() => setScale(_scale / 1.2);

  /// Restores the default zoom and pan.
  void resetView() {
    if (_scale == 1 && _panOffset == Offset.zero) return;
    _scale = 1;
    _panOffset = Offset.zero;
    notifyListeners();
  }

  /// Translates the viewport by a screen-space [delta].
  void panBy(Offset delta) {
    if (delta == Offset.zero) return;
    _panOffset += delta;
    notifyListeners();
  }

  /// Sets the pan directly, in screen space.
  void setPan(Offset value) {
    if (_panOffset == value) return;
    _panOffset = value;
    notifyListeners();
  }

  /// Zooms and pans so every node fits inside [viewportSize].
  ///
  /// Does nothing when the canvas is empty or the viewport has no area.
  void fitToContent(Size viewportSize) {
    if (_nodes.isEmpty) return;
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    for (final ExperimentNode node in _nodes) {
      minX = math.min(minX, node.position.dx);
      minY = math.min(minY, node.position.dy);
      maxX = math.max(maxX, node.position.dx + kNodeWidth);
      maxY = math.max(maxY, node.position.dy + kNodeHeight);
    }

    const double padding = 72;
    final double contentWidth = math.max(1.0, maxX - minX) + padding * 2;
    final double contentHeight = math.max(1.0, maxY - minY) + padding * 2;

    final double fitted = math
        .min(
          viewportSize.width / contentWidth,
          viewportSize.height / contentHeight,
        )
        .clamp(kMinScale, kMaxScale);

    final Offset contentCentre = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    _scale = fitted;
    _panOffset =
        Offset(viewportSize.width / 2, viewportSize.height / 2) -
        contentCentre * fitted;
    notifyListeners();
  }

  /// Converts a screen-space point into world (canvas) coordinates.
  Offset screenToWorld(Offset screenPoint) =>
      (screenPoint - _panOffset) / _scale;

  /// Converts a world (canvas) point into screen-space coordinates.
  Offset worldToScreen(Offset worldPoint) => worldPoint * _scale + _panOffset;

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  int _indexOfNode(String id) =>
      _nodes.indexWhere((ExperimentNode n) => n.id == id);

  _Snapshot _currentSnapshot() => _Snapshot(
    List<ExperimentNode>.of(_nodes),
    List<ExperimentEdge>.of(_edges),
  );

  void _pushSnapshot() {
    _undoStack.add(_currentSnapshot());
    if (_undoStack.length > kMaxHistory) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _restore(_Snapshot snapshot) {
    _nodes
      ..clear()
      ..addAll(snapshot.nodes);
    _edges
      ..clear()
      ..addAll(snapshot.edges);
    if (_selectedNodeId != null && _indexOfNode(_selectedNodeId!) < 0) {
      _selectedNodeId = null;
    }
    _connectingFromId = null;
    _connectingCursor = null;
    notifyListeners();
  }
}
