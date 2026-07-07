package handlers

import (
	"net/http"

	"class-form/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// ListTasks 获取任务列表（管理员）
func ListTasks(c *gin.Context) {
	var tasks []models.Task
	models.DB.Order("created_at desc").Find(&tasks)
	c.JSON(http.StatusOK, tasks)
}

// CreateTask 创建任务
func CreateTask(c *gin.Context) {
	var req struct {
		Title       string `json:"title" binding:"required"`
		Description string `json:"description"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "标题不能为空"})
		return
	}
	task := models.Task{Title: req.Title, Description: req.Description, Status: "open"}
	if err := models.DB.Create(&task).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
		return
	}
	c.JSON(http.StatusOK, task)
}

// UpdateTask 更新任务
func UpdateTask(c *gin.Context) {
	id := c.Param("id")
	var task models.Task
	if err := models.DB.First(&task, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "任务不存在"})
		return
	}
	var req struct {
		Title       *string `json:"title"`
		Description *string `json:"description"`
		Status      *string `json:"status"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	if req.Title != nil {
		task.Title = *req.Title
	}
	if req.Description != nil {
		task.Description = *req.Description
	}
	if req.Status != nil && (*req.Status == "open" || *req.Status == "closed") {
		task.Status = *req.Status
	}
	models.DB.Save(&task)
	c.JSON(http.StatusOK, task)
}

// DeleteTask 删除任务（事务级联删除：提交、字段、学生、任务本体）
func DeleteTask(c *gin.Context) {
	id := c.Param("id")
	err := models.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("task_id = ?", id).Delete(&models.Submission{}).Error; err != nil {
			return err
		}
		if err := tx.Where("task_id = ?", id).Delete(&models.FormField{}).Error; err != nil {
			return err
		}
		if err := tx.Where("task_id = ?", id).Delete(&models.Student{}).Error; err != nil {
			return err
		}
		if err := tx.Delete(&models.Task{}, id).Error; err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "删除失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "已删除"})
}

// GetTask 获取单个任务详情
func GetTask(c *gin.Context) {
	id := c.Param("id")
	var task models.Task
	if err := models.DB.First(&task, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "任务不存在"})
		return
	}
	c.JSON(http.StatusOK, task)
}
