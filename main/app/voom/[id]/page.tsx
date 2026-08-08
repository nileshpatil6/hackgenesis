"use client";

import { useAuth } from "../../../context/AuthContext";
import { useRouter, useParams } from "next/navigation";
import { useEffect, useState } from "react";
import { motion } from "framer-motion";
import { AppHeader } from "@/components/AppHeader";
import {
  Clock,
  Trophy,
  CheckCircle,
  Circle,
  Code,
  Target,
  Medal,
  Crown,
  Zap,
  Users,
} from "lucide-react";

interface Question {
  id: string;
  question_text: string;
  difficulty: "easy" | "medium" | "hard";
  points: number;
  category: string;
}

interface Room {
  id: string;
  topic: string;
  description: string;
  difficulty: "Easy" | "Medium" | "Hard";
  total_questions: number;
  active_users: number;
  starts_at: string;
  ends_at: string;
  status: "upcoming" | "active" | "ended";
  icon: string;
  questions: Question[];
}

interface LeaderboardEntry {
  rank: number;
  user_name: string;
  user_id: string;
  questions_solved: number;
  total_points: number;
  last_solved_at: string;
}

export default function RoomPage() {
  const { user, loading } = useAuth();
  const router = useRouter();
  const params = useParams();
  const roomId = params.id as string;

  const [room, setRoom] = useState<Room | null>(null);
  const [questions, setQuestions] = useState<Question[]>([]);
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);
  const [solvedQuestions, setSolvedQuestions] = useState<Set<string>>(new Set());
  const [userProgress, setUserProgress] = useState({ questionsSolved: 0, totalPoints: 0 });
  const [timeRemaining, setTimeRemaining] = useState("");
  const [activeTab, setActiveTab] = useState<"questions" | "leaderboard">("questions");

  useEffect(() => {
    if (!loading && !user) router.push("/login");
  }, [user, loading, router]);

  useEffect(() => {
    if (roomId) {
      loadRoomData();
      const interval = setInterval(() => {
        calculateTimeRemaining();
      }, 1000);
      return () => clearInterval(interval);
    }
  }, [roomId]);

  useEffect(() => {
    if (roomId && user) {
      loadUserProgress();
    }
  }, [roomId, user]);

  // Listen for the canvas app reporting back that the active question was solved
  useEffect(() => {
    function handleCanvasMessage(event: MessageEvent) {
      const data = event.data;
      if (!data || data.type !== "canvas-challenge-solved" || data.source !== "voom") return;
      if (data.roomId !== roomId) return;
      if (solvedQuestions.has(data.questionId)) return;
      markQuestionSolved(data.questionId, data.points || 0);
    }
    window.addEventListener("message", handleCanvasMessage);
    return () => window.removeEventListener("message", handleCanvasMessage);
  }, [roomId, solvedQuestions, userProgress, user]);

  async function loadRoomData() {
    try {
      const res = await fetch(`/api/voom/rooms/${roomId}`);
      const data = await res.json();
      if (data.success) {
        setRoom(data.room);
        setQuestions(data.room.questions);
      }
    } catch (err) {
      console.error("Failed to load room:", err);
    }
    loadLeaderboard();
  }

  async function loadUserProgress() {
    if (!user) return;
    try {
      const res = await fetch(`/api/voom/progress?roomId=${roomId}&userId=${user.uid}`);
      const data = await res.json();
      if (data.success && data.progress) {
        setSolvedQuestions(new Set(data.progress.questionsSolved));
        setUserProgress({
          questionsSolved: data.progress.questionsSolved.length,
          totalPoints: data.progress.totalPoints
        });
      }
    } catch (err) {
      console.error("Failed to load progress:", err);
    }
  }

  async function loadLeaderboard() {
    try {
      const res = await fetch(`/api/voom/leaderboard?roomId=${roomId}`);
      const data = await res.json();
      if (data.success) {
        setLeaderboard(data.leaderboard);
      }
    } catch (err) {
      console.error("Failed to load leaderboard:", err);
    }
  }

  function calculateTimeRemaining() {
    if (!room) return;

    const now = new Date();
    const end = new Date(room.ends_at);
    const diff = end.getTime() - now.getTime();

    if (diff <= 0) {
      setTimeRemaining("Time's up!");
      return;
    }

    const hours = Math.floor(diff / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((diff % (1000 * 60)) / 1000);

    setTimeRemaining(`${hours}h ${minutes}m ${seconds}s`);
  }

  function handleSolveQuestion(question: Question) {
    // Store the current question in localStorage so canvas can access it
    localStorage.setItem("currentVoomQuestion", JSON.stringify({
      roomId: roomId,
      questionId: question.id,
      questionText: question.question_text,
      points: question.points
    }));

    // Open canvas in new window
    window.open("http://localhost:5000", "_blank");
  }

  async function markQuestionSolved(questionId: string, points: number) {
    if (!user) return;

    try {
      const res = await fetch("/api/voom/submit", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          roomId,
          questionId,
          userId: user.uid,
          userName: user.email?.split("@")[0] || "User",
          pointsEarned: points
        })
      });
      const data = await res.json();
      if (!data.success) return;
    } catch (err) {
      console.error("Failed to submit solution:", err);
      return;
    }

    const newSolved = new Set(solvedQuestions);
    newSolved.add(questionId);
    setSolvedQuestions(newSolved);

    setUserProgress({
      questionsSolved: newSolved.size,
      totalPoints: userProgress.totalPoints + points
    });

    // Reload room (for the real active_users count) and leaderboard
    loadRoomData();
  }

  const getDifficultyColor = (difficulty: string) => {
    switch(difficulty?.toLowerCase()) {
      case "easy": return "bg-emerald-100 dark:bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 border-emerald-200 dark:border-emerald-500/30";
      case "medium": return "bg-amber-100 dark:bg-amber-500/10 text-amber-700 dark:text-amber-400 border-amber-200 dark:border-amber-500/30";
      case "hard": return "bg-rose-100 dark:bg-rose-500/10 text-rose-700 dark:text-rose-400 border-rose-200 dark:border-rose-500/30";
      default: return "bg-zinc-100 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300 border-zinc-200 dark:border-zinc-700";
    }
  };

  const getQuestionStatus = (questionId: string) => {
    return solvedQuestions.has(questionId);
  };

  if (loading || !room) {
    return (
      <div className="min-h-screen flex justify-center items-center bg-white dark:bg-zinc-950">
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="p-8 bg-white/60 dark:bg-zinc-900/60 backdrop-blur-md border border-zinc-200 dark:border-zinc-800 rounded-2xl shadow-lg"
        >
          <div className="flex items-center gap-3">
            <motion.div
              animate={{ rotate: 360 }}
              transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
            >
              <Code className="w-6 h-6 text-orange-500" />
            </motion.div>
            <p className="text-lg font-sans text-zinc-900 dark:text-zinc-100">Loading room...</p>
          </div>
        </motion.div>
      </div>
    );
  }

  const userRank = leaderboard.findIndex(entry => entry.user_id === user?.uid) + 1;

  const isTimeCritical = timeRemaining && !timeRemaining.includes("Time's up") &&
    parseInt(timeRemaining.split('h')[0]) === 0 &&
    parseInt(timeRemaining.split('h')[1]?.split('m')[0] || "60") < 10;

  return (
    <div className="min-h-screen bg-white dark:bg-zinc-950">
      <AppHeader backHref="/voom" backLabel="Back to Rooms" />

      {/* Room Header */}
      <div className="py-16 px-6 max-w-7xl mx-auto">
        <motion.div
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.1 }}
          className="bg-white/60 dark:bg-zinc-900/60 backdrop-blur-md border border-zinc-200 dark:border-zinc-800 rounded-2xl p-8 mb-6 shadow-lg"
        >
          <div className="flex justify-between items-start gap-6 mb-6">
            <div className="flex gap-6 items-center flex-1">
              <motion.div
                whileHover={{ rotate: [0, -10, 10, -10, 0] }}
                transition={{ duration: 0.5 }}
                className="w-20 h-20 flex items-center justify-center bg-gradient-to-br from-orange-400 to-orange-600 rounded-2xl shadow-md"
              >
                <Target className="w-10 h-10 text-white" />
              </motion.div>
              <div>
                <h1 className="text-4xl font-serif font-bold text-zinc-900 dark:text-white mb-2">
                  {room.topic}
                </h1>
                <p className="text-base font-sans text-zinc-600 dark:text-zinc-400">
                  {room.description}
                </p>
              </div>
            </div>

            {/* Timer */}
            <motion.div
              animate={isTimeCritical ? { scale: [1, 1.05, 1] } : {}}
              transition={{ duration: 1, repeat: isTimeCritical ? Infinity : 0 }}
              className={`text-center px-6 py-4 rounded-xl min-w-[200px] border ${
                isTimeCritical
                  ? 'bg-orange-50 dark:bg-orange-500/10 border-orange-200 dark:border-orange-500/30'
                  : 'bg-white dark:bg-zinc-800 border-zinc-200 dark:border-zinc-700'
              }`}
            >
              <div className="flex items-center justify-center gap-2 mb-1">
                <Clock className={`w-4 h-4 ${isTimeCritical ? 'text-orange-500' : 'text-zinc-500 dark:text-zinc-400'}`} />
                <span className="text-xs font-mono uppercase tracking-wide text-zinc-500 dark:text-zinc-400">
                  Time Remaining
                </span>
              </div>
              <div className={`text-2xl font-mono font-bold ${
                isTimeCritical ? 'text-orange-500' : 'text-zinc-900 dark:text-zinc-100'
              }`}>
                {timeRemaining}
              </div>
            </motion.div>
          </div>

          {/* User Stats */}
          <div className="grid grid-cols-4 gap-4 p-6 bg-white/80 dark:bg-zinc-800/50 border border-zinc-100 dark:border-zinc-800 rounded-xl">
            <motion.div
              whileHover={{ y: -2 }}
              className="text-center"
            >
              <div className="text-3xl font-serif font-bold text-zinc-900 dark:text-white mb-1">
                {userProgress.questionsSolved}/{room.total_questions}
              </div>
              <div className="text-sm font-mono text-zinc-500 dark:text-zinc-400 uppercase tracking-wide">Solved</div>
            </motion.div>
            <motion.div
              whileHover={{ y: -2 }}
              className="text-center"
            >
              <div className="text-3xl font-serif font-bold text-orange-500 mb-1">
                {userProgress.totalPoints}
              </div>
              <div className="text-sm font-mono text-zinc-500 dark:text-zinc-400 uppercase tracking-wide">Points</div>
            </motion.div>
            <motion.div
              whileHover={{ y: -2 }}
              className="text-center"
            >
              <div className="text-3xl font-serif font-bold text-zinc-900 dark:text-white mb-1">
                #{userRank || "-"}
              </div>
              <div className="text-sm font-mono text-zinc-500 dark:text-zinc-400 uppercase tracking-wide">Rank</div>
            </motion.div>
            <motion.div
              whileHover={{ y: -2 }}
              className="text-center"
            >
              <div className="text-3xl font-serif font-bold text-zinc-900 dark:text-white mb-1">
                {leaderboard.length}
              </div>
              <div className="text-sm font-mono text-zinc-500 dark:text-zinc-400 uppercase tracking-wide">Competitors</div>
            </motion.div>
          </div>
        </motion.div>

        {/* Tabs */}
        <motion.div
          initial={{ y: 20, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 0.2 }}
          className="bg-white/60 dark:bg-zinc-900/60 backdrop-blur-md border border-zinc-200 dark:border-zinc-800 rounded-2xl p-2 mb-6 flex gap-2"
        >
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setActiveTab("questions")}
            className={`flex-1 px-6 py-4 rounded-xl font-sans text-base font-semibold transition-all flex items-center justify-center gap-2 ${
              activeTab === "questions"
                ? "bg-orange-500 text-white shadow-md"
                : "bg-transparent text-zinc-900 dark:text-zinc-100 hover:bg-zinc-50 dark:hover:bg-zinc-800"
            }`}
          >
            <Code className="w-5 h-5" />
            Questions ({questions.length})
          </motion.button>
          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            onClick={() => setActiveTab("leaderboard")}
            className={`flex-1 px-6 py-4 rounded-xl font-sans text-base font-semibold transition-all flex items-center justify-center gap-2 ${
              activeTab === "leaderboard"
                ? "bg-orange-500 text-white shadow-md"
                : "bg-transparent text-zinc-900 dark:text-zinc-100 hover:bg-zinc-50 dark:hover:bg-zinc-800"
            }`}
          >
            <Trophy className="w-5 h-5" />
            Leaderboard
          </motion.button>
        </motion.div>

        {/* Content */}
        {activeTab === "questions" ? (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {questions.map((question, index) => {
              const isSolved = getQuestionStatus(question.id);
              return (
                <motion.div
                  key={question.id}
                  initial={{ y: 20, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  transition={{ delay: index * 0.05 }}
                  whileHover={{ y: -4 }}
                  className={`bg-white/60 dark:bg-zinc-900/60 backdrop-blur-md rounded-2xl p-6 shadow-lg border-2 transition-all ${
                    isSolved
                      ? "border-emerald-200 dark:border-emerald-500/30 bg-emerald-50/30 dark:bg-emerald-500/5"
                      : "border-zinc-200 dark:border-zinc-800 hover:border-orange-200 dark:hover:border-orange-500/50"
                  }`}
                >
                  <div className="flex justify-between items-start mb-4">
                    <div className="flex items-center gap-2">
                      {isSolved ? (
                        <CheckCircle className="w-5 h-5 text-emerald-500" />
                      ) : (
                        <Circle className="w-5 h-5 text-zinc-400" />
                      )}
                      <span className="text-sm font-mono font-bold text-zinc-900 dark:text-zinc-100 uppercase tracking-wide">
                        Question #{index + 1}
                      </span>
                    </div>
                    <div className="flex gap-2 items-center">
                      <span className={`px-3 py-1 rounded-lg text-xs font-sans font-semibold capitalize border ${getDifficultyColor(question.difficulty)}`}>
                        {question.difficulty}
                      </span>
                      <span className="px-3 py-1 bg-orange-100 dark:bg-orange-500/10 text-orange-700 dark:text-orange-400 border border-orange-200 dark:border-orange-500/30 rounded-lg text-xs font-mono font-bold">
                        {question.points} pts
                      </span>
                    </div>
                  </div>

                  <p className="text-base font-sans text-zinc-700 dark:text-zinc-300 leading-relaxed mb-6 min-h-[60px]">
                    {question.question_text}
                  </p>

                  {isSolved ? (
                    <motion.div
                      initial={{ scale: 0.9 }}
                      animate={{ scale: 1 }}
                      className="flex items-center justify-center gap-2 py-3 px-4 bg-emerald-50 dark:bg-emerald-500/10 border border-emerald-200 dark:border-emerald-500/30 rounded-xl"
                    >
                      <CheckCircle className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
                      <span className="font-sans font-semibold text-emerald-700 dark:text-emerald-400">Solved!</span>
                    </motion.div>
                  ) : (
                    <motion.button
                      whileHover={{ scale: 1.02 }}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => handleSolveQuestion(question)}
                      className="w-full flex items-center justify-center gap-2 py-3 px-4 bg-gradient-to-r from-orange-500 to-orange-600 text-white rounded-xl font-sans font-semibold shadow-md hover:shadow-lg transition-shadow"
                    >
                      <Zap className="w-5 h-5" />
                      Solve on Canvas
                    </motion.button>
                  )}
                </motion.div>
              );
            })}
          </div>
        ) : (
          <motion.div
            initial={{ y: 20, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            className="bg-white/60 dark:bg-zinc-900/60 backdrop-blur-md border border-zinc-200 dark:border-zinc-800 rounded-2xl p-8 shadow-lg"
          >
            <div className="flex items-center gap-3 mb-6">
              <Trophy className="w-7 h-7 text-orange-500" />
              <h2 className="text-3xl font-serif font-bold text-zinc-900 dark:text-white">
                Leaderboard
              </h2>
            </div>
            {leaderboard.length === 0 ? (
              <motion.div
                initial={{ scale: 0.9, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                className="text-center py-16"
              >
                <Users className="w-16 h-16 text-zinc-300 dark:text-zinc-700 mx-auto mb-4" />
                <p className="text-lg font-sans text-zinc-500 dark:text-zinc-400">No submissions yet. Be the first!</p>
              </motion.div>
            ) : (
              <div className="flex flex-col gap-3">
                {leaderboard.map((entry, index) => {
                  const isCurrentUser = entry.user_id === user?.uid;
                  const RankIcon = entry.rank === 1 ? Crown : entry.rank === 2 || entry.rank === 3 ? Medal : Trophy;
                  const rankColor = entry.rank === 1 ? "text-amber-500" : entry.rank === 2 ? "text-zinc-400" : entry.rank === 3 ? "text-orange-600 dark:text-orange-400" : "text-zinc-500 dark:text-zinc-400";

                  return (
                    <motion.div
                      key={entry.user_id}
                      initial={{ x: -20, opacity: 0 }}
                      animate={{ x: 0, opacity: 1 }}
                      transition={{ delay: index * 0.05 }}
                      whileHover={{ x: 4 }}
                      className={`flex items-center gap-4 p-4 rounded-xl border-2 transition-all ${
                        isCurrentUser
                          ? "bg-orange-50/50 dark:bg-orange-500/10 border-orange-200 dark:border-orange-500/30"
                          : "bg-white/80 dark:bg-zinc-800/50 border-zinc-200 dark:border-zinc-700 hover:border-zinc-300 dark:hover:border-zinc-600"
                      }`}
                    >
                      <div className={`w-14 h-14 rounded-full flex items-center justify-center border-2 ${
                        entry.rank <= 3
                          ? "bg-gradient-to-br from-amber-100 to-amber-200 dark:from-amber-500/20 dark:to-amber-500/10 border-amber-300 dark:border-amber-500/40"
                          : "bg-zinc-50 dark:bg-zinc-800 border-zinc-200 dark:border-zinc-700"
                      }`}>
                        {entry.rank <= 3 ? (
                          <RankIcon className={`w-7 h-7 ${rankColor}`} />
                        ) : (
                          <span className="text-lg font-serif font-bold text-zinc-700 dark:text-zinc-300">
                            {entry.rank}
                          </span>
                        )}
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-1">
                          <span className="text-lg font-sans font-semibold text-zinc-900 dark:text-zinc-100">
                            {entry.user_name}
                          </span>
                          {isCurrentUser && (
                            <span className="px-2 py-0.5 bg-orange-100 dark:bg-orange-500/10 text-orange-700 dark:text-orange-400 border border-orange-200 dark:border-orange-500/30 rounded-md text-xs font-mono font-semibold">
                              YOU
                            </span>
                          )}
                        </div>
                        <div className="flex items-center gap-2 text-sm font-sans text-zinc-600 dark:text-zinc-400">
                          <CheckCircle className="w-4 h-4" />
                          <span>
                            Solved {entry.questions_solved} question{entry.questions_solved !== 1 ? 's' : ''}
                          </span>
                        </div>
                      </div>
                      <div className="text-right">
                        <div className="text-3xl font-serif font-bold text-orange-500 mb-1">
                          {entry.total_points}
                        </div>
                        <div className="text-xs font-mono text-zinc-500 dark:text-zinc-400 uppercase tracking-wide">points</div>
                      </div>
                    </motion.div>
                  );
                })}
              </div>
            )}
          </motion.div>
        )}
      </div>
    </div>
  );
}
