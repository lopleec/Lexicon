[README_en](https://github.com/lopleec/Lexicon/blob/main/README.md)

# Lexicon

Lexicon 是一款采用 Swift + SwiftUI 构建的现代 macOS AI 客户端。

## 功能特性

- 多会话聊天管理
  - 创建 / 切换 / 重命名 / 删除会话
  - 会话历史记录本地持久化
- 可折叠/展开的左侧边栏
- 独立的设置窗口（所有连接/模型/生成相关配置均已移出主聊天界面）
- 多级设置导航
  - 按工作区 / 模型 / 生成分组
  - 应用内语言切换（位于设置界面内）
- 多服务提供商管理
  - 添加 / 切换 / 移除服务提供商
  - 每个服务提供商拥有独立的 API 类型 / API 密钥 / 基础URL / 模型
- 模型预设管理
  - 将当前模型保存为预设
  - 添加 / 删除 / 应用预设
- 文本 + 图片输入（支持多图选择）
- 回车发送消息
  - `Return` 发送消息
  - `Shift + Return` 换行
  - 兼容中文输入法状态（输入法组合时不会误发送）
- 支持两种 OpenAI 端点形式：
  - Chat Completions (`/v1/chat/completions`)
  - Responses (`/v1/responses`)
- 可自定义 `baseURL`（兼容直连 OpenAI 及 OpenAI 兼容代理）
- 可配置项：
  - API 密钥
  - 模型
  - 系统提示词
  - 上下文开关
  - 温度
  - Top P
  - 流式输出开关
- 聊天界面流式输出渲染
- 助手输出支持 Markdown 渲染
- 代码块渲染支持轻度语法高亮
- 代码块一键复制按钮
- 界面文案支持中文
- 标准 i18n 本地化（基于 `Localizable.strings`）
  - 包含 `en` 与 `zh-Hans`
  - 自动跟随 macOS/应用语言偏好切换
  - 应用内语言切换：跟随系统 / 简体中文 / 英语
- 自动跟随系统浅色/深色主题（橙色强调色、圆角风格）

## 项目路径

`<项目根目录>/Lexicon`

## 运行方法

1. 在 Xcode 中打开 `Lexicon.xcodeproj`。
2. 选择 `Lexicon` 方案。
3. 在 `My Mac` 上运行。

## 注意事项

- `baseURL` 可输入：
  - `https://api.openai.com`
  - `https://api.openai.com/v1`
  - `https://api.openai.com/v1/responses`
  - 自定义代理域名
- 端点解析会根据所选 API 类型自动进行标准化处理。
