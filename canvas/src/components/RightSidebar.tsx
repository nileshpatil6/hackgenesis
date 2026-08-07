import { Node } from 'reactflow';
import { Square, Circle, Triangle, Minus, MoveUpRight, Hand, ChevronsRight, ChevronsLeft, Trash2, ArrowRightLeft, LayoutGrid } from 'lucide-react';
import { DrawingTool } from '../types/drawing';
import { PartIcon } from '../data/iconRegistry';

interface CategoryStat {
  id: string;
  label: string;
  count: number;
  color: string;
}

interface RightSidebarProps {
  collapsed: boolean;
  onToggleCollapse: () => void;
  selectedTool: DrawingTool | null;
  onToolSelect: (tool: DrawingTool | null) => void;
  selectedNode: Node | null;
  onUpdateLabel: (nodeId: string, label: string) => void;
  onUpdateProperty: (nodeId: string, key: string, value: any) => void;
  onDeleteNode: (nodeId: string) => void;
  nodeCount: number;
  edgeCount: number;
  categoryStats: CategoryStat[];
}

const TOOLS: Array<{ id: DrawingTool; icon: React.ReactNode; label: string }> = [
  { id: 'freehand', icon: <Hand size={17} />, label: 'Freehand' },
  { id: 'rectangle', icon: <Square size={17} />, label: 'Rectangle' },
  { id: 'circle', icon: <Circle size={17} />, label: 'Circle' },
  { id: 'triangle', icon: <Triangle size={17} />, label: 'Triangle' },
  { id: 'line', icon: <Minus size={17} />, label: 'Line' },
  { id: 'arrow', icon: <MoveUpRight size={17} />, label: 'Arrow' },
];

function PropertyField({ propKey, value, onChange }: { propKey: string; value: any; onChange: (v: any) => void }) {
  const label = propKey.replace(/([A-Z])/g, ' $1').replace(/^./, (c) => c.toUpperCase());

  if (typeof value === 'boolean') {
    return (
      <label className="flex items-center justify-between py-1.5 cursor-pointer">
        <span className="text-xs text-zinc-500 dark:text-zinc-400">{label}</span>
        <input
          type="checkbox"
          checked={value}
          onChange={(e) => onChange(e.target.checked)}
          className="w-4 h-4 accent-orange-500"
        />
      </label>
    );
  }

  if (typeof value === 'number') {
    return (
      <label className="flex flex-col gap-1 py-1.5">
        <span className="text-xs text-zinc-500 dark:text-zinc-400">{label}</span>
        <input
          type="number"
          value={value}
          onChange={(e) => onChange(parseFloat(e.target.value) || 0)}
          className="w-full px-2.5 py-1.5 bg-zinc-100 dark:bg-zinc-800 border border-zinc-200 dark:border-white/10 rounded-lg text-xs text-zinc-900 dark:text-zinc-100 outline-none focus:border-orange-500/60 transition-colors"
        />
      </label>
    );
  }

  if (typeof value === 'string') {
    return (
      <label className="flex flex-col gap-1 py-1.5">
        <span className="text-xs text-zinc-500 dark:text-zinc-400">{label}</span>
        <input
          type="text"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-full px-2.5 py-1.5 bg-zinc-100 dark:bg-zinc-800 border border-zinc-200 dark:border-white/10 rounded-lg text-xs text-zinc-900 dark:text-zinc-100 outline-none focus:border-orange-500/60 transition-colors"
        />
      </label>
    );
  }

  return (
    <div className="flex flex-col gap-1 py-1.5">
      <span className="text-xs text-zinc-500 dark:text-zinc-400">{label}</span>
      <span className="text-xs text-zinc-400 dark:text-zinc-500 font-mono truncate">{JSON.stringify(value)}</span>
    </div>
  );
}

