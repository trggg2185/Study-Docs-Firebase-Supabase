# StudyDocs — Quản lý tài liệu học tập (Flutter + Firebase + Supabase)

> **Nhóm 6** · Cập nhật: 22/10/2026
> Trạng thái: **đã merge đủ 4 thành viên**; code đã có tag, vị trí/bản đồ, mượn tài liệu, gợi ý, realtime và responsive.
>
> **Quy tắc quan trọng:** mỗi thành viên làm trên **nhánh riêng**, mở Pull Request để Trưởng review và merge.
> **Tuyệt đối không push trực tiếp lên `main`.**
>
> **Việc còn lại trước khi demo:** chạy `docs/upgrade-v2.sql` trên Supabase → test 2 tài khoản →
> build APK/Web. RLS thật (Third-Party Auth) vẫn là hạn chế đã biết, xem mục 9.3.

---

## 0. TL;DR — đọc nhanh 1 phút

**Đã có:**
- Đăng nhập/đăng ký bằng Firebase Auth (Email/Password + Google), tạo profile Supabase, lấy FCM token.
- CRUD tài liệu, upload file lên Supabase Storage, tìm kiếm, lọc theo loại/tag, chia sẻ `view`/`edit`.
- **Tag** (tối đa 5), **vị trí + bản đồ OpenStreetMap**, **yêu cầu mượn → duyệt/từ chối → trả**.
- **Gợi ý tài liệu** theo tag/môn/loại; **realtime** cho yêu cầu mượn.
- Giao diện tiếng Việt, Material 3, sáng/tối; Home dạng grid trên Web, list trên mobile.
- 37 unit/widget test; build Web + APK release đã chạy được.

**Còn phải làm (chủ yếu ngoài code):**
1. Chạy `docs/upgrade-v2.sql` trên Supabase (bắt buộc, nếu chưa chạy thì thêm/sửa tài liệu sẽ lỗi).
2. Test thủ công 2 tài khoản: share, mượn, duyệt, trả, realtime, tag, bản đồ.
3. RLS thật + Third-Party Auth (timebox) hoặc ghi rõ hạn chế trong báo cáo.
4. Build/kiểm tra bản release cuối và chuẩn bị demo.

**Không làm (để tránh phình to):** chat, versioning file, offline sync/Drift, phân quyền admin, thanh toán, server gửi push tự động, Google Maps/geocoding, reset mật khẩu, xác thực email.

---

## 1. Thông tin dự án & tài khoản cloud

| Mục | Giá trị |
|---|---|
| Tên app | **StudyDocs** |
| Package Flutter | `test_flutter` (giữ nguyên, không đổi) |
| Nền tảng đích | Android, iOS, Web (mobile + web) |
| Flutter | 3.47.2 stable · Dart 3.13.2 |
| Firebase project | **Study-Docs-Group6** (`study-docs-group6`) |
| Supabase project | **trggg2185's Project** |
| Supabase URL | `https://pfpivszvmsiwhgpaqywj.supabase.co` |
| Supabase Storage bucket | `study-docs` (public) |
| Cấu hình Firebase | `lib/firebase_options.dart`, `android/app/google-services.json`, `firebase.json` |
| Cấu hình Supabase | `lib/services/supabase/supabase_config.dart` |

- Tất cả thành viên **đã được mời** vào Firebase và Supabase. **Không tạo project mới.**
- `anon key` của Supabase là khoá công khai, được phép nằm trong client. **Không bao giờ commit `service_role key`.**
- Nếu Google Sign-In lỗi trên máy mới: cần thêm SHA-1 (Android) hoặc domain vào Authorized domains (Web) — báo Trưởng.

---

## 2. Chạy dự án

```powershell
flutter pub get
flutter run -d chrome          # Web
flutter run -d <device_id>     # Android/iOS
flutter devices                # xem danh sách thiết bị
```

Kiểm tra chất lượng trước khi push:

```powershell
flutter analyze
flutter test
```

- Database hiện tại được tạo bằng `supabase_schema.sql`, sau đó chạy thêm `docs/upgrade-v2.sql` (bắt buộc cho tag/vị trí/mượn).
- Nếu database đã có từ trước, **chỉ cần chạy `docs/upgrade-v2.sql`**; file này an toàn để chạy lại.
- `android/app/google-services.json` đã có. iOS cần chạy trên macOS mới build được.
- File `web/sqlite3.wasm` và `web/drift_worker.js` phục vụ Drift (legacy, không dùng trong luồng chính).
- Build release: `flutter build apk --release` và `flutter build web --release`.

---

## 3. Công nghệ hiện có

| Thành phần | Công nghệ | Ghi chú |
|---|---|---|
| UI | Flutter, Material 3, Provider | `provider: ^6.1.4` |
| Auth | Firebase Auth | Email/Password + Google |
| Database | Supabase PostgreSQL | `documents`, `document_shares`, `profiles` |
| Storage | Supabase Storage | bucket `study-docs`, public URL |
| Realtime | Supabase Realtime | `borrow_requests`: subscribe trong `BorrowRequestsPage` và `BorrowRequestButton` |
| Local DB (legacy) | Drift + SQLite | Có code nhưng **không nối vào app** |
| Firebase Firestore/Storage (legacy) | `cloud_firestore`, `firebase_storage` | Có service nhưng **không nối vào app** |
| Chọn file | `file_picker` | Web dùng bytes, mobile dùng `File` |
| Mở file | `url_launcher` | Mở URL public trên trình duyệt |
| ID | `uuid` | Dùng cho Drift category (legacy) |

**Đã thêm:** `flutter_map`, `latlong2`, `firebase_messaging`.
Không tự thêm package khác khi chưa trao đổi với Trưởng.

---

## 4. Chức năng hiện có

| # | Chức năng | Trạng thái | Ghi chú |
|---|---|---|---|
| 1 | Đăng ký / đăng nhập email | ✅ | Firebase Auth |
| 2 | Đăng nhập Google | ✅ | Web popup, mobile `google_sign_in` |
| 3 | Đăng xuất | ✅ | Menu tài khoản ở Home |
| 4 | Xem danh sách tài liệu | ✅ | Supabase, pull-to-refresh, grid trên Web |
| 5 | Thêm tài liệu + upload file | ✅ | File lưu Supabase Storage |
| 6 | Sửa tài liệu + thay file | ✅ | Upload file mới nếu chọn |
| 7 | Xoá tài liệu + file | ✅ | Xoá Storage trước, sau đó xoá row |
| 8 | Tìm kiếm | ✅ | Theo `title` (`ilike`) |
| 9 | Lọc theo loại | ✅ | `lecture`, `exercise`, `reference` |
| 10 | Lọc "được chia sẻ với tôi" | ✅ | Lọc phía client |
| 11 | Chia sẻ trực tiếp theo email | ✅ | Quyền `view` / `edit` |
| 12 | Xem/thu hồi người được chia sẻ | ✅ | Chỉ chủ sở hữu |
| 13 | Xem chi tiết + mở file | ✅ | Mở URL public bằng trình duyệt |
| 14 | Theme sáng/tối | ✅ | Theo hệ thống |
| 15 | Responsive Web | ✅ | Grid ≥ 900px; form/detail giới hạn 800px |
| 16 | Tag | ✅ | Nhập/sửa, chip, lọc theo tag |
| 17 | Vị trí/bản đồ | ✅ | Chọn trên OSM, lưu toạ độ, mở bản đồ |
| 18 | Yêu cầu mượn / duyệt / trả | ✅ | 2 tab, realtime, tạo/thu hồi share khi duyệt/trả |
| 19 | Gợi ý tài liệu | ✅ | Theo tag/môn/loại; fallback tài liệu mới nhất |
| 20 | Thông báo / Firebase Messaging | ✅ | Lấy FCM token sau đăng nhập; realtime trong app |
| 21 | Realtime | ✅ | `borrow_requests` (cần chạy SQL) |
| 22 | Test | ✅ | 37 test: model, tag, location, borrow, recommendation, widget |
| 23 | Đóng gói APK/Web | ✅ | Đã build; build lại trước khi nộp |

