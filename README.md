# 本地邮箱

一个仅在 Android 本机运行的 Outlook 邮件客户端。应用直接通过 Microsoft OAuth 与 Microsoft Graph 通信，不需要自建服务器，也不会把账号或邮件转发给第三方服务。

> 当前版本面向个人自用场景，仅构建 `arm64-v8a` 安装包。

## 功能

- 批量导入 Outlook 账号，自动验证并按收藏、成功、全部、失败筛选
- 重复邮箱重新导入时覆盖旧记录
- 应用前台轮询成功账号，并缓存邮件列表与正文
- 查看收件箱、垃圾邮件、草稿、已发送和已删除邮件
- 邮件详情默认展示纯文本，可左右滑动切换安全过滤后的 HTML 邮件
- 邮件自动标记已读，支持批量全选、已读和删除
- 邮箱与邮件均支持长按多选
- 导出全部、成功或失败账号，也可导出选中的账号
- 账号、Refresh Token 与邮件缓存使用 Android 安全存储保存在本机

## 安装

从 GitHub Releases 下载最新的 `app-arm64-v8a-release.apk`，在 64 位 ARM Android 设备上安装。

升级时直接覆盖安装即可。请勿清除应用数据，否则本地账号和邮件缓存会一并删除。

## 导入格式

每行一个账号，字段使用四个连字符 `----` 分隔：

```text
email----password----client_id----refresh_token
```

也兼容 `client_id` 与 `refresh_token` 位置互换的历史格式。导入时应用会使用 Client ID 和 Refresh Token 向 Microsoft 换取访问令牌；密码仅随账号记录保存在本机并用于原样导出，不参与登录请求。

所用 Microsoft 应用需要具备相应的 Graph 委托权限：

- `Mail.Read`
- `Mail.ReadWrite`（标记已读和删除邮件需要）
- `offline_access`

## 数据与隐私

- 无应用服务器：请求只在设备与 Microsoft 登录服务、Microsoft Graph 之间发生。
- 本地存储：账号凭据和邮件缓存由 `flutter_secure_storage` 保存。
- HTML 隔离：HTML 正文先过滤标签、属性和 URL，再交给 WebView 渲染。
- 删除操作：删除邮件会调用 Microsoft Graph，影响服务器上的真实邮箱数据。
- 导出风险：导出文本包含账号原始字段，请妥善保管，不要上传到网盘或公开 Issue。

## 从源码构建

环境要求：Flutter 3.44 或更高版本、Dart 3.12 或更高版本、Android SDK 与 Java 17。

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

产物位于 `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。

## 技术栈

Flutter / Dart、Microsoft Graph API、OAuth 2.0 Refresh Token、Dio、flutter_secure_storage、webview_flutter、html、share_plus。

## Web 版

仓库内的 `web/` 是无需构建工具的浏览器版工作区，支持演示数据、账号导入、邮箱筛选、邮件搜索、正文切换、已读、删除、收藏、导出和浏览器本地缓存。启动方式：

```powershell
python -m http.server 43100
```

然后打开 <http://127.0.0.1:43100/web/>。浏览器版会直接请求 Microsoft OAuth 和 Graph API，Refresh Token 仅适合保存在个人设备，不建议部署到公共网站。

## 声明

本项目是非官方个人工具，与 Microsoft、Crypton Future Media 或初音未来官方无隶属、合作或授权关系。项目中的角色主题图标仅用于个人非商业展示；公开分发或商业使用前，请自行确认素材授权。

请只导入你本人拥有或已获明确授权访问的邮箱账号。
