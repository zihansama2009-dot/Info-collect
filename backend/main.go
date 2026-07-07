package main

import (
	"embed"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strings"

	"class-form/handlers"
	"class-form/middleware"
	"class-form/models"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

//go:embed web/*
var webFS embed.FS

var APP_VERSION string

func initVersion() {
	data, err := os.ReadFile("VERSION")
	if err != nil {
		APP_VERSION = "dev"
		return
	}
	APP_VERSION = strings.TrimSpace(string(data))
}

func main() {
	initVersion()
	// 1. 初始化数据库
	dbPath := getEnv("DB_PATH", "data.db")
	db, err := gorm.Open(sqlite.Open(dbPath+"?_journal_mode=WAL&_busy_timeout=5000"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Warn),
	})
	if err != nil {
		log.Fatalf("无法打开数据库: %v", err)
	}
	models.DB = db

	// SQLite 单连接串行化：避免多 goroutine 并发写时 "database is locked"
	if sqlDB, err := db.DB(); err == nil {
		sqlDB.SetMaxOpenConns(1)
	}

	// 自动迁移
	if err := db.AutoMigrate(&models.User{}, &models.Task{}, &models.Student{}, &models.FormField{}, &models.Submission{}, &models.StudentUser{}, &models.Group{}, &models.GroupMember{}, &models.TaskAssignment{}, &models.TaskGroupAssignment{}); err != nil {
		log.Fatalf("数据库迁移失败: %v", err)
	}

	// 数据迁移：将旧版 Student 记录迁移为全局 StudentUser
	handlers.MigrateToGlobalUsers(db)

	// 初始化默认管理员（数据库无管理员时随机生成凭证）
	if result, err := handlers.InitAdmin(APP_VERSION); err != nil {
		log.Printf("初始化管理员警告: %v", err)
	} else if result != nil {
		log.Printf("首次启动，已生成管理员账号: %s / %s（请尽快修改密码）", result.Username, result.Password)
	}

	// 迁移旧管理员账号版本号
	handlers.MigrateVersion(APP_VERSION)

	// 2. 设置 Gin
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// CORS（开发期前端独立运行于其他端口时需要；生产单文件部署为同源无需此中间件）
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: false, // AllowAllOrigins=true 时不能启用 credentials
	}))

	// 3. API 路由
	api := r.Group("/api")
	{
		// 认证
		api.POST("/admin/login", handlers.AdminLogin)
		api.POST("/student/login", handlers.StudentLogin)

		// 学生端：获取任务表单配置（无需登录，仅展示题目与任务信息）
		api.GET("/student/tasks/:id/config", handlers.GetFormConfig)

		// 管理员接口
		admin := api.Group("/admin", middleware.AuthRequired(), middleware.AdminRequired())
		{
		admin.PUT("/password", handlers.ChangeAdminPassword)
		admin.PUT("/username", handlers.ChangeAdminUsername)
		admin.GET("/me", handlers.GetAdminInfo)
		admin.GET("/version", handlers.GetVersion)

			// 任务
			admin.GET("/tasks", handlers.ListTasks)
			admin.POST("/tasks", handlers.CreateTask)
			admin.GET("/tasks/:id", handlers.GetTask)
			admin.PUT("/tasks/:id", handlers.UpdateTask)
			admin.DELETE("/tasks/:id", handlers.DeleteTask)
			admin.GET("/tasks/:id/stats", handlers.TaskStats)

		// 表单字段
		admin.GET("/tasks/:id/fields", handlers.ListFormFields)
		admin.PUT("/tasks/:id/fields", handlers.SaveFormFields)

		// 提交查看与导出
		admin.GET("/tasks/:id/submissions", handlers.ListSubmissions)
		admin.GET("/tasks/:id/export", handlers.ExportTaskData)
		}

		// 学生接口
		student := api.Group("/student", middleware.AuthRequired())
		{
			student.GET("/submission", handlers.GetMySubmission)
			student.POST("/submit", handlers.SubmitForm)
			student.GET("/tasks/available", handlers.GetAvailableTasks)
			student.PUT("/password", handlers.ChangeStudentPassword)
		}

		// 全局学生管理（管理员）
		admin.GET("/students", handlers.ListStudents)
		admin.POST("/students", handlers.CreateStudent)
		admin.POST("/students/import", handlers.ImportStudents)
		admin.PUT("/students/:id/password", handlers.ResetStudentPassword)
		admin.DELETE("/students/:id", handlers.DeleteStudent)

		// 组管理（管理员）
		admin.GET("/groups", handlers.ListGroups)
		admin.POST("/groups", handlers.CreateGroup)
		admin.PUT("/groups/:id", handlers.UpdateGroup)
		admin.DELETE("/groups/:id", handlers.DeleteGroup)
		admin.POST("/groups/:id/members", handlers.AddGroupMember)
		admin.DELETE("/groups/:id/members/:user_id", handlers.RemoveGroupMember)
		admin.GET("/groups/:id/members", handlers.ListGroupMembers)

		// 任务分配（管理员）
		admin.POST("/tasks/:id/assign/users", handlers.AssignUsersToTask)
		admin.POST("/tasks/:id/assign/groups", handlers.AssignGroupsToTask)
		admin.GET("/tasks/:id/assignments", handlers.GetTaskAssignments)
	}

	// 4. 静态资源：Flutter Web 产物
	serveFlutterWeb(r)

	// 5. 启动服务
	port := getEnv("PORT", "8080")
	addr := ":" + port
	log.Printf("应用版本: %s", APP_VERSION)
	log.Printf("班级信息收集系统已启动: http://localhost:%s", port)
	if err := r.Run(addr); err != nil {
		log.Fatalf("服务启动失败: %v", err)
	}
}