---

## 5. Kiến trúc hiện tại

```
┌──────────────────── Flutter (Android / iOS / Web) ────────────────────┐
│ lib/main.dart                                                         │
│   ├─ Firebase.initializeApp()          → Firebase Auth                │
│   ├─ Supabase.initialize()             → Postgres + Storage           │
│   └─ MultiProvider                                                    │
│       ├─ AuthService        (services/firebase/auth_service.dart)     │
│       ├─ SupabaseService    (services/supabase/supabase_service.dart) │
│       ├─ DocumentStruct     (struct/document_struct.dart)             │
│       └─ SearchStruct       (struct/search_struct.dart, ít dùng)      │
│                                                                       │
│ AuthGate ──> LoginPage  |  HomePage                                   │
│ HomePage ──> DocumentFormPage (thêm/sửa)                              │
│          └─> DocumentDetailPage (chi tiết, chia sẻ, mở file)          │
└───────────────────────────────────────────────────────────────────────┘
          │ Firebase Auth                        │ Supabase
          ▼                                      ▼
   Email/Password, Google              PostgreSQL: profiles, documents,
                                       document_shares
                                       Storage: bucket study-docs (public)
```

**Luồng dữ liệu chính:** `UI → DocumentStruct → SupabaseService → Supabase`.
`SupabaseService` lấy `uid`/`email` từ Firebase Auth, không có bảng user riêng đang hoạt động.

### 5.1. Code đang hoạt động

| File | Vai trò |
|---|---|
| `lib/main.dart` | Khởi tạo Firebase/Supabase, Provider, `AuthGate` |
| `lib/firebase_options.dart` | Cấu hình Firebase (generated) |
| `lib/pages/login_page.dart` | Đăng nhập/đăng ký/Google |
| `lib/pages/home_page.dart` | Danh sách, tìm kiếm, lọc, chia sẻ, xoá, đăng xuất |
| `lib/pages/document_form_page.dart` | Form thêm/sửa + chọn file |
| `lib/pages/document_detail_page.dart` | Chi tiết, chia sẻ, thu hồi, mở file, xoá |
| `lib/services/firebase/auth_service.dart` | Bọc Firebase Auth |
| `lib/services/supabase/supabase_config.dart` | URL, anon key, bucket |
| `lib/services/supabase/supabase_service.dart` | Toàn bộ query Supabase + Storage + share |
| `lib/struct/document_struct.dart` | Nghiệp vụ tài liệu, validate, stream nội bộ |
| `lib/struct/search_struct.dart` | Tìm kiếm (hiện Home không dùng) |
| `lib/modified/models/document_model.dart` | Model tài liệu + enum `DocumentType` |
| `lib/modified/models/document_share_model.dart` | Model chia sẻ |
| `lib/widgets/framework/app_scaffold.dart` | Scaffold dùng chung |
| `lib/widgets/framework/document_tile.dart` | Card tài liệu |
| `lib/widgets/framework/search_field.dart` | Ô tìm kiếm |
| `lib/widgets/util/empty_state.dart` | Trạng thái rỗng |
| `lib/widgets/util/loading_indicator.dart` | Trạng thái loading |

### 5.2. Code legacy / chưa nối vào app (KHÔNG xoá, KHÔNG mở rộng)

| File | Tình trạng |
|---|---|
| `lib/database/app_database.dart` + `lib/database/tables/*` | Drift SQLite, có seed category, không dùng |
| `lib/database/app_database.g.dart` | Generated cho Drift |
| `lib/struct/category_struct.dart` | Nghiệp vụ category, không dùng |
| `lib/struct/cloud_document_struct.dart` | Luồng Firebase Firestore + Storage, không dùng |
| `lib/services/firebase/firestore_service.dart` | Firestore, không dùng |
| `lib/services/firebase/storage_service.dart` | Firebase Storage, không dùng |
| `lib/modified/models/category_model.dart` | Model category, không dùng |
| `lib/modified/converters/document_converter.dart` | Map Drift ↔ model, không dùng |

> Lý do giữ: đây là phần việc cũ của thành viên, có thể dùng cho báo cáo so sánh.
> Luồng chính **chỉ dùng Supabase** cho database/storage.

---

## 6. Mô hình dữ liệu hiện tại (Supabase)

### 6.1. Bảng `profiles` — đã dùng

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | `text` PK | Firebase UID |
| `email` | `text` | |
| `full_name` | `text` | |
| `interests` | `text[]` | dự phòng cho gợi ý |
| `fcm_token` | `text` | token Firebase Messaging |
| `created_at` | `timestamptz` | |

`ensureProfile` tạo/cập nhật row sau đăng nhập; `setupFcmToken` lưu token.

### 6.2. Bảng `documents`

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `title` | `text` | bắt buộc, ≤ 200 ký tự (validate client) |
| `description` | `text` | |
| `type` | `text` | `lecture` / `exercise` / `reference` |
| `subject` | `text` | tên môn, text tự do |
| `file_url` | `text` | public URL |
| `file_path` | `text` | đường dẫn trong bucket |
| `file_name` | `text` | tên file gốc |
| `file_size` | `bigint` | bytes |
| `owner_id` | `text` | Firebase UID |
| `owner_email` | `text` | |
| `tags` | `text[]` | tối đa 5 tag chữ thường |
| `location_name` | `text` | tên vị trí, có thể null |
| `latitude` | `double precision` | nullable |
| `longitude` | `double precision` | nullable |
| `created_at` | `timestamptz` | |
| `updated_at` | `timestamptz` | |

**Đã có:** `tags`, `location_name`, `latitude`, `longitude` (sau khi chạy `docs/upgrade-v2.sql`).
**Không có** cột `category_id` dù model/Drift/Firestore có nhắc tới → không dùng `categoryId` cho Supabase.

### 6.3. Bảng `document_shares`

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | `uuid` PK | |
| `document_id` | `uuid` FK → `documents.id` | cascade delete |
| `shared_with_email` | `text` | email người nhận |
| `permission` | `text` | `view` / `edit` |
| `created_at` | `timestamptz` | |

