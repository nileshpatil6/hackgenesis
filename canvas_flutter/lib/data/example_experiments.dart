/// Ready-made demo experiments, ported 1:1 from the React app's
/// `src/data/exampleExperiments.ts` (`EXAMPLE_EXPERIMENTS` + `EXAMPLE_LIST`).
///
/// Each entry exposes a [ExampleExperiment.build] closure rather than a const
/// value because the TS source stamps `created: new Date()` at read time.
library;

import 'package:flutter/material.dart';

import '../models/component_data.dart';
import '../models/experiment.dart';

/// A menu entry in the "Load Example" picker.
@immutable
class ExampleExperiment {
  const ExampleExperiment({
    required this.id,
    required this.name,
    required this.category,
    required this.build,
  });

  final String id;
  final String name;
  final String category;

  /// Builds a fresh graph (with a current `created` timestamp).
  final ExperimentJson Function() build;
}

ExperimentJson _simpleCircuit() {
  return ExperimentJson(
    nodes: const [
      ExperimentNode(
        id: '1',
        position: Offset(100, 100),
        label: 'Power Source 5V USB',
        component: ComponentData(
          id: 'power_5',
          label: 'Power Source 5V USB',
          category: 'electronics',
          description: 'Electrical power supply',
          icon: '🔋',
          properties: {'voltage': 5, 'type': 'supply'},
          inputs: 0,
          outputs: 1,
        ),
      ),
      ExperimentNode(
        id: '2',
        position: Offset(350, 100),
        label: 'Resistor 220Ω',
        component: ComponentData(
          id: 'resistor_220',
          label: 'Resistor 220Ω',
          category: 'electronics',
          description: 'Electrical resistance component',
          icon: '⚡',
          properties: {'resistance': 220, 'unit': 'Ω'},
          inputs: 1,
          outputs: 1,
        ),
      ),
      ExperimentNode(
        id: '3',
        position: Offset(600, 100),
        label: 'LED Red',
        component: ComponentData(
          id: 'diode_led_red',
          label: 'LED Red',
          category: 'electronics',
          description: 'One-way current flow',
          icon: '▶',
          properties: {'type': 'led', 'color': 'red'},
          inputs: 1,
          outputs: 0,
        ),
      ),
    ],
    edges: const [
      ExperimentEdge(id: 'e1-2', source: '1', target: '2', label: '+5V'),
      ExperimentEdge(id: 'e2-3', source: '2', target: '3', label: '22.7mA'),
    ],
    title: 'Simple LED Circuit',
    description: 'A basic circuit with a power source, resistor, and LED',
    created: DateTime.now(),
  );
}

ExperimentJson _chemicalReaction() {
  return ExperimentJson(
    nodes: const [
      ExperimentNode(
        id: '1',
        position: Offset(100, 100),
        label: 'Hydrochloric Acid (HCl)',
        component: ComponentData(
          id: 'acid_hcl',
          label: 'Hydrochloric Acid (HCl)',
          category: 'chemicals',
          description: 'Acidic compound',
          icon: '🧪',
          properties: {'formula': 'HCl', 'pH': 1},
          inputs: 0,
          outputs: 1,
        ),
      ),
      ExperimentNode(
        id: '2',
        position: Offset(100, 250),
        label: 'Sodium Hydroxide (NaOH)',
        component: ComponentData(
          id: 'base_naoh',
          label: 'Sodium Hydroxide (NaOH)',
          category: 'chemicals',
          description: 'Basic compound',
          icon: '🧪',
          properties: {'formula': 'NaOH', 'pH': 14},
          inputs: 0,
          outputs: 1,
        ),
      ),
      ExperimentNode(
        id: '3',
        position: Offset(400, 175),
        label: 'Beaker 250ml',
        component: ComponentData(
          id: 'beaker_250',
          label: 'Beaker 250ml',
          category: 'chemicals',
          description: 'Laboratory equipment',
          icon: '🔬',
          properties: {'type': 'beaker', 'volume': 250},
          inputs: 2,
          outputs: 1,
        ),
      ),
    ],
    edges: const [
      ExperimentEdge(id: 'e1-3', source: '1', target: '3', label: 'HCl'),
      ExperimentEdge(id: 'e2-3', source: '2', target: '3', label: 'NaOH'),
    ],
    title: 'Acid-Base Neutralization',
    description: 'Mixing hydrochloric acid with sodium hydroxide',
    created: DateTime.now(),
  );
}

