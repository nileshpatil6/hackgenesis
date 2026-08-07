import {
  Cpu,
  BatteryCharging,
  Antenna,
  MonitorSmartphone,
  Atom,
  FlaskConical,
  FlaskRound,
  Diamond,
  Hexagon,
  TestTube,
  Cog,
  MoveRight,
  Aperture,
  AudioWaveform,
  Thermometer,
  Binary,
  Calculator,
  Scale,
  Split,
  Variable,
  FunctionSquare,
  Sigma,
  BarChart3,
  Microscope,
  Dna,
  Orbit,
  Telescope,
  Mountain,
  Music,
  Bot,
  BrainCircuit,
  CircuitBoard,
  Square,
  Circle,
  Triangle,
  Minus,
  Shapes,
  LucideIcon,
} from 'lucide-react';
import { ResistorIcon, CapacitorIcon, InductorIcon, DiodeIcon, TransistorIcon } from '../components/icons/CircuitIcons';

type IconComponent = LucideIcon | typeof ResistorIcon;

export const ICON_REGISTRY: Record<string, IconComponent> = {
  // Electronics
  resistor: ResistorIcon,
  capacitor: CapacitorIcon,
  inductor: InductorIcon,
  diode: DiodeIcon,
  transistor: TransistorIcon,
  ic: Cpu,
  power: BatteryCharging,
  sensor: Antenna,
  display: MonitorSmartphone,

  // Chemicals
  element: Atom,
  acid: FlaskConical,
  base: FlaskRound,
  salt: Diamond,
  organic: Hexagon,
  chem_equipment: TestTube,

  // Physics
  mechanics: Cog,
  force: MoveRight,
  optics: Aperture,
  waves: AudioWaveform,
  thermo: Thermometer,

  // Coding
  logic_block: Binary,
  arithmetic: Calculator,
  comparison: Scale,
  control: Split,
  variable: Variable,
  function: FunctionSquare,

  // Mathematics
  math_function: Sigma,
  statistics: BarChart3,

  // Biology
  bio_cell: Microscope,
  biomolecule: Dna,

  // Other sciences
  quantum: Orbit,
  astro: Telescope,
  geo: Mountain,
  audio: Music,
  robot: Bot,
  ai: BrainCircuit,

  // Category-only keys
  electronics: CircuitBoard,
  chemicals: FlaskConical,
  physics: Atom,
  biology: Microscope,
  coding: Binary,
  mathematics: Sigma,
  thermodynamics: Thermometer,
  astronomy: Telescope,
  geology: Mountain,
  music: Music,
  robotics: Bot,
  ai_ml: BrainCircuit,

  // Hand-drawn shapes
  rectangle: Square,
  circle: Circle,
  triangle: Triangle,
  line: Minus,
  arrow: MoveRight,
};

export const DEFAULT_ICON: IconComponent = Shapes;

export function PartIcon({ iconKey, size = 22, className }: { iconKey: string; size?: number; className?: string }) {
  const Icon = ICON_REGISTRY[iconKey] || DEFAULT_ICON;
  return <Icon size={size} className={className} />;
}
