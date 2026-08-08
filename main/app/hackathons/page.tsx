"use client";

import { useAuth } from "../../context/AuthContext";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { Search, Filter, Award, Calendar, Users, ArrowLeft, Beaker, Sprout, HeartPulse, Building2, Brain, Zap } from "lucide-react";

interface Problem {
  id: string;
  title: string;
  description: string;
  category: string;
  difficulty: "Beginner" | "Intermediate" | "Advanced";
  postedBy: string;
  organization: string;
  tags: string[];
  submissions: number;
  prize?: string;
  deadline?: string;
}


export default function HackathonsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const [selectedCategory, setSelectedCategory] = useState<string>("All");
  const [selectedDifficulty, setSelectedDifficulty] = useState<string>("All");
  const [searchQuery, setSearchQuery] = useState("");
  const [problems, setProblems] = useState<Problem[]>([]);
  const [loadingProblems, setLoadingProblems] = useState(true);

  useEffect(() => {
    if (!loading && !user) router.push("/login");
  }, [user, loading, router]);

  useEffect(() => {
    async function loadProblems() {
      setLoadingProblems(true);
      try {
        const res = await fetch("/api/hackathons/problems");
        const data = await res.json();
        if (data.success) setProblems(data.problems);
      } catch (err) {
        console.error("Failed to load hackathon problems:", err);
      } finally {
        setLoadingProblems(false);
      }
    }
    loadProblems();
  }, []);

  const categories = ["All", "Environment", "Healthcare", "Smart Cities", "Agriculture", "Energy", "Emergency Management", "Education", "Wildlife", "Disaster Management", "Accessibility"];
  const difficulties = ["All", "Beginner", "Intermediate", "Advanced"];

  const filteredProblems = problems.filter(problem => {
    const matchesCategory = selectedCategory === "All" || problem.category === selectedCategory;
    const matchesDifficulty = selectedDifficulty === "All" || problem.difficulty === selectedDifficulty;
    const matchesSearch = searchQuery === "" || 
      problem.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      problem.description.toLowerCase().includes(searchQuery.toLowerCase()) ||
      problem.tags.some(tag => tag.toLowerCase().includes(searchQuery.toLowerCase()));
    
    return matchesCategory && matchesDifficulty && matchesSearch;
  });

  const getDifficultyColor = (difficulty: string) => {
    switch(difficulty) {
      case "Beginner": return "#28a745";
      case "Intermediate": return "#fd7e14";
      case "Advanced": return "#dc3545";
      default: return "#6c757d";
    }
  };

  const categoryIcons: Record<string, any> = {
    Environment: Beaker,
    Healthcare: HeartPulse,
    "Smart Cities": Building2,
    Agriculture: Sprout,
    Education: Brain,
    Energy: Zap
  };

  if (loading) return (
    <div className="min-h-screen bg-white flex items-center justify-center">
      <div className="text-center">
        <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-orange-500 border-r-transparent"></div>
        <p className="mt-4 font-mono text-sm text-zinc-500">LOADING CHALLENGES</p>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-white">
      {/* Navigation Bar */}
      <nav className="bg-white/60 backdrop-blur-md border-b border-zinc-200 sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-8 py-4 flex justify-between items-center">
          <button
            onClick={() => router.push("/dashboard")}
            className="font-serif text-2xl font-bold text-zinc-900 hover:text-orange-500 transition-colors"
          >
            Yukti-AI
          </button>
          
          <button
            onClick={() => router.push("/dashboard")}
            className="flex items-center gap-2 px-4 py-2 bg-white border border-zinc-200 hover:border-orange-200 rounded-lg text-sm font-mono text-zinc-700 hover:text-orange-500 transition-all"
          >
            <ArrowLeft className="w-4 h-4" />
            DASHBOARD
          </button>
        </div>
      </nav>

      {/* Header */}
      <div className="py-16 px-8 text-center">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <div className="flex items-center justify-center gap-3 mb-4">
            <Award className="w-12 h-12 text-orange-500" />
            <h1 className="font-serif text-5xl font-bold text-zinc-900">
              Global Research Hackathons
            </h1>
          </div>
          <p className="font-sans text-xl text-zinc-600 max-w-3xl mx-auto">
            Solve real-world problems posted by scientists and researchers. Make your contribution count!
          </p>
        </motion.div>
      </div>

      {/* Filters and Search */}
      <div className="max-w-7xl mx-auto px-8 pb-16">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="bg-white/60 backdrop-blur-md border border-zinc-200 rounded-2xl p-6 mb-6 shadow-sm"
        >
          {/* Search Bar */}
          <div className="relative mb-6">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-zinc-400" />
            <input
              type="text"
              placeholder="Search problems, tags, or keywords..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-12 pr-4 py-3 bg-white border border-zinc-200 hover:border-orange-200 focus:border-orange-500 focus:outline-none rounded-lg font-sans text-zinc-900 placeholder:text-zinc-400"
            />
          </div>

          {/* Category Filter */}
          <div className="mb-6">
            <label className="flex items-center gap-2 font-mono text-xs uppercase tracking-wider text-zinc-700 mb-3">
              <Filter className="w-4 h-4" />
              Category
            </label>
            <div className="flex flex-wrap gap-2">
              {categories.map(category => (
                <button
                  key={category}
                  onClick={() => setSelectedCategory(category)}
                  className={`px-4 py-2 rounded-lg font-sans text-sm transition-all ${
                    selectedCategory === category
                      ? "bg-orange-500 text-white border-2 border-orange-500"
                      : "bg-white text-zinc-700 border-2 border-zinc-200 hover:border-orange-200"
                  }`}
                >
                  {category}
                </button>
              ))}
            </div>
          </div>

          {/* Difficulty Filter */}
          <div>
            <label className="flex items-center gap-2 font-mono text-xs uppercase tracking-wider text-zinc-700 mb-3">
              <Zap className="w-4 h-4" />
              Difficulty
            </label>
            <div className="flex gap-2">
              {difficulties.map(difficulty => (
                <button
                  key={difficulty}
                  onClick={() => setSelectedDifficulty(difficulty)}
                  className={`px-4 py-2 rounded-lg font-sans text-sm transition-all ${
                    selectedDifficulty === difficulty
                      ? "bg-orange-500 text-white border-2 border-orange-500"
                      : "bg-white text-zinc-700 border-2 border-zinc-200 hover:border-orange-200"
                  }`}
                >
                  {difficulty}
                </button>
              ))}
            </div>
          </div>
        </motion.div>

        {/* Results Count */}
        <div className="flex items-center justify-center gap-2 mb-6">
          <div className="font-mono text-sm text-zinc-600">
            {filteredProblems.length} Problem{filteredProblems.length !== 1 ? 's' : ''} Available
          </div>
        </div>

        {/* Problems Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredProblems.map((problem, index) => {
            const CategoryIcon = categoryIcons[problem.category] || Brain;
            return (
            <motion.div
              key={problem.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: index * 0.05 }}
              whileHover={{ y: -4, transition: { duration: 0.2 } }}
              onClick={() => router.push(`/hackathons/${problem.id}`)}
              className="bg-white/60 backdrop-blur-md border border-zinc-200 hover:border-orange-200 rounded-2xl p-6 cursor-pointer flex flex-col group shadow-sm hover:shadow-md transition-all"
            >
              {/* Header */}
              <div className="mb-4">
                <div className="flex justify-between items-start mb-3">
                  <span className={`px-3 py-1 rounded-md font-mono text-xs font-semibold ${
                    problem.difficulty === "Beginner" ? "bg-green-100 text-green-700" :
                    problem.difficulty === "Intermediate" ? "bg-orange-100 text-orange-700" :
                    "bg-red-100 text-red-700"
                  }`}>
                    {problem.difficulty.toUpperCase()}
                  </span>
                  <div className="flex items-center gap-1.5 px-3 py-1 bg-zinc-100 rounded-md">
                    <CategoryIcon className="w-3.5 h-3.5 text-zinc-600" />
                    <span className="font-mono text-xs text-zinc-600">
                      {problem.category}
                    </span>
                  </div>
                </div>
                <h3 className="font-serif text-xl font-bold text-zinc-900 mb-2 leading-tight group-hover:text-orange-500 transition-colors">
                  {problem.title}
                </h3>
                <p className="font-sans text-sm text-zinc-600 leading-relaxed">
                  {problem.description}
                </p>
              </div>

              {/* Tags */}
              <div className="flex flex-wrap gap-2 mb-4">
                {problem.tags.map(tag => (
                  <span
                    key={tag}
                    className="px-2 py-1 bg-orange-50 text-orange-600 rounded font-mono text-xs"
                  >
                    {tag}
                  </span>
                ))}
              </div>

              {/* Footer */}
              <div className="mt-auto pt-4 border-t border-zinc-200">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <div className="font-mono text-xs text-zinc-400 uppercase tracking-wider mb-1">Posted by</div>
                    <div className="font-sans text-sm font-semibold text-zinc-900">{problem.postedBy}</div>
                    <div className="font-sans text-xs text-zinc-600">{problem.organization}</div>
                  </div>
                  <div className="text-right">
                    <div className="flex items-center gap-1 justify-end mb-1">
                      <Users className="w-3.5 h-3.5 text-zinc-400" />
                      <span className="font-mono text-xs text-zinc-400 uppercase tracking-wider">Submissions</span>
                    </div>
                    <div className="font-serif text-xl font-bold text-orange-500">{problem.submissions}</div>
                  </div>
                </div>

                {problem.prize && (
                  <div className="flex justify-between items-center p-3 bg-orange-50 border border-orange-200 rounded-lg mb-3">
                    <div className="flex items-center gap-2">
                      <Award className="w-4 h-4 text-orange-600" />
                      <span className="font-mono text-sm font-semibold text-orange-700">
                        {problem.prize}
                      </span>
                    </div>
                    {problem.deadline && (
                      <div className="flex items-center gap-1.5">
                        <Calendar className="w-3.5 h-3.5 text-orange-600" />
                        <span className="font-mono text-xs text-orange-700">
                          {problem.deadline}
                        </span>
                      </div>
                    )}
                  </div>
                )}

                <button className="w-full py-3 bg-orange-500 hover:bg-orange-600 text-white rounded-lg font-sans text-sm font-semibold transition-colors">
                  View Details & Contribute →
                </button>
              </div>
            </motion.div>
          );})}
        </div>

        {filteredProblems.length === 0 && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="bg-white/60 backdrop-blur-md border border-zinc-200 rounded-2xl p-12 text-center"
          >
            <Search className="w-16 h-16 text-zinc-300 mx-auto mb-4" />
            <h3 className="font-serif text-2xl font-bold text-zinc-900 mb-2">
              No Problems Found
            </h3>
            <p className="font-sans text-base text-zinc-600">
              Try adjusting your filters or search query
            </p>
          </motion.div>
        )}
      </div>
    </div>
  );
}
