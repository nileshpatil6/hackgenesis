interface IconProps {
  size?: number | string;
  className?: string;
  strokeWidth?: number;
}

const base = {
  fill: 'none',
  stroke: 'currentColor',
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  viewBox: '0 0 24 24',
};

export function ResistorIcon({ size = 24, className, strokeWidth = 1.75 }: IconProps) {
  return (
    <svg {...base} width={size} height={size} strokeWidth={strokeWidth} className={className}>
      <path d="M1 12h3l2-6 4 12 4-12 4 12 2-6h3" />
    </svg>
  );
}

export function CapacitorIcon({ size = 24, className, strokeWidth = 1.75 }: IconProps) {
  return (
    <svg {...base} width={size} height={size} strokeWidth={strokeWidth} className={className}>
      <path d="M2 12h8M14 12h8M10 5v14M14 5v14" />
    </svg>
  );
}

export function InductorIcon({ size = 24, className, strokeWidth = 1.75 }: IconProps) {
  return (
    <svg {...base} width={size} height={size} strokeWidth={strokeWidth} className={className}>
      <path d="M1 12h3a2.5 2.5 0 0 1 5 0 2.5 2.5 0 0 1 5 0 2.5 2.5 0 0 1 5 0h3" />
    </svg>
  );
}

export function DiodeIcon({ size = 24, className, strokeWidth = 1.75 }: IconProps) {
  return (
    <svg {...base} width={size} height={size} strokeWidth={strokeWidth} className={className}>
      <path d="M2 12h6M16 12h6M16 6v12" />
      <path d="M8 6v12l8-6-8-6Z" fill="currentColor" stroke="currentColor" strokeLinejoin="round" />
    </svg>
  );
}

export function TransistorIcon({ size = 24, className, strokeWidth = 1.75 }: IconProps) {
  return (
    <svg {...base} width={size} height={size} strokeWidth={strokeWidth} className={className}>
      <circle cx="12" cy="12" r="8" />
      <path d="M9 8v8M3 12h6M9 10.5 16 5M16 5v3.5M9 13.5 16 19M16 19v-3.5" />
    </svg>
  );
}
