import { Square, Circle, Triangle, Minus, MoveUpRight, Hand } from 'lucide-react';
import { DrawingTool } from '../types/drawing';

interface DrawingToolbarProps {
  selectedTool: DrawingTool | null;
  onToolSelect: (tool: DrawingTool | null) => void;
}

export function DrawingToolbar({ selectedTool, onToolSelect }: DrawingToolbarProps) {
  const tools: Array<{ id: DrawingTool; icon: React.ReactNode; label: string }> = [
    { id: 'freehand', icon: <Hand size={17} />, label: 'Freehand' },
    { id: 'rectangle', icon: <Square size={17} />, label: 'Rectangle' },
    { id: 'circle', icon: <Circle size={17} />, label: 'Circle' },
    { id: 'triangle', icon: <Triangle size={17} />, label: 'Triangle' },
    { id: 'line', icon: <Minus size={17} />, label: 'Line' },
    { id: 'arrow', icon: <MoveUpRight size={17} />, label: 'Arrow' },
  ];

  return (
    <div className="fixed top-1/2 right-5 -translate-y-1/2 z-[100] bg-zinc-900/95 backdrop-blur-md border border-white/10 p-2 rounded-2xl shadow-[0_8px_28px_rgba(0,0,0,0.5)] flex flex-col gap-1.5">
      <div className="text-[11px] font-semibold text-zinc-500 px-2 pb-2 mb-0.5 border-b border-white/10 text-center uppercase tracking-wider">
        Draw
      </div>
      {tools.map((tool) => (
        <button
          key={tool.id}
          onClick={() => onToolSelect(tool.id)}
          title={tool.label}
          className={`flex items-center justify-center gap-2 px-3 py-2.5 rounded-xl text-sm font-medium transition-all whitespace-nowrap ${
            selectedTool === tool.id
              ? 'bg-orange-500 text-white shadow-[0_4px_14px_rgba(255,79,0,0.4)]'
              : 'bg-transparent text-zinc-400 hover:text-white hover:bg-white/5'
          }`}
        >
          {tool.icon}
        </button>
      ))}
    </div>
  );
}