Ràng buộc unique `(document_id, shared_with_email)`.

### 6.4. Bảng `borrow_requests`

| Cột | Kiểu | Ghi chú |
|---|---|---|
| `id` | `uuid` PK | |
| `document_id` | `uuid` FK → `documents.id` | cascade delete |
| `owner_id` | `text` | Firebase UID chủ tài liệu |
| `requester_id` | `text` | Firebase UID người mượn |
| `requester_email` | `text` | dùng để tạo share khi duyệt |
| `message` | `text` | lời nhắn |
| `status` | `text` | `pending` / `approved` / `rejected` / `returned` |
| `created_at`, `responded_at` | `timestamptz` | |

Unique index chỉ chặn 2 yêu cầu `pending` cùng lúc cho một tài liệu/người.

### 6.5. Storage

- Bucket `study-docs`, **public**.
- Đường dẫn: `<uid>/<timestamp>_<tên_file>`.
- Policy storage hiện cho phép anon upload/read/update/delete.

### 6.6. Bảo mật hiện tại (quan trọng)

`supabase_schema.sql` đang bật RLS nhưng policy là `using (true)` / `with check (true)` cho `anon`:

```sql
create policy "Allow access to documents for app clients"
  on public.documents for all to anon, authenticated
  using (true) with check (true);
```

Hệ quả: **bất kỳ ai có anon key đều đọc/ghi/xoá được toàn bộ dữ liệu**, app chỉ lọc ở client.
Đây là lỗ hổng cần xử lý (xem việc của Trưởng) hoặc phải ghi rõ là hạn chế trong báo cáo.
Không đưa tài liệu nhạy cảm lên hệ thống này.

---

## 7. Cấu trúc thư mục

```
test_flutter/
├── lib/
│   ├── main.dart                      # entry point, Provider, AuthGate
│   ├── firebase_options.dart          # generated
│   ├── database/                      # LEGACY Drift
│   │   ├── app_database.dart
│   │   ├── app_database.g.dart        # generated
│   │   └── tables/
│   │       ├── categories_table.dart
│   │       └── documents_table.dart
│   ├── modified/
│   │   ├── converters/
│   │   │   └── document_converter.dart
│   │   └── models/
│   │       ├── borrow_request_model.dart
│   │       ├── category_model.dart
│   │       ├── document_model.dart
│   │       └── document_share_model.dart
│   ├── pages/
│   │   ├── login_page.dart
│   │   ├── home_page.dart
│   │   ├── borrow_requests_page.dart
│   │   ├── document_form_page.dart
│   │   ├── document_detail_page.dart
│   │   └── location_picker_page.dart
│   ├── services/
│   │   ├── firebase/
│   │   │   ├── auth_service.dart
│   │   │   ├── firestore_service.dart # LEGACY
│   │   │   └── storage_service.dart   # LEGACY
│   │   └── supabase/
│   │       ├── borrow_service.dart
│   │       ├── supabase_config.dart
│   │       └── supabase_service.dart
│   ├── struct/
│   │   ├── document_struct.dart
│   │   ├── location_data.dart
│   │   ├── recommendation_struct.dart
│   │   ├── search_struct.dart
│   │   ├── category_struct.dart       # LEGACY
│   │   └── cloud_document_struct.dart # LEGACY
│   ├── utils/
│   │   └── tag_utils.dart
│   └── widgets/
│       ├── framework/
│       │   ├── app_scaffold.dart
│       │   ├── borrow_request_button.dart
│       │   ├── document_location_card.dart
│       │   ├── document_tile.dart
│       │   ├── location_field.dart
│       │   ├── recommendation_section.dart
│       │   └── search_field.dart
│       └── util/
│           ├── empty_state.dart
│           └── loading_indicator.dart
├── test/
│   ├── borrow_test.dart
│   ├── cloud_document_test.dart
│   ├── document_struct_test.dart
│   ├── document_tile_test.dart
│   ├── location_data_test.dart
│   ├── recommendation_struct_test.dart
│   ├── tag_utils_test.dart
│   └── widget_test.dart
├── docs/
│   ├── about-firebase.md
│   ├── firebase-setup.md
│   ├── security-rules.md
│   ├── comparison.md
│   ├── evaluation.md
│   └── upgrade-v2.sql
├── web/
│   ├── index.html
│   ├── manifest.json
│   ├── drift_worker.js                # LEGACY Drift web
│   └── sqlite3.wasm                   # LEGACY Drift web
├── android/                           # Android config + google-services.json
├── ios/                               # iOS config
├── android_profile_app/               # project Kotlin minh hoạ, KHÔNG liên quan app Flutter
├── supabase_schema.sql                # schema hiện tại + RLS + storage
├── firebase.json                      # FlutterFire metadata
├── pubspec.yaml
├── analysis_options.yaml
└── README.md                          # file này
```

**Kích thước code chính:** ~6.500 dòng Dart, trong đó ~1.400 dòng generated Drift.
**File lớn nhất:** `document_detail_page.dart` (724 dòng), `borrow_requests_page.dart` (747), `home_page.dart` (579).

---

## 8. Đối chiếu đề bài với hiện trạng

| Yêu cầu đề bài | Hiện trạng | Đánh giá |
|---|---|---|
| Kiến trúc Firebase (Auth/Messaging) + Supabase (DB/Storage) | Firebase Auth + FCM token + Supabase DB/Storage/Realtime | ✅ |
| UI đa nền tảng, responsive Mobile + Web | Grid ≥900px, list mobile; form/detail giới hạn 800px | ✅ |
| Phân loại bằng Tag | `tags text[]`, nhập/sửa, hiển thị, lọc | ✅ |
| Bản đồ/vị trí tài liệu | `location_name`, `latitude`, `longitude`; chọn OSM; mở bản đồ | ✅ |
| Chia sẻ/mượn tài liệu | Share trực tiếp + `borrow_requests` + duyệt/từ chối/trả | ✅ |
| Recommendation | Chấm điểm tag/môn/loại, fallback tài liệu mới | ✅ |
| Dữ liệu thời gian thực | Supabase Realtime cho `borrow_requests` | ✅ |
| Kiểm thử | 37 test; cần test tay 2 tài khoản | ✅/⚠️ |
| Đóng gói sản phẩm | APK + Web build được; build lại trước khi nộp | ✅ |
| Bảo mật | RLS đang mở, lọc client; Third-Party Auth chưa làm | ❌ (hạn chế đã biết) |

**Kết luận:** đã đủ các chức năng chính của đề bài. Việc còn lại là **chạy SQL**, test thật 2 tài khoản, build bản cuối và xử lý/ghi rõ hạn chế RLS.

---

## 9. Kiến trúc và dữ liệu đích

### 9.1. Kiến trúc sau nâng cấp

