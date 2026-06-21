-- ============================================================================
-- Family Garden — 记忆/节点/AI 数据模型（增量迁移）
-- ----------------------------------------------------------------------------
-- 在 Supabase Dashboard → SQL Editor 运行。
-- 本文件是 supabase_schema.sql 的【增量】，只新增表，不改动既有
-- family_members / travel_places / postcards / messages / mailbox_events。
--
-- 设计依据：docs/05_backend_data_model.md（数据模型）、docs/04_ai_interfaces.md
-- （AI 契约 / 枚举）、docs/dev/34_work_plan.md（cross_member_interaction_count、
-- bottles.target_member_id、memory_link 等）。
--
-- 关键边界（务必遵守）：
--   * AI 不输出坐标。nodes.slot_id 由游戏系统（SlotManager）分配，AI 只产出
--     suggested_scene / node_type / object_type / zone。
--   * 表内 *_type / scene / status / state 等枚举用 CHECK 约束锁定，取值与
--     docs/04 契约一致；契约变更须按 Part 0.2 同步更新 docs/04 + mock + 本文件，
--     并在下方变更日志登记。
--   * MVP 仍按固定 family_id = 'Happy_birthday_David' 做 RLS 隔离（与既有一致）。
--
-- 变更日志：
--   2026-06-19  初版：families(+cross_member_interaction_count) / memories /
--               nodes / bottles(+target_member_id) / answers / rooms /
--               room_objects + RLS + 索引。
-- ============================================================================

create extension if not exists pgcrypto;
create extension if not exists moddatetime schema extensions;

-- ----------------------------------------------------------------------------
-- families：家庭级表。
--   * 既有数据用固定 text family_id 标识，这里给它一个正式落点，
--     并承载 cross_member_interaction_count（分季背景的“家庭关系温度计”）。
--   * cross_member_interaction_count 是缓存值：每次“有效跨成员回答”+1。
--     有效定义（在应用层 MemoryManager 维护）：回答者 != 该 memory 上传者，
--     且同一人对同一 memory 的重复回答只计一次。
-- ----------------------------------------------------------------------------
create table if not exists public.families (
  id text primary key,
  name text,
  invite_code text,
  created_by text,
  cross_member_interaction_count integer not null default 0,
  created_at timestamptz not null default now()
);

