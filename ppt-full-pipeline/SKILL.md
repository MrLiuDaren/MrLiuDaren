---
name: ppt-full-pipeline
description: "Complete 8-Agent PPT generation Agent. Converts documents (DOCX/PDF/Excel) to professional PPTX with image planning. Bundled with 3+ PPT templates, v0.1 prompt, and setup scripts. Self-contained installable package."
version: 2.1.0
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

 Agent 5       Agent 6                       Agent 7
 配图规划  →   搜图生图+视觉验证   →   组装定稿+完成确认
 (Hermes)     (DuckDuckGo+Vision+DALL-E)    (python-pptx)
```

**四个确认关卡**：Agent 2（文案）→ Agent 2.5（模板）→ Agent 5（配图）→ Agent 7（终稿）

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

## Agent 3：提示词细化（含图片占位——关键）

**执行者**：PPT-Pro（加载 `ppt-pro` skill）
**输入**：Agent 2 文案 + Agent 2.5 模板 design_spec
**动作**：
1. 将每页文案转为 ppt-master SVG 生成指令，嵌入模板配色/字体/布局模式
2. **图片占位（必须）**：读 Agent 2 的 `【配图】` 标签，按以下规则在 SVG 中预留空间：

| 配图类型 | SVG 做法 | Agent 7 填图方式 |
|----------|----------|-----------------|
| **全幅背景**（封面/章节/封底） | 叠加层降低不透明度：`stop-opacity` 从 `0.92` → `0.70`，在叠加层下方放一个 `<rect>` 占位标注 `"背景图位"` | 找到占位 `<rect>` 的坐标 → 删除 → `add_picture(0, 0, 13.33)` |
| **侧栏插图**（左/右） | 文字卡片收窄到 `width="560"`，另一侧放虚线框 `<rect stroke-dasharray="6" fill="none" stroke="#94A3B8"/>` 标注 `"图片位"` | 读取虚线框的 x,y,w,h → 删除 → `add_picture(x, y, w)` |
| **数据图表** | `<rect>` 占位 + `"【matplotlib生成】"` 文字 | 同上替换 |
| **无配图** | 全宽 1160px 卡片，不预留 | — |

**SVG 生成参数调整**：
- 封面深蓝渐变：第2个 `<stop stop-opacity>` 从 `0.95` → `0.65`
- 章节页：`<rect fill="url(#secGrad)">` 保持原值，不加额外 opacity
- 内容页卡片宽度：有侧图 → `width="560"`（左栏）或 `width="580"`（右栏），无图 → `width="1160"`
- 封底渐变：同封面，`stop-opacity` 降到 `0.65`

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
**输出**：初稿 PPTX（含图片占位）

---

## Agent 5：配图规划（关卡 3）

**执行者**：Hermes
**输入**：初稿 PPTX + Agent 2 配图提示词
**动作**：
1. 逐页审查配图需求，按类型分流：
   - 意向照片/底图 → cn.bing.com 搜真实图（首选），不可用时备选 DuckDuckGo
   - 结构图 → DALL-E（api.apiyi.com/v1）
   - 数据图表 → matplotlib
2. 输出配图清单表
**关卡**：⚠️ 必须用户确认
**铁律**：封面底图/实景照片禁止 AI 生成

---

## Agent 6：搜图生图 + 视觉验证

**执行者**：terminal(curl) + vision model + DALL-E + matplotlib
**输入**：Agent 5 配图清单

### 6a. 实景照片搜索

**首选 cn.bing.com**（无频率限制，中文匹配好）：

```bash
# browser_navigate 搜索"重庆 + 关键词"
# browser_get_images 获取 URL
# curl -x proxy 下载
```

**备选 DuckDuckGo**（cn.bing 不可用时。注意：ddgs 是免费网页抓取，无限流限制，不是付费 API。报"额度用完"说明短时间内请求太多，换 IP 或等几分钟即可）：

```bash
pip install ddgs -q
python -c "
from ddgs import DDGS
with DDGS() as d: print(list(d.images('Chongqing Hongyadong night', max_results=5)))
"
```

### 6b. 下载 + 视觉验证（强制关卡——每张必验）

1. `curl -x http://127.0.0.1:7890` 逐张下载
2. `file *.jpg` 验证是 JPEG 非 HTML
3. **vision_analyze 逐张验证**：`"这是重庆XX场景吗？与<页面主题>相关吗？"`
4. 标记：✅ 相关 → 重命名为 `PXX_描述.jpg` / ❌ 不相关 → 删除，换备选 URL 重搜