```
┌──────────────────── Flutter responsive (Mobile + Web) ────────────────────┐
│ AuthGate → LoginPage | HomePage (grid/list, tag filter, gợi ý)            │
│   ├─ DocumentFormPage   (tag + chọn vị trí trên bản đồ)                    │
│   ├─ DocumentDetailPage (tag, bản đồ, share, yêu cầu mượn)                 │
│   └─ BorrowRequestsPage (yêu cầu đến / yêu cầu đã gửi, realtime)          │
│                                                                           │
│ Services/Structs:                                                         │
│  Firebase Auth ──┐                                                        │
│  Firebase Messaging (token) ──> profiles.fcm_token                        │
│  SupabaseService ─> documents / document_shares / profiles                │
│  BorrowService   ─> borrow_requests + Realtime + share khi duyệt          │
│  RecommendationStruct ─> chấm điểm client-side trên tài liệu được phép xem│
└───────────────────────────────────────────────────────────────────────────┘
            │ Firebase Auth / FCM              │ Supabase
            ▼                                 ▼
     Email/Google, token              PostgreSQL + Storage + Realtime
```

**Quyết định kiến trúc:**
- Database/storage vẫn là **Supabase** (không chuyển sang Firestore).
- Firebase giữ **Auth**; thêm **Messaging** ở mức token + nhận test message.
- **Không** làm server gửi push tự động (cần service account/Edge Function) — nằm ngoài phạm vi bài nhỏ.
- Thông báo trong app dùng **Supabase Realtime** trên `borrow_requests`.
- Bản đồ dùng **tile OpenStreetMap trực tiếp** trong `location_picker_page.dart` — không cần API key.
- Recommendation chạy **client-side** trên danh sách tài liệu người dùng được xem — đủ cho bài tập, không cần ML.

### 9.2. Schema bổ sung (đã có trong `docs/upgrade-v2.sql`, cần chạy trên Supabase)

```sql
-- 1. Tag + vị trí cho tài liệu
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
  owner_id text not null,              -- Firebase UID chủ tài liệu
  requester_id text not null,          -- Firebase UID người mượn
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
```

**Quy ước dữ liệu:**
- `tags`: chữ thường, trim, bỏ trùng, tối đa **5 tag**, mỗi tag ≤ **30 ký tự**.
- `location_name`: ví dụ `"Kệ A3 - Phòng 201"`; có thể null.
- `latitude`/`longitude`: nullable, cả hai cùng có hoặc cùng null.
- `status`: `pending → approved | rejected`; `approved → returned`; không quay lại `pending`.
- Khi **duyệt**: thêm row `document_shares` với `permission = 'view'` để người mượn đọc được.
- Khi **trả**: xoá row share tương ứng (nếu có) và set `status = 'returned'`.

### 9.3. RLS thật (khuyến nghị, timebox 60–90 phút)

Hiện tại Supabase không biết Firebase user. Cách đúng:
1. Supabase Dashboard → **Authentication → Third-Party Auth → Firebase** → thêm project `study-docs-group6`.
2. Trong `main.dart`, truyền Firebase ID token cho Supabase:
   ```dart
   Supabase.initialize(
     url: SupabaseConfig.url,
     anonKey: SupabaseConfig.anonKey,
     accessToken: () async =>
         await FirebaseAuth.instance.currentUser?.getIdToken() ?? '',
   );
   ```
   (Kiểm tra API của `supabase_flutter` đang dùng; nếu chưa hỗ trợ thì dừng, ghi chú.)
3. Policy dùng `auth.jwt()->>'sub'` (Firebase UID) và `auth.jwt()->>'email'`.

Mẫu policy (Trưởng điều chỉnh theo docs và test thật):

```sql
-- documents: chủ sở hữu hoặc được share
drop policy if exists "Allow access to documents for app clients" on public.documents;
create policy documents_read on public.documents for select to authenticated
using (
  owner_id = auth.jwt()->>'sub'
  or exists (
    select 1 from public.document_shares s
    where s.document_id = documents.id
      and lower(s.shared_with_email) = lower(auth.jwt()->>'email')
  )
);

create policy documents_insert on public.documents for insert to authenticated
with check (owner_id = auth.jwt()->>'sub');

-- Giữ quyền 'edit' hiện có: thêm OR exists(... permission = 'edit') vào USING/WITH CHECK.
-- App không cho đổi owner_id; nếu cần chặt hơn, chặn bằng trigger.
create policy documents_update on public.documents for update to authenticated
using (owner_id = auth.jwt()->>'sub')
with check (owner_id = auth.jwt()->>'sub');

create policy documents_delete on public.documents for delete to authenticated
using (owner_id = auth.jwt()->>'sub');
```

- `document_shares`: chủ tài liệu được CRUD; người nhận chỉ select row của mình.
- `profiles`: mỗi người select/update row `id = auth.jwt()->>'sub'`.
- `borrow_requests`: owner/requester được select; requester insert; owner update trạng thái.
- **Bắt buộc test** bằng 2 tài khoản: B không đọc được tài liệu chưa share của A.
- **Nếu không kịp** (third-party auth lỗi/cấu hình chặn): giữ policy hiện tại, **ghi rõ hạn chế trong báo cáo**, không dùng dữ liệu thật. Không được âm thầm bỏ qua.

---

## 10. Hợp đồng tích hợp (để 4 người làm song song không conflict)

> Các field/method/stub dưới đây đã được tạo ở **Sprint 0** và merge vào `main`.
> Giữ đúng tên/signature khi sửa để không phá các màn hình khác.

### 10.1. Field model

`DocumentModel` thêm:

```dart
final List<String> tags;          // mặc định const []
final String? locationName;
final double? latitude;
final double? longitude;

bool get hasLocation => latitude != null && longitude != null;
```

Cập nhật `fromMap`, `toMap`, `copyWith` tương ứng:
- `tags` ↔ `tags` (Postgres `text[]`).
- `locationName` ↔ `location_name`, `latitude` ↔ `latitude`, `longitude` ↔ `longitude`.

`DocumentStruct.create/update` nhận thêm `tags`, `locationName`, `latitude`, `longitude`.

### 10.2. `SupabaseService`

```dart
Future<List<DocumentModel>> getDocuments({
  String? query,
  DocumentType? type,
  String? subject,
  List<String>? tags,        // lọc AND: tài liệu chứa tất cả tag
  bool onlyShared = false,
});

Future<String> createDocument({
  required String title,
  String description = '',
  required DocumentType type,
  required String subject,
  String fileUrl = '',
  String filePath = '',
  String fileName = '',
  int fileSize = 0,
  List<String> tags = const [],
  String? locationName,
  double? latitude,
  double? longitude,
});

Future<void> updateDocument({
  required String id,
  required String title,
  String description = '',
  required DocumentType type,
  required String subject,
  String? fileUrl,
  String? filePath,
  String? fileName,
  int? fileSize,
  List<String> tags = const [],   // form luôn gửi danh sách đầy đủ
  String? locationName,
  double? latitude,
  double? longitude,
});

Future<void> ensureProfile({
  required String uid,
  required String email,
  String fullName = '',
});

Future<Map<String, dynamic>?> getProfile(String uid);
Future<void> updateInterests(String uid, List<String> interests);
Future<void> updateFcmToken(String uid, String? token);
```

