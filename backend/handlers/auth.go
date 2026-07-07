package handlers

import (
	"math/rand"
	"net/http"
	"time"

	"class-form/middleware"
	"class-form/models"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

const (
	adminUsernameChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	adminPasswordChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%"
	adminUsernameLen   = 10
	adminPasswordLen   = 12
)

func randomString(length int, charset string) string {
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[r.Intn(len(charset))]
	}
	return string(b)
}

func checkStudentPassword(hash, password string) bool {
	if hash == password {
		return true
	}
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}

// InitAdmin 初始化默认管理员账号（仅当不存在时）。
// 如果数据库中尚无管理员，则随机生成用户名和密码并写入数据库。
// 返回生成的凭证（仅在首次创建时非空），供启动日志打印。
func InitAdmin(version string) (*InitAdminResult, error) {
	var count int64
	models.DB.Model(&models.User{}).Count(&count)
	if count > 0 {
		return nil, nil
	}
	username := randomString(adminUsernameLen, adminUsernameChars)
	password := randomString(adminPasswordLen, adminPasswordChars)
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	user := models.User{
		Username:     username,
		PasswordHash: string(hash),
		Role:         "admin",
		Version:      version,
	}
	if err := models.DB.Create(&user).Error; err != nil {
		return nil, err
	}
	return &InitAdminResult{Username: username, Password: password}, nil
}

// InitAdminResult 初始化管理员的结果
type InitAdminResult struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

// MigrateVersion 将空版本的管理员账号更新为当前版本号
func MigrateVersion(version string) {
	models.DB.Model(&models.User{}).Where("version = ? OR version IS NULL OR version = ''", "").Update("version", version)
}

// MigrateToGlobalUsers 将旧版 Student 记录迁移为全局 StudentUser
func MigrateToGlobalUsers(db *gorm.DB) {
	var count int64
	db.Model(&models.StudentUser{}).Count(&count)
	if count > 0 {
		return
	}

	var students []models.Student
	if err := db.Find(&students).Error; err != nil {
		return
	}
	if len(students) == 0 {
		return
	}

	for _, s := range students {
		user := models.StudentUser{
			StudentNo: s.StudentNo,
			Name:      s.Name,
			PasswordHash: s.Password, // plaintext from old system
			MustChangePassword: true,
		}
		if err := db.Create(&user).Error; err != nil {
			continue
		}

		var submissions []models.Submission
		if err := db.Where("student_id = ?", s.ID).Find(&submissions).Error; err != nil {
			continue
		}
		for _, sub := range submissions {
			sub.StudentID = user.ID
			db.Save(&sub)
		}
	}

	db.Exec("DELETE FROM students")
}

// AdminLogin 管理员登录
func AdminLogin(c *gin.Context) {
	var req struct {
		Username string `json:"username" binding:"required"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	var user models.User
	if err := models.DB.Where("username = ?", req.Username).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "用户名或密码错误"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "用户名或密码错误"})
		return
	}

	token, _ := middleware.GenerateToken(middleware.Claims{
		UserID:   user.ID,
		Username: user.Username,
		Role:     "admin",
	})
	c.JSON(http.StatusOK, gin.H{"token": token, "username": user.Username})
}

// StudentLogin 学生登录（学号 + 密码，全局账号）
func StudentLogin(c *gin.Context) {
	var req struct {
		StudentNo string `json:"student_no" binding:"required"`
		Password  string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	var user models.StudentUser
	if err := models.DB.Where("student_no = ?", req.StudentNo).First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "学号或密码错误"})
		return
	}

	if !checkStudentPassword(user.PasswordHash, req.Password) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "学号或密码错误"})
		return
	}

	token, _ := middleware.GenerateToken(middleware.Claims{
		Role:       "student",
		StudentID:  user.ID,
	})
	c.JSON(http.StatusOK, gin.H{
		"token":                token,
		"name":                 user.Name,
		"must_change_password": user.MustChangePassword,
	})
}

// ChangeAdminPassword 修改管理员密码
func ChangeAdminPassword(c *gin.Context) {
	claims := c.MustGet("claims").(*middleware.Claims)

	var req struct {
		OldPassword string `json:"old_password" binding:"required"`
		NewPassword string `json:"new_password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	var user models.User
	if err := models.DB.First(&user, claims.UserID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.OldPassword)) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "原密码错误"})
		return
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	user.PasswordHash = string(hash)
	models.DB.Save(&user)
	c.JSON(http.StatusOK, gin.H{"message": "修改成功"})
}

// ChangeAdminUsername 修改管理员用户名
func ChangeAdminUsername(c *gin.Context) {
	claims := c.MustGet("claims").(*middleware.Claims)

	var req struct {
		NewUsername string `json:"new_username" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	newUsername := req.NewUsername
	if len(newUsername) < 3 || len(newUsername) > 64 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "用户名长度需在 3-64 位之间"})
		return
	}

	var user models.User
	if err := models.DB.First(&user, claims.UserID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}
	if user.Username == newUsername {
		c.JSON(http.StatusBadRequest, gin.H{"error": "新用户名与当前用户名相同"})
		return
	}

	var exists int64
	models.DB.Model(&models.User{}).Where("username = ? AND id != ?", newUsername, claims.UserID).Count(&exists)
	if exists > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "该用户名已被占用"})
		return
	}

	user.Username = newUsername
	models.DB.Save(&user)
	c.JSON(http.StatusOK, gin.H{"message": "用户名修改成功", "username": newUsername})
}

// GetAdminInfo 获取当前管理员信息
func GetAdminInfo(c *gin.Context) {
	claims := c.MustGet("claims").(*middleware.Claims)

	var user models.User
	if err := models.DB.First(&user, claims.UserID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}
	version := user.Version
	if version == "" {
		version = "unknown"
	}
	c.JSON(http.StatusOK, gin.H{
		"username": user.Username,
		"version":  version,
	})
}

// GetVersion 返回应用版本号（从数据库读取）
func GetVersion(c *gin.Context) {
	var user models.User
	if err := models.DB.First(&user).Error; err != nil {
		c.JSON(http.StatusOK, gin.H{"version": "unknown"})
		return
	}
	version := user.Version
	if version == "" {
		version = "unknown"
	}
	c.JSON(http.StatusOK, gin.H{"version": version})
}
