import 'package:flutter/material.dart';

import '../models/experiment.dart';
import '../theme/app_theme.dart';

/// Logical width of every node card on the canvas, in world units.
///
/// Shared with `edge_painter.dart` and `canvas_controller.dart` so that edge
/// endpoints line up exactly with the rendered port dots.
const double kNodeWidth = 180;

/// Logical height of every node card on the canvas, in world units.
const double kNodeHeight = 92;

/// Transparent halo around the card, in world units.
///
/// The port dots and the delete badge overhang the card's edges. Flutter does
/// not hit-test outside a render box, so the card is laid out inside a slightly
/// larger box and the canvas offsets it by this amount when positioning.
const double kNodePadding = 12;

/// Diameter of the input/output port dots, in world units.
const double kPortSize = 14;

/// Category id -> accent colour used for the card's left bar and glow.
///
/// Kept private on purpose: the canvas layer must stay decoupled from
/// `lib/data/component_library.dart`.
const Map<String, Color> _kCategoryColors = <String, Color>{
  'electronics': Color(0xFF3B82F6),
  'chemicals': Color(0xFF10B981),
  'physics': Color(0xFF8B5CF6),
  'biology': Color(0xFFEC4899),
  'coding': Color(0xFFF59E0B),
  'mathematics': Color(0xFFEF4444),
  'thermodynamics': Color(0xFF06B6D4),
  'optics': Color(0xFFA855F7),
  'quantum': Color(0xFF14B8A6),
  'mechanics': Color(0xFF6366F1),
  'astronomy': Color(0xFF818CF8),
  'geology': Color(0xFFB45309),
  'music': Color(0xFFDB2777),
  'robotics': Color(0xFF4B5563),
  'ai_ml': Color(0xFF7C3AED),
};

/// Resolves the accent colour for a component [categoryId].
///
/// Falls back to [AppColors.primary] for unknown categories so the canvas can
/// never break on a category the library adds later.
Color categoryColor(String categoryId) =>
    _kCategoryColors[categoryId] ?? AppColors.primary;

/// Category id -> vector icon, replacing the old emoji glyphs.
///
/// Kept private on purpose: the canvas layer must stay decoupled from
/// `lib/data/component_library.dart`.
const Map<String, IconData> _kCategoryIcons = <String, IconData>{
  'electronics': Icons.bolt,
  'chemicals': Icons.science,
  'physics': Icons.blur_circular,
  'biology': Icons.biotech,
  'coding': Icons.code,
  'mathematics': Icons.functions,
  'thermodynamics': Icons.thermostat,
  'optics': Icons.remove_red_eye,
  'quantum': Icons.all_inclusive,
  'mechanics': Icons.settings,
  'astronomy': Icons.public,
  'geology': Icons.terrain,
  'music': Icons.music_note,
  'robotics': Icons.smart_toy,
  'ai_ml': Icons.psychology,
};

/// Resolves the vector icon for a component [categoryId].
///
/// Falls back to a generic glyph for unknown categories so the canvas can
/// never break on a category the library adds later.
IconData categoryIcon(String categoryId) =>
    _kCategoryIcons[categoryId] ?? Icons.widgets_outlined;

/// The world-space anchor of a node's output port (right edge, centred).
Offset nodeOutputPort(ExperimentNode node) =>
    Offset(node.position.dx + kNodeWidth, node.position.dy + kNodeHeight / 2);

/// The world-space anchor of a node's input port (left edge, centred).
Offset nodeInputPort(ExperimentNode node) =>
    Offset(node.position.dx, node.position.dy + kNodeHeight / 2);

/// The world-space bounding rectangle of a node card (excluding the halo).
Rect nodeRect(ExperimentNode node) =>
    Rect.fromLTWH(node.position.dx, node.position.dy, kNodeWidth, kNodeHeight);

/// A single component instance rendered on the canvas.
///
/// Purely presentational: every interaction is reported through callbacks so
/// that `CanvasController` remains the single source of truth.
///
/// The widget measures `kNodeWidth + 2 * kNodePadding` by
/// `kNodeHeight + 2 * kNodePadding`; the visible card sits inset by
/// [kNodePadding] on all sides.
class NodeCard extends StatelessWidget {
  /// Creates a card for [node].
  const NodeCard({
    super.key,
    required this.node,
    required this.isSelected,
    required this.isConnecting,
    required this.onTap,
    required this.onDelete,
    required this.onStartConnection,
    required this.onDrag,
    required this.onDragStart,
  });