### 10.3. Yêu cầu mượn

File mới:
- `lib/modified/models/borrow_request_model.dart`
- `lib/services/supabase/borrow_service.dart`

```dart
class BorrowRequestModel {
  final String id;
  final String documentId;
  final String documentTitle;   // join để hiển thị
  final String ownerId;
  final String requesterId;
  final String requesterEmail;
  final String message;
  final String status;          // pending | approved | rejected | returned
  final DateTime createdAt;
  final DateTime? respondedAt;
}

class BorrowService {
  BorrowService(SupabaseService service);

  Future<String> request({
    required DocumentModel document,
    String message = '',
  });

  Stream<List<BorrowRequestModel>> watchIncoming();  // owner_id = tôi
  Stream<List<BorrowRequestModel>> watchOutgoing();  // requester_id = tôi
  /// true nếu đã có yêu cầu pending hoặc approved (chưa trả)
  Future<bool> hasOpenRequest(String documentId);

  Future<void> approve(BorrowRequestModel request);  // + tạo share view
  Future<void> reject(BorrowRequestModel request);
  Future<void> markReturned(BorrowRequestModel request); // + xoá share
}
```

### 10.4. Gợi ý

File mới: `lib/struct/recommendation_struct.dart`

```dart
class RecommendationStruct {
  RecommendationStruct(SupabaseService service);

  Future<List<DocumentModel>> suggest({int limit = 6});

  static double score(
    DocumentModel candidate, {
    required Map<String, int> tagWeights, // tag -> số lần xuất hiện trong tài liệu của tôi
    required Set<String> subjects,        // các môn tôi có
    required Set<DocumentType> types,     // các loại tôi có
  });
}
```

Công thức chấm điểm (đơn giản, dễ test):
- Mỗi tag trùng: `+3 × weight` (weight = số tài liệu của tôi có tag đó, tối đa 3).
- Cùng `subject`: `+2`.
- Cùng `type`: `+1`.
- Không gợi ý tài liệu của chính mình; tài liệu đã share vẫn có thể được gợi ý.
- Nếu không có tài liệu nào đạt điểm > 0 (người dùng mới), fallback về các tài liệu mới nhất của người khác.

### 10.5. Widget stub do Trưởng chèn sẵn

| File stub | Được chèn ở | Người hoàn thiện |
|---|---|---|
| `lib/widgets/framework/recommendation_section.dart` | `home_page.dart` (dưới filter) | Đức |
| `lib/widgets/framework/document_location_card.dart` | `document_detail_page.dart` | Đức |
| `lib/widgets/framework/location_field.dart` | `document_form_page.dart` | Đức |
| `lib/widgets/framework/borrow_request_button.dart` | `document_detail_page.dart` | Đại |

Stub ban đầu chỉ là `const SizedBox.shrink()` (hoặc widget rỗng) để app vẫn compile.
**Không sửa trực tiếp `home_page.dart` / `document_form_page.dart` / `document_detail_page.dart`** nếu không phải người sở hữu — hãy sửa widget stub của mình.

### 10.6. Phân quyền file (tránh conflict)

| Vùng | Người sở hữu | Người khác |
|---|---|---|
| `supabase_schema.sql`, `docs/upgrade-v2.sql`, `lib/main.dart`, `lib/services/supabase/*`, `lib/modified/models/document_model.dart`, `pubspec.yaml` | Trưởng | Chỉ đọc |
| `lib/pages/home_page.dart`, `document_form_page.dart`, `document_detail_page.dart`, `lib/widgets/framework/document_tile.dart` | Hà | Không sửa |
| File mới của borrow + `borrow_request_button.dart` | Đại | Không sửa |
| File mới location/recommendation + 3 stub còn lại | Đức | Không sửa |
| `README.md`, `docs/*` | Trưởng | Không sửa (báo Trưởng cập nhật) |
| Code legacy | Không ai | Không xoá, không sửa |

> Nếu buộc phải sửa file ngoài vùng của mình: báo Trưởng trước, giữ thay đổi nhỏ nhất.

---

## 11. Phân công 4 thành viên

### Nguyên tắc chung

- Mỗi người **1 nhánh riêng**, tạo từ `main` (Sprint 0 đã merge).
- Không push `main`. Không merge PR của người khác.
- Mỗi PR: mô tả ngắn, ảnh chụp màn hình (nếu có UI), đã chạy `flutter analyze` + `flutter test`.
- Commit nhỏ, message tiếng Việt hoặc tiếng Anh đều được, ví dụ: `feat: them tag cho tai lieu`.
- Task ước lượng 4–8 giờ/người, đủ cho bài tập nhỏ. Không làm thêm ngoài scope.

### 11.1. Nguyễn Thế Trưởng — Leader / Nền tảng & tích hợp

**Nhánh:** `feature/truong-foundation` (đã merge)
**Trạng thái:** hoàn thành phần nền tảng và tích hợp cuối.

**Đã làm:**
1. Tạo `docs/upgrade-v2.sql` (tag, vị trí, profile, `borrow_requests`, Realtime publication); **chưa chạy trên project Supabase thật**.
2. Thêm `flutter_map`, `latlong2`, `firebase_messaging`.
3. Mở rộng model/service/profile/FCM token.
4. Tạo widget stub và merge lần lượt 4 nhánh.
5. Sửa lỗi merge, nối `BorrowRequestsPage`, provider `BorrowService`, gợi ý, quyền xem tài liệu.
6. `flutter analyze` 0 issue; 37 test pass; build APK/Web.

**Còn lại (ngoài code):**
- Chạy SQL trên Supabase nếu chưa chạy.
- Test tay 2 tài khoản: share, mượn, duyệt, trả, realtime, bản đồ.
- Quyết định làm hoặc ghi rõ hạn chế RLS/Third-Party Auth.
- Build lại APK/Web trước khi nộp.

**Definition of Done hiện tại:**
- [x] Code merge, không còn lỗi biên dịch.
- [x] `flutter analyze` 0 issue, `flutter test` pass.
- [x] Có luồng tag, vị trí, mượn, gợi ý, responsive.
- [ ] SQL chạy trên project Supabase thật.
- [ ] Test tay 2 tài khoản trên bản release.
- [ ] RLS thật (hoặc ghi rõ hạn chế trong báo cáo).

---

### 11.2. Hàn Hoàng Hà — Tag + tìm kiếm/lọc + Responsive

**Nhánh:** `feature/ha-tags-responsive`
**Phụ thuộc:** Sprint 0 của Trưởng (field `tags` + `getDocuments(tags:)`).

**Việc cần làm:**
1. Tạo `lib/utils/tag_utils.dart`:
   - `normalizeTags(String input)`: tách theo dấu phẩy, trim, lowercase, bỏ rỗng, bỏ trùng, tối đa 5, mỗi tag ≤ 30 ký tự.
   - `formatTags(List<String>)` nếu cần.
