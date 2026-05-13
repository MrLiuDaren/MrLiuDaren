---
name: ppt-full-pipeline
description: "Complete 8-Agent PPT generation Agent. Converts documents (DOCX/PDF/Excel) to professional PPTX with image planning. Bundled with 3+ PPT templates, v0.1 prompt, and setup scripts. Self-contained installable package."
version: 2.0.0
metadata:
  hermes:
    tags: [ppt, pipeline, agent, government, multi-agent]
    category: productivity
    requires_toolsets: [terminal, file, browser, web]
---

# PPT Full Pipeline · 完整 Agent

端到端 PPT 生成 Agent。输入公文材料，输出专业政务/咨询风 PPTX。

## 安装

```bash
cp -r ppt-full-pipeline ~/AppData/Local/hermes/skills/productivity/
# 重启 Hermes 即可
```

详细安装见 [`references/install.md`](references/install.md)。

---

## 八 Agent 流水线

```
 Agent 1       Agent 2        Agent 2.5       Agent 3         Agent 4
 需求理解  →   文案创作   →   模板选择   →   提示词细化  →   PPT生成
 (Hermes)     (v0.1提示词)    (模板库匹配)    (PPT-Pro)      (PPT-Master)

 Agent 5       Agent 6        Agent 7
 配图规划  →   搜图生图   →   组装定稿
 (Hermes)     (Browser+DALL-E) (pptxgenjs)
```

**三个确认关卡**：Agent 2（文案）→ Agent 2.5（模板）→ Agent 5（配图）→ Agent 7（终稿）

---

## Agent 1：需求理解

**执行者**：Hermes
**输入**：用户指令 + 源文件路径
**动作**：
1. 读取源文件（DOCX/PDF/Excel），提取全文一二级标题结构
2. 确定本章节页码范围
3. 从 memory 读取项目规范：配色、字体、编号

---

## Agent 2：文案创作（关卡 1）

**执行者**：v0.1 提示词
**输入**：Agent 1 的章节结构 + 公文原文
**提示词**：加载 `prompts/v0.1-prompt.md`
**输出**：逐页文案包（概括 + 卡片条目 + 注释 + 配图提示词）
**关卡**：⚠️ 必须用户确认

---

## Agent 2.5：模板选择（关卡 2）

**执行者**：Hermes + 用户
**输入**：Agent 2 的文案 + 模板库
**模板库**（已内置在 `templates/` 目录）：

| 模板 | 路径 | 风格 | 适用 |
|------|------|------|------|
| 顶级政务风 | `templates/gov-blue/` | 深蓝渐变+平行四边形+卡片 | 政府工作汇报 |
| 顶级咨询风 | `templates/consulting-blue/` | MBB咨询风+图表+卡片 | 规划方案/调研报告 |
| 红金政务风 | `templates/gov-red/` | 红底金点缀+思源字体 | 老干部/党委汇报 |

**动作**：
1. 根据文案内容推荐模板
2. 列出候选模板关键参数（配色/字体/布局模式）
3. 加载模板的 `design_spec.md` 提取设计规范
**关卡**：⚠️ 用户确认模板选择

---

## Agent 3：提示词细化

**执行者**：PPT-Pro（加载 `ppt-pro` skill）
**输入**：Agent 2 文案 + Agent 2.5 模板 design_spec
**动作**：将每页文案转为 ppt-master SVG 生成指令，嵌入模板配色/字体/布局模式

---

## Agent 4：PPT 生成

**执行者**：PPT-Master
**输入**：Agent 3 的 SVG 指令
**命令**：
```bash
cd ppt-master/
python skills/ppt-master/scripts/finalize_svg.py <project>
python skills/ppt-master/scripts/svg_to_pptx.py <project>
```
**输出**：初稿 PPTX

---

## Agent 5：配图规划（关卡 3）

**执行者**：Hermes
**输入**：初稿 PPTX + Agent 2 配图提示词
**动作**：
1. 逐页审查配图需求，按类型分流：
   - 意向照片/底图 → cn.bing.com 搜真实图
   - 结构图 → DALL-E（api.apiyi.com/v1）
   - 数据图表 → matplotlib
2. 输出配图清单表
**关卡**：⚠️ 必须用户确认
**铁律**：封面底图/实景照片禁止 AI 生成

---

## Agent 6：搜图生图

**执行者**：Browser + DALL-E + matplotlib
**输入**：Agent 5 配图清单
**动作**：
1. `browser_navigate` → cn.bing.com 搜索"重庆 + 关键词"
2. DALL-E：`image_gen.py --backend openai --model gpt-image-2`
3. matplotlib：从 Excel 生成 PNG（dpi=180）

---

## Agent 7：组装定稿（关卡 4）

**执行者**：pptxgenjs / python-pptx
**输入**：初稿 PPTX + 配图文件
**动作**：嵌入图片 → 调整尺寸 → 校验 → 输出终稿
**关卡**：⚠️ 用户最终确认

---

## 关键约束

| 约束 | 说明 |
|------|------|
| 文案 | 严格从原文提取，不增不减 |
| 标题 | 每个一二标题必须对应PPT页面 |
| 卡片递进 | 上页卡片要点 = 下页概括总起 |
| 封面底图 | 必须搜索真实照片，禁止AI生成 |
| 搜图 | 关键词必须带"重庆" |
| 关卡 | 四处用户确认不可跳过 |

---

## 依赖

- **ppt-master**：`git clone https://github.com/hugohe3/ppt-master.git`（需单独克隆）
- **Node.js**：pptxgenjs, playwright, sharp
- **Python**：python-pptx, matplotlib, pymupdf
- **API**：api.apiyi.com/v1（图片生成）, 高德地图（可选）

## 模板制作

要添加新模板，在 `templates/<name>/` 下放 `design_spec.md` + `svg/*.svg`。
Agent 2.5 会自动扫描 `templates/` 目录发现新模板。
