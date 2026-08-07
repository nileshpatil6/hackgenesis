"use client";

import { useAuth } from "../../context/AuthContext";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Code, Trophy, Zap, Target, BookOpen, LogOut, User } from "lucide-react";

interface UserProfile {
  id: string;
  name: string;
  age: number;
  email: string | null;
}

export default function DashboardPage() {
  const { user, loading, logout } = useAuth();
  const router = useRouter();
  const [showModal, setShowModal] = useState(false);
  const [name, setName] = useState("");
  const [age, setAge] = useState("");
  const [userProfile, setUserProfile] = useState<UserProfile | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!loading && !user) router.push("/login");
  }, [user, loading, router]);

  useEffect(() => {
    if (user) {
      checkUserProfile();
    }
  }, [user]);

  function checkUserProfile() {
    if (!user) return;

    if (user.isGuest) {
      setUserProfile({
        id: user.uid,
        name: "Guest",
        age: 0,
        email: null,
      });
      setShowModal(false);
      return;
    }

    const storageKey = `profile_${user.uid}`;
    const storedProfile = localStorage.getItem(storageKey);

    if (!storedProfile) {
      setShowModal(true);
      return;
    }

    try {
      const parsedProfile: UserProfile = JSON.parse(storedProfile);
      setUserProfile(parsedProfile);
      setShowModal(false);
    } catch (error) {
      console.error("Invalid local profile data:", error);
      localStorage.removeItem(storageKey);
      setShowModal(true);
    }
  }

  function saveProfile() {
    if (!user || !name || !age) return;

    setSaving(true);
    try {
      const profileData: UserProfile = {
        id: user.uid,
        name: name.trim(),
        age: parseInt(age, 10),
        email: user.email ?? null,
      };

      localStorage.setItem(`profile_${user.uid}`, JSON.stringify(profileData));
      setUserProfile(profileData);
      setShowModal(false);
    } catch (error) {
      console.error("Error saving local profile:", error);
      alert("Failed to save profile locally. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  const containerVariants = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: { staggerChildren: 0.1 }
    }
  };

  const itemVariants = {
    hidden: { y: 20, opacity: 0 },
    visible: {
      y: 0,
      opacity: 1,
      transition: { duration: 0.5, ease: [0.25, 0.1, 0.25, 1] }
    }
  };

  const cards = [
    {
      title: "Experiment Lab",
      description: "Explore and experiment on our infinite canvas — your personal space for creative problem-solving.",
      icon: Code,
      path: "http://localhost:5000",
      external: true
    },
    {
      title: "Learning Platform",
      description: "Structured courses and guided modules to build mastery in AI and computational thinking.",
      icon: BookOpen,
      path: "http://localhost:3001",
      external: true
    },
    {
      title: "Challenges",
      description: "Test your skills with curated coding challenges from beginner to advanced levels.",
      icon: Trophy,
      path: "/challenges",
      external: false
    },
    {
      title: "Hackathons",
      description: "Join global research hackathons and solve real-world problems posted by scientists.",
      icon: Zap,
      path: "/hackathons",
      external: false
    },
    {
      title: "Voom",
      description: "Enter 24-hour challenge rooms and compete on live leaderboards across topics.",
      icon: Target,
      path: "/voom",
      external: false
    }
  ];

  if (loading) return (
    <div className="min-h-screen bg-white flex items-center justify-center">
      <div className="text-center">
        <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-orange-500 border-r-transparent"></div>
        <p className="mt-4 font-mono text-sm text-zinc-500">LOADING SYSTEM</p>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-white">
      {/* Navigation */}
      <nav className="border-b border-zinc-200 bg-white/80 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="font-serif text-2xl text-zinc-900">Yukti-AI</h1>
              <p className="font-mono text-xs text-zinc-500 mt-0.5">LEARNING ECOSYSTEM</p>
            </div>

            <div className="flex items-center gap-4">
              {userProfile && (
                <div className="flex items-center gap-3 px-4 py-2 bg-zinc-50 border border-zinc-200 rounded-lg">
                  <User className="w-4 h-4 text-zinc-500" />
                  <span className="font-sans text-sm text-zinc-900">{userProfile.name}</span>
                </div>
              )}
              <button
                onClick={logout}
                className="flex items-center gap-2 px-4 py-2 bg-zinc-900 text-white rounded-lg hover:bg-orange-500 transition-colors duration-300 font-sans text-sm"
              >
                <LogOut className="w-4 h-4" />
                Logout
              </button>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        className="max-w-7xl mx-auto px-6 py-16"
      >
        <motion.div variants={itemVariants} className="text-center mb-12">
          <h2 className="font-serif text-5xl text-zinc-900 mb-4">
            Learning Ecosystem
          </h2>
          <p className="font-sans text-lg text-zinc-600 max-w-2xl mx-auto">
            Master computational thinking through interactive challenges and collaborative problem-solving
          </p>
        </motion.div>

        {/* Cards Grid */}
        <motion.div
          variants={itemVariants}
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          {cards.map((card) => (
            <motion.div
              key={card.title}
              whileHover={{ y: -4 }}
              onClick={() => card.external ? window.open(card.path, '_blank') : router.push(card.path)}
              className="group relative bg-white/60 backdrop-blur-md border border-zinc-200 rounded-2xl p-8 cursor-pointer hover:border-orange-200 transition-all duration-300 overflow-hidden"
            >
              <div className="absolute inset-0 bg-gradient-to-br from-orange-50/0 to-orange-50/0 group-hover:from-orange-50/30 group-hover:to-orange-50/10 transition-all duration-300" />

              <div className="relative z-10">
                <div className="w-12 h-12 rounded-xl bg-zinc-50 border border-zinc-200 flex items-center justify-center mb-6 group-hover:border-orange-200 group-hover:bg-orange-50 transition-all duration-300">
                  <card.icon className="w-6 h-6 text-zinc-700 group-hover:text-orange-500 transition-colors duration-300" />
                </div>

                <h3 className="font-serif text-2xl text-zinc-900 mb-3">
                  {card.title}
                </h3>
                <p className="font-sans text-zinc-600 leading-relaxed">
                  {card.description}
                </p>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </motion.div>

      {/* Profile Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="bg-white border border-zinc-200 rounded-2xl p-8 max-w-md w-[90%] shadow-2xl"
          >
            <h2 className="font-serif text-3xl text-zinc-900 mb-2">
              Complete Profile
            </h2>
            <p className="font-sans text-zinc-600 mb-8">
              Please provide your information to continue
            </p>

            <div className="space-y-4">
              <div>
                <label className="font-mono text-xs text-zinc-500 uppercase tracking-wider block mb-2">
                  Full Name
                </label>
                <input
                  type="text"
                  placeholder="Enter your name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full px-4 py-3 bg-zinc-50 border border-zinc-200 rounded-lg font-sans text-zinc-900 placeholder-zinc-400 focus:border-orange-500 focus:outline-none transition-colors"
                />
              </div>

              <div>
                <label className="font-mono text-xs text-zinc-500 uppercase tracking-wider block mb-2">
                  Age
                </label>
                <input
                  type="number"
                  placeholder="Enter your age"
                  value={age}
                  onChange={(e) => setAge(e.target.value)}
                  className="w-full px-4 py-3 bg-zinc-50 border border-zinc-200 rounded-lg font-sans text-zinc-900 placeholder-zinc-400 focus:border-orange-500 focus:outline-none transition-colors"
                />
              </div>
            </div>

            <button
              onClick={saveProfile}
              disabled={!name || !age || saving}
              className={`w-full px-6 py-3 mt-8 font-sans font-medium rounded-lg transition-all duration-300 ${
                name && age
                  ? 'bg-orange-500 text-white hover:bg-orange-600 cursor-pointer'
                  : 'bg-zinc-200 text-zinc-400 cursor-not-allowed'
              }`}
            >
              {saving ? "Saving..." : "Save Profile"}
            </button>
          </motion.div>
        </div>
      )}
    </div>
  );
}
