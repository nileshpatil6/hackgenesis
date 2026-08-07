"use client";
import { useState } from "react";
import { signInWithEmailAndPassword } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { motion } from "framer-motion";
import { Mail, Lock, LogIn, ArrowRight, UserCheck } from "lucide-react";

export default function LoginPage() {
  const router = useRouter();
  const { loginAsGuest } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const login = async () => {
    try {
      await signInWithEmailAndPassword(auth, email, password);
      router.push("/dashboard");
    } catch (err: any) {
      setError(err.message || "Login failed");
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
            onClick={handleGuestLogin}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full px-6 py-4 bg-zinc-900 text-white rounded-xl font-sans font-medium hover:bg-orange-500 transition-all duration-300 mb-6 shadow-sm hover:shadow-md flex items-center justify-center gap-3"
          >
            <UserCheck className="w-5 h-5" />
            Continue as Guest
          </motion.button>

          <div className="relative my-8">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-zinc-200"></div>
            </div>
            <div className="relative flex justify-center text-sm">
              <span className="px-4 bg-white/60 font-mono text-zinc-500 uppercase tracking-wider text-xs">
                or sign in
              </span>
            </div>
          </div>

          <div className="relative mb-4">
            <div className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-400">
              <Mail className="w-5 h-5" />
            </div>
            <input
              type="email"
              placeholder="Email address"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full pl-12 pr-5 py-4 bg-white border border-zinc-200 rounded-xl font-sans text-zinc-900 placeholder-zinc-400 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 focus:outline-none transition-all duration-500"
            />
          </div>

          <div className="relative mb-8">
            <div className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-400">
              <Lock className="w-5 h-5" />
            </div>
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full pl-12 pr-5 py-4 bg-white border border-zinc-200 rounded-xl font-sans text-zinc-900 placeholder-zinc-400 focus:border-orange-500 focus:ring-2 focus:ring-orange-500/20 focus:outline-none transition-all duration-500"
            />
          </div>

          <motion.button
            onClick={login}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full px-6 py-4 bg-gradient-to-r from-orange-500 to-orange-600 text-white font-sans font-medium rounded-xl hover:from-orange-600 hover:to-orange-700 transition-all duration-500 shadow-lg hover:shadow-xl flex items-center justify-center gap-2"
          >
            Sign In
            <ArrowRight className="w-5 h-5" />
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

          <p className="font-sans text-center mt-8 text-zinc-600">
            Don't have an account?{" "}
            <a
              href="/signup"
              className="text-orange-500 hover:text-orange-600 font-medium transition-colors duration-500"
            >
              Sign up
            </a>
          </p>
        </div>
      </motion.div>
    </div>
  );
}