ExperimentJson _pendulumPhysics() {
  return ExperimentJson(
    nodes: const [
      ExperimentNode(
        id: '1',
        position: Offset(250, 50),
        label: 'Pendulum',
        component: ComponentData(
          id: 'pendulum',
          label: 'Pendulum',
          category: 'physics',
          description: 'Mechanical component',
          icon: '⚙️',
          properties: {'type': 'pendulum', 'length': 1},
          inputs: 1,
          outputs: 1,
        ),
      ),
      ExperimentNode(
        id: '2',
        position: Offset(250, 200),
        label: 'Mass 1kg',
        component: ComponentData(
          id: 'mass_1kg',
          label: 'Mass 1kg',
          category: 'physics',
          description: 'Mechanical component',
          icon: '⚙️',
          properties: {'type': 'mass', 'value': 1, 'unit': 'kg'},
          inputs: 1,
          outputs: 1,
        ),
      ),
      ExperimentNode(
        id: '3',
        position: Offset(250, 350),
        label: 'Gravity 9.8m/s²',
        component: ComponentData(
          id: 'gravity',
          label: 'Gravity 9.8m/s²',
          category: 'physics',
          description: 'Force vector',
          icon: '➡️',
          properties: {'type': 'gravity', 'value': 9.8},
          inputs: 0,
          outputs: 1,
        ),
      ),
    ],
    edges: const [
      ExperimentEdge(id: 'e1-2', source: '1', target: '2', label: 'attached'),
      ExperimentEdge(id: 'e3-2', source: '3', target: '2', label: 'force'),
    ],
    title: 'Simple Pendulum',
    description: 'Physics simulation of a pendulum under gravity',
    created: DateTime.now(),
  );
}

ExperimentJson _logicFlow() {
  return ExperimentJson(
    nodes: const [
      ExperimentNode(
        id: '1',
        position: Offset(100, 150),
        label: 'Number Variable',
        component: ComponentData(
          id: 'var_number',
          label: 'Variable Number',
          category: 'coding',
          description: 'Data storage',
          icon: '📦',
          properties: {'type': 'number', 'value': 10},
          inputs: 1,
          outputs: 1,
        ),
      ),
      ExperimentNode(
        id: '2',
        position: Offset(350, 150),
        label: 'Compare > 5',
        component: ComponentData(
          id: 'compare_gt',
          label: 'Compare Greater >',
          category: 'coding',
          description: 'Comparison operator',
          icon: '⚖️',
          properties: {'operator': '>', 'symbol': '>'},
          inputs: 2,
          outputs: 1,
        ),
      ),
      ExperimentNode(
        id: '3',
        position: Offset(600, 150),
        label: 'If Statement',
        component: ComponentData(
          id: 'if_statement',
          label: 'If Statement',
          category: 'coding',
          description: 'Control flow',
          icon: '🔀',
          properties: {'type': 'if'},
          inputs: 1,
          outputs: 2,
        ),
      ),
    ],
    edges: const [
      ExperimentEdge(id: 'e1-2', source: '1', target: '2', label: 'value'),
      ExperimentEdge(id: 'e2-3', source: '2', target: '3', label: 'condition'),
    ],
    title: 'Conditional Logic Flow',
    description: 'Programming logic with variables and conditions',
    created: DateTime.now(),
  );
}

/// The picker list, in the same order as the TS `EXAMPLE_LIST` export.
const List<ExampleExperiment> kExampleExperiments = <ExampleExperiment>[
  ExampleExperiment(
    id: 'simpleCircuit',
    name: 'Simple LED Circuit',
    category: 'Electronics',
    build: _simpleCircuit,
  ),
  ExampleExperiment(
    id: 'chemicalReaction',
    name: 'Acid-Base Neutralization',
    category: 'Chemistry',
    build: _chemicalReaction,
  ),
  ExampleExperiment(
    id: 'pendulumPhysics',
    name: 'Simple Pendulum',
    category: 'Physics',
    build: _pendulumPhysics,
  ),
  ExampleExperiment(
    id: 'logicFlow',
    name: 'Conditional Logic Flow',
    category: 'Coding',
    build: _logicFlow,
  ),
];

/// Builds the example with the given [id], or returns `null` when unknown.
ExperimentJson? buildExample(String id) {
  for (final ExampleExperiment e in kExampleExperiments) {
    if (e.id == id) return e.build();
  }
  return null;
}
