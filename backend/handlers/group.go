package handlers

import (
	"net/http"

	"class-form/models"

	"github.com/gin-gonic/gin"
)

// CreateGroup 创建组
func CreateGroup(c *gin.Context) {
	var req struct {
		Name        string `json:"name" binding:"required"`
		Description string `json:"description"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	group := models.Group{Name: req.Name, Description: req.Description}
	if err := models.DB.Create(&group).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "创建失败"})
		return
	}
	c.JSON(http.StatusOK, group)
}

// ListGroups 获取组列表
func ListGroups(c *gin.Context) {
	var groups []models.Group
	models.DB.Order("created_at desc").Find(&groups)
	c.JSON(http.StatusOK, groups)
}

// UpdateGroup 更新组
func UpdateGroup(c *gin.Context) {
	id := c.Param("id")
	var group models.Group
	if err := models.DB.First(&group, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "组不存在"})
		return
	}
	var req struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	if req.Name != "" {
		group.Name = req.Name
	}
	group.Description = req.Description
	models.DB.Save(&group)
	c.JSON(http.StatusOK, group)
}

// DeleteGroup 删除组
func DeleteGroup(c *gin.Context) {
	id := c.Param("id")
	if err := models.DB.Delete(&models.Group{}, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "组不存在"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "已删除"})
}

// AddGroupMember 添加组成员
func AddGroupMember(c *gin.Context) {
	groupID := c.Param("id")
	var req struct {
		StudentUserID uint `json:"student_user_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	member := models.GroupMember{GroupID: uintToInt(groupID), StudentUserID: req.StudentUserID}
	if err := models.DB.Create(&member).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "添加失败，可能已存在"})
		return
	}
	c.JSON(http.StatusOK, member)
}

// RemoveGroupMember 移除组成员
func RemoveGroupMember(c *gin.Context) {
	groupID := c.Param("id")
	userID := c.Param("user_id")
	if err := models.DB.Where("group_id = ? AND student_user_id = ?", groupID, userID).Delete(&models.GroupMember{}).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "成员不存在"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "已移除"})
}

// ListGroupMembers 获取组成员列表
func ListGroupMembers(c *gin.Context) {
	groupID := c.Param("id")
	var members []models.GroupMember
	models.DB.Where("group_id = ?", groupID).Find(&members)
	c.JSON(http.StatusOK, members)
}

func uintToInt(s string) uint {
	// simple conversion for route param
	var n uint
	for _, c := range s {
		n = n*10 + uint(c-'0')
	}
	return n
}
