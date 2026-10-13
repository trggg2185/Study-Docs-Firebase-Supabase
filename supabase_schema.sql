-- ============================================================================
-- SUPABASE SCHEMA - STUDYDOCS (DATABASE & STORAGE)
-- Kiến trúc:
--   - Xác thực (Auth): Firebase Authentication (Email/Password, Google)
--   - Cơ sở dữ liệu (Database): Supabase PostgreSQL (profiles, documents, document_shares)
--   - Lưu trữ tệp tin (Storage): Supabase Storage (bucket 'study-docs')
--
-- Hướng dẫn: Copy toàn bộ nội dung file này, dán vào "SQL Editor" trên Supabase
-- Dashboard (https://supabase.com/dashboard/project/pfpivszvmsiwhgpaqywj/sql) và nhấn "Run".
-- ============================================================================

-- 1. BẢNG NGƯỜI DÙNG (profiles)
-- Lưu thông tin người dùng được định danh từ Firebase Auth (id = Firebase UID)
create table if not exists public.profiles (
  id text primary key,                 -- Firebase UID (chuỗi ký tự định danh)
  email text not null,                 -- Email tài khoản Firebase
  full_name text default '',           -- Tên hiển thị
  created_at timestamptz default now()
);

-- 2. BẢNG TÀI LIỆU (documents)
-- Lưu metadata của tài liệu học tập, liên kết đến file trong Supabase Storage
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,                                   -- Tiêu đề tài liệu
  description text default '',                           -- Mô tả nội dung
  type text not null default 'lecture',                  -- 'lecture' (bài giảng), 'exercise' (bài tập), 'reference' (tham khảo)
  subject text not null default '',                      -- Môn học (VD: Lập trình di động, Toán...)
  file_url text default '',                              -- URL công khai để tải/mở file từ Supabase Storage
  file_path text default '',                             -- Đường dẫn file trong bucket (VD: general/123_slide.pdf)
  file_name text default '',                             -- Tên file gốc (VD: de_cuong.pdf)
  file_size bigint default 0,                            -- Kích thước file (bytes)
  owner_id text not null,                                -- Firebase UID của người tạo
  owner_email text default '',                           -- Email người tạo
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. BẢNG QUYỀN CHIA SẺ (document_shares)
-- Lưu danh sách tài khoản được chia sẻ quyền truy cập tài liệu
create table if not exists public.document_shares (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.documents(id) on delete cascade,
  shared_with_email text not null,                       -- Email người được chia sẻ
  permission text not null default 'view',               -- 'view' (chỉ xem) hoặc 'edit' (được chỉnh sửa)
  created_at timestamptz default now(),
  constraint unique_document_share unique(document_id, shared_with_email)
);

-- Tạo chỉ mục (Index) để tối ưu truy vấn
create index if not exists idx_documents_owner on public.documents(owner_id);
create index if not exists idx_documents_updated on public.documents(updated_at desc);
create index if not exists idx_shares_doc on public.document_shares(document_id);
create index if not exists idx_shares_email on public.document_shares(shared_with_email);

-- ============================================================================
-- 4. BẢO MẬT DÒNG (ROW LEVEL SECURITY - RLS)
-- ============================================================================
-- Bật Row Level Security cho các bảng
alter table public.profiles enable row level security;
alter table public.documents enable row level security;
alter table public.document_shares enable row level security;

-- Do ứng dụng sử dụng Firebase Authentication làm Auth Provider độc lập,
-- các kết nối từ Flutter app tới Supabase sử dụng anon key.
-- Phân quyền và bảo mật tài liệu:
--  - Chỉ người tạo (owner_id = Firebase UID) hoặc người nhận (shared_with_email = Firebase Email)
--    mới truy cập được tài liệu qua bộ lọc logic tại App Data Layer (SupabaseService).
--  - Quyền sửa ('edit') và xóa (chỉ owner) được kiểm tra chặt chẽ trước khi gửi mutation.

-- RLS Policy cho documents
drop policy if exists "Allow access to documents for app clients" on public.documents;
create policy "Allow access to documents for app clients"
  on public.documents for all
  to anon, authenticated
  using (true)
  with check (true);

-- RLS Policy cho document_shares
drop policy if exists "Allow access to document_shares for app clients" on public.document_shares;
create policy "Allow access to document_shares for app clients"
  on public.document_shares for all
  to anon, authenticated
  using (true)
  with check (true);

-- RLS Policy cho profiles
drop policy if exists "Allow access to profiles for app clients" on public.profiles;
create policy "Allow access to profiles for app clients"
  on public.profiles for all
  to anon, authenticated
  using (true)
  with check (true);

-- ============================================================================
-- 5. CẤU HÌNH SUPABASE STORAGE CHO FILE TÀI LIỆU
-- ============================================================================
-- Tạo bucket 'study-docs' ở chế độ Public để xem/tải file
insert into storage.buckets (id, name, public)
values ('study-docs', 'study-docs', true)
on conflict (id) do update set public = true;

-- Cho phép upload file lên bucket 'study-docs'
drop policy if exists "Allow upload to study-docs bucket" on storage.objects;
create policy "Allow upload to study-docs bucket"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'study-docs');

-- Cho phép đọc / tải file công khai từ bucket 'study-docs'
drop policy if exists "Allow public read from study-docs bucket" on storage.objects;
create policy "Allow public read from study-docs bucket"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'study-docs');

-- Cho phép cập nhật file trong bucket 'study-docs'
drop policy if exists "Allow update on study-docs bucket" on storage.objects;
create policy "Allow update on study-docs bucket"
  on storage.objects for update
  to anon, authenticated
  using (bucket_id = 'study-docs');

-- Cho phép xóa file khỏi bucket 'study-docs'
drop policy if exists "Allow delete from study-docs bucket" on storage.objects;
create policy "Allow delete from study-docs bucket"
  on storage.objects for delete
  to anon, authenticated
  using (bucket_id = 'study-docs');
