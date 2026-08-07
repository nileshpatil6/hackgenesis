-- 1. PROFILES
create table if not exists public.profiles (
  id uuid references auth.users not null primary key,
  name text,
  email text,
  age int,
  educationLevel text,
  stream text,
  learningPreferences text[],
  learningPace text,
  interests text[],
  aiPersonality text,
  xpPoints int,
  badges text[],
  dailyStreak int,
  lastActiveDate timestamp with time zone,
  photoUrl text
);

-- 2. SUBJECTS
create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(), -- ensuring UUID
  name text not null,
  description text,
  color text,
  icon_name text, -- snake_case
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  total_notes int,
  completed_topics int,
  total_topics int,
  progress_percentage float,
  file_search_store_id text
);

-- 3. NOTES
create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text not null,
  description text,
  note_type int,
  file_path text,
  gemini_file_id text,
  file_search_document_id text,
  uploaded_at timestamp with time zone,
  updated_at timestamp with time zone,
  page_count int,
  file_size int,
  is_processed boolean,
  metadata jsonb,
  tags text[] -- or jsonb
);

-- 4. LESSONS
create table if not exists public.lessons (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text not null,
  description text,
  slides jsonb, -- Storing slides as JSONB 
  created_at timestamp with time zone,
  is_completed boolean,
  current_slide_index int,
  audio_url text
);

-- 5. QUIZZES
create table if not exists public.quizzes (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  lesson_id text,
  title text not null,
  questions jsonb, -- Storing questions as JSONB
  created_at timestamp with time zone,
  is_completed boolean,
  score int,
  total_attempts int,
  best_score int
);

-- 6. FLASHCARD DECKS
create table if not exists public.flashcard_decks (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text,
  cards jsonb, -- Storing cards list as JSONB
  created_at timestamp with time zone,
  last_reviewed_at timestamp with time zone,
  total_reviews int,
  mastery_percentage float
);

-- 7. ACHIEVEMENTS
create table if not exists public.achievements (
  id uuid primary key default gen_random_uuid(),
  title text,
  description text,
  icon_name text,
  xp_reward int,
  is_unlocked boolean,
  unlocked_at timestamp with time zone,
  category text
);

-- 8. STUDY PLANS
create table if not exists public.study_plans (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text,
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  tasks jsonb, -- Storing tasks as JSONB
  is_active boolean,
  completed_tasks int
);

-- 9. PLAYLISTS
create table if not exists public.study_playlists (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid references public.subjects(id) on delete cascade,
  title text,
  description text,
  videos jsonb, -- Storing videos as JSONB
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  playlist_url text,
  thumbnail_url text,
  total_duration int,
  watched_videos int
);

-- 10. CALENDAR EVENTS
create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  title text,
  description text,
  date timestamp with time zone,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  event_type text,
  subject_id uuid, -- Optional reference to subject
  color text,
  is_completed boolean,
  priority int,
  has_reminder boolean,
  reminder_minutes_before jsonb,
  location text,
  attachments jsonb,
  notes text,
  is_recurring boolean,
  recurring_pattern text,
  recurring_end_date timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone
);