2. `DocumentFormPage`: thêm ô nhập tag (gợi ý "cách nhau bằng dấu phẩy"), truyền `tags` vào `create/update`. Giữ nguyên `LocationField` stub của Đức.
3. `DocumentTile`: hiển thị tối đa 3 tag dạng chip nhỏ (ẩn nếu rỗng).
4. `DocumentDetailPage`: hiển thị đầy đủ tag; giữ nguyên `DocumentLocationCard` + `BorrowRequestButton`.
5. `HomePage`: thêm hàng chip lọc theo tag (lấy từ tài liệu đang có), chọn 1 tag; kết hợp được với search + loại + "được chia sẻ"; nút "Tất cả" để bỏ lọc.
6. Responsive:
   - Breakpoint **900px**.
   - `< 900`: giữ `ListView` như hiện tại.
   - `>= 900`: nội dung tối đa ~1100px, danh sách dạng `GridView` (2–3 cột, `maxCrossAxisExtent ≈ 420`).
   - Form/detail: bọc `Center` + `ConstrainedBox(maxWidth: 800)`.
   - Login đã ổn, không cần sửa.
7. Test:
   - Unit test `normalizeTags` (lowercase, trim, dedupe, quá 5 tag, tag quá dài).
   - Widget test nhỏ: `SearchField` hoặc `DocumentTile` render tag (không cần gọi mạng).
   - Test tay: 400px và 1440px trên Chrome; Android.

**Definition of Done:**
- [ ] Thêm tài liệu với tag, sửa tag, xoá tag đều đúng.
- [ ] Lọc theo tag kết hợp search/loại/shared đúng.
- [ ] Web ≥ 900px hiển thị grid, không bị kéo full-width.
- [ ] Không sửa file ngoài vùng sở hữu; stub còn nguyên.
- [ ] `flutter analyze` + `flutter test` pass.

---

### 11.3. Nguyễn Đăng Đại — Mượn/chia sẻ + thông báo realtime

**Nhánh:** `feature/dai-borrow`
**Phụ thuộc:** bảng `borrow_requests` + `ensureProfile` của Trưởng.

**Việc cần làm:**
1. Tạo `BorrowRequestModel` + `BorrowService` theo hợp đồng mục 10.3.
2. Hoàn thiện `BorrowRequestButton`:
   - Chỉ hiện với tài liệu **không phải của mình**.
   - Nhập lời nhắn (tuỳ chọn) → gửi yêu cầu.
   - Trạng thái: chưa có → "Yêu cầu mượn"; đang chờ → "Đang chờ duyệt" (disable); đã duyệt → "Đã được duyệt".
   - Chặn gửi trùng (dựa unique index + `hasOpenRequest`).
3. Tạo `lib/pages/borrow_requests_page.dart`:
   - Tab **"Tôi nhận"**: yêu cầu gửi đến tài liệu của tôi; nút Duyệt / Từ chối; yêu cầu đã duyệt có nút "Đã trả".
   - Tab **"Tôi gửi"**: trạng thái các yêu cầu đã gửi.
   - Pull-to-refresh + trạng thái rỗng.
4. Duyệt: gọi `shareDocument(..., permission: 'view')`; Từ chối: chỉ đổi status; Trả: xoá share + status `returned`.
5. Realtime: subscribe Supabase Realtime bảng `borrow_requests`:
   - Owner nhận thông báo khi có request mới (SnackBar + badge trên icon Home nếu kịp).
   - Requester nhận khi được duyệt/từ chối.
   - Huỷ subscription trong `dispose`.
6. Firebase Messaging (mức tối thiểu):
   - Xin quyền, lấy FCM token, lưu vào `profiles.fcm_token` qua service của Trưởng.
   - Gửi 1 test message từ Firebase Console để chứng minh tích hợp (Android).
   - Không làm server gửi tự động; ghi chú trong báo cáo.
7. Test:
   - Unit test chuyển trạng thái: chỉ owner được duyệt/từ chối; chỉ `approved` mới trả; không trả 2 lần.
   - Test tay 2 tài khoản A/B (bắt buộc).

**Definition of Done:**
- [ ] B gửi yêu cầu cho tài liệu của A; A thấy ngay (≤ 2–3 giây) không cần refresh.
- [ ] A duyệt → B thấy tài liệu trong "Được chia sẻ"; A từ chối → B thấy trạng thái.
- [ ] A đánh dấu đã trả → B mất quyền xem.
- [ ] Không gửi trùng yêu cầu đang chờ.
- [ ] Không ảnh hưởng chia sẻ trực tiếp hiện có.
- [ ] `flutter analyze` + `flutter test` pass.

---

### 11.4. Phương Văn Đức — Vị trí/bản đồ + Gợi ý tài liệu

**Nhánh:** `feature/duc-location-recommend`
**Phụ thuộc:** field `location_name/latitude/longitude`, `tags`, dependency `flutter_map`/`latlong2` của Trưởng.

**Việc cần làm:**

**A. Vị trí/bản đồ (ưu tiên):**
1. Hoàn thiện `LocationField`:
   - Ô nhập `location_name` (ví dụ "Kệ A3 - Phòng 201").
   - Nút "Chọn trên bản đồ" mở `LocationPickerPage`; hiển thị toạ độ đã chọn; nút xoá vị trí.
   - Trả giá trị qua callback; form lưu cùng tài liệu.
2. Tạo `lib/pages/location_picker_page.dart`:
   - Tile OpenStreetMap + `InteractiveViewer` (không cần API key).
   - Chạm để đặt marker; nút "Xác nhận"; hiển thị lat/lng.
   - Không cần GPS/geocoding/tìm kiếm địa chỉ.
3. Hoàn thiện `DocumentLocationCard`:
   - Ẩn nếu không có vị trí.
   - Hiển thị tên vị trí, toạ độ, mini-map (không tương tác) hoặc nút "Mở bản đồ" bằng `url_launcher` tới OpenStreetMap.
4. Validate: nếu có lat thì phải có lng; lat ∈ [-90, 90], lng ∈ [-180, 180]; tên ≤ 100 ký tự.
5. Test: hàm validate/serialize vị trí; mở form sửa thấy lại vị trí; xoá vị trí hoạt động.

**B. Gợi ý tài liệu (làm sau khi A xong):**
6. Tạo `RecommendationStruct` theo mục 10.4:
   - Lấy tài liệu người dùng được xem bằng `SupabaseService.getDocuments()`.
   - Xây `tagWeights` từ tài liệu **của tôi**; lấy `subjects`/`types` từ tài liệu của tôi; có thể cộng `profiles.interests` nếu Trưởng đã làm.
   - Loại tài liệu của chính mình, chấm điểm, sắp xếp giảm dần, lấy top 6, loại điểm 0.
7. Hoàn thiện `RecommendationSection`:
   - Tiêu đề "Gợi ý cho bạn".
   - Danh sách ngang các card nhỏ (tiêu đề, môn, tag, lý do ngắn nếu có).
   - Ẩn hoàn toàn nếu không có gợi ý; có nút thử lại.
