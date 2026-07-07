package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

// JWT 签名密钥（生产环境应通过环境变量注入）
var JWTSecret = []byte("class-form-secret-key-change-me")

// Claims 自定义 JWT 声明
type Claims struct {
	UserID   uint   `json:"user_id"`
	Username string `json:"username"`
	Role     string `json:"role"` // admin / student
	TaskID   uint   `json:"task_id,omitempty"`
	StudentID uint  `json:"student_id,omitempty"`
	jwt.RegisteredClaims
}

// GenerateToken 生成 JWT
func GenerateToken(claims Claims) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString(JWTSecret)
}

// ParseToken 解析 JWT
func ParseToken(tokenStr string) (*Claims, error) {
	claims := &Claims{}
	_, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (interface{}, error) {
		return JWTSecret, nil
	})
	return claims, err
}

// AuthRequired 通用认证中间件
//
// 支持两种 token 传递方式：
//  1. 标准 Authorization: Bearer <token> 头（axios/dio 等 XHR 请求）
//  2. ?token=<token> 查询参数（浏览器 <a> 标签下载文件，无法自定义请求头）
func AuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		var tokenStr string
		auth := c.GetHeader("Authorization")
		if auth != "" {
			tokenStr = strings.TrimPrefix(auth, "Bearer ")
		} else if q := c.Query("token"); q != "" {
			// 浏览器原生下载（如 Excel 导出）无法设置请求头，回退到查询参数
			tokenStr = q
		}
		if tokenStr == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "未登录"})
			return
		}
		claims, err := ParseToken(tokenStr)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "登录已过期"})
			return
		}
		c.Set("claims", claims)
		c.Next()
	}
}

// AdminRequired 管理员权限校验
func AdminRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		claims, ok := c.Get("claims")
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "未登录"})
			return
		}
		if claims.(*Claims).Role != "admin" {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "无权限"})
			return
		}
		c.Next()
	}
}
