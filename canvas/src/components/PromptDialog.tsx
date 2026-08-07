import { useState, useEffect, useRef } from 'react';
import { AnimatePresence, motion } from 'framer-motion';

export interface PromptDialogState {
  title: string;
  message?: string;
  defaultValue?: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  showInput?: boolean;
  onConfirm: (value: string) => void;
}

interface PromptDialogProps {
  state: PromptDialogState | null;
  onClose: () => void;
}

export function PromptDialog({ state, onClose }: PromptDialogProps) {
  const [value, setValue] = useState('');
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (state) {
      setValue(state.defaultValue || '');
      requestAnimationFrame(() => {
        inputRef.current?.focus();
        inputRef.current?.select();
      });
    }
  }, [state]);

  const handleConfirm = () => {
    if (!state) return;
    state.onConfirm(value);
    onClose();
  };

  return (
    <AnimatePresence>
      {state && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-[3000] p-4"
          onClick={onClose}
        >
          <motion.div
            initial={{ opacity: 0, y: 16, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 16, scale: 0.96 }}
            transition={{ duration: 0.15 }}
            onClick={(e) => e.stopPropagation()}
            className="bg-white dark:bg-zinc-950 border border-zinc-200 dark:border-white/10 p-6 rounded-3xl w-full max-w-[420px] shadow-[0_20px_60px_rgba(0,0,0,0.25)] dark:shadow-[0_20px_60px_rgba(0,0,0,0.7)]"
          >
            <h2 className="font-serif text-xl text-zinc-900 dark:text-white mb-1.5">{state.title}</h2>
            {state.message && (
              <p className="text-sm text-zinc-500 dark:text-zinc-400 mb-4">{state.message}</p>
            )}

            {state.showInput !== false && (
              <input
                ref={inputRef}
                type="text"
                value={value}
                onChange={(e) => setValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') handleConfirm();
                  if (e.key === 'Escape') onClose();
                }}
                className="w-full px-3.5 py-2.5 bg-zinc-100 dark:bg-zinc-900 border border-zinc-200 dark:border-white/10 rounded-xl text-sm text-zinc-900 dark:text-zinc-100 outline-none focus:border-orange-500/60 transition-colors mb-5"
              />
            )}

            <div className={`flex gap-2.5 justify-end ${state.showInput === false ? 'mt-1' : ''}`}>
              <button
                onClick={onClose}
                className="px-4 py-2 rounded-full bg-zinc-100 dark:bg-white/5 text-zinc-600 dark:text-zinc-300 hover:bg-zinc-200 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white text-sm font-medium transition-colors"
              >
                {state.cancelLabel || 'Cancel'}
              </button>
              <button
                onClick={handleConfirm}
                className={`px-4 py-2 rounded-full text-sm font-medium transition-colors ${
                  state.danger
                    ? 'bg-red-500 text-white hover:bg-red-600 shadow-[0_4px_16px_rgba(239,68,68,0.35)]'
                    : 'bg-orange-500 text-white hover:bg-orange-600 shadow-[0_4px_16px_rgba(255,79,0,0.35)]'
                }`}
              >
                {state.confirmLabel || 'OK'}
              </button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