-- 为 MVP 固定家庭播种一行（幂等）。
insert into public.families (id, name)
values ('Happy_birthday_David', 'Happy birthday David')
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- memories：核心表。存用户上传的原始记忆 + AI 生成的记忆卡片（ai_card）。
--   * ai_card 为 jsonb，结构即 docs/04 generate-memory-card 的输出
--     （title/description/memory_type/suggested_scene/question/node_type/
--      confidence/safety_note）。游戏读取的是从中物化出来的 nodes 行。
-- ----------------------------------------------------------------------------
create table if not exists public.memories (
  id uuid primary key default gen_random_uuid(),
  family_id text not null references public.families(id) on delete cascade,
  user_id text,
  input_type text not null default 'photo'
    check (input_type in ('photo', 'room_photo', 'text', 'postcard', 'bottle_answer')),
  raw_text text,
  image_url text,
  status text not null default 'uploaded'
    check (status in ('uploaded', 'ai_processing', 'ai_done', 'ai_failed', 'published')),
  ai_card jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists memories_set_updated_at on public.memories;
create trigger memories_set_updated_at
  before update on public.memories
  for each row execute function extensions.moddatetime(updated_at);

-- ----------------------------------------------------------------------------
-- nodes：地图上的可点击节点（AI 输出的物化结果）。
--   * AI 只给 scene_id / node_type；slot_id 由 SlotManager 分配（AI 不输出坐标）。
--   * memory_link 连线节点：连接两条记忆，端点 A = memory_id，端点 B =
--     linked_memory_id，relation_type/question 来自 cross-memory-link 接口。
-- ----------------------------------------------------------------------------
create table if not exists public.nodes (
  id uuid primary key default gen_random_uuid(),
  family_id text not null references public.families(id) on delete cascade,
  memory_id uuid references public.memories(id) on delete cascade,
  scene_id text not null
    check (scene_id in ('garden', 'fishpond', 'farm', 'room', 'old_street', 'travel_area')),
  node_type text not null
    check (node_type in ('memory_flower', 'bottle', 'photo_board', 'room_object', 'postcard', 'memory_link')),
  asset_key text,
  slot_id text,
  state text not null default 'new'
    check (state in ('new', 'read', 'answered', 'grown')),
  clickable boolean not null default true,
  -- memory_link 专用（其它 node_type 留空）：
  linked_memory_id uuid references public.memories(id) on delete cascade,
  relation_type text
    check (relation_type is null or relation_type in ('same_place', 'same_people', 'same_theme', 'same_era')),
  question text,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- bottles：漂流瓶问题。
--   * target_member_id 可空：空 = 漂流（放进场景等人捡）；非空 = 定向投递
--     到指定家人的花园。
--   * created_by_ai 同时表达“AI 生成”与“家人提问”两种来源。
-- ----------------------------------------------------------------------------
create table if not exists public.bottles (
  id uuid primary key default gen_random_uuid(),
  family_id text not null references public.families(id) on delete cascade,
  scene_id text not null default 'fishpond'
    check (scene_id in ('garden', 'fishpond', 'farm', 'room', 'old_street', 'travel_area')),
  question text not null,
  created_by text,
  created_by_ai boolean not null default false,
  target_member_id text,            -- null = 漂流；非 null = 定向给某家人
  target_memory_type text,          -- shared_memory / childhood / travel ... （自由取值）
  status text not null default 'floating'
    check (status in ('floating', 'opened', 'answered', 'archived')),
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- answers：对漂流瓶或记忆卡片的回答。
--   * 跨成员互动计数的事实来源：当 memory_id 非空、user_id != 该 memory 上传者，
--     即为一次跨成员回答（去重后驱动 families.cross_member_interaction_count）。
-- ----------------------------------------------------------------------------
create table if not exists public.answers (
  id uuid primary key default gen_random_uuid(),
  family_id text not null references public.families(id) on delete cascade,
  bottle_id uuid references public.bottles(id) on delete set null,
  memory_id uuid references public.memories(id) on delete set null,
  user_id text,
  answer_text text not null,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- rooms：个人记忆空间（AI 房间识别的结果）。
-- ----------------------------------------------------------------------------
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  family_id text not null references public.families(id) on delete cascade,
  user_id text,
  room_name text,
  room_type text
    check (room_type is null or room_type in ('bedroom', 'study', 'living_room', 'kitchen_corner', 'unknown')),
  style text
    check (style is null or style in ('warm_cozy', 'simple', 'nostalgic', 'bright', 'quiet')),
  background_asset text,
  source_memory_id uuid references public.memories(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- room_objects：房间内的物件（由 RoomLayoutManager 摆放）。
--   * family_id 为冗余列：统一 RLS 策略 + 简化按家庭查询（room_id 已能定位房间）。
--   * slot_id 由游戏系统分配，AI 只给 object_type / zone。
-- ----------------------------------------------------------------------------
create table if not exists public.room_objects (
  id uuid primary key default gen_random_uuid(),
  family_id text not null references public.families(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  object_type text not null,
  asset_key text,
  slot_id text,
  zone text,
  clickable boolean not null default true,
  collision boolean not null default false,
  source_memory_id uuid references public.memories(id) on delete set null,
  created_at timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 索引（按 family_id / 外键 / 常用过滤维度）。
-- ----------------------------------------------------------------------------
create index if not exists idx_memories_family on public.memories(family_id);
create index if not exists idx_memories_status on public.memories(status);
create index if not exists idx_nodes_family on public.nodes(family_id);
create index if not exists idx_nodes_scene on public.nodes(scene_id);
create index if not exists idx_nodes_memory on public.nodes(memory_id);
create index if not exists idx_bottles_family on public.bottles(family_id);
create index if not exists idx_bottles_target on public.bottles(target_member_id);
create index if not exists idx_answers_family on public.answers(family_id);
create index if not exists idx_answers_memory on public.answers(memory_id);
create index if not exists idx_answers_bottle on public.answers(bottle_id);
create index if not exists idx_rooms_family on public.rooms(family_id);
create index if not exists idx_rooms_user on public.rooms(user_id);
create index if not exists idx_room_objects_room on public.room_objects(room_id);
create index if not exists idx_room_objects_family on public.room_objects(family_id);

-- ----------------------------------------------------------------------------
-- 行级安全（RLS）。沿用既有 MVP 模式：anon 角色按固定 family_id 隔离。
-- 注意：这是简单隔离、非强认证；正式对外前需收紧（见 README 已知问题 1）。
-- ----------------------------------------------------------------------------
alter table public.families enable row level security;
alter table public.memories enable row level security;
alter table public.nodes enable row level security;
alter table public.bottles enable row level security;
alter table public.answers enable row level security;
alter table public.rooms enable row level security;
alter table public.room_objects enable row level security;

-- families：仅允许读取/更新固定家庭那一行（计数器需要 update）。
drop policy if exists "fg_select_families" on public.families;
drop policy if exists "fg_update_families" on public.families;
create policy "fg_select_families" on public.families
  for select to anon using (id = 'Happy_birthday_David');
create policy "fg_update_families" on public.families
  for update to anon using (id = 'Happy_birthday_David') with check (id = 'Happy_birthday_David');

-- 其余表：统一 select/insert/update/delete 四策略，限定 family_id。
do $$
declare
  t text;
begin
  foreach t in array array['memories', 'nodes', 'bottles', 'answers', 'rooms', 'room_objects']
  loop
    execute format('drop policy if exists "fg_select_%1$s" on public.%1$s;', t);
    execute format('drop policy if exists "fg_insert_%1$s" on public.%1$s;', t);
    execute format('drop policy if exists "fg_update_%1$s" on public.%1$s;', t);
    execute format('drop policy if exists "fg_delete_%1$s" on public.%1$s;', t);

    execute format($f$create policy "fg_select_%1$s" on public.%1$s
      for select to anon using (family_id = 'Happy_birthday_David');$f$, t);
    execute format($f$create policy "fg_insert_%1$s" on public.%1$s
      for insert to anon with check (family_id = 'Happy_birthday_David');$f$, t);
    execute format($f$create policy "fg_update_%1$s" on public.%1$s
      for update to anon using (family_id = 'Happy_birthday_David') with check (family_id = 'Happy_birthday_David');$f$, t);
    execute format($f$create policy "fg_delete_%1$s" on public.%1$s
      for delete to anon using (family_id = 'Happy_birthday_David');$f$, t);
  end loop;
end$$;