8. Test:
   - Unit test `score()`: trùng tag > cùng môn > cùng loại; không có tín hiệu → 0; tài liệu của mình bị loại.
   - Test tay: tạo 2 tài liệu cùng tag, xem gợi ý xuất hiện đúng thứ tự.

**Definition of Done:**
- [ ] Chọn vị trí trên bản đồ, lưu, mở lại form thấy đúng; xoá được.
- [ ] Chi tiết hiển thị vị trí + mở được bản đồ ngoài.
- [ ] Gợi ý không chứa tài liệu của mình, ưu tiên tag trùng.
- [ ] Không có vị trí/gợi ý thì UI không vỡ.
- [ ] `flutter analyze` + `flutter test` pass.

---

### 11.5. Tóm tắt phân công

| Thành viên | Nhánh | Phạm vi chính | File chính | Kết quả bàn giao |
|---|---|---|---|---|
| **Nguyễn Thế Trưởng** (leader) | `feature/truong-foundation` | Schema, model, service, auth/RLS, stub, tích hợp, build | `supabase_schema.sql`, `docs/upgrade-v2.sql`, `main.dart`, `services/supabase/*`, `document_model.dart`, `pubspec.yaml` | Nền tảng chạy + app build được + review/merge |
| **Hàn Hoàng Hà** | `feature/ha-tags-responsive` | Tag, lọc tag, responsive mobile/web | `tag_utils.dart`, `home_page.dart`, `document_form_page.dart`, `document_detail_page.dart`, `document_tile.dart` | Tag hoạt động + Web 2 breakpoint + test |
| **Nguyễn Đăng Đại** | `feature/dai-borrow` | Yêu cầu mượn, duyệt/từ chối/trả, realtime, FCM token | `borrow_request_model.dart`, `borrow_service.dart`, `borrow_requests_page.dart`, `borrow_request_button.dart` | Luồng mượn 2 tài khoản + thông báo realtime |
| **Phương Văn Đức** | `feature/duc-location-recommend` | Bản đồ/vị trí, gợi ý tài liệu | `location_field.dart`, `location_picker_page.dart`, `document_location_card.dart`, `recommendation_struct.dart`, `recommendation_section.dart` | Chọn vị trí + gợi ý theo tag + test |

**Thứ tự merge:** `Trưởng (Sprint 0)` → `Hà` → `Đại` → `Đức` → `Trưởng (tích hợp cuối)`.
Nếu Hà chưa xong, Đại/Đức vẫn làm nhánh riêng; chỉ merge khi Trưởng thông báo.

---

## 12. Quy trình Git & review (bắt buộc)

### 12.1. Tạo nhánh

```powershell
git switch main
git pull origin main
git switch -c feature/<ten-nhanh>
```

> `main` hiện đã có Sprint 0 và đủ 4 nhánh thành viên.
> Nếu nhánh của bạn đã cũ: `git rebase origin/main` (hoặc merge `main` vào nhánh) rồi xử lý conflict.

### 12.2. Commit & push

```powershell
git add <cac-file-cua-minh>
git commit -m "feat(borrow): them yeu cau muon tai lieu"
git push -u origin feature/<ten-nhanh>
```

- **Không** chạy `git push origin main`.
- **Không** force push lên `main`.
- Chỉ commit file thuộc phạm vi của mình; không commit `.dart_tool/`, `build/`, file IDE.
- Nếu lỡ commit file ngoài phạm vi: báo Trưởng, không tự revert lung tung.

### 12.3. Pull Request

Tạo PR **vào `main`**, ghi:

```
## Việc đã làm
- ...
## Cách test
1. ...
## Ảnh/chứng cứ
- ...
## Checklist
- [ ] flutter analyze
- [ ] flutter test
- [ ] Không sửa file ngoài phạm vi
- [ ] Không push main
```

Trưởng review, chạy lại test, merge. Thành viên **không tự merge**.

### 12.4. Mẫu tin nhắn gửi nhóm

```
Mọi người làm trên nhánh riêng, KHÔNG push main. Trưởng review + merge.
- Trưởng: feature/truong-foundation (schema + nền tảng, merge trước)
- Hà: feature/ha-tags-responsive (tag + responsive)
- Đại: feature/dai-borrow (mượn + realtime)
- Đức: feature/duc-location-recommend (vị trí + gợi ý)

Chờ Trưởng merge nền tảng rồi mới tạo nhánh từ main mới.
Trước khi push: flutter analyze && flutter test. Mở PR, ghi rõ cách test.
```

---

## 13. Kiểm thử & đóng gói

### 13.1. Test tự động

```powershell
flutter analyze
flutter test
```

| Loại | Nội dung | Người phụ trách |
|---|---|---|
| Unit | `normalizeTags`: trim/lowercase/dedupe/max 5/max 30 | Hà |
| Unit | `RecommendationStruct.score`: tag > subject > type; tài liệu của mình bị loại | Đức |
| Unit | Validate vị trí, serialize `DocumentModel` có/vị trí null | Đức |
| Unit | Trạng thái mượn: chỉ owner duyệt/từ chối; chỉ approved mới trả | Đại |
| Unit | Model/serialization hiện có vẫn pass | Trưởng |
| Widget | Login render, `DocumentTile` hiển thị tag, `SearchField` | Hà |
| Regression | Đăng nhập, CRUD, share cũ | Trưởng |

Không viết test gọi Supabase/Firebase thật. Dùng fake như `test/document_struct_test.dart`.

### 13.2. Test tay bắt buộc (2 tài khoản A/B)

- [ ] A đăng nhập email; B đăng nhập Google (hoặc email khác).
- [ ] A thêm tài liệu có file + 3 tag + vị trí bản đồ.
- [ ] A sửa tag/vị trí; dữ liệu giữ đúng sau khi mở lại.
- [ ] Tìm kiếm + lọc tag + lọc loại + lọc "được chia sẻ" kết hợp đúng.
- [ ] A chia sẻ trực tiếp cho B (`view`); B thấy và mở file.
- [ ] B gửi yêu cầu mượn tài liệu khác của A; A thấy realtime.
- [ ] A duyệt; B thấy tài liệu; A đánh dấu đã trả; B mất quyền.
- [ ] A từ chối một yêu cầu khác; B thấy trạng thái.
- [ ] Home hiển thị "Gợi ý cho bạn" đúng (không có tài liệu của A).
- [ ] Web 1440px: grid + form giới hạn chiều rộng; 400px: list.
- [ ] Theme tối/sáng không lỗi chữ.
- [ ] Refresh app không mất dữ liệu.

### 13.3. Đóng gói

```powershell
flutter build apk --release
flutter build web --release
```

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Web: thư mục `build/web/` (zip hoặc deploy static hosting).
- iOS: chỉ build trên macOS; nếu không có, ghi rõ trong báo cáo.
- Sản phẩm bàn giao: source + README + APK + Web build + báo cáo + slide + video demo (nếu có).

---

## 14. Rủi ro & lưu ý