export function RightSidebar({
  collapsed,
  onToggleCollapse,
  selectedTool,
  onToolSelect,
  selectedNode,
  onUpdateLabel,
  onUpdateProperty,
  onDeleteNode,
  nodeCount,
  edgeCount,
  categoryStats,
}: RightSidebarProps) {
  if (collapsed) {
    return (
      <div className="w-14 h-full bg-white dark:bg-zinc-950 border-l border-zinc-200 dark:border-white/10 flex flex-col items-center py-4 gap-3 transition-colors duration-300">
        <button
          onClick={onToggleCollapse}
          title="Expand panel"
          className="w-9 h-9 flex items-center justify-center rounded-lg text-zinc-500 dark:text-zinc-400 hover:bg-zinc-100 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white transition-colors"
        >
          <ChevronsLeft size={17} />
        </button>
        <div className="w-full h-px bg-zinc-200 dark:bg-white/10" />
        {TOOLS.map((tool) => (
          <button
            key={tool.id}
            onClick={() => onToolSelect(tool.id)}
            title={tool.label}
            className={`w-9 h-9 flex items-center justify-center rounded-lg transition-colors ${
              selectedTool === tool.id
                ? 'bg-orange-500 text-white'
                : 'text-zinc-500 dark:text-zinc-400 hover:bg-zinc-100 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white'
            }`}
          >
            {tool.icon}
          </button>
        ))}
      </div>
    );
  }

  return (
    <div className="w-[300px] h-full bg-white dark:bg-zinc-950 border-l border-zinc-200 dark:border-white/10 flex flex-col overflow-hidden transition-colors duration-300">
      {/* Header */}
      <div className="p-5 border-b border-zinc-200 dark:border-white/10 flex items-center justify-between">
        <h2 className="font-serif text-xl text-zinc-900 dark:text-white">Inspector</h2>
        <button
          onClick={onToggleCollapse}
          title="Collapse panel"
          className="w-8 h-8 flex items-center justify-center rounded-lg text-zinc-400 dark:text-zinc-500 hover:bg-zinc-100 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white transition-colors"
        >
          <ChevronsRight size={16} />
        </button>
      </div>

      {/* Draw tools */}
      <div className="p-4 border-b border-zinc-200 dark:border-white/10">
        <div className="text-[11px] font-semibold text-zinc-400 dark:text-zinc-500 uppercase tracking-wider mb-2.5">
          Draw Tools
        </div>
        <div className="grid grid-cols-6 gap-1.5">
          {TOOLS.map((tool) => (
            <button
              key={tool.id}
              onClick={() => onToolSelect(tool.id)}
              title={tool.label}
              className={`aspect-square flex items-center justify-center rounded-lg transition-colors ${
                selectedTool === tool.id
                  ? 'bg-orange-500 text-white shadow-[0_2px_10px_rgba(255,79,0,0.35)]'
                  : 'bg-zinc-100 dark:bg-white/5 text-zinc-600 dark:text-zinc-300 hover:bg-zinc-200 dark:hover:bg-white/10'
              }`}
            >
              {tool.icon}
            </button>
          ))}
        </div>
      </div>

      {/* Selected node inspector OR experiment overview */}
      <div className="flex-1 overflow-y-auto p-4">
        {selectedNode ? (
          <div>
            <div className="flex items-center gap-3 mb-4">
              <div className="w-11 h-11 flex items-center justify-center rounded-xl bg-orange-500/10 text-orange-500 shrink-0">
                <PartIcon iconKey={selectedNode.data.component.icon} size={22} />
              </div>
              <div className="min-w-0">
                <div className="text-sm font-semibold text-zinc-900 dark:text-zinc-100 truncate">
                  {selectedNode.data.customText || selectedNode.data.label}
                </div>
                <div className="text-[11px] text-zinc-500 dark:text-zinc-400 truncate">
                  {selectedNode.data.component.description}
                </div>
              </div>
            </div>

            <label className="flex flex-col gap-1 mb-3">
              <span className="text-xs text-zinc-500 dark:text-zinc-400">Label</span>
              <input
                type="text"
                value={selectedNode.data.customText || selectedNode.data.label}
                onChange={(e) => onUpdateLabel(selectedNode.id, e.target.value)}
                className="w-full px-2.5 py-1.5 bg-zinc-100 dark:bg-zinc-800 border border-zinc-200 dark:border-white/10 rounded-lg text-xs text-zinc-900 dark:text-zinc-100 outline-none focus:border-orange-500/60 transition-colors"
              />
            </label>

            <div className="flex items-center gap-2 mb-4">
              <span className="text-[10px] uppercase tracking-wider font-semibold bg-zinc-100 dark:bg-white/5 text-zinc-500 dark:text-zinc-400 px-2 py-1 rounded-md">
                {selectedNode.data.component.category}
              </span>
              <span className="flex items-center gap-1 text-[10px] text-zinc-400 dark:text-zinc-500">
                <ArrowRightLeft size={11} />
                {selectedNode.data.component.inputs ?? 1} in / {selectedNode.data.component.outputs ?? 1} out
              </span>
            </div>

            {selectedNode.data.component.properties && Object.keys(selectedNode.data.component.properties).length > 0 && (
              <div className="mb-4">
                <div className="text-[11px] font-semibold text-zinc-400 dark:text-zinc-500 uppercase tracking-wider mb-1">
                  Properties
                </div>
                <div className="flex flex-col divide-y divide-zinc-100 dark:divide-white/5">
                  {Object.entries(selectedNode.data.component.properties).map(([key, value]) => (
                    <PropertyField
                      key={key}
                      propKey={key}
                      value={value}
                      onChange={(v) => onUpdateProperty(selectedNode.id, key, v)}
                    />
                  ))}
                </div>
              </div>
            )}

            <button
              onClick={() => onDeleteNode(selectedNode.id)}
              className="w-full flex items-center justify-center gap-2 px-3 py-2.5 rounded-xl text-sm font-medium bg-red-50 dark:bg-red-500/10 text-red-600 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-500/20 transition-colors"
            >
              <Trash2 size={15} />
              Delete Component
            </button>
          </div>
        ) : (
          <div>
            <div className="text-[11px] font-semibold text-zinc-400 dark:text-zinc-500 uppercase tracking-wider mb-2.5">
              Experiment Overview
            </div>
            <div className="grid grid-cols-2 gap-2 mb-5">
              <div className="p-3 rounded-xl bg-zinc-100 dark:bg-white/5">
                <div className="text-xl font-semibold text-orange-500">{nodeCount}</div>
                <div className="text-[11px] text-zinc-500 dark:text-zinc-400">Components</div>
              </div>
              <div className="p-3 rounded-xl bg-zinc-100 dark:bg-white/5">
                <div className="text-xl font-semibold text-orange-500">{edgeCount}</div>
                <div className="text-[11px] text-zinc-500 dark:text-zinc-400">Connections</div>
              </div>
            </div>

            {categoryStats.length > 0 ? (
              <div className="mb-5">
                <div className="text-[11px] font-semibold text-zinc-400 dark:text-zinc-500 uppercase tracking-wider mb-2">
                  Categories Used
                </div>
                <div className="flex flex-col gap-1.5">
                  {categoryStats.map((cat) => (
                    <div key={cat.id} className="flex items-center gap-2.5">
                      <div
                        className="w-6 h-6 rounded-md flex items-center justify-center shrink-0"
                        style={{ backgroundColor: `${cat.color}1a`, color: cat.color }}
                      >
                        <PartIcon iconKey={cat.id} size={13} />
                      </div>
                      <span className="text-xs text-zinc-600 dark:text-zinc-300 flex-1 truncate">{cat.label}</span>
                      <span className="text-xs font-semibold text-zinc-400 dark:text-zinc-500">{cat.count}</span>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div className="flex flex-col items-center text-center gap-2 py-8 px-2">
                <div className="w-11 h-11 rounded-xl bg-zinc-100 dark:bg-white/5 flex items-center justify-center text-zinc-400 dark:text-zinc-500">
                  <LayoutGrid size={20} />
                </div>
                <p className="text-xs text-zinc-400 dark:text-zinc-500 leading-relaxed">
                  Drag a component onto the canvas or click a node to inspect and edit its properties here.
                </p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
