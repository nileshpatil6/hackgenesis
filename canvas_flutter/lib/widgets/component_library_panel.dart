import 'package:flutter/material.dart';

import '../canvas/node_card.dart' show categoryColor;
import '../data/component_library.dart';
import '../models/component_data.dart';
import '../theme/app_theme.dart';

/// Browsable, searchable palette of every component the player can place.
///
/// Tiles are [Draggable] (drop onto the canvas) and also tappable, which adds
/// the component straight to the middle of the viewport — essential on touch
/// devices where dragging across a small screen is awkward.
class ComponentLibraryPanel extends StatefulWidget {
  const ComponentLibraryPanel({
    super.key,
    required this.onQuickAdd,
    this.onDragStarted,
    this.onDragEnded,
  });

  /// Called when a tile is tapped — the host drops the component at the
  /// centre of the visible canvas.
  final ValueChanged<ComponentData> onQuickAdd;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  State<ComponentLibraryPanel> createState() => _ComponentLibraryPanelState();
}

class _ComponentLibraryPanelState extends State<ComponentLibraryPanel> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ComponentData> get _results =>
      searchComponents(_query, categoryId: _categoryId);

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(results.length),
          _buildCategoryChips(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: results.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, i) => _ComponentTile(
                      component: results[i],
                      onQuickAdd: () => widget.onQuickAdd(results[i]),
                      onDragStarted: widget.onDragStarted,
                      onDragEnded: widget.onDragEnded,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.widgets_outlined,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Components',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search 300+ components…',
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppColors.textMuted,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: AppColors.textMuted,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _CategoryChip(
            label: 'All',
            icon: '✨',
            color: AppColors.primary,
            selected: _categoryId == null,
            onTap: () => setState(() => _categoryId = null),
          ),
          for (final c in kCategories)
            _CategoryChip(
              label: c.label,
              icon: c.icon,
              color: c.color,
              selected: _categoryId == c.id,
              onTap: () => setState(
                () => _categoryId = _categoryId == c.id ? null : c.id,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 30, color: AppColors.textMuted),
            SizedBox(height: 10),
            Text(
              'No components match',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Try a different search or category.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Center(
        child: Material(
          color: selected
              ? color.withValues(alpha: 0.18)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? color : AppColors.border,
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({
    required this.component,
    required this.onQuickAdd,
    this.onDragStarted,
    this.onDragEnded,
  });

  final ComponentData component;
  final VoidCallback onQuickAdd;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(component.category);

    final tile = Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onQuickAdd,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    component.icon,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        component.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        component.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Draggable<ComponentData>(
      data: component,
      onDragStarted: onDragStarted,
      onDragEnd: (_) => onDragEnded?.call(),
      onDraggableCanceled: (_, _) => onDragEnded?.call(),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragGhost(component: component, color: color),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _DragGhost extends StatelessWidget {
  const _DragGhost({required this.component, required this.color});

  final ComponentData component;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(-70, -26),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(component.icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  component.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
