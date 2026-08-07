/// The full component library, ported 1:1 from the React app's
/// `src/data/componentLibrary.ts`.
///
/// Every component is produced by [_generate], the Dart equivalent of the
/// TypeScript `generateComponents(base, variations)` helper, so ids, labels,
/// descriptions and merged properties match the web build exactly.
library;

import 'package:flutter/material.dart';

import '../models/component_data.dart';

/// One entry of the `variations` array passed to `generateComponents` in TS.
@immutable
class _Variation {
  const _Variation(this.suffix, [this.props]);

  final String suffix;
  final Map<String, dynamic>? props;
}

/// One [ComponentFamily] per call to [_generate], in call order.
///
/// Populated as a side effect of building [kComponentLibrary] — every read
/// of this list goes through [kComponentFamilies], which touches
/// `kComponentLibrary` first to guarantee it has already been populated.
final List<ComponentFamily> _familyOrder = <ComponentFamily>[];

/// Dart port of the TS `generateComponents(base, variations)` helper.
///
/// `id` becomes `<base.id>_<index>`, `label` becomes `<base.label> <suffix>`,
/// `description` becomes `<base.description> - <suffix>` and `properties` is
/// `base.properties` shallow-merged with the variation's props.
///
/// Note: the TS source writes `base.inputs || 1` / `base.outputs || 1`, so a
/// base declaring `0` ports/outputs falls back to `1`. That quirk is preserved
/// here so the Dart library is byte-for-byte equivalent to the web one.
List<ComponentData> _generate(ComponentData base, List<_Variation> variations) {
  _familyOrder.add(
    ComponentFamily(
      id: base.id,
      label: base.label,
      category: base.category,
      description: base.description,
    ),
  );
  return List<ComponentData>.generate(variations.length, (int index) {
    final _Variation v = variations[index];
    return ComponentData(
      id: '${base.id}_$index',
      label: '${base.label} ${v.suffix}',
      category: base.category,
      description: '${base.description} - ${v.suffix}',
      icon: base.icon,
      properties: <String, dynamic>{...base.properties, ...?v.props},
      inputs: base.inputs == 0 ? 1 : base.inputs,
      outputs: base.outputs == 0 ? 1 : base.outputs,
    );
  });
}