// serveFlutterWeb 提供 Flutter Web 静态资源，并支持前端路由的刷新回退
func serveFlutterWeb(r *gin.Engine) {
	subFS, err := fs.Sub(webFS, "web")
	if err != nil {
		// 未构建前端时 web 目录可能不存在，提供一个占位提示
		r.NoRoute(func(c *gin.Context) {
			if strings.HasPrefix(c.Request.URL.Path, "/api/") {
				c.JSON(http.StatusNotFound, gin.H{"error": "接口不存在"})
				return
			}
			c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(frontendPlaceholder))
		})
		return
	}

	fileServer := http.FileServer(http.FS(subFS))
	// 优先匹配静态文件
	r.GET("/favicon.ico", func(c *gin.Context) {
		c.FileFromFS("favicon.ico", http.FS(subFS))
	})

	r.NoRoute(func(c *gin.Context) {
		path := strings.TrimPrefix(c.Request.URL.Path, "/")
		// 接口请求直接 404
		if strings.HasPrefix(c.Request.URL.Path, "/api/") {
			c.JSON(http.StatusNotFound, gin.H{"error": "接口不存在"})
			return
		}
		// 尝试直接读取文件（assets 等）
		if path != "" {
			if _, err := fs.Stat(subFS, path); err == nil {
				fileServer.ServeHTTP(c.Writer, c.Request)
				return
			}
		}
		// 其余路径回退到 index.html（SPA 路由）
		c.Header("Content-Type", "text/html; charset=utf-8")
		data, err := fs.ReadFile(subFS, "index.html")
		if err != nil {
			c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(frontendPlaceholder))
			return
		}
		c.Data(http.StatusOK, "text/html; charset=utf-8", data)
	})
}

func getEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

const frontendPlaceholder = `<!DOCTYPE html><html><head><meta charset="utf-8"><title>班级信息收集系统</title>
<style>body{font-family:sans-serif;text-align:center;padding:80px;background:#faf8ff;color:#4a4458}
h1{color:#6750A4}code{background:#eee;padding:2px 6px;border-radius:4px}</style></head>
<body><h1>前端尚未构建</h1><p>请先在 <code>frontend/</code> 目录执行 Flutter Web 构建并将产物放入 <code>backend/web/</code>。</p>
<p>API 文档：<code>/api/admin/login</code> 等接口已可用。</p></body></html>`
