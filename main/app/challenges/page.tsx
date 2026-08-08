"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { 
  ArrowLeft, 
  Code, 
  Trophy, 
  Target, 
  Zap, 
  CheckCircle, 
  Circle,
  BookOpen,
  Brain,
  Award,
  Sparkles
} from "lucide-react";
import { AppHeader } from "@/components/AppHeader";

export default function ChallengesPage() {
  const router = useRouter();
  const [step, setStep] = useState(1);
  const [category, setCategory] = useState("");
  const [difficulty, setDifficulty] = useState("");
  const [questionCount, setQuestionCount] = useState(5);
  const [loading, setLoading] = useState(false);
  const [questions, setQuestions] = useState<any[]>([]);
  const [error, setError] = useState("");
  const [completedIndexes, setCompletedIndexes] = useState<Set<number>>(new Set());

  // Check for existing challenge data on mount
  useEffect(() => {
    const storedData = localStorage.getItem("challengeData");
    if (storedData) {
      const challengeData = JSON.parse(storedData);

      // Check if data has expired
      if (Date.now() < challengeData.expiresAt) {
        setQuestions(challengeData.questions);
        setCategory(challengeData.category);
        setDifficulty(challengeData.difficulty);
        setCompletedIndexes(new Set(challengeData.completedQuestions || []));
        setStep(2);
      } else {
        // Clear expired data
        localStorage.removeItem("challengeData");
      }
    }
  }, []);

  // Listen for the canvas app reporting back that a question was solved
  useEffect(() => {
    function handleCanvasMessage(event: MessageEvent) {
      const data = event.data;
      if (!data || data.type !== "canvas-challenge-solved" || data.source !== "challenge") return;

      const stored = localStorage.getItem("challengeData");
      if (!stored) return;
      const challengeData = JSON.parse(stored);
      const completed: number[] = challengeData.completedQuestions || [];
      if (completed.includes(data.questionIndex)) return;

      const updated = [...completed, data.questionIndex];
      challengeData.completedQuestions = updated;
      localStorage.setItem("challengeData", JSON.stringify(challengeData));
      setCompletedIndexes(new Set(updated));
    }
    window.addEventListener("message", handleCanvasMessage);
    return () => window.removeEventListener("message", handleCanvasMessage);
  }, []);

  const categories = [
    { id: "electronics", name: "Electronics", icon: Zap },
    { id: "ml", name: "Machine Learning", icon: Brain },
    { id: "physics", name: "Physics", icon: Target },
    { id: "mathematics", name: "Mathematics", icon: Code },
    { id: "programming", name: "Programming", icon: Code },
    { id: "chemistry", name: "Chemistry", icon: BookOpen }
  ];

  const difficulties = [
    { id: "easy", name: "Easy", color: "text-green-600", bgColor: "bg-green-50", borderColor: "border-green-200", icon: CheckCircle },
    { id: "medium", name: "Medium", color: "text-orange-600", bgColor: "bg-orange-50", borderColor: "border-orange-200", icon: Circle },
    { id: "hard", name: "Hard", color: "text-red-600", bgColor: "bg-red-50", borderColor: "border-red-200", icon: Zap }
  ];

  async function generateQuestions() {
    setLoading(true);
    setError("");

    try {
      const response = await fetch("/api/generate-questions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ category, difficulty, count: questionCount })
      });

      const data = await response.json();
      
      if (!response.ok) {
        throw new Error(data.error || "Failed to generate questions");
      }

      // Store all questions in localStorage with 30 minutes expiration
      const challengeData = {
        questions: data.questions,
        category,
        difficulty,
        createdAt: Date.now(),
        expiresAt: Date.now() + (30 * 60 * 1000), // 30 minutes
        currentIndex: 0,
        completedQuestions: []
      };
      localStorage.setItem("challengeData", JSON.stringify(challengeData));

      setQuestions(data.questions);
      setStep(2);
    } catch (err: any) {
      setError(err.message || "Failed to generate questions");
    } finally {
      setLoading(false);
    }
  }

  function startChallenge(questionIndex: number) {
    // Update current question index in localStorage
    const storedData = localStorage.getItem("challengeData");
    if (storedData) {
      const challengeData = JSON.parse(storedData);
      challengeData.currentIndex = questionIndex;
      localStorage.setItem("challengeData", JSON.stringify(challengeData));

      const question = challengeData.questions?.[questionIndex];
      if (question) {
        localStorage.setItem("currentChallengeQuestion", JSON.stringify({
          questionIndex,
          question: question.question,
          description: question.description,
          difficulty: question.difficulty,
          category: question.category,
          canvasType: question.canvasType,
          hints: question.hints,
        }));
      }
    }

    // Open the real drawing canvas app, same as the Voom room flow
    window.open("http://localhost:5000", "_blank");
  }

  return (
    <div className="min-h-screen bg-white dark:bg-zinc-950">
      <AppHeader />

      <div className="container mx-auto px-6 py-16">
        {step === 1 ? (
          // Step 1: Question Configuration
          <motion.div 
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="max-w-4xl mx-auto"
          >
            <div className="border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900 rounded-2xl p-10 shadow-sm">
              <div className="flex items-center gap-3 mb-2">
                <Trophy className="w-8 h-8 text-orange-500" />
                <h1 className="font-serif text-4xl font-bold text-zinc-900 dark:text-white">Generate Challenge</h1>
              </div>
              <p className="text-zinc-600 dark:text-zinc-400 mb-12">Configure your challenge questions</p>

              {/* Category Selection */}
              <div className="mb-10">
                <label className="font-mono text-sm uppercase tracking-wider text-zinc-500 dark:text-zinc-400 mb-4 flex items-center gap-2">
                  <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-orange-500 text-white text-xs font-bold">1</span>
                  Select Category
                </label>
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  {categories.map((cat) => {
                    const Icon = cat.icon;
                    return (
                      <motion.div
                        key={cat.id}
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        onClick={() => setCategory(cat.id)}
                        className={`p-6 border-2 rounded-xl cursor-pointer transition-all ${
                          category === cat.id
                            ? "border-orange-500 bg-orange-50 dark:bg-orange-500/10"
                            : "border-zinc-200 dark:border-zinc-700 hover:border-orange-200 dark:hover:border-orange-500/50 bg-white dark:bg-zinc-800"
                        }`}
                      >
                        <Icon className={`w-8 h-8 mb-3 ${category === cat.id ? "text-orange-500" : "text-zinc-400"}`} />
                        <div className="font-sans text-sm font-semibold text-zinc-900 dark:text-zinc-100">{cat.name}</div>
                      </motion.div>
                    );
                  })}
                </div>
              </div>

              {/* Difficulty Selection */}
              <div className="mb-10">
                <label className="font-mono text-sm uppercase tracking-wider text-zinc-500 dark:text-zinc-400 mb-4 flex items-center gap-2">
                  <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-orange-500 text-white text-xs font-bold">2</span>
                  Select Difficulty
                </label>
                <div className="grid grid-cols-3 gap-4">
                  {difficulties.map((diff) => {
                    const Icon = diff.icon;
                    return (
                      <motion.div
                        key={diff.id}
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        onClick={() => setDifficulty(diff.id)}
                        className={`p-6 border-2 rounded-xl cursor-pointer transition-all ${
                          difficulty === diff.id
                            ? `${diff.borderColor} ${diff.bgColor} dark:bg-opacity-10`
                            : "border-zinc-200 dark:border-zinc-700 hover:border-orange-200 dark:hover:border-orange-500/50 bg-white dark:bg-zinc-800"
                        }`}
                      >
                        <Icon className={`w-8 h-8 mb-3 ${difficulty === diff.id ? diff.color : "text-zinc-400"}`} />
                        <div className={`font-sans text-base font-semibold ${difficulty === diff.id ? diff.color : "text-zinc-900 dark:text-zinc-100"}`}>
                          {diff.name}
                        </div>
                      </motion.div>
                    );
                  })}
                </div>
              </div>

              {/* Question Count */}
              <div className="mb-10">
                <label className="font-mono text-sm uppercase tracking-wider text-zinc-500 dark:text-zinc-400 mb-4 flex items-center gap-2">
                  <span className="inline-flex items-center justify-center w-6 h-6 rounded-full bg-orange-500 text-white text-xs font-bold">3</span>
                  Number of Questions
                </label>
                <div className="flex gap-6 items-center">
                  <input
                    type="range"
                    min="3"
                    max="10"
                    value={questionCount}
                    onChange={(e) => setQuestionCount(parseInt(e.target.value))}
                    className="flex-1 h-2 bg-zinc-200 dark:bg-zinc-700 rounded-lg appearance-none cursor-pointer accent-orange-500"
                  />
                  <div className="px-6 py-3 bg-orange-500 text-white rounded-xl text-2xl font-bold font-mono min-w-[80px] text-center">
                    {questionCount}
                  </div>
                </div>
              </div>

              {error && (
                <motion.div
                  initial={{ opacity: 0, y: -10 }}
                  animate={{ opacity: 1, y: 0 }}
                  className="p-4 bg-red-50 dark:bg-red-500/10 border border-red-200 dark:border-red-500/30 text-red-700 dark:text-red-400 rounded-xl mb-6 flex items-start gap-2"
                >
                  <Circle className="w-5 h-5 flex-shrink-0 mt-0.5" />
                  <span className="text-sm">{error}</span>
                </motion.div>
              )}

              <motion.button
                whileHover={{ scale: category && difficulty ? 1.02 : 1 }}
                whileTap={{ scale: category && difficulty ? 0.98 : 1 }}
                onClick={generateQuestions}
                disabled={!category || !difficulty || loading}
                className={`w-full py-4 rounded-xl text-base font-semibold transition-all flex items-center justify-center gap-2 ${
                  category && difficulty
                    ? "bg-orange-500 hover:bg-orange-600 text-white cursor-pointer"
                    : "bg-zinc-200 dark:bg-zinc-800 text-zinc-400 dark:text-zinc-600 cursor-not-allowed"
                }`}
              >
                {loading ? (
                  <>
                    <motion.div
                      animate={{ rotate: 360 }}
                      transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
                    >
                      <Circle className="w-5 h-5" />
                    </motion.div>
                    Generating Questions...
                  </>
                ) : (
                  <>
                    <Sparkles className="w-5 h-5" />
                    Generate Questions
                  </>
                )}
              </motion.button>
            </div>
          </motion.div>
        ) : (
          // Step 2: Display Generated Questions
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="max-w-7xl mx-auto"
          >
            <div className="border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900 rounded-2xl p-8 mb-8 shadow-sm">
              <div className="flex items-center gap-3 mb-2">
                <BookOpen className="w-7 h-7 text-orange-500" />
                <h2 className="font-serif text-3xl font-bold text-zinc-900 dark:text-white">
                  Generated Questions
                </h2>
              </div>
              <p className="text-zinc-600 dark:text-zinc-400 font-mono text-sm">
                Category: <strong>{categories.find(c => c.id === category)?.name}</strong> |
                Difficulty: <strong className="capitalize">{difficulty}</strong> |
                Total: <strong>{questions.length} questions</strong>
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              {questions.map((q, index) => {
                const getDifficultyStyles = (difficulty: string) => {
                  switch (difficulty.toLowerCase()) {
                    case "easy":
                      return { bg: "bg-green-50 dark:bg-green-500/10", text: "text-green-600 dark:text-green-400", border: "border-green-200" };
                    case "medium":
                      return { bg: "bg-orange-50 dark:bg-orange-500/10", text: "text-orange-600 dark:text-orange-400", border: "border-orange-200" };
                    case "hard":
                      return { bg: "bg-red-50 dark:bg-red-500/10", text: "text-red-600 dark:text-red-400", border: "border-red-200" };
                    default:
                      return { bg: "bg-zinc-50 dark:bg-zinc-800", text: "text-zinc-600 dark:text-zinc-400", border: "border-zinc-200" };
                  }
                };

                const diffStyles = getDifficultyStyles(q.difficulty);
                const isSolved = completedIndexes.has(index);

                return (
                  <motion.div
                    key={index}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.05 }}
                    whileHover={{ scale: 1.02 }}
                    className={`border rounded-xl p-6 shadow-sm transition-all ${
                      isSolved
                        ? "border-green-200 dark:border-green-500/30 bg-green-50/30 dark:bg-green-500/5"
                        : "border-zinc-200 dark:border-zinc-800 hover:border-orange-200 dark:hover:border-orange-500/50 bg-white dark:bg-zinc-900"
                    }`}
                  >
                    <div className="flex justify-between items-center mb-4">
                      <span className="font-mono text-sm font-semibold text-orange-500">
                        Question {index + 1}
                      </span>
                      <span className={`px-3 py-1 rounded-lg text-xs font-mono font-semibold uppercase ${diffStyles.bg} ${diffStyles.text}`}>
                        {q.difficulty}
                      </span>
                    </div>

                    <h3 className="font-sans text-base font-semibold text-zinc-900 dark:text-zinc-100 mb-3 line-clamp-2">
                      {q.question}
                    </h3>

                    {q.description && (
                      <p className="text-sm text-zinc-600 dark:text-zinc-400 mb-4 line-clamp-3 leading-relaxed">
                        {q.description}
                      </p>
                    )}

                    {isSolved ? (
                      <div className="w-full py-3 bg-green-100 dark:bg-green-500/10 text-green-700 dark:text-green-400 rounded-lg text-sm font-semibold flex items-center justify-center gap-2">
                        <CheckCircle className="w-4 h-4" />
                        Solved!
                      </div>
                    ) : (
                      <motion.button
                        whileHover={{ scale: 1.02 }}
                        whileTap={{ scale: 0.98 }}
                        onClick={() => startChallenge(index)}
                        className="w-full py-3 bg-orange-500 hover:bg-orange-600 text-white rounded-lg text-sm font-semibold transition-colors flex items-center justify-center gap-2"
                      >
                        <Target className="w-4 h-4" />
                        Start Challenge
                      </motion.button>
                    )}
                  </motion.div>
                );
              })}
            </div>

            <motion.button
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.3 }}
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => {
                setStep(1);
                setQuestions([]);
                setCategory("");
                setDifficulty("");
              }}
              className="mt-8 mx-auto block px-6 py-3 bg-white dark:bg-zinc-900 border-2 border-zinc-200 dark:border-zinc-700 hover:border-orange-200 dark:hover:border-orange-500/50 text-zinc-900 dark:text-zinc-100 rounded-xl text-base font-semibold transition-colors flex items-center gap-2"
            >
              <ArrowLeft className="w-5 h-5" />
              Generate New Questions
            </motion.button>
          </motion.div>
        )}
      </div>
    </div>
  );
}