| # | Rủi ro | Mức độ | Cách xử lý |
|---|---|---|---|
| 1 | RLS `true`, ai có anon key cũng đọc/ghi/xoá được | **Cao** | Trưởng làm mục 9.3; nếu không kịp, ghi rõ hạn chế trong báo cáo |
| 2 | Third-Party Auth Firebase ↔ Supabase có thể không chạy trong thời gian ngắn | Trung bình | Timebox 60–90 phút; fallback policy hiện tại + ghi chú |
| 3 | Push FCM thật cần server/service account | Trung bình | Chỉ làm token + test message từ Console; realtime trong app là chính |
| 4 | Google Maps cần API key/billing | Thấp | Dùng OpenStreetMap (`flutter_map`) |
| 5 | Ảnh bản đồ tải từ OSM, không offline | Thấp | Chấp nhận cho bài tập; không chọn vị trí khi offline |
| 6 | Merge conflict do 4 người sửa file chung | Trung bình | Tuân thủ phân vùng file + stub; merge theo thứ tự |
| 7 | Sửa nhầm code legacy Drift/Firestore | Thấp | Không chạm; chỉ Supabase là luồng chính |
| 8 | Web upload dùng bytes, mobile dùng `File` | Thấp | Giữ nguyên logic hiện có |
| 9 | `categoryId` có trong model nhưng không có cột Supabase | Thấp | Không dùng `categoryId`; dùng tag thay thế |
| 10 | `profiles` chưa được tạo tự động | Trung bình | Trưởng thêm `ensureProfile` sau đăng nhập |
| 11 | Test hiện tại quá ít, dễ vỡ khi refactor | Trung bình | Mỗi người thêm test cho logic mới |
| 12 | Build iOS không thực hiện được trên Windows | Thấp | Ghi rõ trong báo cáo; demo Android + Web |
| 13 | Nhầm `android_profile_app` là app chính | Thấp | Đây là project Kotlin minh hoạ, không sửa |

---

## 15. Hướng dẫn cho AI agent (đọc trước khi code)

Nếu bạn là AI được giao một nhiệm vụ trong repo này:

1. **Xác định bạn đang làm cho ai** (Trưởng/Hà/Đại/Đức) và **chỉ sửa file thuộc vùng của người đó** (mục 10.6).
2. **Không sửa `main`, không commit trực tiếp lên `main`.** Làm trên nhánh `feature/...` đã nêu.
3. **Không tự đổi kiến trúc**, không chuyển sang Firestore, không thêm state management mới, không xoá code legacy.
4. **Không thêm dependency** ngoài danh sách đã chốt (`flutter_map`, `latlong2`, `firebase_messaging`). Nếu thấy cần, dừng và báo Trưởng.
5. **Bám đúng hợp đồng** tên field/class/method ở mục 10. Không đổi signature của `DocumentModel`, `SupabaseService`, `BorrowService`, `RecommendationStruct`.
6. **Không sửa schema Supabase trực tiếp trong dashboard.** Mọi thay đổi SQL ghi vào `docs/upgrade-v2.sql` (Trưởng chạy) hoặc báo Trưởng.
7. **Giữ UI tiếng Việt**, Material 3, pattern hiện có: `AppScaffold`, `LoadingIndicator`, `EmptyState`, `Provider`.
8. **Không sửa `README.md`** (Trưởng cập nhật). Nếu cần ghi chú, tạo file trong `docs/` hoặc ghi trong PR.
9. **Luôn chạy** trước khi push:
   ```powershell
   flutter analyze
   flutter test
   ```
10. **Test logic mới** bằng unit test, không gọi mạng thật. Dùng fake service như `test/document_struct_test.dart`.
11. **Commit nhỏ, push sớm** để Trưởng thấy tiến độ; mở PR vào `main`, không tự merge.
12. **Nếu bế tắc > 30 phút**: dừng, ghi rõ lỗi + cách đã thử, báo nhóm. Không đoán mò schema/API.
13. **Không làm thêm feature ngoài scope** (chat, versioning, offline, admin...). Ưu tiên "chạy được, đơn giản, có test".
14. **Bảo mật:** không commit `service_role key`, không log token, không đưa dữ liệu thật lên bucket public.
15. **Khi hoàn thành**, cập nhật checklist trong PR và ghi rõ:
    - file đã sửa;
    - cách chạy/test;
    - phần còn thiếu hoặc cần Trưởng tích hợp.

---

## 16. Checklist tổng & kịch bản demo

### 16.1. Definition of Done toàn dự án

- [ ] Đăng nhập Email + Google; hồ sơ `profiles` được tạo.
- [ ] CRUD tài liệu + upload/download/xoá file Supabase.
- [ ] Tag: thêm/sửa/xoá, hiển thị, lọc.
- [ ] Vị trí: chọn trên bản đồ, lưu, hiển thị, mở bản đồ ngoài.
- [ ] Chia sẻ trực tiếp (`view`/`edit`) vẫn hoạt động.
- [ ] Yêu cầu mượn → duyệt/từ chối → trả; realtime; chặn trùng.
- [ ] Gợi ý theo tag/môn/loại; không gợi ý tài liệu của mình.
- [ ] Responsive: mobile list + web grid; form/detail không full-width.
- [ ] `flutter analyze` 0 issue; `flutter test` pass.
- [ ] Test tay 2 tài khoản đạt.
- [ ] APK release + Web release build chạy.
- [ ] README + báo cáo + slide cập nhật.
- [ ] Không ai push `main`; mọi thay đổi qua PR.

### 16.2. Kịch bản demo (5–7 phút)

1. A đăng nhập Google; B đăng nhập email.
2. A thêm tài liệu "Giáo trình Flutter", tag `flutter, mobile`, chọn vị trí trên bản đồ, upload PDF.
3. A tìm/lọc theo tag; mở chi tiết, xem bản đồ, mở file.
4. B gửi yêu cầu mượn; A nhận thông báo realtime, bấm Duyệt.
5. B thấy tài liệu trong "Được chia sẻ" và mở file.
6. A đánh dấu "Đã trả"; B mất quyền.
7. Mở Web ở 1440px: grid + gợi ý; thu nhỏ 400px: list.
8. Trình bày kiến trúc Firebase Auth + Supabase DB/Storage/Realtime trên slide.

---

## 17. Lệnh & công cụ tham khảo

```powershell
# Flutter
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
flutter build apk --release
flutter build web --release

# Git (ví dụ Hà)
git switch main
git pull origin main
git switch -c feature/ha-tags-responsive
git add lib/pages/home_page.dart lib/widgets/framework/document_tile.dart   # chỉ file của mình
git commit -m "feat(tag): hien thi va loc tag"
git push -u origin feature/ha-tags-responsive
```

Tài liệu nội bộ:
- `docs/about-firebase.md` — kiến thức Firebase, dùng cho báo cáo/slide.
- `docs/firebase-setup.md` — cấu hình FlutterFire.
- `docs/security-rules.md` — lý thuyết Security Rules.
- `docs/comparison.md` — so sánh local vs cloud.
- `docs/evaluation.md` — đánh giá bảo mật/chi phí/hiệu năng.

---

> **Nhắc lại:** không push `main`. Mỗi người một nhánh, mở PR, Trưởng review và merge.
