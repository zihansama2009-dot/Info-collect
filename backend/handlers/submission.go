package handlers

import (
	"encoding/json"
	"net/http"
	"time"

	"class-form/middleware"
	"class-form/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// GetMySubmission 学生获取自己的提交（如有）
// 保密字段脱敏：学生再次编辑时返回掩码 ******（管理员接口不受影响）
func GetMySubmission(c *gin.Context) {
	claims := c.MustGet("claims").(*middleware.Claims)
	var sub models.Submission
	err := models.DB.Where("task_id = ? AND student_id = ?", claims.TaskID, claims.StudentID).First(&sub).Error
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"data": nil})
		return
	}
	var data map[string]interface{}
	json.Unmarshal([]byte(sub.Data), &data)

	var fields []models.FormField
	models.DB.Where("task_id = ?", claims.TaskID).Find(&fields)
	for _, f := range fields {
		if f.IsConfidential {
			key := strconvUint(f.ID)
			if _, exists := data[key]; exists {
				data[key] = "******"
			}
		}
	}
	c.JSON(http.StatusOK, gin.H{"data": data, "updated_at": sub.UpdatedAt})
}

// SubmitForm 学生提交/更新表单
// 保密字段智能过滤：值为掩码 ****** 时保留数据库原值（仅学生方向）
func SubmitForm(c *gin.Context) {
	claims := c.MustGet("claims").(*middleware.Claims)

	var req map[string]interface{}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	// 校验必填字段
	var fields []models.FormField
	models.DB.Where("task_id = ?", claims.TaskID).Find(&fields)
	for _, f := range fields {
		if f.IsRequired {
			val, ok := req[strconvUint(f.ID)]
			if !ok || isEmpty(val) {
				c.JSON(http.StatusBadRequest, gin.H{"error": "「" + f.Label + "」为必填项"})
				return
			}
		}
	}

	// 事务内完成「查询→脱敏过滤→upsert」，避免并发重复提交
	err := models.DB.Transaction(func(tx *gorm.DB) error {
		var sub models.Submission
		findErr := tx.Where("task_id = ? AND student_id = ?", claims.TaskID, claims.StudentID).First(&sub).Error

		// 保密字段智能过滤：值为掩码 ****** 时保留原值
		if findErr == nil {
			var originalData map[string]interface{}
			json.Unmarshal([]byte(sub.Data), &originalData)
			for _, f := range fields {
				if !f.IsConfidential {
					continue
				}
				key := strconvUint(f.ID)
				if val, ok := req[key]; ok && val == "******" {
					if orig, has := originalData[key]; has {
						req[key] = orig
					} else {
						delete(req, key)
					}
				}
			}
		}

		dataBytes, _ := json.Marshal(req)
		dataStr := string(dataBytes)

		if findErr == nil {
			sub.Data = dataStr
			sub.UpdatedAt = time.Now()
			return tx.Save(&sub).Error
		}
		return tx.Create(&models.Submission{
			TaskID:    claims.TaskID,
			StudentID: claims.StudentID,
			Data:      dataStr,
		}).Error
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "提交失败，请重试"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "提交成功"})
}

// ListSubmissions 管理员查看任务的所有提交（含学生信息）
func ListSubmissions(c *gin.Context) {
	taskID := c.Param("id")
	var students []models.Student
	models.DB.Where("task_id = ?", taskID).Order("student_no asc").Find(&students)

	var subs []models.Submission
	models.DB.Where("task_id = ?", taskID).Find(&subs)

	subMap := make(map[uint]models.Submission, len(subs))
	for _, s := range subs {
		subMap[s.StudentID] = s
	}

	result := make([]gin.H, 0, len(students))
	for _, st := range students {
		var data interface{}
		if sub, ok := subMap[st.ID]; ok {
			var m interface{}
			json.Unmarshal([]byte(sub.Data), &m)
			data = m
			result = append(result, gin.H{
				"student":     st,
				"submitted":   true,
				"data":        data,
				"updated_at":  sub.UpdatedAt,
			})
		} else {
			result = append(result, gin.H{
				"student":    st,
				"submitted":  false,
				"data":       nil,
			})
		}
	}
	c.JSON(http.StatusOK, result)
}

// isEmpty 判断值是否为空
func isEmpty(v interface{}) bool {
	if v == nil {
		return true
	}
	switch val := v.(type) {
	case string:
		return val == ""
	default:
		return false
	}
}

// strconvUint 简单包装：field.ID 是 uint，直接转字符串
func strconvUint(id uint) string {
	return intToStr(int(id))
}

func intToStr(i int) string {
	if i == 0 {
		return "0"
	}
	neg := false
	if i < 0 {
		neg = true
		i = -i
	}
	var buf [20]byte
	pos := len(buf)
	for i > 0 {
		pos--
		buf[pos] = byte('0' + i%10)
		i /= 10
	}
	if neg {
		pos--
		buf[pos] = '-'
	}
	return string(buf[pos:])
}
