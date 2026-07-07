# 📘 班级动态信息收集系统 (V5.0)

轻量级、免运维、高颜值的班级信息收集系统。管理员通过 Web 后台管理全局学生账号与组、自定义表单结构并导出 Excel；学生通过移动端浏览器登录后查看可填报任务并完成提交。

## 核心特性

- **全局学生账号**：学号全局唯一，独立于任务；bcrypt 哈希存储密码，首次登录强制改密。旧版按任务维度的 `Student` 表启动时自动迁移为 `StudentUser`。
- **批量导入学生**：通过 xlsx 一键导入学生名单（A=学号, B=姓名, C=密码可选），支持默认密码、去重、错误明细回显。
- **组管理**：管理员可创建组、增删成员；任务可分配给用户或组，组内成员自动继承任务权限。
- **双轨制表头映射**：题目「显示名 (`label`)」与「Excel 导出列名 (`export_header`)」分离，口语化题目也能导出官方格式表头，留空自动降级。
- **流式 Excel 导出**：内存生成 + 流式写入 HTTP 响应，避免并发临时文件冲突（基于 `excelize`）。
- **Material 3 Expressive UI**：通过 MD3E Tokens（spacing / typography / shapes）告别硬编码像素值。
- **单文件部署**：Go Embed 打包 Flutter Web 产物，双击即用，配合内网穿透全网可访。
- **随机管理员初始化**：数据库无管理员时自动生成高强度随机账号密码，启动日志一次性打印明文凭证。
- **版本追踪**：管理员账号绑定应用版本号，支持前端查看当前版本。
- **APK 构建**：Android 客户端通过 `--dart-define=BACKEND_URL=...` 注入后端地址，不再硬编码。

## 技术栈

| 层 | 技术 |
| :--- | :--- |
| 后端 | Go + Gin + GORM + SQLite + Excelize |
| 前端 | Flutter Web + Riverpod + GoRouter + MD3E |
| 部署 | 单文件可执行程序 + 内网穿透 |

## 目录结构

```
class-form/
├── VERSION                     # 应用版本号（后端启动时读取）
├── backend/
│   ├── main.go                 # 入口：DB/路由/embed静态资源/SPA回退
│   ├── go.mod
│   ├── models/models.go        # 数据模型（StudentUser/Group/TaskAssignment/FormField 等）
│   ├── middleware/auth.go      # JWT 认证中间件
│   ├── handlers/               # auth/task/form_field/student_user/group/task_assignment/export
│   └── web/                    # Flutter Web 构建产物（go:embed）
└── frontend/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart           # withM3ETheme 主题初始化
        ├── router.dart         # GoRouter 路由 + 权限重定向
        ├── theme/m3e_theme.dart# MD3E Tokens 实现层
        ├── models/models.dart  # 前端模型
        ├── services/api_service.dart
        ├── providers/providers.dart
        └── pages/{admin,student}/
```

## 后端构建与运行

```bash
cd backend
go mod tidy
go run .
# 默认 http://localhost:8080
# 首次启动若数据库无管理员，启动日志会打印随机生成的账号密码
# 已有管理员时不再生成，环境变量 ADMIN_USER/ADMIN_PASS 不再用于初始创建
```

环境变量：

| 变量 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `PORT` | 8080 | 监听端口 |
| `DB_PATH` | data.db | SQLite 文件路径 |

> 管理员账号改为数据库持久化存储。首次启动时随机生成 10 位用户名 + 12 位密码（含特殊字符），bcrypt 哈希后存入 `users` 表。明文凭证仅在**首次启动日志**中打印一次，之后不再通过环境变量注入。

## 前端构建

```bash
cd frontend
flutter create . --platforms=web   # 首次需初始化 web 平台目录
flutter pub get
flutter build web --base-href /
# 将 build/web/* 复制到 backend/web/ 后重新编译后端
```

