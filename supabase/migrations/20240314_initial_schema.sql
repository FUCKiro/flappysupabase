-- Enable UUID extension
create extension if not exists "uuid-ossp" schema extensions;

-- Create highscores table
create table if not exists public.highscores (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users not null,
  score integer not null check (score >= 0),
  username text not null,
  timestamp timestamptz not null default now(),
  constraint unique_user_highscore unique (user_id)
);

-- Setup Row Level Security
alter table public.highscores enable row level security;

-- Drop existing policies if they exist
drop policy if exists "Anyone can read highscores" on public.highscores;
drop policy if exists "Users can insert their own scores" on public.highscores;
drop policy if exists "Users can update their own scores" on public.highscores;

-- Access policies
create policy "Anyone can read highscores"
  on public.highscores for select using (true);

create policy "Users can insert their own scores"
  on public.highscores for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own scores"
  on public.highscores for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id AND score > (
    select score from public.highscores 
    where user_id = auth.uid()
  ));

-- Create function to clean old scores
create or replace function public.clean_old_scores()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.highscores
  where timestamp < date_trunc('week', now());
end;
$$;