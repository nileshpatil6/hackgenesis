import { memo, useState } from 'react';
import { Handle, Position, NodeProps } from 'reactflow';
import { ComponentData } from '../types';

interface CustomNodeData {
  label: string;
  component: ComponentData;
  customText?: string;
  properties?: Record<string, any>;
}

export const CustomNode = memo(({ data, selected }: NodeProps<CustomNodeData>) => {
  const [isEditing, setIsEditing] = useState(false);
  const [text, setText] = useState(data.customText || data.label);

  const handleDoubleClick = () => {
    setIsEditing(true);
  };

  const handleBlur = () => {
    setIsEditing(false);
    data.customText = text;
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      setIsEditing(false);
      data.customText = text;
    }
  };

  return (
    <div
      className={`custom-node min-w-[170px] rounded-2xl border-2 px-6 py-4 backdrop-blur-md transition-all duration-200 cursor-grab active:cursor-grabbing ${
        selected
          ? 'border-orange-500 bg-zinc-900/95 shadow-[0_8px_28px_rgba(255,79,0,0.35)]'
          : 'border-white/10 bg-zinc-900/90 shadow-[0_4px_16px_rgba(0,0,0,0.4)] hover:border-white/20'
      }`}
      onDoubleClick={handleDoubleClick}
    >
      {/* Input handle */}
      {data.component.inputs !== 0 && (
        <Handle
          type="target"
          position={Position.Left}
          style={{
            background: '#3b82f6',
            width: 12,
            height: 12,
            border: '2px solid #09090b',
            boxShadow: '0 0 0 2px rgba(59,130,246,0.3)',
          }}
        />
      )}

      <div className="flex flex-col gap-1.5">
        <div className="text-3xl text-center mb-1 drop-shadow">{data.component.icon}</div>

        {isEditing ? (
          <input
            type="text"
            value={text}
            onChange={(e) => setText(e.target.value)}
            onBlur={handleBlur}
            onKeyDown={handleKeyDown}
            autoFocus
            className="w-full px-1.5 py-1 bg-zinc-800 border border-orange-500 rounded text-xs text-white outline-none text-center"
          />
        ) : (
          <div className="text-sm font-semibold text-center text-zinc-100 break-words leading-snug tracking-tight">
            {text}
          </div>
        )}

        <div className="text-[10px] bg-white/5 text-zinc-400 px-2 py-1 rounded-md text-center uppercase tracking-wider font-semibold">
          {data.component.category}
        </div>
      </div>

      {/* Output handle */}
      {data.component.outputs !== 0 && (
        <Handle
          type="source"
          position={Position.Right}
          style={{
            background: '#ff4f00',
            width: 12,
            height: 12,
            border: '2px solid #09090b',
            boxShadow: '0 0 0 2px rgba(255,79,0,0.3)',
          }}
        />
      )}
    </div>
  );
});

CustomNode.displayName = 'CustomNode';