**铁律**：禁止跳过视觉验证。曾实测 Unsplash 直链返回故宫/西班牙别墅/新加坡鱼尾狮，完全不是重庆。

### 6c. AI 结构图

```bash
python image_gen.py "prompt" --backend openai --model gpt-image-2 --aspect_ratio 16:9 -o images/ -f PXX
```
**必须串行调用**——并行触发 429 rate limit。

### 6d. 手绘 SVG 结构图（方案 B）

AI API 限流时的备选。直接写 SVG（四象限/时间轴/流程图/齿轮图），视觉同效且无 API 依赖。

### 6e. 数据图表

```bash
python -c "
import matplotlib.pyplot as plt
# ... 从 Excel 读取数据 ...
plt.savefig('images/PXX_chart.png', dpi=180, bbox_inches='tight')
"
```

---

## Agent 7：组装定稿 + 完成确认（关卡 4）

**执行者**：python-pptx
**输入**：Agent 4 初稿 PPTX + Agent 6 验证通过的配图文件

### 7a. 生成 PPTX
```bash
cd ppt-master/
python skills/ppt-master/scripts/finalize_svg.py <project>
python skills/ppt-master/scripts/svg_to_pptx.py <project>
```

### 7b. 嵌入图片
用 python-pptx 的 `slide.shapes.add_picture()` 嵌入，填入 Agent 3 预留的位置：

- **全幅背景页**：`add_picture(0, 0, Inches(13.33))` + 调整图片置于底层
- **侧栏插图页**：读虚线占位框坐标 → `add_picture(x, y, Inches(w/72), Inches(h/72))`
- **数据图表页**：同上替换

### 7c. 完成确认（强制）
**Agent 7 完成后必须输出以下三条**：
1. **文件路径**：终稿 PPTX 的完整绝对路径
2. **配图验证清单**：每页配图来源 + 视觉验证结果（✅/❌）
3. **完成消息**：明确告诉用户"已完成"

---

## 关键约束

| 约束 | 说明 |
|------|------|
| 文案 | 严格从原文提取，不增不减 |
| 标题 | 每个一二标题必须对应 PPT 页面 |
| 卡片递进 | 上页卡片要点 = 下页概括总起 |
| 配图 | 只给内容相关的页配图，不对应的宁可留白 |
| 封面底图 | 必须搜索真实照片，禁止 AI 生成 |
| 关卡 | 四个用户确认点不可跳过 |

---

## 已知陷阱

| 陷阱 | 现象 | 对策 |
|------|------|------|
| `browser_navigate` + 中文 URL | `'utf-8' codec can't decode byte 0xb2` | 用 `curl -x proxy` 下载；中文搜索用 DuckDuckGo |
| Unsplash URL 图不对题 | 视觉验证出故宫/西班牙/新加坡而非重庆 | 视觉模型逐张验证后再用；不可跳过 |
| `read_file`→`write_file` 编辑 SVG | XML 损坏（行号前缀污染） | 用 Python `open()` 直接读写文件 |
| AI 生图并行调用 | 429 rate limit | 必须串行调用 |
| 图片嵌入报 PIL 错误 | `UnidentifiedImageError` | `file *.jpg` 验证；损坏文件换有效源 |
| API key 截断/失效 | 401 无效令牌 | 用 `memory replace` 更新完整 key |

---

## 依赖

- **ppt-master**：`git clone https://github.com/hugohe3/ppt-master.git`（需单独克隆）
- **Python**：python-pptx, matplotlib, pymupdf, duckduckgo-search
- **API**：api.apiyi.com/v1（图片生成）, 高德地图（可选）

## 模板制作

要添加新模板，在 `templates/<name>/` 下放 `design_spec.md` + `svg/*.svg`。
Agent 2.5 会自动扫描 `templates/` 目录发现新模板。