/// Every component available in the palette (308 entries).
final List<ComponentData> kComponentLibrary = <ComponentData>[
  // ---------------------------------------------------------------- ELECTRONICS
  // Resistors
  ..._generate(
    const ComponentData(
      id: 'resistor',
      label: 'Resistor',
      category: 'electronics',
      description: 'Electrical resistance component',
      icon: '⚡',
      properties: {'resistance': 0, 'unit': 'Ω'},
    ),
    const [
      _Variation('10Ω', {'resistance': 10}),
      _Variation('100Ω', {'resistance': 100}),
      _Variation('1kΩ', {'resistance': 1000}),
      _Variation('10kΩ', {'resistance': 10000}),
      _Variation('100kΩ', {'resistance': 100000}),
      _Variation('1MΩ', {'resistance': 1000000}),
      _Variation('220Ω', {'resistance': 220}),
      _Variation('330Ω', {'resistance': 330}),
      _Variation('470Ω', {'resistance': 470}),
      _Variation('4.7kΩ', {'resistance': 4700}),
    ],
  ),

  // Capacitors
  ..._generate(
    const ComponentData(
      id: 'capacitor',
      label: 'Capacitor',
      category: 'electronics',
      description: 'Energy storage component',
      icon: '⚡',
      properties: {'capacitance': 0, 'unit': 'F'},
    ),
    const [
      _Variation('1pF', {'capacitance': 0.000000000001}),
      _Variation('10pF', {'capacitance': 0.00000000001}),
      _Variation('100pF', {'capacitance': 0.0000000001}),
      _Variation('1nF', {'capacitance': 0.000000001}),
      _Variation('10nF', {'capacitance': 0.00000001}),
      _Variation('100nF', {'capacitance': 0.0000001}),
      _Variation('1μF', {'capacitance': 0.000001}),
      _Variation('10μF', {'capacitance': 0.00001}),
      _Variation('100μF', {'capacitance': 0.0001}),
      _Variation('1000μF', {'capacitance': 0.001}),
    ],
  ),

  // Inductors
  ..._generate(
    const ComponentData(
      id: 'inductor',
      label: 'Inductor',
      category: 'electronics',
      description: 'Magnetic field component',
      icon: '⚡',
      properties: {'inductance': 0, 'unit': 'H'},
    ),
    const [
      _Variation('1μH', {'inductance': 0.000001}),
      _Variation('10μH', {'inductance': 0.00001}),
      _Variation('100μH', {'inductance': 0.0001}),
      _Variation('1mH', {'inductance': 0.001}),
      _Variation('10mH', {'inductance': 0.01}),
      _Variation('100mH', {'inductance': 0.1}),
    ],
  ),

  // Diodes
  ..._generate(
    const ComponentData(
      id: 'diode',
      label: 'Diode',
      category: 'electronics',
      description: 'One-way current flow',
      icon: '▶',
      properties: {'type': 'standard'},
    ),
    const [
      _Variation('1N4148', {'type': 'signal'}),
      _Variation('1N4007', {'type': 'rectifier'}),
      _Variation('LED Red', {'type': 'led', 'color': 'red'}),
      _Variation('LED Green', {'type': 'led', 'color': 'green'}),
      _Variation('LED Blue', {'type': 'led', 'color': 'blue'}),
      _Variation('LED White', {'type': 'led', 'color': 'white'}),
      _Variation('Zener 5V', {'type': 'zener', 'voltage': 5}),
      _Variation('Zener 12V', {'type': 'zener', 'voltage': 12}),
      _Variation('Schottky', {'type': 'schottky'}),
    ],
  ),

  // Transistors
  ..._generate(
    const ComponentData(
      id: 'transistor',
      label: 'Transistor',
      category: 'electronics',
      description: 'Amplification and switching',
      icon: '🔺',
      properties: {'type': 'npn'},
      inputs: 2,
      outputs: 1,
    ),
    const [
      _Variation('NPN 2N2222', {'type': 'npn', 'model': '2N2222'}),
      _Variation('NPN BC547', {'type': 'npn', 'model': 'BC547'}),
      _Variation('PNP 2N2907', {'type': 'pnp', 'model': '2N2907'}),
      _Variation('PNP BC557', {'type': 'pnp', 'model': 'BC557'}),
      _Variation('MOSFET N-Channel', {'type': 'mosfet', 'channel': 'n'}),
      _Variation('MOSFET P-Channel', {'type': 'mosfet', 'channel': 'p'}),
      _Variation('JFET N-Channel', {'type': 'jfet', 'channel': 'n'}),
    ],
  ),

  // Integrated Circuits
  ..._generate(
    const ComponentData(
      id: 'ic',
      label: 'IC',
      category: 'electronics',
      description: 'Integrated Circuit',
      icon: '🔲',
      properties: {'type': 'logic'},
      inputs: 2,
      outputs: 1,
    ),
    const [
      _Variation('555 Timer', {'type': 'timer', 'model': '555'}),
      _Variation('741 Op-Amp', {'type': 'opamp', 'model': '741'}),
      _Variation('7805 Voltage Regulator', {'type': 'regulator', 'voltage': 5}),
      _Variation('7812 Voltage Regulator', {
        'type': 'regulator',
        'voltage': 12,
      }),
      _Variation('AND Gate 7408', {'type': 'logic', 'gate': 'AND'}),
      _Variation('OR Gate 7432', {'type': 'logic', 'gate': 'OR'}),
      _Variation('NOT Gate 7404', {'type': 'logic', 'gate': 'NOT'}),
      _Variation('NAND Gate 7400', {'type': 'logic', 'gate': 'NAND'}),
      _Variation('NOR Gate 7402', {'type': 'logic', 'gate': 'NOR'}),
      _Variation('XOR Gate 7486', {'type': 'logic', 'gate': 'XOR'}),
      _Variation('Arduino Uno', {
        'type': 'microcontroller',
        'model': 'Arduino',
      }),
      _Variation('Raspberry Pi', {'type': 'microcontroller', 'model': 'RPi'}),
      _Variation('ESP32', {'type': 'microcontroller', 'model': 'ESP32'}),
    ],
  ),

  // Power Sources
  ..._generate(
    const ComponentData(
      id: 'power',
      label: 'Power Source',
      category: 'electronics',
      description: 'Electrical power supply',
      icon: '🔋',
      properties: {'voltage': 0},
      inputs: 0,
      outputs: 1,
    ),
    const [
      _Variation('1.5V Battery', {'voltage': 1.5, 'type': 'battery'}),
      _Variation('3.7V Li-ion', {'voltage': 3.7, 'type': 'battery'}),
      _Variation('5V USB', {'voltage': 5, 'type': 'supply'}),
      _Variation('9V Battery', {'voltage': 9, 'type': 'battery'}),
      _Variation('12V DC', {'voltage': 12, 'type': 'supply'}),
      _Variation('24V DC', {'voltage': 24, 'type': 'supply'}),
      _Variation('120V AC', {'voltage': 120, 'type': 'ac'}),
      _Variation('240V AC', {'voltage': 240, 'type': 'ac'}),
    ],
  ),

  // Sensors
  ..._generate(
    const ComponentData(
      id: 'sensor',
      label: 'Sensor',
      category: 'electronics',
      description: 'Environmental sensor',
      icon: '📡',
      properties: {'type': 'generic'},
      inputs: 0,
      outputs: 1,
    ),
    const [
      _Variation('Temperature DHT11', {
        'type': 'temperature',
        'model': 'DHT11',
      }),
      _Variation('Temperature DHT22', {
        'type': 'temperature',
        'model': 'DHT22',
      }),
      _Variation('Humidity', {'type': 'humidity'}),
      _Variation('Pressure BMP180', {'type': 'pressure', 'model': 'BMP180'}),
      _Variation('Light LDR', {'type': 'light', 'model': 'LDR'}),
      _Variation('Ultrasonic HC-SR04', {
        'type': 'distance',
        'model': 'HC-SR04',
      }),
      _Variation('PIR Motion', {'type': 'motion', 'model': 'PIR'}),
      _Variation('Gas MQ-2', {'type': 'gas', 'model': 'MQ-2'}),
      _Variation('Accelerometer MPU6050', {
        'type': 'accelerometer',
        'model': 'MPU6050',
      }),
      _Variation('Gyroscope MPU6050', {
        'type': 'gyroscope',
        'model': 'MPU6050',
      }),
      _Variation('Hall Effect', {'type': 'magnetic'}),
    ],
  ),

  // Displays
  ..._generate(
    const ComponentData(
      id: 'display',
      label: 'Display',
      category: 'electronics',
      description: 'Output display',
      icon: '📺',
      properties: {'type': 'generic'},
      inputs: 1,
      outputs: 0,
    ),
    const [
      _Variation('7-Segment', {'type': '7segment'}),
      _Variation('LCD 16x2', {'type': 'lcd', 'size': '16x2'}),
      _Variation('LCD 20x4', {'type': 'lcd', 'size': '20x4'}),
      _Variation('OLED 128x64', {'type': 'oled', 'size': '128x64'}),
      _Variation('TFT Display', {'type': 'tft'}),
      _Variation('LED Matrix 8x8', {'type': 'matrix', 'size': '8x8'}),
    ],
  ),

  // ------------------------------------------------------------------ CHEMICALS
  // Elements
  ..._generate(
    const ComponentData(
      id: 'element',
      label: 'Element',
      category: 'chemicals',
      description: 'Chemical element',
      icon: '⚗️',
      properties: {'symbol': '', 'atomicNumber': 0},
    ),
    const [
      _Variation('Hydrogen (H)', {'symbol': 'H', 'atomicNumber': 1}),
      _Variation('Helium (He)', {'symbol': 'He', 'atomicNumber': 2}),
      _Variation('Carbon (C)', {'symbol': 'C', 'atomicNumber': 6}),
      _Variation('Nitrogen (N)', {'symbol': 'N', 'atomicNumber': 7}),
      _Variation('Oxygen (O)', {'symbol': 'O', 'atomicNumber': 8}),
      _Variation('Fluorine (F)', {'symbol': 'F', 'atomicNumber': 9}),
      _Variation('Sodium (Na)', {'symbol': 'Na', 'atomicNumber': 11}),
      _Variation('Magnesium (Mg)', {'symbol': 'Mg', 'atomicNumber': 12}),
      _Variation('Aluminum (Al)', {'symbol': 'Al', 'atomicNumber': 13}),
      _Variation('Silicon (Si)', {'symbol': 'Si', 'atomicNumber': 14}),
      _Variation('Phosphorus (P)', {'symbol': 'P', 'atomicNumber': 15}),
      _Variation('Sulfur (S)', {'symbol': 'S', 'atomicNumber': 16}),
      _Variation('Chlorine (Cl)', {'symbol': 'Cl', 'atomicNumber': 17}),
      _Variation('Potassium (K)', {'symbol': 'K', 'atomicNumber': 19}),
      _Variation('Calcium (Ca)', {'symbol': 'Ca', 'atomicNumber': 20}),
      _Variation('Iron (Fe)', {'symbol': 'Fe', 'atomicNumber': 26}),
      _Variation('Copper (Cu)', {'symbol': 'Cu', 'atomicNumber': 29}),
      _Variation('Zinc (Zn)', {'symbol': 'Zn', 'atomicNumber': 30}),
      _Variation('Silver (Ag)', {'symbol': 'Ag', 'atomicNumber': 47}),
      _Variation('Gold (Au)', {'symbol': 'Au', 'atomicNumber': 79}),
    ],
  ),

  // Acids
  ..._generate(
    const ComponentData(
      id: 'acid',
      label: 'Acid',
      category: 'chemicals',
      description: 'Acidic compound',
      icon: '🧪',
      properties: {'pH': 0, 'concentration': '1M'},
    ),
    const [
      _Variation('Hydrochloric (HCl)', {'formula': 'HCl', 'pH': 1}),
      _Variation('Sulfuric (H2SO4)', {'formula': 'H2SO4', 'pH': 1}),
      _Variation('Nitric (HNO3)', {'formula': 'HNO3', 'pH': 1}),
      _Variation('Acetic (CH3COOH)', {'formula': 'CH3COOH', 'pH': 3}),
      _Variation('Citric', {'formula': 'C6H8O7', 'pH': 3}),
      _Variation('Phosphoric (H3PO4)', {'formula': 'H3PO4', 'pH': 2}),
      _Variation('Carbonic (H2CO3)', {'formula': 'H2CO3', 'pH': 4}),
    ],
  ),

  // Bases
  ..._generate(
    const ComponentData(
      id: 'base',
      label: 'Base',
      category: 'chemicals',
      description: 'Basic compound',
      icon: '🧪',
      properties: {'pH': 14, 'concentration': '1M'},
    ),
    const [
      _Variation('Sodium Hydroxide (NaOH)', {'formula': 'NaOH', 'pH': 14}),
      _Variation('Potassium Hydroxide (KOH)', {'formula': 'KOH', 'pH': 14}),
      _Variation('Calcium Hydroxide (Ca(OH)2)', {
        'formula': 'Ca(OH)2',
        'pH': 12,
      }),
      _Variation('Ammonia (NH3)', {'formula': 'NH3', 'pH': 11}),
      _Variation('Sodium Carbonate (Na2CO3)', {'formula': 'Na2CO3', 'pH': 11}),
    ],
  ),

  // Salts
  ..._generate(
    const ComponentData(
      id: 'salt',
      label: 'Salt',
      category: 'chemicals',
      description: 'Ionic compound',
      icon: '🧂',
      properties: {'formula': '', 'solubility': 'soluble'},
    ),
    const [
      _Variation('Sodium Chloride (NaCl)', {'formula': 'NaCl'}),
      _Variation('Potassium Chloride (KCl)', {'formula': 'KCl'}),
      _Variation('Calcium Chloride (CaCl2)', {'formula': 'CaCl2'}),
      _Variation('Magnesium Sulfate (MgSO4)', {'formula': 'MgSO4'}),
      _Variation('Copper Sulfate (CuSO4)', {
        'formula': 'CuSO4',
        'color': 'blue',
      }),
      _Variation('Silver Nitrate (AgNO3)', {'formula': 'AgNO3'}),
      _Variation('Barium Chloride (BaCl2)', {'formula': 'BaCl2'}),
    ],
  ),

  // Organic Compounds
  ..._generate(
    const ComponentData(
      id: 'organic',
      label: 'Organic',
      category: 'chemicals',
      description: 'Organic compound',
      icon: '🧬',
      properties: {'formula': '', 'type': 'hydrocarbon'},
    ),
    const [
      _Variation('Methane (CH4)', {'formula': 'CH4', 'type': 'alkane'}),
      _Variation('Ethane (C2H6)', {'formula': 'C2H6', 'type': 'alkane'}),
      _Variation('Propane (C3H8)', {'formula': 'C3H8', 'type': 'alkane'}),
      _Variation('Butane (C4H10)', {'formula': 'C4H10', 'type': 'alkane'}),
      _Variation('Ethene (C2H4)', {'formula': 'C2H4', 'type': 'alkene'}),
      _Variation('Benzene (C6H6)', {'formula': 'C6H6', 'type': 'aromatic'}),
      _Variation('Ethanol (C2H5OH)', {'formula': 'C2H5OH', 'type': 'alcohol'}),
      _Variation('Methanol (CH3OH)', {'formula': 'CH3OH', 'type': 'alcohol'}),
      _Variation('Acetone (C3H6O)', {'formula': 'C3H6O', 'type': 'ketone'}),
      _Variation('Glucose (C6H12O6)', {'formula': 'C6H12O6', 'type': 'sugar'}),
    ],
  ),

  // Lab Equipment (Chemical)
  ..._generate(
    const ComponentData(
      id: 'chem_equipment',
      label: 'Equipment',
      category: 'chemicals',
      description: 'Laboratory equipment',
      icon: '🔬',
      properties: {'type': 'glassware'},
    ),
    const [
      _Variation('Beaker 50ml', {'type': 'beaker', 'volume': 50}),
      _Variation('Beaker 250ml', {'type': 'beaker', 'volume': 250}),
      _Variation('Flask 100ml', {'type': 'flask', 'volume': 100}),
      _Variation('Test Tube', {'type': 'test_tube'}),
      _Variation('Burette', {'type': 'burette'}),
      _Variation('Pipette', {'type': 'pipette'}),
      _Variation('Bunsen Burner', {'type': 'burner', 'maxTemp': 1500}),
      _Variation('Hot Plate', {'type': 'heater', 'maxTemp': 400}),
      _Variation('pH Meter', {'type': 'meter', 'measures': 'pH'}),
      _Variation('Thermometer', {'type': 'thermometer'}),
    ],
  ),

  // -------------------------------------------------------------------- PHYSICS
  // Mechanics
  ..._generate(
    const ComponentData(
      id: 'mechanics',
      label: 'Mechanics',
      category: 'mechanics',
      description: 'Mechanical component',
      icon: '⚙️',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('Mass 1kg', {'type': 'mass', 'value': 1, 'unit': 'kg'}),
      _Variation('Mass 5kg', {'type': 'mass', 'value': 5, 'unit': 'kg'}),
      _Variation('Mass 10kg', {'type': 'mass', 'value': 10, 'unit': 'kg'}),
      _Variation('Spring k=100', {'type': 'spring', 'constant': 100}),
      _Variation('Spring k=500', {'type': 'spring', 'constant': 500}),
      _Variation('Pulley', {'type': 'pulley'}),
      _Variation('Inclined Plane 30°', {'type': 'incline', 'angle': 30}),
      _Variation('Inclined Plane 45°', {'type': 'incline', 'angle': 45}),
      _Variation('Lever', {'type': 'lever'}),
      _Variation('Wheel & Axle', {'type': 'wheel_axle'}),
      _Variation('Pendulum', {'type': 'pendulum', 'length': 1}),
    ],
  ),

  // Forces
  ..._generate(
    const ComponentData(
      id: 'force',
      label: 'Force',
      category: 'physics',
      description: 'Force vector',
      icon: '➡️',
      properties: {'magnitude': 0, 'direction': 0},
      inputs: 0,
      outputs: 1,
    ),
    const [
      _Variation('10N', {'magnitude': 10, 'unit': 'N'}),
      _Variation('50N', {'magnitude': 50, 'unit': 'N'}),
      _Variation('100N', {'magnitude': 100, 'unit': 'N'}),
      _Variation('Gravity 9.8m/s²', {'type': 'gravity', 'value': 9.8}),
      _Variation('Friction', {'type': 'friction'}),
      _Variation('Normal Force', {'type': 'normal'}),
      _Variation('Tension', {'type': 'tension'}),
    ],
  ),

  // Optics
  ..._generate(
    const ComponentData(
      id: 'optics',
      label: 'Optics',
      category: 'optics',
      description: 'Optical component',
      icon: '🔍',
      properties: {'type': 'lens'},
    ),
    const [
      _Variation('Convex Lens f=10cm', {'type': 'convex', 'focal': 10}),
      _Variation('Convex Lens f=20cm', {'type': 'convex', 'focal': 20}),
      _Variation('Concave Lens f=-10cm', {'type': 'concave', 'focal': -10}),
      _Variation('Plane Mirror', {'type': 'mirror', 'shape': 'plane'}),
      _Variation('Concave Mirror', {'type': 'mirror', 'shape': 'concave'}),
      _Variation('Convex Mirror', {'type': 'mirror', 'shape': 'convex'}),
      _Variation('Prism', {'type': 'prism', 'angle': 60}),
      _Variation('Glass Block', {'type': 'block', 'refractiveIndex': 1.5}),
      _Variation('Light Source White', {'type': 'light', 'color': 'white'}),
      _Variation('Light Source Red', {
        'type': 'light',
        'color': 'red',
        'wavelength': 650,
      }),
      _Variation('Light Source Blue', {
        'type': 'light',
        'color': 'blue',
        'wavelength': 450,
      }),
      _Variation('Laser Red', {'type': 'laser', 'color': 'red', 'power': 5}),
    ],
  ),

  // Waves
  ..._generate(
    const ComponentData(
      id: 'waves',
      label: 'Waves',
      category: 'physics',
      description: 'Wave phenomena',
      icon: '〰️',
      properties: {'frequency': 0, 'amplitude': 0},
    ),
    const [
      _Variation('Sound Wave 440Hz', {'type': 'sound', 'frequency': 440}),
      _Variation('Sound Wave 1kHz', {'type': 'sound', 'frequency': 1000}),
      _Variation('Radio Wave FM', {'type': 'radio', 'band': 'FM'}),
      _Variation('Microwave', {'type': 'electromagnetic', 'wavelength': 0.01}),
      _Variation('X-Ray', {'type': 'electromagnetic', 'wavelength': 0.000001}),
      _Variation('Gamma Ray', {
        'type': 'electromagnetic',
        'wavelength': 0.0000001,
      }),
    ],
  ),

  // ------------------------------------------------------------- THERMODYNAMICS
  ..._generate(
    const ComponentData(
      id: 'thermo',
      label: 'Thermodynamics',
      category: 'thermodynamics',
      description: 'Thermal component',
      icon: '🌡️',
      properties: {'temperature': 0},
    ),
    const [
      _Variation('Heat Source 100°C', {'type': 'source', 'temperature': 100}),
      _Variation('Heat Source 500°C', {'type': 'source', 'temperature': 500}),
      _Variation('Ice Bath 0°C', {'type': 'sink', 'temperature': 0}),
      _Variation('Insulator', {'type': 'insulator'}),
      _Variation('Conductor Copper', {
        'type': 'conductor',
        'material': 'copper',
      }),
      _Variation('Gas Ideal', {'type': 'gas', 'behavior': 'ideal'}),
      _Variation('Piston', {'type': 'piston'}),
    ],
  ),

  // --------------------------------------------------------------------- CODING
  // Logic
  ..._generate(
    const ComponentData(
      id: 'logic_block',
      label: 'Logic',
      category: 'coding',
      description: 'Programming logic',
      icon: '💻',
      properties: {'type': 'operation'},
      inputs: 2,
      outputs: 1,
    ),
    const [
      _Variation('AND', {'operation': 'AND'}),
      _Variation('OR', {'operation': 'OR'}),
      _Variation('NOT', {'operation': 'NOT'}),
      _Variation('XOR', {'operation': 'XOR'}),
      _Variation('NAND', {'operation': 'NAND'}),
      _Variation('NOR', {'operation': 'NOR'}),
    ],
  ),

  // Arithmetic
  ..._generate(
    const ComponentData(
      id: 'arithmetic',
      label: 'Math',
      category: 'coding',
      description: 'Arithmetic operation',
      icon: '➕',
      properties: {'operation': 'add'},
      inputs: 2,
      outputs: 1,
    ),
    const [
      _Variation('Add', {'operation': 'add', 'symbol': '+'}),
      _Variation('Subtract', {'operation': 'subtract', 'symbol': '-'}),
      _Variation('Multiply', {'operation': 'multiply', 'symbol': '×'}),
      _Variation('Divide', {'operation': 'divide', 'symbol': '÷'}),
      _Variation('Modulo', {'operation': 'modulo', 'symbol': '%'}),
      _Variation('Power', {'operation': 'power', 'symbol': '^'}),
      _Variation('Square Root', {'operation': 'sqrt', 'symbol': '√'}),
    ],
  ),

  // Comparison
  ..._generate(
    const ComponentData(
      id: 'comparison',
      label: 'Compare',
      category: 'coding',
      description: 'Comparison operator',
      icon: '⚖️',
      properties: {'operator': 'equal'},
      inputs: 2,
      outputs: 1,
    ),
    const [
      _Variation('Equal ==', {'operator': '==', 'symbol': '=='}),
      _Variation('Not Equal !=', {'operator': '!=', 'symbol': '!='}),
      _Variation('Greater >', {'operator': '>', 'symbol': '>'}),
      _Variation('Less <', {'operator': '<', 'symbol': '<'}),
      _Variation('Greater Equal >=', {'operator': '>=', 'symbol': '>='}),
      _Variation('Less Equal <=', {'operator': '<=', 'symbol': '<='}),
    ],
  ),

  // Control Flow
  ..._generate(
    const ComponentData(
      id: 'control',
      label: 'Control',
      category: 'coding',
      description: 'Control flow',
      icon: '🔀',
      properties: {'type': 'if'},
      inputs: 1,
      outputs: 2,
    ),
    const [
      _Variation('If Statement', {'type': 'if'}),
      _Variation('While Loop', {'type': 'while'}),
      _Variation('For Loop', {'type': 'for'}),
      _Variation('Switch', {'type': 'switch'}),
      _Variation('Try-Catch', {'type': 'try'}),
    ],
  ),

  // Variables
  ..._generate(
    const ComponentData(
      id: 'variable',
      label: 'Variable',
      category: 'coding',
      description: 'Data storage',
      icon: '📦',
      properties: {'type': 'string', 'value': ''},
      inputs: 1,
      outputs: 1,
    ),
    const [
      _Variation('Number', {'type': 'number', 'value': 0}),
      _Variation('String', {'type': 'string', 'value': ''}),
      _Variation('Boolean', {'type': 'boolean', 'value': false}),
      _Variation('Array', {'type': 'array', 'value': <dynamic>[]}),
      _Variation('Object', {'type': 'object', 'value': <String, dynamic>{}}),
    ],
  ),

  // Functions
  ..._generate(
    const ComponentData(
      id: 'function',
      label: 'Function',
      category: 'coding',
      description: 'Function block',
      icon: '📋',
      properties: {'name': 'function'},
      inputs: 1,
      outputs: 1,
    ),
    const [
      _Variation('Print', {'name': 'print'}),
      _Variation('Random', {'name': 'random'}),
      _Variation('Map', {'name': 'map'}),
      _Variation('Filter', {'name': 'filter'}),
      _Variation('Reduce', {'name': 'reduce'}),
      _Variation('Sort', {'name': 'sort'}),
    ],
  ),

  // ---------------------------------------------------------------- MATHEMATICS
  ..._generate(
    const ComponentData(
      id: 'math_function',
      label: 'Math Function',
      category: 'mathematics',
      description: 'Mathematical function',
      icon: '📐',
      properties: {'function': 'generic'},
      inputs: 1,
      outputs: 1,
    ),
    const [
      _Variation('Sin(x)', {'function': 'sin'}),
      _Variation('Cos(x)', {'function': 'cos'}),
      _Variation('Tan(x)', {'function': 'tan'}),
      _Variation('Log(x)', {'function': 'log'}),
      _Variation('Ln(x)', {'function': 'ln'}),
      _Variation('Exp(x)', {'function': 'exp'}),
      _Variation('Abs(x)', {'function': 'abs'}),
      _Variation('Floor(x)', {'function': 'floor'}),
      _Variation('Ceil(x)', {'function': 'ceil'}),
      _Variation('Round(x)', {'function': 'round'}),
    ],
  ),

  // Statistics
  ..._generate(
    const ComponentData(
      id: 'statistics',
      label: 'Statistics',
      category: 'mathematics',
      description: 'Statistical operation',
      icon: '📊',
      properties: {'operation': 'mean'},
      inputs: 1,
      outputs: 1,
    ),
    const [
      _Variation('Mean', {'operation': 'mean'}),
      _Variation('Median', {'operation': 'median'}),
      _Variation('Mode', {'operation': 'mode'}),
      _Variation('Standard Deviation', {'operation': 'stddev'}),
      _Variation('Variance', {'operation': 'variance'}),
      _Variation('Min', {'operation': 'min'}),
      _Variation('Max', {'operation': 'max'}),
      _Variation('Sum', {'operation': 'sum'}),
    ],
  ),

  // -------------------------------------------------------------------- BIOLOGY
  ..._generate(
    const ComponentData(
      id: 'bio_cell',
      label: 'Cell',
      category: 'biology',
      description: 'Biological cell',
      icon: '🧫',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('Plant Cell', {'type': 'plant'}),
      _Variation('Animal Cell', {'type': 'animal'}),
      _Variation('Bacteria', {'type': 'bacteria'}),
      _Variation('Neuron', {'type': 'neuron'}),
      _Variation('Red Blood Cell', {'type': 'rbc'}),
      _Variation('White Blood Cell', {'type': 'wbc'}),
    ],
  ),

  // Biomolecules
  ..._generate(
    const ComponentData(
      id: 'biomolecule',
      label: 'Biomolecule',
      category: 'biology',
      description: 'Biological molecule',
      icon: '🧬',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('DNA', {'type': 'dna'}),
      _Variation('RNA', {'type': 'rna'}),
      _Variation('Protein', {'type': 'protein'}),
      _Variation('Enzyme', {'type': 'enzyme'}),
      _Variation('ATP', {'type': 'atp'}),
      _Variation('Glucose', {'type': 'glucose'}),
    ],
  ),

  // ------------------------------------------------------------ QUANTUM PHYSICS
  ..._generate(
    const ComponentData(
      id: 'quantum',
      label: 'Quantum',
      category: 'quantum',
      description: 'Quantum component',
      icon: '⚛️',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('Qubit |0⟩', {'type': 'qubit', 'state': 0}),
      _Variation('Qubit |1⟩', {'type': 'qubit', 'state': 1}),
      _Variation('Hadamard Gate', {'type': 'gate', 'name': 'H'}),
      _Variation('Pauli-X Gate', {'type': 'gate', 'name': 'X'}),
      _Variation('Pauli-Y Gate', {'type': 'gate', 'name': 'Y'}),
      _Variation('Pauli-Z Gate', {'type': 'gate', 'name': 'Z'}),
      _Variation('CNOT Gate', {'type': 'gate', 'name': 'CNOT'}),
      _Variation('Measurement', {'type': 'measurement'}),
    ],
  ),

  // ------------------------------------------------------------------ ASTRONOMY
  ..._generate(
    const ComponentData(
      id: 'astro',
      label: 'Astronomy',
      category: 'astronomy',
      description: 'Astronomical object',
      icon: '🪐',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('Star (Sun-like)', {'type': 'star', 'class': 'G'}),
      _Variation('Red Giant', {'type': 'star', 'class': 'M'}),
      _Variation('White Dwarf', {'type': 'star', 'class': 'D'}),
      _Variation('Black Hole', {'type': 'blackhole'}),
      _Variation('Neutron Star', {'type': 'neutron_star'}),
      _Variation('Planet (Rocky)', {
        'type': 'planet',
        'subtype': 'terrestrial',
      }),
      _Variation('Planet (Gas Giant)', {
        'type': 'planet',
        'subtype': 'gas_giant',
      }),
      _Variation('Moon', {'type': 'moon'}),
      _Variation('Asteroid', {'type': 'asteroid'}),
      _Variation('Comet', {'type': 'comet'}),
      _Variation('Galaxy (Spiral)', {'type': 'galaxy', 'shape': 'spiral'}),
      _Variation('Galaxy (Elliptical)', {
        'type': 'galaxy',
        'shape': 'elliptical',
      }),
      _Variation('Nebula', {'type': 'nebula'}),
    ],
  ),

  // -------------------------------------------------------------------- GEOLOGY
  ..._generate(
    const ComponentData(
      id: 'geo',
      label: 'Geology',
      category: 'geology',
      description: 'Geological component',
      icon: '🌋',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('Volcano', {'type': 'volcano'}),
      _Variation('Earthquake Source', {'type': 'earthquake'}),
      _Variation('Tectonic Plate', {'type': 'plate'}),
      _Variation('Magma Chamber', {'type': 'magma'}),
      _Variation('Sedimentary Rock', {
        'type': 'rock',
        'subtype': 'sedimentary',
      }),
      _Variation('Igneous Rock', {'type': 'rock', 'subtype': 'igneous'}),
      _Variation('Metamorphic Rock', {
        'type': 'rock',
        'subtype': 'metamorphic',
      }),
      _Variation('Fossil', {'type': 'fossil'}),
      _Variation('Mineral (Quartz)', {'type': 'mineral', 'name': 'quartz'}),
      _Variation('Mineral (Gold)', {'type': 'mineral', 'name': 'gold'}),
    ],
  ),

  // -------------------------------------------------------------- MUSIC & AUDIO
  ..._generate(
    const ComponentData(
      id: 'audio',
      label: 'Audio',
      category: 'music',
      description: 'Audio component',
      icon: '🎵',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('Oscillator (Sine)', {'type': 'oscillator', 'wave': 'sine'}),
      _Variation('Oscillator (Square)', {
        'type': 'oscillator',
        'wave': 'square',
      }),
      _Variation('Oscillator (Saw)', {
        'type': 'oscillator',
        'wave': 'sawtooth',
      }),
      _Variation('Filter (Low Pass)', {'type': 'filter', 'subtype': 'lowpass'}),
      _Variation('Filter (High Pass)', {
        'type': 'filter',
        'subtype': 'highpass',
      }),
      _Variation('Amplifier', {'type': 'amp'}),
      _Variation('Speaker', {'type': 'speaker'}),
      _Variation('Microphone', {'type': 'mic'}),
      _Variation('Delay', {'type': 'effect', 'subtype': 'delay'}),
      _Variation('Reverb', {'type': 'effect', 'subtype': 'reverb'}),
    ],
  ),

  // ------------------------------------------------------------------- ROBOTICS
  ..._generate(
    const ComponentData(
      id: 'robot',
      label: 'Robotics',
      category: 'robotics',
      description: 'Robotic component',
      icon: '🤖',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('Servo Motor', {'type': 'motor', 'subtype': 'servo'}),
      _Variation('Stepper Motor', {'type': 'motor', 'subtype': 'stepper'}),
      _Variation('DC Motor', {'type': 'motor', 'subtype': 'dc'}),
      _Variation('Robot Arm Joint', {'type': 'joint'}),
      _Variation('Gripper', {'type': 'effector', 'subtype': 'gripper'}),
      _Variation('Lidar Sensor', {'type': 'sensor', 'subtype': 'lidar'}),
      _Variation('Camera', {'type': 'sensor', 'subtype': 'camera'}),
      _Variation('IMU', {'type': 'sensor', 'subtype': 'imu'}),
      _Variation('Wheel', {'type': 'actuator', 'subtype': 'wheel'}),
      _Variation('Chassis', {'type': 'structure'}),
    ],
  ),

  // --------------------------------------------------------------------- AI/ ML
  ..._generate(
    const ComponentData(
      id: 'ai',
      label: 'AI/ML',
      category: 'ai_ml',
      description: 'AI/ML Block',
      icon: '🧠',
      properties: {'type': 'generic'},
    ),
    const [
      _Variation('Neural Network Layer', {'type': 'layer', 'subtype': 'dense'}),
      _Variation('Convolution Layer', {'type': 'layer', 'subtype': 'conv2d'}),
      _Variation('Pooling Layer', {'type': 'layer', 'subtype': 'maxpool'}),
      _Variation('Activation (ReLU)', {'type': 'activation', 'func': 'relu'}),
      _Variation('Activation (Sigmoid)', {
        'type': 'activation',
        'func': 'sigmoid',
      }),
      _Variation('Activation (Softmax)', {
        'type': 'activation',
        'func': 'softmax',
      }),
      _Variation('Dataset (Images)', {'type': 'data', 'subtype': 'images'}),
      _Variation('Dataset (Text)', {'type': 'data', 'subtype': 'text'}),
      _Variation('Optimizer (Adam)', {'type': 'optimizer', 'name': 'adam'}),
      _Variation('Loss Function', {'type': 'loss'}),
    ],
  ),
];

