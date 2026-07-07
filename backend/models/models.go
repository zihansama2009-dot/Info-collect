package models

import (
	"time"

	"gorm.io/gorm"
)

// DB 全局数据库实例
var DB *gorm.DB

// User 管理员账号
type User struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	Username     string    `gorm:"uniqueIndex;size:64;not null" json:"username"`
	PasswordHash string    `gorm:"size:255;not null" json:"-"`
	Role         string    `gorm:"size:32;default:admin" json:"role"`
	Version      string    `gorm:"size:64" json:"version"`
	CreatedAt    time.Time `json:"created_at"`
}

// Task 信息收集任务
type Task struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	Title       string    `gorm:"size:255;not null" json:"title"`
	Description string    `gorm:"size:1024" json:"description"`
	Status      string    `gorm:"size:32;default:open" json:"status"` // open / closed
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// Student 学生名单（按任务维度导入）
type Student struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	TaskID    uint      `gorm:"index;not null" json:"task_id"`
	StudentNo string    `gorm:"size:64;not null" json:"student_no"` // 学号
	Name      string    `gorm:"size:64;not null" json:"name"`
	Password  string    `gorm:"size:255;not null" json:"-"` // 统一分配的登录密码
	CreatedAt time.Time `json:"created_at"`
}

// StudentUser 全局学生账号（独立于任务）
type StudentUser struct {
	ID                 uint      `gorm:"primaryKey" json:"id"`
	StudentNo          string    `gorm:"uniqueIndex;size:64;not null" json:"student_no"`
	Name               string    `gorm:"size:64;not null" json:"name"`
	PasswordHash       string    `gorm:"size:255;not null" json:"-"`
	MustChangePassword bool      `gorm:"default:true" json:"must_change_password"`
	CreatedAt          time.Time `json:"created_at"`
	UpdatedAt          time.Time `json:"updated_at"`
}

// Group 学生组
type Group struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	Name        string    `gorm:"size:128;not null" json:"name"`
	Description string    `gorm:"size:255" json:"description"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// GroupMember 组与学生的多对多关联
type GroupMember struct {
	GroupID       uint `gorm:"uniqueIndex:idx_group_member" json:"group_id"`
	StudentUserID uint `gorm:"uniqueIndex:idx_group_member" json:"student_user_id"`
	CreatedAt     time.Time `json:"created_at"`
}

// TaskAssignment 任务与用户/组的关联（用户级）
type TaskAssignment struct {
	TaskID        uint `gorm:"uniqueIndex:idx_task_user" json:"task_id"`
	StudentUserID uint `gorm:"uniqueIndex:idx_task_user" json:"student_user_id"`
	CreatedAt     time.Time `json:"created_at"`
}

// TaskGroupAssignment 任务与组的关联（组级）
type TaskGroupAssignment struct {
	TaskID  uint `gorm:"uniqueIndex:idx_task_group" json:"task_id"`
	GroupID uint `gorm:"uniqueIndex:idx_task_group" json:"group_id"`
	CreatedAt time.Time `json:"created_at"`
}

// FormField 表单字段配置（双轨制：label 显示名 + export_header 导出列名）
type FormField struct {
	ID             uint   `gorm:"primaryKey" json:"id"`
	TaskID         uint   `gorm:"index;not null" json:"task_id"`
	Label          string `gorm:"size:255;not null" json:"label"`          // 学生看到的题目
	ExportHeader   string `gorm:"size:255" json:"export_header"`           // Excel 导出表头（为空则降级为 label）
	FieldType      string `gorm:"size:32;default:text" json:"field_type"`  // text / number / date / select
	IsRequired     bool   `gorm:"default:false" json:"is_required"`
	IsConfidential bool   `gorm:"default:false" json:"is_confidential"`    // 是否保密（学生再次编辑时脱敏）
	Options        string `gorm:"type:text" json:"options"`                // JSON 字符串，select 用
	SortOrder      int    `gorm:"default:0" json:"sort_order"`
	HasData        bool   `gorm:"-" json:"has_data"` // 临时标志：该字段是否已有提交数据（非数据库列）
}

// Submission 学生提交记录
type Submission struct {
	ID        uint      `gorm:"primaryKey" json:"id"`
	TaskID    uint      `gorm:"uniqueIndex:idx_task_student;not null" json:"task_id"`
	StudentID uint      `gorm:"uniqueIndex:idx_task_student;not null" json:"student_id"`
	Data      string    `gorm:"type:text" json:"data"` // JSON 字符串 {field_id: value}
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
