import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/gamification.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  UserProfile? _currentUser;
  DailyStreak? _streak;
  List<Achievement> _achievements = [];
  bool _isLoading = false;

  UserProfile? get currentUser => _currentUser;
  DailyStreak? get streak => _streak;
  List<Achievement> get achievements => _achievements;
  bool get isLoading => _isLoading;

  // Initialize user data
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _authService.getCurrentUserProfile();
      if (_currentUser != null) {
        // CRITICAL: Set Firebase user ID in SupabaseService for all Supabase operations
        SupabaseService.setFirebaseUserId(_currentUser!.id);
        print('🔑 User ID set during init: ${_currentUser!.id}');

        await loadUserData();
        await updateDailyStreak();
      }
    } catch (e) {
      print('Error initializing user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load all user data
  Future<void> loadUserData() async {
    if (_currentUser == null) return;

    _streak = await _dbService.getStreak();
    _achievements = await _dbService.getAchievements();

    // Initialize streak if it doesn't exist
    if (_streak == null) {
      _streak = DailyStreak(
        lastActiveDate: DateTime.now(),
        activityDates: [DateTime.now()],
      );
      await _dbService.updateStreak(_streak!);
    }

    // Initialize default achievements if none exist
    if (_achievements.isEmpty) {
      await _initializeAchievements();
    }

    notifyListeners();
  }

  // Update daily streak
  Future<void> updateDailyStreak() async {
    if (_currentUser == null || _streak == null) return;

    final now = DateTime.now();
    final lastActive = _streak!.lastActiveDate;
    final daysDifference = now.difference(lastActive).inDays;

    if (daysDifference == 0) {
      // Same day, do nothing
      return;
    } else if (daysDifference == 1) {
      // Consecutive day, increase streak
      _streak!.currentStreak++;
      if (_streak!.currentStreak > _streak!.longestStreak) {
        _streak!.longestStreak = _streak!.currentStreak;
      }
    } else {
      // Streak broken
      _streak!.currentStreak = 1;
    }

    _streak!.lastActiveDate = now;
    _streak!.activityDates.add(now);
    await _dbService.updateStreak(_streak!);

    // Update user profile
    _currentUser!.dailyStreak = _streak!.currentStreak;
    _currentUser!.lastActiveDate = now;
    await _authService.updateUserProfile(_currentUser!);

    notifyListeners();

    // Check for streak achievements
    await _checkStreakAchievements();
  }

  // Add XP
  Future<void> addXP(int xp) async {
    if (_currentUser == null) return;

    _currentUser!.xpPoints += xp;
    await _authService.updateUserProfile(_currentUser!);
    notifyListeners();
  }

  // Unlock achievement
  Future<void> unlockAchievement(String achievementId) async {
    if (_achievements.isEmpty) {
      await _initializeAchievements();
    }

    try {
      final achievement = _achievements.firstWhere(
        (a) => a.id == achievementId,
        orElse: () => Achievement(
          id: 'unknown',
          title: 'Unknown',
          description: '',
          iconName: '',
          xpReward: 0,
          category: '',
        ),
      );

      if (achievement.id != 'unknown' && !achievement.isUnlocked) {
        achievement.isUnlocked = true;
        achievement.unlockedAt = DateTime.now();
        await _dbService.unlockAchievement(achievementId);

        // Add XP reward
        await addXP(achievement.xpReward);

        notifyListeners();
      }
    } catch (e) {
      print('Error unlocking achievement: $e');
    }
  }

  // Update user profile
  Future<void> updateProfile(UserProfile profile) async {
    _currentUser = profile;
    await _authService.updateUserProfile(profile);
    notifyListeners();
  }

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _streak = null;
    _achievements = [];
    notifyListeners();
  }

  // Initialize default achievements
  Future<void> _initializeAchievements() async {
    final defaultAchievements = [
      Achievement(
        id: 'first_login',
        title: 'Welcome Aboard!',
        description: 'Completed your first login',
        iconName: 'welcome',
        xpReward: 10,
        category: 'general',
      ),
      Achievement(
        id: 'first_subject',
        title: 'Subject Master',
        description: 'Created your first subject',
        iconName: 'subject',
        xpReward: 20,
        category: 'learning',
      ),
      Achievement(
        id: 'first_quiz',
        title: 'Quiz Taker',
        description: 'Completed your first quiz',
        iconName: 'quiz',
        xpReward: 30,
        category: 'quiz',
      ),
      Achievement(
        id: 'quiz_master_10',
        title: 'Quiz Master',
        description: 'Completed 10 quizzes',
        iconName: 'quiz_master',
        xpReward: 100,
        category: 'quiz',
      ),
      Achievement(
        id: 'perfect_score',
        title: 'Perfect Score!',
        description: 'Got 100% on a quiz',
        iconName: 'perfect',
        xpReward: 50,
        category: 'quiz',
      ),
      Achievement(
        id: 'streak_3',
        title: '3-Day Streak',
        description: 'Learned for 3 consecutive days',
        iconName: 'streak_3',
        xpReward: 30,
        category: 'streak',
      ),
      Achievement(
        id: 'streak_7',
        title: 'Week Warrior',
        description: 'Learned for 7 consecutive days',
        iconName: 'streak_7',
        xpReward: 70,
        category: 'streak',
      ),
      Achievement(
        id: 'streak_30',
        title: 'Monthly Master',
        description: 'Learned for 30 consecutive days',
        iconName: 'streak_30',
        xpReward: 300,
        category: 'streak',
      ),
      Achievement(
        id: 'flashcard_50',
        title: 'Memory Champion',
        description: 'Reviewed 50 flashcards',
        iconName: 'flashcard',
        xpReward: 50,
        category: 'flashcard',
      ),
      Achievement(
        id: 'game_player',
        title: 'Game Player',
        description: 'Played your first learning game',
        iconName: 'game',
        xpReward: 25,
        category: 'learning',
      ),
    ];

    for (var achievement in defaultAchievements) {
      await _dbService.saveAchievement(achievement);
    }

    _achievements = defaultAchievements;
    notifyListeners();
  }

  // Check streak achievements
  Future<void> _checkStreakAchievements() async {
    final currentStreak = _streak?.currentStreak ?? 0;

    if (currentStreak >= 3) await unlockAchievement('streak_3');
    if (currentStreak >= 7) await unlockAchievement('streak_7');
    if (currentStreak >= 30) await unlockAchievement('streak_30');
  }
}
