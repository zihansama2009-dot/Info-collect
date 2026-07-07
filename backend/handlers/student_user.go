package handlers

import (
	"fmt"
	"net/http"
	"strings"

	"class-form/middleware"
	"class-form/models"

	"github.com/gin-gonic/gin"
	"github.com/xuri/excelize/v2"
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

// ImportStudents 批量导入学生账号（xlsx）
// 表格格式：第一行为表头（跳过），A=学号, B=姓名, C=密码(可选，为空则用默认密码)
// 默认密码通过 query 参数 default_password 指定，未指定则为 "123456"
func ImportStudents(c *gin.Context) {
	file, _, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请上传 xlsx 文件"})
		return
	}
	defer file.Close()

	f, err := excelize.OpenReader(file)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无法解析 xlsx 文件"})
		return
	}
	defer f.Close()

	sheetName := f.GetSheetName(0)
	rows, err := f.GetRows(sheetName)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无法读取工作表"})
		return
	}
	if len(rows) < 2 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "文件无数据行"})
		return
	}

	defaultPwd := strings.TrimSpace(c.Query("default_password"))
	if defaultPwd == "" {
		defaultPwd = "123456"
	}
	if len(defaultPwd) < 6 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "默认密码至少6位"})
		return
	}

	// 预加载已存在的学号，避免逐行查询
	var existing []models.StudentUser
	models.DB.Find(&existing)
	existSet := make(map[string]bool, len(existing))
	for _, u := range existing {
		existSet[u.StudentNo] = true
	}

	type failRow struct {
		Row       int    `json:"row"`
		StudentNo string `json:"student_no"`
		Reason    string `json:"reason"`
	}

	created := 0
	skipped := 0
	var fails []failRow
	var skippedRows []failRow
	seen := make(map[string]bool)

	for i := 1; i < len(rows); i++ {
		row := rows[i]
		rowNum := i + 1

		// 跳过空行
		if len(row) == 0 {
			continue
		}
		studentNo := strings.TrimSpace(cellAt(row, 0))
		name := strings.TrimSpace(cellAt(row, 1))
		pwd := strings.TrimSpace(cellAt(row, 2))

		if studentNo == "" || name == "" {
			fails = append(fails, failRow{Row: rowNum, StudentNo: studentNo, Reason: "学号或姓名为空"})
			continue
		}
		if existSet[studentNo] || seen[studentNo] {
			skippedRows = append(skippedRows, failRow{Row: rowNum, StudentNo: studentNo, Reason: "学号已存在"})
			skipped++
			continue
		}
		if pwd == "" {
			pwd = defaultPwd
		}
		if len(pwd) < 6 {
			fails = append(fails, failRow{Row: rowNum, StudentNo: studentNo, Reason: "密码不足6位"})
			continue
		}

		hash, _ := bcrypt.GenerateFromPassword([]byte(pwd), bcrypt.DefaultCost)
		user := models.StudentUser{
			StudentNo:          studentNo,
			Name:               name,
			PasswordHash:       string(hash),
			MustChangePassword: true,
		}
		if err := models.DB.Create(&user).Error; err != nil {
			fails = append(fails, failRow{Row: rowNum, StudentNo: studentNo, Reason: fmt.Sprintf("写入失败: %v", err)})
			continue
		}
		existSet[studentNo] = true
		seen[studentNo] = true
		created++
	}

	c.JSON(http.StatusOK, gin.H{
		"created":       created,
		"skipped":       skipped,
		"failed":        len(fails),
		"errors":        fails,
		"skipped_rows":  skippedRows,
		"total":         len(rows) - 1,
	})
}

// cellAt 安全获取切片指定位置元素
func cellAt(row []string, idx int) string {
	if idx < len(row) {
		return row[idx]
	}
	return ""
}
