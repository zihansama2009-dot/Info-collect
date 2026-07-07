package handlers

import (
	"net/http"

	"class-form/middleware"
	"class-form/models"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

// ListStudents 获取所有全局学生账号（管理员）
func ListStudents(c *gin.Context) {
	var users []models.StudentUser
	models.DB.Order("created_at desc").Find(&users)
	c.JSON(http.StatusOK, users)
}

// CreateStudent 创建全局学生账号（管理员）
func CreateStudent(c *gin.Context) {
	var req struct {
		StudentNo string `json:"student_no" binding:"required"`
		Name      string `json:"name" binding:"required"`
		Password  string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	if len(req.Password) < 6 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "密码至少6位"})
		return
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	user := models.StudentUser{
		StudentNo:          req.StudentNo,
		Name:               req.Name,
		PasswordHash:       string(hash),
		MustChangePassword: true,
	}
	if err := models.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败，学号可能已存在"})
		return
	}
	c.JSON(http.StatusOK, user)
}

// ResetStudentPassword 重置学生密码（管理员）
func ResetStudentPassword(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	if len(req.Password) < 6 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "密码至少6位"})
		return
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err := models.DB.Model(&models.StudentUser{}).Where("id = ?", id).Update("password_hash", string(hash)).Update("must_change_password", true).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "密码已重置"})
}

// DeleteStudent 删除学生账号（管理员）
func DeleteStudent(c *gin.Context) {
	id := c.Param("id")
	if err := models.DB.Delete(&models.StudentUser{}, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "已删除"})
}

// ChangeStudentPassword 学生修改自己的密码
func ChangeStudentPassword(c *gin.Context) {
	claims := c.MustGet("claims").(*middleware.Claims)

	var req struct {
		OldPassword string `json:"old_password" binding:"required"`
		NewPassword string `json:"new_password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	if len(req.NewPassword) < 6 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "新密码至少6位"})
		return
	}

	var user models.StudentUser
	if err := models.DB.First(&user, claims.StudentID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "用户不存在"})
		return
	}
	if !checkStudentPassword(user.PasswordHash, req.OldPassword) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "原密码错误"})
		return
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	user.PasswordHash = string(hash)
	user.MustChangePassword = false
	models.DB.Save(&user)
	c.JSON(http.StatusOK, gin.H{"message": "密码修改成功"})
}
