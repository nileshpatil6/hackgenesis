import { AnimatePresence, motion } from 'framer-motion';
import { CheckCircle, AlertCircle, Info, X } from 'lucide-react';

export type ToastType = 'success' | 'error' | 'info';

export interface ToastItem {
  id: number;
  message: string;
  type: ToastType;
}

const ICONS: Record<ToastType, React.ReactNode> = {
  success: <CheckCircle size={17} className="text-emerald-500" />,
  error: <AlertCircle size={17} className="text-red-500" />,
  info: <Info size={17} className="text-blue-500" />,
};

interface ToastStackProps {
  toasts: ToastItem[];
  onDismiss: (id: number) => void;
}

export function ToastStack({ toasts, onDismiss }: ToastStackProps) {
  return (
    <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-[4000] flex flex-col-reverse gap-2 items-center pointer-events-none">
      <AnimatePresence>
        {toasts.map((toast) => (
          <motion.div
            key={toast.id}
            initial={{ opacity: 0, y: 12, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 8, scale: 0.95 }}
            transition={{ duration: 0.18 }}
            className="pointer-events-auto flex items-center gap-2.5 bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-white/10 rounded-full pl-3.5 pr-2 py-2 shadow-[0_8px_28px_rgba(0,0,0,0.15)] dark:shadow-[0_8px_28px_rgba(0,0,0,0.5)] max-w-[420px]"
          >
            {ICONS[toast.type]}
            <span className="text-sm text-zinc-700 dark:text-zinc-200">{toast.message}</span>
            <button
              onClick={() => onDismiss(toast.id)}
              className="w-6 h-6 flex items-center justify-center rounded-full text-zinc-400 hover:bg-zinc-100 dark:hover:bg-white/10 hover:text-zinc-900 dark:hover:text-white transition-colors shrink-0"
            >
              <X size={13} />
            </button>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}