/// The palette's filter chips, in the same order as the TS `CATEGORIES` export.
const List<ComponentCategory> kCategories = <ComponentCategory>[
  ComponentCategory(
    id: 'electronics',
    label: 'Electronics',
    icon: '⚡',
    color: Color(0xFF3B82F6),
  ),
  ComponentCategory(
    id: 'chemicals',
    label: 'Chemicals',
    icon: '⚗️',
    color: Color(0xFF10B981),
  ),
  ComponentCategory(
    id: 'physics',
    label: 'Physics',
    icon: '⚙️',
    color: Color(0xFF8B5CF6),
  ),
  ComponentCategory(
    id: 'biology',
    label: 'Biology',
    icon: '🧫',
    color: Color(0xFFEC4899),
  ),
  ComponentCategory(
    id: 'coding',
    label: 'Coding',
    icon: '💻',
    color: Color(0xFFF59E0B),
  ),
  ComponentCategory(
    id: 'mathematics',
    label: 'Mathematics',
    icon: '📐',
    color: Color(0xFFEF4444),
  ),
  ComponentCategory(
    id: 'thermodynamics',
    label: 'Thermodynamics',
    icon: '🌡️',
    color: Color(0xFF06B6D4),
  ),
  ComponentCategory(
    id: 'optics',
    label: 'Optics',
    icon: '🔍',
    color: Color(0xFFA855F7),
  ),
  ComponentCategory(
    id: 'quantum',
    label: 'Quantum',
    icon: '⚛️',
    color: Color(0xFF14B8A6),
  ),
  ComponentCategory(
    id: 'mechanics',
    label: 'Mechanics',
    icon: '⚙️',
    color: Color(0xFF6366F1),
  ),
  ComponentCategory(
    id: 'astronomy',
    label: 'Astronomy',
    icon: '🪐',
    color: Color(0xFF818CF8),
  ),
  ComponentCategory(
    id: 'geology',
    label: 'Geology',
    icon: '🌋',
    color: Color(0xFFB45309),
  ),
  ComponentCategory(
    id: 'music',
    label: 'Music & Audio',
    icon: '🎵',
    color: Color(0xFFDB2777),
  ),
  ComponentCategory(
    id: 'robotics',
    label: 'Robotics',
    icon: '🤖',
    color: Color(0xFF4B5563),
  ),
  ComponentCategory(
    id: 'ai_ml',
    label: 'AI & ML',
    icon: '🧠',
    color: Color(0xFF7C3AED),
  ),
];

