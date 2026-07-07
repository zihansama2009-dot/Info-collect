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
cd frontend && flutter build web --web-renderer html --base-href /

# Full single-file deploy
cp -r frontend/build/web/* backend/web/
cd backend && go build -ldflags="-s -w" -o class-form main.go
./class-form
```

## Environment variables

| Var | Default | Notes |
|-----|---------|-------|
| `PORT` | `8080` | |
| `DB_PATH` | `data.db` | SQLite 文件路径 |
| `ADMIN_USER` | (随机生成) | 不再使用环境变量；首次启动时随机生成管理员账号，密码在启动日志中打印 |
| `ADMIN_PASS` | (随机生成) | 同上 |

## 管理员账号

- 数据库无管理员时，`InitAdmin` 随机生成 10 位用户名 + 12 位密码（含特殊字符），bcrypt 哈希后存入 `users` 表。
- 明文凭证仅在**首次启动日志**中打印一次，之后不再通过环境变量注入。
- `User.Version` 字段记录首次创建时的应用版本号。

## 新增 API

| 方法 | 路径 | 说明 |
| :--- | :--- | :--- |
| GET | `/api/admin/me` | 获取当前管理员信息（用户名、版本） |
| PUT | `/api/admin/username` | 修改管理员用户名（需登录） |
| PUT | `/api/admin/password` | 修改管理员密码（需登录，原版已有） |
| GET | `/api/admin/version` | 获取应用版本号（需登录） |

## 前端管理路由

| 路径 | 页面 | 说明 |
| :--- | :--- | :--- |
| `/admin/settings` | `AdminSettingsPage` | 管理员账号设置（修改用户名/密码、查看版本） |

## Important gotchas

- **JWT secret is hardcoded** in `backend/middleware/auth.go:12` (`class-form-secret-key-change-me`). Replace before exposing to any network.
- **Student passwords are stored in plaintext** (see `backend/handlers/auth.go:77`, `models/models.go:37`). Not bcrypt.
- **SQLite concurrency:** `sqlDB.SetMaxOpenConns(1)` in `main.go:38` — intentional serialization to avoid "database is locked".
- **CORS is wide open** (`AllowAllOrigins: true`, `main.go:59`) — suitable for single-file deploy (same origin), but worth tightening if proxied separately.
- **Frontend `m3e_design` is commented out** in `pubspec.yaml:16`; the project ships its own `lib/theme/m3e_theme.dart` implementation. Do not uncomment without also updating that file.

## Testing

- Backend: no test suite present.
- Frontend: `flutter test` runs the default boilerplate `test/widget_test.dart` (smoke test, not meaningful).

## No migration tooling

Schema changes rely on GORM `AutoMigrate` (`main.go:42`). There is no versioned migration system.
