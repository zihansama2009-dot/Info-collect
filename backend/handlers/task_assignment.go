package handlers

import (
	"net/http"

	"class-form/middleware"
	"class-form/models"

	"github.com/gin-gonic/gin"
)

// AssignUsersToTask 分配用户到任务
func AssignUsersToTask(c *gin.Context) {
	taskID := c.Param("id")
	var req struct {
		UserIDs []uint `json:"user_ids" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 清除旧分配
	models.DB.Where("task_id = ?", taskID).Delete(&models.TaskAssignment{})

	// 添加新分配
	for _, uid := range req.UserIDs {
		models.DB.Create(&models.TaskAssignment{TaskID: uintToInt(taskID), StudentUserID: uid})
	}
	c.JSON(http.StatusOK, gin.H{"message": "分配成功"})
}

// AssignGroupsToTask 分配组到任务
func AssignGroupsToTask(c *gin.Context) {
	taskID := c.Param("id")
	var req struct {
		GroupIDs []uint `json:"group_ids" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	models.DB.Where("task_id = ?", taskID).Delete(&models.TaskGroupAssignment{})

	for _, gid := range req.GroupIDs {
		models.DB.Create(&models.TaskGroupAssignment{TaskID: uintToInt(taskID), GroupID: gid})
	}
	c.JSON(http.StatusOK, gin.H{"message": "分配成功"})
}

// GetTaskAssignments 获取任务分配情况
func GetTaskAssignments(c *gin.Context) {
	taskID := c.Param("id")
	var userAssignments []models.TaskAssignment
	models.DB.Where("task_id = ?", taskID).Find(&userAssignments)

	var groupAssignments []models.TaskGroupAssignment
	models.DB.Where("task_id = ?", taskID).Find(&groupAssignments)

	c.JSON(http.StatusOK, gin.H{
		"users":  userAssignments,
		"groups": groupAssignments,
	})
}

// GetAvailableTasks 获取学生可用的任务列表
func GetAvailableTasks(c *gin.Context) {
	claims := c.MustGet("claims").(*middleware.Claims)
	userID := claims.StudentID

	// 直接分配给用户的任务
	var userTasks []models.Task
	models.DB.Joins("JOIN task_assignments ON tasks.id = task_assignments.task_id").
		Where("task_assignments.student_user_id = ?", userID).
		Find(&userTasks)

	// 通过组分配的任务
	var groupTasks []models.Task
	models.DB.Joins("JOIN task_group_assignments ON tasks.id = task_group_assignments.task_id").
		Joins("JOIN group_members ON task_group_assignments.group_id = group_members.group_id").
		Where("group_members.student_user_id = ?", userID).
		Find(&groupTasks)

	c.JSON(http.StatusOK, gin.H{
		"user_tasks":  userTasks,
		"group_tasks": groupTasks,
	})
}
