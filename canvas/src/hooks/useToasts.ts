import { useCallback, useRef, useState } from 'react';
import { ToastItem, ToastType } from '../components/ToastStack';

export function useToasts() {
  const [toasts, setToasts] = useState<ToastItem[]>([]);
  const nextId = useRef(0);

  const dismissToast = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const showToast = useCallback((message: string, type: ToastType = 'info') => {
    const id = nextId.current++;
    setToasts((prev) => [...prev, { id, message, type }]);
    setTimeout(() => dismissToast(id), 3500);
  }, [dismissToast]);

  return { toasts, showToast, dismissToast };
}
