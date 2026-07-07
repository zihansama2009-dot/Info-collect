package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"class-form/models"

	"github.com/gin-gonic/gin"
	"github.com/xuri/excelize/v2"
	"gorm.io/gorm"
)

// ListStudents 获取任务的学生名单
func ListStudents(c *gin.Context) {
	taskID := c.Param("id")
	var students []models.Student
	models.DB.Where("task_id = ?", taskID).Order("student_no asc").Find(&students)
	c.JSON(http.StatusOK, students)
}

// ImportStudents 从上传的 Excel 导入学生名单
// Excel 表头需包含：学号、姓名、密码
func ImportStudents(c *gin.Context) {
	taskID := c.Param("id")
	file, _, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "请上传文件"})
		return
	}
	defer file.Close()

	f, err := excelize.OpenReader(file)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "无法读取 Excel 文件"})
		return
	}
	defer f.Close()

	rows, err := f.GetRows(f.GetSheetName(0))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "读取工作表失败"})
		return
	}
	if len(rows) < 2 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Excel 无有效数据行"})
		return
	}

	// 解析表头定位列索引
	header := rows[0]
	idxNo, idxName, idxPass := -1, -1, -1
	for i, h := range header {
		h = strings.TrimSpace(h)
		switch h {
		case "学号", "student_no":
			idxNo = i
		case "姓名", "name":
			idxName = i
		case "密码", "password":
			idxPass = i
		}
	}
	if idxNo < 0 || idxName < 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Excel 表头需包含「学号」和「姓名」列"})
		return
	}

	tid := parseUint(taskID)
	count := 0
	err = models.DB.Transaction(func(tx *gorm.DB) error {
		// 先清空旧名单及对应提交
		if err := tx.Where("task_id = ?", tid).Delete(&models.Student{}).Error; err != nil {
			return err
		}
		if err := tx.Where("task_id = ?", tid).Delete(&models.Submission{}).Error; err != nil {
			return err
		}
		for i := 1; i < len(rows); i++ {
			row := rows[i]
			if idxNo >= len(row) || idxName >= len(row) {
				continue
			}
			no := strings.TrimSpace(row[idxNo])
			name := strings.TrimSpace(row[idxName])
			if no == "" || name == "" {
				continue
			}
			pass := "123456" // 默认密码
			if idxPass >= 0 && idxPass < len(row) && strings.TrimSpace(row[idxPass]) != "" {
				pass = strings.TrimSpace(row[idxPass])
			}
			if err := tx.Create(&models.Student{
				TaskID:    tid,
				StudentNo: no,
				Name:      name,
				Password:  pass,
			}).Error; err != nil {
				return err
			}
			count++
		}
		return nil
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "导入失败: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "导入成功", "count": count})
}

// ResetStudentPassword 重置单个学生密码
func ResetStudentPassword(c *gin.Context) {
	id := c.Param("sid")
	var req struct {
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}
	models.DB.Model(&models.Student{}).Where("id = ?", id).Update("password", req.Password)
	c.JSON(http.StatusOK, gin.H{"message": "已重置"})
}

// DeleteStudent 删除学生（事务级联删除提交记录）
func DeleteStudent(c *gin.Context) {
	id := c.Param("sid")
	err := models.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("student_id = ?", id).Delete(&models.Submission{}).Error; err != nil {
			return err
		}
		if err := tx.Delete(&models.Student{}, id).Error; err != nil {
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

// parseUint 字符串转 uint
func parseUint(s string) uint {
	n, _ := strconv.ParseUint(s, 10, 64)
	return uint(n)
}

// defaultStr 字符串为空时返回默认值
func defaultStr(s, def string) string {
	if s == "" {
		return def
	}
	return s
}
