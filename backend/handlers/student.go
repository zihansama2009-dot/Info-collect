package handlers

import (
	"strconv"
)

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
