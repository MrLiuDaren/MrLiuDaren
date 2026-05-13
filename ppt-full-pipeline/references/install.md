# 安装指南

## 前提条件

1. **Hermes Agent** 已安装运行
2. **Node.js** >= 18（pptxgenjs 需要）
3. **Python** >= 3.10（matplotlib / python-pptx）
4. **Git** 可用

## 安装步骤

### 1. 克隆 ppt-master

```bash
git clone https://github.com/hugohe3/ppt-master.git
cd ppt-master
npm install pptxgenjs playwright sharp
npx playwright install chromium
```

Windows 用户注意：html2pptx.js 需要修复路径 bug，详见 ppt-pro skill。

### 2. 安装 Python 依赖

```bash
pip install python-pptx matplotlib pymupdf markitdown
```

### 3. 安装 Agent

将此目录复制到 Hermes skills 目录：

```bash
cp -r ppt-full-pipeline ~/AppData/Local/hermes/skills/productivity/
```

重启 Hermes，Agent 自动发现。

### 4. 配置 API Key（图片生成）

```bash
export OPENAI_API_KEY="sk-xxx"
export OPENAI_BASE_URL="https://api.apiyi.com/v1"
export AMAP_API_KEY="xxx"  # 高德地图（可选）
```

## 验证

在 Hermes 中发送：
```
用 ppt-full-pipeline 生成 PPT
```

如果加载了 SKILL.md 并列出 8 个 Agent 步骤，安装成功。

## 目录结构

```
ppt-full-pipeline/
├── SKILL.md              ← Agent 主定义
├── templates/            ← 3套PPT模板（SVG + design_spec）
│   ├── gov-blue/         ← 顶级政务风（深蓝渐变）
│   ├── consulting-blue/  ← 顶级咨询风（MBB级）
│   └── gov-red/          ← 红金政务风（老干部汇报）
├── prompts/              ← 提示词库
│   └── v0.1-prompt.md    ← PPT文案架构师
├── references/           ← 本文档
└── scripts/              ← 辅助脚本
    └── setup.sh          ← 一键初始化
```
