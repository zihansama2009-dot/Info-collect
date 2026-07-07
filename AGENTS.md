# AGENTS.md — class-form

## Repo layout

- **Go module:** `class-form` (`backend/go.mod`) — all Go packages import as `class-form/...`
- **Frontend package:** `class_form_frontend` (`frontend/pubspec.yaml`)
- **Artifact coupling:** `backend/web/` must hold the Flutter Web build output. `main.go` uses `//go:embed web/*` to serve the SPA; if missing, a placeholder page is returned.

## Key commands

```bash
# Backend (Go 1.21+)
cd backend && go mod tidy && go run .

# Frontend — first time only
cd frontend && flutter create . --platforms=web && flutter pub get

# Frontend build
cd frontend && flutter build web --base-href /

# Full single-file deploy
cp -r frontend/build/web/* backend/web/
cd backend && go build -ldflags="-s -w" -o class-form main.go
./class-form
```

## Versioning

- Version stored in root `VERSION` file (e.g. `5.0.0`).
- Backend reads it at startup; frontend reads it via `/api/admin/version`.
- Bump rules: major (+1.0.0) for breaking changes, minor (+0.1.0) for features, patch (+0.0.1) for fixes.

## Environment variables

| Var | Default | Notes |
|-----|---------|-------|
| `PORT` | `8080` | |
| `DB_PATH` | `data.db` | SQLite 文件路径 |

## 管理员账号

- 数据库无管理员时，`InitAdmin` 随机生成 10 位用户名 + 12 位密码（含特殊字符），bcrypt 哈希后存入 `users` 表。
- 明文凭证仅在**首次启动日志**中打印一次。
- `User.Version` 字段记录首次创建时的应用版本号。

## 学生账号（全局）

- 已从「按任务维度的局部账号」改为「全局账号」：`StudentUser` 表，`student_no` 全局唯一。
- 密码使用 bcrypt 哈希存储。
- 首次登录强制修改密码（`must_change_password` 标记）。
- 旧版 `Student` 表在启动时自动迁移为 `StudentUser`，迁移后删除旧表。

## 组（Group）

- 管理员可创建组、添加/移除成员。
- 任务可分配给**用户**或**组**；组内成员自动继承任务权限。

## CI/CD

- 推送到 `main` 或打 `v*` 标签：自动构建多平台二进制 + Flutter Web，创建 GitHub Release。
- 手动触发 (`workflow_dispatch`) 可勾选：
  - `upload_to_release`：是否上传到 GitHub Release
  - `build_apk`：是否构建 Android APK（需输入后端网址）
- APK 构建：通过 `--dart-define=BACKEND_URL=...` 注入后端地址，不再硬编码。

## 新增 API

| 方法 | 路径 | 说明 |
| :--- | :--- | :--- |
| POST | `/api/admin/login` | 管理员登录 |
| POST | `/api/student/login` | 学生登录（仅学号+密码，无需任务ID） |
| GET/POST | `/api/admin/tasks` | 任务列表/创建 |
| GET/PUT/DELETE | `/api/admin/tasks/:id` | 任务详情/更新/删除 |
| GET/PUT | `/api/admin/tasks/:id/fields` | 表单字段查询/保存 |
| GET | `/api/admin/tasks/:id/submissions` | 提交查看 |
| GET | `/api/admin/tasks/:id/export` | Excel 流式导出 |
| GET/POST | `/api/student/submission` `/submit` | 学生提交 |
| GET | `/api/student/tasks/available` | 学生可用任务列表 |
| GET | `/api/student/tasks/:id/config` | 任务表单配置 |
| PUT | `/api/admin/password` | 管理员修改密码 |
| PUT | `/api/admin/username` | 管理员修改用户名 |
| GET | `/api/admin/me` | 获取当前管理员信息 |
| GET | `/api/admin/version` | 获取应用版本号 |
| GET/POST/DELETE | `/api/admin/students` | 全局学生 CRUD |
| PUT | `/api/admin/students/:id/password` | 重置学生密码 |
| GET/POST/PUT/DELETE | `/api/admin/groups` | 组 CRUD |
| POST/DELETE | `/api/admin/groups/:id/members` | 组成员管理 |
| POST | `/api/admin/tasks/:id/assign/users` | 分配用户到任务 |
| POST | `/api/admin/tasks/:id/assign/groups` | 分配组到任务 |
| GET | `/api/admin/tasks/:id/assignments` | 获取任务分配情况 |
| PUT | `/api/student/password` | 学生修改密码 |

## 前端管理路由

| 路径 | 页面 | 说明 |
| :--- | :--- | :--- |
| `/admin/settings` | `AdminSettingsPage` | 管理员账号设置 |
| `/admin/students` | `AdminStudentListPage` | 学生账号管理 |
| `/admin/groups` | `AdminGroupListPage` | 组管理 |
| `/admin/tasks/:id/assign` | `AdminTaskAssignPage` | 任务分配（用户/组） |
| `/student/change-password` | `StudentChangePasswordPage` | 首次登录修改密码 |
| `/student/tasks` | `StudentTaskSelectPage` | 学生选择要填报的任务 |

## Important gotchas

- **JWT secret is hardcoded** in `backend/middleware/auth.go:12` (`class-form-secret-key-change-me`). Replace before exposing to any network.
- **Student passwords were stored in plaintext** (legacy `Student` table). Migrated users keep plaintext until they change password; new accounts use bcrypt.
- **SQLite concurrency:** `sqlDB.SetMaxOpenConns(1)` in `main.go:38` — intentional serialization to avoid "database is locked".
- **CORS is wide open** (`AllowAllOrigins: true`, `main.go:59`) — suitable for single-file deploy (same origin), but worth tightening if proxied separately.
- **Frontend `m3e_design` is commented out** in `pubspec.yaml:16`; the project ships its own `lib/theme/m3e_theme.dart` implementation.
- **APK backend URL:** No longer hardcoded. Pass via `--dart-define=BACKEND_URL=https://your-server.com` when building APK.

## Testing

- Backend: no test suite present.
- Frontend: `flutter test` runs the default boilerplate `test/widget_test.dart` (smoke test, not meaningful).

## No migration tooling

Schema changes rely on GORM `AutoMigrate` (`main.go:42`). There is no versioned migration system.
