import 'package:flutter/material.dart';

import '../canvas/shape_recognition.dart';
import '../data/component_library.dart';
import '../models/component_data.dart';
import '../theme/app_theme.dart';

/// Builds a component the library does not ship.
///
/// The library covers a lot of ground but never everything, and an experiment
/// stalls the moment a player cannot represent the one part they care about.
/// A custom block is an ordinary [ComponentData], so it connects, runs and
/// exports exactly like a built-in one; only its category marks it as
/// player-authored.
class CustomComponentDialog extends StatefulWidget {
  const CustomComponentDialog({super.key});

  /// Shows the dialog, resolving to the new component or to `null` on cancel.
  static Future<ComponentData?> show(BuildContext context) {
    return showDialog<ComponentData>(
      context: context,
      builder: (BuildContext context) => const CustomComponentDialog(),
    );
  }

  @override
  State<CustomComponentDialog> createState() => _CustomComponentDialogState();
}

class _CustomComponentDialogState extends State<CustomComponentDialog> {
  final TextEditingController _label = TextEditingController();
  final TextEditingController _description = TextEditingController();

  /// Which field the block belongs to.
  ///
  /// Defaults to the player-authored category rather than guessing a science,
  /// so an unedited choice never mislabels the block.
  String _categoryId = kCustomCategory;

  bool get _canSubmit => _label.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // The submit button tracks the name field, so it cannot be pressed on an
    // empty block.
    _label.addListener(_onLabelChanged);
  }

  @override
  void dispose() {
    _label.removeListener(_onLabelChanged);
    _label.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onLabelChanged() => setState(() {});

  void _submit() {
    final String label = _label.text.trim();
    if (label.isEmpty) return;

    final String description = _description.text.trim();
    Navigator.of(context).pop(
      ComponentData(
        // The canvas suffixes this with a unique run of digits, so a stable
        // prefix here is enough and keeps exported JSON readable.
        id: 'custom_${label.toLowerCase().replaceAll(RegExp(r'\s+'), '_')}',
        label: label,
        category: _categoryId,
        description: description.isEmpty ? 'Custom block' : description,
        icon: '🧩',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create a custom block'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Anything the library is missing. It behaves like every other '
                'block once it is on the canvas.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _label,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Peltier module',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What it does (optional)',
                  hintText: 'e.g. Moves heat when current flows',
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 18),
              const Text(
                'FIELD',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _categoryChip(kCustomCategory, 'Custom'),
                  for (final ComponentCategory category in kCategories)
                    _categoryChip(category.id, category.label),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Add to canvas'),
        ),
      ],
    );
  }

  Widget _categoryChip(String id, String label) {
    final bool selected = _categoryId == id;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _categoryId = id),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Asks the player to name a shape they just drew.
///
/// Returns the trimmed label, or `null` when they back out (in which case the
/// shape is discarded rather than dropped on the canvas unnamed).
Future<String?> showShapeLabelDialog(
  BuildContext context,
  ShapeKind kind,
) {
  final String name = shapeName(kind);
  final TextEditingController controller = TextEditingController(
    // Pre-filled and selected, so accepting the shape name is one tap and
    // replacing it is one keystroke.
    text: '${name[0].toUpperCase()}${name.substring(1)}',
  );
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );

  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text('Name this $name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Beaker, Rotor, Cell'),
        onSubmitted: (String value) =>
            Navigator.of(context).pop(value.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Add'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
