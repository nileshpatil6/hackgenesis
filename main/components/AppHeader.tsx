"use client";

import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { ArrowLeft, Sun, Moon, Trophy } from "lucide-react";
import { useTheme } from "@/context/ThemeContext";
import { ReactNode } from "react";

interface AppHeaderProps {
  backHref?: string;
  backLabel?: string;
  rightContent?: ReactNode;
}

export function AppHeader({ backHref = "/dashboard", backLabel = "Back to Dashboard", rightContent }: AppHeaderProps) {
  const router = useRouter();
  const { theme, toggleTheme } = useTheme();

  return (
    <nav className="sticky top-0 z-50 border-b border-zinc-200 dark:border-zinc-800 bg-white/70 dark:bg-zinc-950/70 backdrop-blur-md">
      <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between gap-4">
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="flex items-center gap-2 cursor-pointer"
          onClick={() => router.push("/dashboard")}
        >
          <Trophy className="w-6 h-6 text-orange-500" />
          <span className="font-serif text-2xl font-bold text-zinc-900 dark:text-white">Yukti-AI</span>
        </motion.div>

        <div className="flex items-center gap-3">
          {rightContent}

          <motion.button
            whileHover={{ scale: 1.05 }}
            whileTap={{ scale: 0.95 }}
            onClick={toggleTheme}
            aria-label="Toggle theme"
            className="flex items-center justify-center w-10 h-10 border border-zinc-200 dark:border-zinc-700 hover:border-orange-200 dark:hover:border-orange-500/50 bg-white dark:bg-zinc-900 rounded-lg text-zinc-700 dark:text-zinc-300 transition-colors"
          >
            {theme === "dark" ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
          </motion.button>

          {backHref && (
            <motion.button
              initial={{ opacity: 0, x: 20 }}
              animate={{ opacity: 1, x: 0 }}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => router.push(backHref)}
              className="flex items-center gap-2 px-4 py-2 border border-zinc-200 dark:border-zinc-700 hover:border-orange-200 dark:hover:border-orange-500/50 bg-white dark:bg-zinc-900 rounded-lg text-sm font-medium text-zinc-900 dark:text-zinc-100 transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              {backLabel}
            </motion.button>
          )}
        </div>
      </div>
    </nav>
  );
}
