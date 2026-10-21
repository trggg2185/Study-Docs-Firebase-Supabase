-- ============================================================================
-- StudyDocs - Nâng cấp schema v2
-- Chạy trong Supabase SQL Editor:
-- https://supabase.com/dashboard/project/pfpivszvmsiwhgpaqywj/sql
--
-- Thay đổi:
--   1. documents: tags, location_name, latitude, longitude
--   2. profiles: interests, fcm_token
--   3. borrow_requests: yêu cầu mượn tài liệu
--
-- An toàn để chạy lại (if not exists). KHÔNG xoá dữ liệu hiện có.
-- ============================================================================

-- 1. Tag + vị trí vật lý của tài liệu
alter table public.documents
  add column if not exists tags text[] not null default '{}',
  add column if not exists location_name text,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

create index if not exists idx_documents_tags
  on public.documents using gin (tags);

-- 2. Hồ sơ người dùng: sở thích + FCM token
alter table public.profiles
  add column if not exists interests text[] not null default '{}',
  add column if not exists fcm_token text;

-- 3. Yêu cầu mượn tài liệu
create table if not exists public.borrow_requests (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  owner_id text not null,
  requester_id text not null,
  requester_email text not null,
  message text default '',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'returned')),
  created_at timestamptz default now(),
  responded_at timestamptz
);

create index if not exists idx_borrow_owner
  on public.borrow_requests (owner_id, status);
create index if not exists idx_borrow_requester
  on public.borrow_requests (requester_id, status);

-- Mỗi người chỉ có 1 yêu cầu đang chờ cho 1 tài liệu
create unique index if not exists uq_borrow_pending
  on public.borrow_requests (document_id, requester_id)
  where status = 'pending';

-- 4. Bật Supabase Realtime cho bảng yêu cầu mượn (cho thông báo trong app)
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'borrow_requests'
  ) then
    alter publication supabase_realtime add table public.borrow_requests;
  end if;
end $$;

-- Lưu ý: RLS hiện tại vẫn đang mở (using true) như bản schema cũ.
-- Trưởng làm bước Third-Party Auth + RLS thật trong docs/README mục 9.3.
