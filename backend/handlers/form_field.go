package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sort"
	"strconv"

	"class-form/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// ListFormFields 获取任务的表单字段（含 has_data 标志，供前端禁用删除按钮）
func ListFormFields(c *gin.Context) {
	taskID := c.Param("id")
	tid := parseUint(taskID)
	c.JSON(http.StatusOK, withHasData(models.DB, tid))
}

// SaveFormFields 批量保存表单字段（diff 增量更新，保稳定 ID）
//   - 请求中带 ID 的字段 → 更新（有提交数据时禁止改类型）
//   - 请求中不带 ID 的字段 → 新建
//   - 现有但不在请求中的字段 → 删除（有提交数据时拒绝）
func SaveFormFields(c *gin.Context) {
	taskID := c.Param("id")
	tid := parseUint(taskID)

	var req []struct {
		ID             uint   `json:"id"`
		Label          string `json:"label" binding:"required"`
		ExportHeader   string `json:"export_header"`
		FieldType      string `json:"field_type"`
		IsRequired     bool   `json:"is_required"`
		IsConfidential bool   `json:"is_confidential"`
		Options        string `json:"options"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "参数错误"})
		return
	}

	err := models.DB.Transaction(func(tx *gorm.DB) error {
		// 1. 加载现有字段
		var existing []models.FormField
		if err := tx.Where("task_id = ?", tid).Find(&existing).Error; err != nil {
			return err
		}
		existingMap := make(map[uint]models.FormField, len(existing))
		for _, f := range existing {
			existingMap[f.ID] = f
		}

		// 2. 计算有提交数据的字段 ID 集合
		usedIDs, err := usedFieldIDs(tx, tid)
		if err != nil {
			return err
		}

		// 3. 请求中出现的 ID 集合
		reqIDs := make(map[uint]bool, len(req))
		for _, f := range req {
			if f.ID != 0 {
				reqIDs[f.ID] = true
			}
		}

		// 4. 删除：现有但不在请求中的字段（有数据则拒绝）
		for id, f := range existingMap {
			if reqIDs[id] {
				continue
			}
			if usedIDs[id] {
				return fmt.Errorf("字段「%s」已有学生填报数据，无法删除", f.Label)
			}
			if err := tx.Delete(&models.FormField{}, id).Error; err != nil {
				return err
			}
		}

		// 5. 更新或创建
		for i, f := range req {
			ftype := defaultStr(f.FieldType, "text")
			opts := f.Options
			if ftype != "select" {
				opts = ""
			}
			if f.ID == 0 {
				field := models.FormField{
					TaskID:         tid,
					Label:          f.Label,
					ExportHeader:   f.ExportHeader,
					FieldType:      ftype,
					IsRequired:     f.IsRequired,
					IsConfidential: f.IsConfidential,
					Options:        opts,
					SortOrder:      i,
				}
				if err := tx.Create(&field).Error; err != nil {
					return err
				}
			} else {
				old, ok := existingMap[f.ID]
				if !ok {
					return fmt.Errorf("字段 ID %d 不存在", f.ID)
				}
				if usedIDs[f.ID] && old.FieldType != ftype {
					return fmt.Errorf("字段「%s」已有填报数据，无法修改类型", old.Label)
				}
				old.Label = f.Label
				old.ExportHeader = f.ExportHeader
				old.FieldType = ftype
				old.IsRequired = f.IsRequired
				old.IsConfidential = f.IsConfidential
				old.Options = opts
				old.SortOrder = i
				if err := tx.Save(&old).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, withHasData(models.DB, tid))
}

// usedFieldIDs 返回某任务下所有 Submission.Data 中出现过的字段 ID 集合
func usedFieldIDs(db *gorm.DB, tid uint) (map[uint]bool, error) {
	var subs []models.Submission
	if err := db.Where("task_id = ?", tid).Find(&subs).Error; err != nil {
		return nil, err
	}
	used := make(map[uint]bool)
	for _, s := range subs {
		var data map[string]interface{}
		if json.Unmarshal([]byte(s.Data), &data) == nil {
			for k := range data {
				if id, perr := strconv.ParseUint(k, 10, 64); perr == nil {
					used[uint(id)] = true
				}
			}
		}
	}
	return used, nil
}

// withHasData 查询字段列表并填充 HasData 临时标志
func withHasData(db *gorm.DB, tid uint) []models.FormField {
	var fields []models.FormField
	db.Where("task_id = ?", tid).Order("sort_order asc").Find(&fields)
	usedIDs, _ := usedFieldIDs(db, tid)
	for i := range fields {
		fields[i].HasData = usedIDs[fields[i].ID]
	}
	return fields
}

// GetFormConfig 学生端获取任务表单配置（含任务信息）
func GetFormConfig(c *gin.Context) {
	taskID := c.Param("id")
	var task models.Task
	if err := models.DB.First(&task, taskID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "任务不存在"})
		return
	}
	var fields []models.FormField
	models.DB.Where("task_id = ?", taskID).Order("sort_order asc").Find(&fields)
	sort.SliceStable(fields, func(i, j int) bool {
		return fields[i].SortOrder < fields[j].SortOrder
	})
	c.JSON(http.StatusOK, gin.H{"task": task, "fields": fields})
}
