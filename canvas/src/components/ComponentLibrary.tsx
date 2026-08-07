import { useState } from 'react';
import { Search, X } from 'lucide-react';
import { COMPONENT_LIBRARY, CATEGORIES } from '../data/componentLibrary';
import { ComponentData } from '../types';

interface ComponentLibraryProps {
  onDragStart: (component: ComponentData) => void;
}

export const ComponentLibrary = ({ onDragStart }: ComponentLibraryProps) => {
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const filteredComponents = COMPONENT_LIBRARY.filter((comp) => {
    const matchesCategory = selectedCategory === 'all' || comp.category === selectedCategory;
    const matchesSearch = comp.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         comp.description.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  const handleDragStart = (event: React.DragEvent, component: ComponentData) => {
    event.dataTransfer.setData('application/reactflow', JSON.stringify(component));
    event.dataTransfer.effectAllowed = 'move';
    onDragStart(component);
  };

  return (
    <div className="w-[300px] h-full bg-zinc-950/95 border-r border-white/10 flex flex-col overflow-hidden">
      {/* Header */}
      <div className="p-5 border-b border-white/10">
        <h2 className="font-serif text-xl text-white mb-4">Component Library</h2>

        {/* Search */}
        <div className="relative">
          <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-zinc-500" />
          <input
            type="text"
            placeholder="Search components..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-8 py-2.5 bg-zinc-900 border border-white/10 rounded-full text-sm text-zinc-200 placeholder:text-zinc-500 outline-none focus:border-orange-500/60 focus:ring-1 focus:ring-orange-500/30 transition-colors"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-white transition-colors"
            >
              <X size={14} />
            </button>
          )}
        </div>
      </div>

      {/* Categories */}
      <div className="p-3 border-b border-white/10 flex flex-wrap gap-1.5">
        <button
          onClick={() => setSelectedCategory('all')}
          className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
            selectedCategory === 'all'
              ? 'bg-orange-500 text-white shadow-[0_2px_10px_rgba(255,79,0,0.35)]'
              : 'bg-zinc-900 text-zinc-400 hover:text-white hover:bg-zinc-800'
          }`}
        >
          All
        </button>
        {CATEGORIES.map((cat) => (
          <button
            key={cat.id}
            onClick={() => setSelectedCategory(cat.id)}
            className={`px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
              selectedCategory === cat.id
                ? 'bg-orange-500 text-white shadow-[0_2px_10px_rgba(255,79,0,0.35)]'
                : 'bg-zinc-900 text-zinc-400 hover:text-white hover:bg-zinc-800'
            }`}
          >
            {cat.icon} {cat.label}
          </button>
        ))}
      </div>

      {/* Component List */}
      <div className="flex-1 overflow-y-auto p-3">
        <div className="text-xs text-zinc-500 mb-3 px-1">
          {filteredComponents.length} components
        </div>

        <div className="flex flex-col gap-2">
          {filteredComponents.map((component) => (
            <div
              key={component.id}
              draggable
              onDragStart={(e) => handleDragStart(e, component)}
              className="group p-3 bg-zinc-900 border border-white/10 rounded-xl cursor-grab active:cursor-grabbing transition-all hover:border-orange-500/50 hover:bg-zinc-800/80 hover:shadow-[0_4px_16px_rgba(255,79,0,0.15)]"
            >
              <div className="flex items-center gap-3">
                <div className="text-2xl leading-none">{component.icon}</div>
                <div className="flex-1 min-w-0">
                  <div className="text-[13px] font-medium text-zinc-100 truncate">
                    {component.label}
                  </div>
                  <div className="text-[11px] text-zinc-500 truncate">
                    {component.description}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
