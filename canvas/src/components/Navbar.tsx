import { useState } from 'react';
import { Play, Download, Trash2, BookOpen, Upload, Menu, Undo, Redo, Sun, Moon } from 'lucide-react';
import { AnimatePresence, motion } from 'framer-motion';

interface NavbarProps {
  isAnalyzing: boolean;
  canUndo: boolean;
  canRedo: boolean;
  isDark: boolean;
  nodeCount: number;
  edgeCount: number;
  onUndo: () => void;
  onRedo: () => void;
  onRunExperiment: () => void;
  onShowExamples: () => void;
  onToggleTheme: () => void;
  onDownloadJSON: () => void;
  onImportJSON: () => void;
  onClearCanvas: () => void;
}

export function Navbar({
  isAnalyzing,
  canUndo,
  canRedo,
  isDark,
  nodeCount,
  edgeCount,
  onUndo,
  onRedo,
  onRunExperiment,
  onShowExamples,
  onToggleTheme,
  onDownloadJSON,
  onImportJSON,
  onClearCanvas,
}: NavbarProps) {
  const [showSettingsMenu, setShowSettingsMenu] = useState(false);

  return (
    <header className="h-16 shrink-0 flex items-center justify-between px-5 bg-white dark:bg-zinc-950 border-b border-zinc-200 dark:border-white/10 z-[500] relative">
      {/* Brand */}
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-full bg-orange-500 flex items-center justify-center text-white font-serif font-bold text-base leading-none pb-0.5 shadow-[0_4px_14px_rgba(255,79,0,0.35)]">
          Y
        </div>
        <div className="flex items-center gap-2">
          <span className="font-serif text-lg text-zinc-900 dark:text-white tracking-tight">Yukti-AI</span>
          <span className="hidden sm:inline-block text-[11px] font-medium text-zinc-500 dark:text-zinc-400 bg-zinc-100 dark:bg-white/5 px-2 py-0.5 rounded-full">
            Experiment Lab
          </span>
        </div>

        <div className="hidden md:flex items-center gap-1.5 ml-4 pl-4 border-l border-zinc-200 dark:border-white/10 text-xs text-zinc-500 dark:text-zinc-400">
          <span className="text-orange-500 font-semibold">{nodeCount}</span> components
          <span className="text-zinc-300 dark:text-zinc-700 mx-0.5">•</span>
          <span className="text-orange-500 font-semibold">{edgeCount}</span> connections
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2">
        <div className="flex gap-1 mr-1 pr-2 border-r border-zinc-200 dark:border-white/10">
          <button
            onClick={onUndo}
            disabled={!canUndo}
            title="Undo"
            className={`flex items-center justify-center w-9 h-9 rounded-lg transition-colors ${
              canUndo ? 'text-zinc-500 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white' : 'text-zinc-300 dark:text-zinc-700 cursor-not-allowed'
            }`}
          >
            <Undo size={17} />
          </button>
          <button
            onClick={onRedo}
            disabled={!canRedo}
            title="Redo"
            className={`flex items-center justify-center w-9 h-9 rounded-lg transition-colors ${
              canRedo ? 'text-zinc-500 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white' : 'text-zinc-300 dark:text-zinc-700 cursor-not-allowed'
            }`}
          >
            <Redo size={17} />
          </button>
        </div>

        <button
          onClick={onShowExamples}
          className="hidden sm:flex items-center gap-2 px-3.5 py-2 rounded-full text-sm font-medium bg-zinc-100 dark:bg-white/5 text-zinc-700 dark:text-zinc-200 hover:bg-zinc-200 dark:hover:bg-white/10 transition-colors"
        >
          <BookOpen size={15} />
          Examples
        </button>

        <button
          onClick={onToggleTheme}
          title={isDark ? 'Switch to light mode' : 'Switch to dark mode'}
          className="flex items-center justify-center w-9 h-9 rounded-full bg-zinc-100 dark:bg-white/5 text-zinc-700 dark:text-zinc-200 hover:bg-zinc-200 dark:hover:bg-white/10 transition-colors"
        >
          {isDark ? <Sun size={16} /> : <Moon size={16} />}
        </button>

        <div className="relative">
          <button
            onClick={() => setShowSettingsMenu((v) => !v)}
            className="flex items-center justify-center w-9 h-9 rounded-full bg-zinc-100 dark:bg-white/5 text-zinc-700 dark:text-zinc-200 hover:bg-zinc-200 dark:hover:bg-white/10 transition-colors"
          >
            <Menu size={16} />
          </button>

          <AnimatePresence>
            {showSettingsMenu && (
              <>
                <div className="fixed inset-0 z-[999]" onClick={() => setShowSettingsMenu(false)} />
                <motion.div
                  initial={{ opacity: 0, y: -6, scale: 0.97 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -6, scale: 0.97 }}
                  transition={{ duration: 0.15 }}
                  className="absolute top-full right-0 mt-2 bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-white/10 rounded-xl shadow-[0_12px_32px_rgba(0,0,0,0.15)] dark:shadow-[0_12px_32px_rgba(0,0,0,0.5)] min-w-[170px] z-[1000] overflow-hidden"
                >
                  <button
                    onClick={() => {
                      onDownloadJSON();
                      setShowSettingsMenu(false);
                    }}
                    className="w-full flex items-center gap-2.5 px-4 py-3 text-sm text-zinc-600 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-white/5 hover:text-zinc-900 dark:hover:text-white transition-colors text-left"
                  >
                    <Download size={15} />
                    Export JSON
                  </button>
                  <button
                    onClick={() => {
                      onImportJSON();
                      setShowSettingsMenu(false);
                    }}
                    className="w-full flex items-center gap-2.5 px-4 py-3 text-sm text-zinc-600 dark:text-zinc-300 hover:bg-zinc-100 dark:hover:bg-white/5 hover:text-zinc-900 dark:hover:text-white transition-colors text-left"
                  >
                    <Upload size={15} />
                    Import JSON
                  </button>
                  <div className="h-px bg-zinc-200 dark:bg-white/10 my-1" />
                  <button
                    onClick={() => {
                      onClearCanvas();
                      setShowSettingsMenu(false);
                    }}
                    className="w-full flex items-center gap-2.5 px-4 py-3 text-sm text-red-500 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-500/10 transition-colors text-left"
                  >
                    <Trash2 size={15} />
                    Clear Canvas
                  </button>
                </motion.div>
              </>
            )}
          </AnimatePresence>
        </div>

        <button
          onClick={onRunExperiment}
          disabled={isAnalyzing}
          className={`flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium transition-all ${
            isAnalyzing
              ? 'bg-zinc-200 dark:bg-zinc-700 text-zinc-400 cursor-not-allowed'
              : 'bg-orange-500 text-white hover:bg-orange-600 shadow-[0_4px_16px_rgba(255,79,0,0.35)]'
          }`}
        >
          <Play size={15} />
          {isAnalyzing ? 'Analyzing...' : 'Run Experiment'}
        </button>
      </div>
    </header>
  );
}
