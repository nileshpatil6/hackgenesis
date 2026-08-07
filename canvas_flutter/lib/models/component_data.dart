import 'package:flutter/material.dart';

/// A single draggable building block in the component library.
/// Mirrors `ComponentData` from the React app's `src/types/index.ts`.
@immutable
class ComponentData {
  const ComponentData({
    required this.id,
    required this.label,
    required this.category,
    required this.description,
    required this.icon,
    this.properties = const {},
    this.inputs = 1,
    this.outputs = 1,
  });

  final String id;
  final String label;

  /// Matches a [ComponentCategory.id].
  final String category;
  final String description;

  /// Emoji glyph, e.g. `⚡`.
  final String icon;
  final Map<String, dynamic> properties;
  final int inputs;
  final int outputs;

  ComponentData copyWith({
    String? id,
    String? label,
    String? category,
    String? description,
    String? icon,
    Map<String, dynamic>? properties,
    int? inputs,
    int? outputs,
  }) {
    return ComponentData(
      id: id ?? this.id,
      label: label ?? this.label,
      category: category ?? this.category,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      properties: properties ?? this.properties,
      inputs: inputs ?? this.inputs,
      outputs: outputs ?? this.outputs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'category': category,
    'description': description,
    'icon': icon,
    'properties': properties,
    'inputs': inputs,
    'outputs': outputs,
  };

  factory ComponentData.fromJson(Map<String, dynamic> json) {
    return ComponentData(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? '📦',
      properties: Map<String, dynamic>.from(
        (json['properties'] as Map?) ?? const {},
      ),
      inputs: (json['inputs'] as num?)?.toInt() ?? 1,
      outputs: (json['outputs'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ComponentData && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// A top-level grouping shown as a filter chip in the component library.
@immutable
class ComponentCategory {
  const ComponentCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;

  /// Emoji glyph.
  final String icon;
  final Color color;
}
