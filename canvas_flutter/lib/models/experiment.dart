import 'package:flutter/material.dart';

import 'component_data.dart';

/// A component instance placed on the canvas.
@immutable
class ExperimentNode {
  const ExperimentNode({
    required this.id,
    required this.position,
    required this.component,
    this.label,
    this.customText,
    this.properties,
  });

  final String id;

  /// Top-left position in canvas (world) coordinates.
  final Offset position;
  final ComponentData component;

  /// Defaults to [component.label] when null.
  final String? label;
  final String? customText;
  final Map<String, dynamic>? properties;

  String get displayLabel => label ?? component.label;

  ExperimentNode copyWith({
    String? id,
    Offset? position,
    ComponentData? component,
    String? label,
    String? customText,
    Map<String, dynamic>? properties,
  }) {
    return ExperimentNode(
      id: id ?? this.id,
      position: position ?? this.position,
      component: component ?? this.component,
      label: label ?? this.label,
      customText: customText ?? this.customText,
      properties: properties ?? this.properties,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': 'custom',
    'position': {'x': position.dx, 'y': position.dy},
    'data': {
      'label': displayLabel,
      'component': component.toJson(),
      if (customText != null) 'customText': customText,
      'properties': properties ?? component.properties,
    },
  };

  factory ExperimentNode.fromJson(Map<String, dynamic> json) {
    final pos = (json['position'] as Map?) ?? const {};
    final data = (json['data'] as Map?) ?? const {};
    return ExperimentNode(
      id: json['id'] as String? ?? '',
      position: Offset(
        (pos['x'] as num?)?.toDouble() ?? 0,
        (pos['y'] as num?)?.toDouble() ?? 0,
      ),
      component: ComponentData.fromJson(
        Map<String, dynamic>.from((data['component'] as Map?) ?? const {}),
      ),
      label: data['label'] as String?,
      customText: data['customText'] as String?,
      properties: data['properties'] == null
          ? null
          : Map<String, dynamic>.from(data['properties'] as Map),
    );
  }
}

/// A directed connection between two [ExperimentNode]s.
@immutable
class ExperimentEdge {
  const ExperimentEdge({
    required this.id,
    required this.source,
    required this.target,
    this.label,
    this.condition,
  });

  final String id;

  /// Source [ExperimentNode.id].
  final String source;

  /// Target [ExperimentNode.id].
  final String target;
  final String? label;
  final String? condition;

  ExperimentEdge copyWith({
    String? id,
    String? source,
    String? target,
    String? label,
    String? condition,
  }) {
    return ExperimentEdge(
      id: id ?? this.id,
      source: source ?? this.source,
      target: target ?? this.target,
      label: label ?? this.label,
      condition: condition ?? this.condition,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'target': target,
    if (label != null) 'label': label,
    if (condition != null) 'condition': condition,
  };

  factory ExperimentEdge.fromJson(Map<String, dynamic> json) {
    return ExperimentEdge(
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? '',
      target: json['target'] as String? ?? '',
      label: json['label'] as String?,
      condition: json['condition'] as String?,
    );
  }
}

/// A full experiment graph — the payload sent to the AI for analysis.
@immutable
class ExperimentJson {
  const ExperimentJson({
    required this.nodes,
    required this.edges,
    this.title = 'Untitled Experiment',
    this.description = '',
    this.created,
  });

  final List<ExperimentNode> nodes;
  final List<ExperimentEdge> edges;
  final String title;
  final String description;
  final DateTime? created;

  Map<String, dynamic> toJson() => {
    'nodes': nodes.map((n) => n.toJson()).toList(),
    'edges': edges.map((e) => e.toJson()).toList(),
    'metadata': {
      'title': title,
      'description': description,
      'created': (created ?? DateTime.now()).toIso8601String(),
    },
  };

  factory ExperimentJson.fromJson(Map<String, dynamic> json) {
    final meta = (json['metadata'] as Map?) ?? const {};
    return ExperimentJson(
      nodes: ((json['nodes'] as List?) ?? const [])
          .map((n) => ExperimentNode.fromJson(Map<String, dynamic>.from(n)))
          .toList(),
      edges: ((json['edges'] as List?) ?? const [])
          .map((e) => ExperimentEdge.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      title: meta['title'] as String? ?? 'Untitled Experiment',
      description: meta['description'] as String? ?? '',
      created: DateTime.tryParse(meta['created'] as String? ?? ''),
    );
  }
}

/// The AI's verdict on a submitted experiment.
@immutable
class AnalysisResult {
  const AnalysisResult({
    required this.success,
    required this.title,
    required this.message,
    required this.explanation,
    this.mistake,
  });

  final bool success;
  final String title;
  final String message;
  final String explanation;

  /// Present when [success] is false — describes the error without solving it.
  final String? mistake;

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    String? nullIfBlank(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return null;
      return s;
    }

    return AnalysisResult(
      success: json['success'] as bool? ?? false,
      title: json['title'] as String? ?? 'Result',
      message: json['message'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      mistake: nullIfBlank(json['mistake']),
    );
  }

  factory AnalysisResult.error(String message, String details) {
    return AnalysisResult(
      success: false,
      title: 'Analysis Error',
      message: message,
      explanation: details,
      mistake: 'There was an error communicating with the AI service.',
    );
  }
}

/// One entry in the chat with the lab-assistant robot.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.isUser,
    required this.content,
    required this.timestamp,
  });

  final bool isUser;
  final String content;
  final DateTime timestamp;
}