/// Every component whose [ComponentData.category] equals [categoryId], in
/// library order.
List<ComponentData> componentsInCategory(String categoryId) {
  return kComponentLibrary.where((c) => c.category == categoryId).toList();
}

/// Case-insensitive search over label, description and category.
///
/// An empty (or whitespace-only) [query] matches everything. When
/// [categoryId] is supplied the results are additionally restricted to that
/// category.
List<ComponentData> searchComponents(String query, {String? categoryId}) {
  final String q = query.trim().toLowerCase();
  return kComponentLibrary.where((c) {
    if (categoryId != null && c.category != categoryId) return false;
    if (q.isEmpty) return true;
    return c.label.toLowerCase().contains(q) ||
        c.description.toLowerCase().contains(q) ||
        c.category.toLowerCase().contains(q);
  }).toList();
}

/// One [ComponentFamily] per generated group (e.g. all ten resistor values
/// collapse to a single `resistor` family), in library order.
///
/// Touches [kComponentLibrary] first so its lazy initializer — which
/// populates [_familyOrder] as a side effect — has always run before this
/// is read.
List<ComponentFamily> get kComponentFamilies {
  // ignore: unnecessary_statements
  kComponentLibrary;
  return List<ComponentFamily>.unmodifiable(_familyOrder);
}