  /// The node this card represents.
  final ExperimentNode node;

  /// Whether this node is the canvas selection.
  final bool isSelected;

  /// Whether a connection drag is currently in flight and this node could
  /// receive it — used to emphasise the input port as a drop target.
  final bool isConnecting;

  /// Fired when the card body is tapped.
  final VoidCallback onTap;

  /// Fired when the delete affordance is tapped.
  final VoidCallback onDelete;

  /// Fired when a drag begins on the output port.
  final VoidCallback onStartConnection;

  /// Fired continuously while the card is dragged.
  ///
  /// The reported [Offset] is the pointer delta in the card's **own** (local)
  /// coordinate space. Because the canvas renders cards inside its zoom
  /// transform, that delta is already free of the canvas scale and can be
  /// added straight onto [ExperimentNode.position].
  final ValueChanged<Offset> onDrag;

  /// Fired once when a card drag begins (used to push an undo snapshot).
  final VoidCallback onDragStart;

  String get _subtitle {
    final String? custom = node.customText?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final String description = node.component.description.trim();
    if (description.isNotEmpty) return description;
    final Map<String, dynamic> properties =
        node.properties ?? node.component.properties;
    if (properties.isNotEmpty) {
      final MapEntry<String, dynamic> first = properties.entries.first;
      return '${first.key}: ${first.value}';
    }
    return node.component.category;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = categoryColor(node.component.category);
    const double centreY = kNodePadding + kNodeHeight / 2;

    return SizedBox(
      width: kNodeWidth + kNodePadding * 2,
      height: kNodeHeight + kNodePadding * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Card body — tap to select, drag to move.
          Positioned(
            left: kNodePadding,
            top: kNodePadding,
            width: kNodeWidth,
            height: kNodeHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onPanStart: (_) => onDragStart(),
              onPanUpdate: (DragUpdateDetails details) => onDrag(details.delta),
              child: _CardBody(
                node: node,
                accent: accent,
                isSelected: isSelected,
                subtitle: _subtitle,
              ),
            ),
          ),

          // Input port (visual only).
          if (node.component.inputs > 0)
            Positioned(
              left: kNodePadding - kPortSize / 2,
              top: centreY - kPortSize / 2,
              child: _PortDot(
                color: AppColors.primary,
                emphasised: isConnecting,
              ),
            ),

          // Output port — the connection drag handle.
          if (node.component.outputs > 0)
            Positioned(
              left: kNodePadding + kNodeWidth - 15,
              top: centreY - 15,
              width: 30,
              height: 30,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                // The port sits partly over the card, so keep tap-to-select
                // working here too.
                onTap: onTap,
                onPanStart: (_) => onStartConnection(),
                onPanUpdate: (_) {},
                onPanEnd: (_) {},
                onPanCancel: () {},
                child: Center(
                  child: _PortDot(
                    color: AppColors.success,
                    emphasised: isSelected,
                  ),
                ),
              ),
            ),

          if (isSelected)
            Positioned(
              left: kNodePadding + kNodeWidth - 11,
              top: kNodePadding - 11,
              child: _DeleteButton(onPressed: onDelete),
            ),
        ],
      ),
    );
  }
}

/// The visual body of a [NodeCard] — background, accent bar, icon and text.
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.node,
    required this.accent,
    required this.isSelected,
    required this.subtitle,
  });

  final ExperimentNode node;
  final Color accent;
  final bool isSelected;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        // Restrained elevation: a neutral drop shadow lifts the card off the
        // canvas, and only the selected card earns a hint of accent colour.
        boxShadow: <BoxShadow>[
          const BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
          if (isSelected)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.16),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        categoryIcon(node.component.category),
                        size: 20,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            node.displayLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single connection port dot.
class _PortDot extends StatelessWidget {
  const _PortDot({required this.color, required this.emphasised});

  final Color color;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: kPortSize,
      height: kPortSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 3),
        boxShadow: <BoxShadow>[
          if (emphasised)
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
            )
          else
            const BoxShadow(color: AppColors.shadow, blurRadius: 4),
        ],
      ),
    );
  }
}

/// The small circular "remove node" affordance shown on the selected card.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.danger,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: AppColors.shadow, blurRadius: 6),
          ],
        ),
        child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
      ),
    );
  }
}
