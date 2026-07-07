package handlers

import (
	"net/http"

	"class-form/models"

	"github.com/gin-gonic/gin"
)

// TaskStats 任务统计：总人数、已提交人数
func TaskStats(c *gin.Context) {
	taskID := c.Param("id")
	var total int64
	models.DB.Model(&models.Student{}).Where("task_id = ?", taskID).Count(&total)
	var submitted int64
	models.DB.Model(&models.Submission{}).Where("task_id = ?", taskID).Count(&submitted)
	c.JSON(http.StatusOK, gin.H{
		"total":     total,
		"submitted": submitted,
		"pending":   total - submitted,
	})
}
