package handlers

import (
	"encoding/json"
	"time"

	"class-form/models"

	"github.com/gin-gonic/gin"
	"github.com/xuri/excelize/v2"
)

// ExportTaskData 流式导出指定任务的填报数据为 Excel（双轨制表头）
// 核心逻辑：导出表头优先使用 export_header，为空则降级使用 label
func ExportTaskData(c *gin.Context) {
	taskID := c.Param("id")

	// 1. 获取表单字段配置（包含 export_header）
	var fields []models.FormField
	models.DB.Where("task_id = ?", taskID).Order("sort_order asc").Find(&fields)

	// 2. 获取学生名单及提交数据
	var students []models.Student
	models.DB.Where("task_id = ?", taskID).Order("student_no asc").Find(&students)

	var subs []models.Submission
	models.DB.Where("task_id = ?", taskID).Find(&subs)
	subMap := make(map[uint]models.Submission, len(subs))
	for _, s := range subs {
		subMap[s.StudentID] = s
	}

	// 3. 创建 Excel 文件
	f := excelize.NewFile()
	defer f.Close()
	sheetName := "数据汇总"
	f.SetSheetName(f.GetSheetName(0), sheetName)

	// 4. 写入自定义表头（第一行）
	// 列 A=学号, B=姓名, C 起为各字段
	f.SetCellValue(sheetName, "A1", "学号")
	f.SetCellValue(sheetName, "B1", "姓名")

	col := 3 // 从第 3 列(C)开始
	for _, field := range fields {
		cell, _ := excelize.CoordinatesToCellName(col, 1)
		// 核心逻辑：优先使用 export_header，若为空则降级使用 label
		header := field.ExportHeader
		if header == "" {
			header = field.Label
		}
		f.SetCellValue(sheetName, cell, header)
		col++
	}

	// 5. 写入数据行（第二行开始）
	// 正确使用 CoordinatesToCellName 处理列号与行号，避免文档示例中
	// string(rune(row)) 在行号>9、列字母超过 'Z' 时的错误。
	for i, st := range students {
		row := i + 2
		cellA, _ := excelize.CoordinatesToCellName(1, row)
		cellB, _ := excelize.CoordinatesToCellName(2, row)
		f.SetCellValue(sheetName, cellA, st.StudentNo)
		f.SetCellValue(sheetName, cellB, st.Name)

		// 解析该学生的提交数据
		dataMap := map[string]interface{}{}
		if sub, ok := subMap[st.ID]; ok {
			_ = json.Unmarshal([]byte(sub.Data), &dataMap)
		}

		col = 3
		for _, field := range fields {
			cell, _ := excelize.CoordinatesToCellName(col, row)
			val, exists := dataMap[intToStr(int(field.ID))]
			if exists {
				f.SetCellValue(sheetName, cell, val)
			} else {
				f.SetCellValue(sheetName, cell, "")
			}
			col++
		}
	}

	// 6. 设置响应头，触发浏览器下载（流式输出到 HTTP 响应）
	fileName := time.Now().Format("20060102150405") + "_导出数据.xlsx"
	c.Header("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
	c.Header("Content-Disposition", "attachment; filename="+fileName)
	c.Header("Content-Transfer-Encoding", "binary")
	c.Header("Access-Control-Expose-Headers", "Content-Disposition")

	if _, err := f.WriteTo(c.Writer); err != nil {
		// 响应已开始写入，无法再返回 JSON，仅记录
		return
	}
}
