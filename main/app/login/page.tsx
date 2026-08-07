"use client";
import { useState } from "react";
import { signInWithPopup } from "firebase/auth";
import { auth, googleProvider } from "@/lib/firebase";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { motion } from "framer-motion";
import { LogIn, UserCheck } from "lucide-react";

export default function LoginPage() {
  const router = useRouter();
  const { loginAsGuest } = useAuth();
  const [error, setError] = useState("");
  const [signingIn, setSigningIn] = useState(false);

  const handleGoogleLogin = async () => {
    setError("");
    setSigningIn(true);
    try {
      await signInWithPopup(auth, googleProvider);
      router.push("/dashboard");
    } catch (err: any) {
      setError(err.message || "Google sign-in failed");
    } finally {
      setSigningIn(false);
    }
  };

  const handleGuestLogin = () => {
    loginAsGuest();
    router.push("/dashboard");
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 via-white to-zinc-50 flex items-center justify-center px-8 py-16 transition-colors duration-500">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.6 }}
        className="w-full max-w-md"
      >
        <div className="bg-white/60 backdrop-blur-md border border-zinc-200 rounded-2xl p-10 shadow-xl hover:shadow-2xl transition-shadow duration-500">
          <div className="text-center mb-10">
            <motion.div
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={{ delay: 0.2 }}
              className="inline-flex items-center justify-center w-16 h-16 bg-gradient-to-br from-orange-500 to-orange-600 rounded-2xl mb-6 shadow-lg"
            >
              <LogIn className="w-8 h-8 text-white" />
            </motion.div>
            <h1 className="font-serif text-4xl text-zinc-900 mb-3">
              Welcome Back
            </h1>
            <p className="font-sans text-zinc-600">
              Sign in to continue your learning journey
            </p>
          </div>

          <motion.button
            onClick={handleGoogleLogin}
            disabled={signingIn}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full px-6 py-4 bg-white text-zinc-900 border border-zinc-200 rounded-xl font-sans font-medium hover:border-orange-300 hover:shadow-md transition-all duration-300 mb-4 flex items-center justify-center gap-3 disabled:opacity-60 disabled:cursor-not-allowed"
          >
            <svg className="w-5 h-5" viewBox="0 0 24 24">
              <path fill="#4285F4" d="M23.52 12.27c0-.85-.08-1.67-.22-2.45H12v4.64h6.47c-.28 1.5-1.13 2.78-2.4 3.63v3h3.88c2.27-2.09 3.57-5.17 3.57-8.82z" />
              <path fill="#34A853" d="M12 24c3.24 0 5.96-1.07 7.95-2.91l-3.88-3c-1.08.72-2.45 1.15-4.07 1.15-3.13 0-5.78-2.11-6.73-4.96H1.27v3.11C3.25 21.3 7.31 24 12 24z" />
              <path fill="#FBBC05" d="M5.27 14.28A7.2 7.2 0 0 1 4.9 12c0-.79.14-1.56.37-2.28V6.61H1.27A11.98 11.98 0 0 0 0 12c0 1.94.46 3.77 1.27 5.39l4-3.11z" />
              <path fill="#EA4335" d="M12 4.75c1.76 0 3.35.61 4.6 1.8l3.45-3.45C17.95 1.19 15.24 0 12 0 7.31 0 3.25 2.7 1.27 6.61l4 3.11C6.22 6.86 8.87 4.75 12 4.75z" />
            </svg>
            {signingIn ? "Signing in..." : "Continue with Google"}
          </motion.button>

          <div className="relative my-8">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-zinc-200"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-4 bg-white/60 font-mono text-zinc-500 uppercase tracking-wider text-xs">
                or
              </span>
            </div>
          </div>

          <motion.button
            onClick={handleGuestLogin}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full px-6 py-4 bg-zinc-900 text-white rounded-xl font-sans font-medium hover:bg-orange-500 transition-all duration-300 shadow-sm hover:shadow-md flex items-center justify-center gap-3"
          >
            <UserCheck className="w-5 h-5" />
            Continue as Guest
          </motion.button>

          {error && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-6 px-5 py-4 bg-red-50 border border-red-200 rounded-xl"
            >
              <p className="font-sans text-sm text-red-800 text-center">
                {error}
              </p>
            </motion.div>
          )}
        </div>
      </motion.div>
    </div>
  );
}
