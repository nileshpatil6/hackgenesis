import 'package:flutter/material.dart';

import '../canvas/node_card.dart' show categoryColor, categoryIcon;
import '../data/component_library.dart';
import '../models/component_data.dart';
import '../theme/app_theme.dart';

/// Browsable, searchable palette of every component family the player can
/// place.
///
/// Each row is one family (e.g. "Resistor") rather than every individual
/// variation, so the list stays short enough to scan instead of burying
/// every other family under ten resistor values. Tapping a family expands
/// it in place to reveal its variations; tapping a variation adds it to the
/// middle of the visible viewport.
class ComponentLibraryPanel extends StatefulWidget {
  const ComponentLibraryPanel({super.key, required this.onQuickAdd});

  /// Called when a variation is tapped — the host drops the component at
  /// the centre of the visible canvas.
  final ValueChanged<ComponentData> onQuickAdd;

  @override
  State<ComponentLibraryPanel> createState() => _ComponentLibraryPanelState();
}

class _ComponentLibraryPanelState extends State<ComponentLibraryPanel> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryId;
  final Set<String> _expandedFamilyIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ComponentFamily> get _families =>
      searchFamilies(_query, categoryId: _categoryId);

  /// Expands (or adds straight to canvas, for a single-variation family)
  /// when tapped; collapses back when tapped again while expanded.
  void _onFamilyTap(ComponentFamily family, List<ComponentData> variations) {
    if (variations.length <= 1) {
      if (variations.isNotEmpty) widget.onQuickAdd(variations.single);
      return;
    }
    setState(() {
      if (!_expandedFamilyIds.remove(family.id)) {
        _expandedFamilyIds.add(family.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final families = _families;
    // Searching hunts for a specific variation, so every matching family
    // auto-expands instead of making the user tap in twice.
    final bool searching = _query.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(families.length),
          _buildCategoryChips(),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: families.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    itemCount: families.length,
                    itemBuilder: (context, i) {
                      final family = families[i];
                      final variations = familyVariations(family.id);
                      final expanded =
                          searching || _expandedFamilyIds.contains(family.id);
                      return _FamilyGroup(
                        family: family,
                        variations: variations,
                        expanded: expanded,
                        onFamilyTap: () => _onFamilyTap(family, variations),
                        onVariationTap: widget.onQuickAdd,
                      );
                    },
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
            icon: Icons.auto_awesome,
            color: AppColors.primary,
            selected: _categoryId == null,
            onTap: () => setState(() => _categoryId = null),
          ),
          for (final c in kCategories)
            _CategoryChip(
              label: c.label,
              icon: categoryIcon(c.id),
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
  final IconData icon;
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
                  Icon(
                    icon,
                    size: 13,
                    color: selected ? color : AppColors.textSecondary,
                  ),
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

/// One family header, plus its variations directly beneath when [expanded].
class _FamilyGroup extends StatelessWidget {
  const _FamilyGroup({
    required this.family,
    required this.variations,
    required this.expanded,
    required this.onFamilyTap,
    required this.onVariationTap,
  });

  final ComponentFamily family;
  final List<ComponentData> variations;
  final bool expanded;
  final VoidCallback onFamilyTap;
  final ValueChanged<ComponentData> onVariationTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FamilyHeaderTile(
          family: family,
          variationCount: variations.length,
          expanded: expanded,
          onTap: onFamilyTap,
        ),
        if (expanded)
          for (final component in variations)
            _VariationTile(
              component: component,
              onTap: () => onVariationTap(component),
            ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _FamilyHeaderTile extends StatelessWidget {
  const _FamilyHeaderTile({
    required this.family,
    required this.variationCount,
    required this.expanded,
    required this.onTap,
  });

  final ComponentFamily family;
  final int variationCount;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(family.category);
    final bool expandable = variationCount > 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: expanded
            ? const BorderRadius.vertical(top: Radius.circular(10))
            : BorderRadius.circular(10),
        border: Border.all(color: expanded ? color : AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
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
                  child: Icon(
                    categoryIcon(family.category),
                    size: 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        family.label,
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
                        family.description,
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
                if (expandable) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$variationCount',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.expand_more,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ] else
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
  }
}

/// One variation, indented under its expanded [_FamilyHeaderTile].
class _VariationTile extends StatelessWidget {
  const _VariationTile({required this.component, required this.onTap});

  final ComponentData component;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(component.category);

    return Container(
      margin: const EdgeInsets.only(left: 14, top: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.35), width: 2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    component.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.add_circle_outline,
                  size: 14,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