> 关于 `m3e_design`：文档指定使用该包提供 Tokens。由于该包在 pub.dev 上可能不可用，本项目在 `lib/theme/m3e_theme.dart` 中实现了等价 API（`withM3ETheme` / `M3ETheme.of(context).spacing|typography|shapes`），业务代码与文档保持一致且可独立编译。接入官方包时仅需替换该文件实现。

## 完整打包流程

```bash
# 1. 构建前端
cd frontend && flutter build web --base-href /

# 2. 移动产物
cp -r build/web/* ../backend/web/

# 3. 编译单文件可执行程序
cd ../backend
go build -ldflags="-s -w" -o class-form main.go

# 4. 运行（生成 data.db，监听 8080）
./class-form
```

配合 `cpolar` / `ngrok` 将 8080 映射到公网，把链接或二维码发到班级群即可。

## API 概览

| 方法 | 路径 | 说明 |
| :--- | :--- | :--- |
| POST | `/api/admin/login` | 管理员登录 |
| POST | `/api/student/login` | 学生登录（仅学号+密码，无需任务ID） |
| GET/POST | `/api/admin/tasks` | 任务列表/创建 |
| GET/PUT/DELETE | `/api/admin/tasks/:id` | 任务详情/更新/删除 |
| GET | `/api/admin/tasks/:id/stats` | 任务统计 |
| GET/PUT | `/api/admin/tasks/:id/fields` | 表单字段查询/保存 |
| GET | `/api/admin/tasks/:id/submissions` | 提交查看 |
| GET | `/api/admin/tasks/:id/export` | Excel 流式导出 |
| PUT | `/api/admin/password` | 管理员修改密码 |
| PUT | `/api/admin/username` | 管理员修改用户名 |
| GET | `/api/admin/me` | 获取当前管理员信息 |
| GET | `/api/admin/version` | 获取应用版本号 |
| GET/POST/DELETE | `/api/admin/students` | 全局学生 CRUD |
| POST | `/api/admin/students/import` | 批量导入学生（xlsx） |
| PUT | `/api/admin/students/:id/password` | 重置学生密码 |
| GET/POST/PUT/DELETE | `/api/admin/groups` | 组 CRUD |
| POST/DELETE/GET | `/api/admin/groups/:id/members` | 组成员管理 |
| POST | `/api/admin/tasks/:id/assign/users` | 分配用户到任务 |
| POST | `/api/admin/tasks/:id/assign/groups` | 分配组到任务 |
| GET | `/api/admin/tasks/:id/assignments` | 获取任务分配情况 |
| GET/POST | `/api/student/submission` `/submit` | 学生提交 |
| GET | `/api/student/tasks/available` | 学生可用任务列表 |
| GET | `/api/student/tasks/:id/config` | 任务表单配置（无需登录） |
| PUT | `/api/student/password` | 学生修改密码 |

## 管理后台功能

- **任务管理**：创建、查看、关闭/开启任务，导出填报数据（Excel）
- **表单字段配置**：自定义题目显示名与导出表头（双轨制），支持文本/数字/日期/下拉选择类型，可设置必填和保密字段
- **学生管理**：全局学生账号 CRUD、批量 xlsx 导入、重置密码
- **组管理**：创建组、增删成员，任务可按用户或组分配
- **任务分配**：将用户或组分配到任务，组内成员自动继承权限
- **账号设置**：修改管理员用户名和密码，查看应用版本号

## 注意事项

- JWT 签名密钥硬编码在 `backend/middleware/auth.go:12`，生产环境暴露前请务必修改
- 学生密码使用 bcrypt 哈希存储；旧版明文密码（legacy `Student` 表）在迁移后保留，学生改密后自动升级为 bcrypt
- SQLite 通过 `SetMaxOpenConns(1)` 串行化写操作，避免 "database is locked"
- 数据库 schema 通过 GORM `AutoMigrate` 自动更新，无版本化迁移工具
- CORS 全开放（`AllowAllOrigins: true`），适合单文件同源部署；若前后端分离代理需自行收紧
