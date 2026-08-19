# 本地邮箱 Web 版

这是一个无需构建工具的静态 Web 客户端。因为品牌图标复用项目内 Android 资源，建议在项目根目录启动静态服务器：

```powershell
python -m http.server 43100
```

打开 <http://127.0.0.1:43100/web/>。

默认数据为演示账号和邮件，真实账号通过“添加账号”导入。浏览器版直接请求 Microsoft OAuth 和 Graph API，账号凭据会写入当前浏览器的 `localStorage`，仅适合个人设备使用。生产部署不应把 Refresh Token 放进公共网站。