final RegExp _familyIndexSuffix = RegExp(r'^(.+)_\d+$');

/// [ComponentData.id] -> [ComponentFamily.id] it was generated from.
String familyIdOf(String componentId) =>
    _familyIndexSuffix.firstMatch(componentId)?.group(1) ?? componentId;

/// Every variation belonging to family [familyId], in library order.
List<ComponentData> familyVariations(String familyId) => kComponentLibrary
    .where((ComponentData c) => familyIdOf(c.id) == familyId)
    .toList(growable: false);

/// Case-insensitive search over families, restricted to [categoryId] when
/// given. A family matches when its own label/description matches, or when
/// any of its variations do — so searching "220" still surfaces the
/// Resistor family even though "220" only appears on one of its variations.
///
/// An empty (or whitespace-only) [query] matches every family.
List<ComponentFamily> searchFamilies(String query, {String? categoryId}) {
  final String q = query.trim().toLowerCase();
  return kComponentFamilies
      .where((ComponentFamily family) {
        if (categoryId != null && family.category != categoryId) return false;
        if (q.isEmpty) return true;
        if (family.label.toLowerCase().contains(q) ||
            family.description.toLowerCase().contains(q)) {
          return true;
        }
        return familyVariations(
          family.id,
        ).any((ComponentData c) => c.label.toLowerCase().contains(q));
      })
      .toList(growable: false);
}

/// Looks up a component by [ComponentData.id], or `null` when there is none.
ComponentData? componentById(String id) {
  for (final ComponentData c in kComponentLibrary) {
    if (c.id == id) return c;
  }
  return null;
}
