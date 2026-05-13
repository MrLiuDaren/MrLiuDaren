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

**执行者**：terminal(curl) + vision model + DALL-E + matplotlib
**输入**：Agent 5 配图清单

### 6a. 实景照片搜索

首选 DuckDuckGo（中文搜索稳定），不用 Unsplash（ID 不对应内容）：

```bash
pip install duckduckgo-search -q
python -c "
from duckduckgo_search import DDGS
with DDGS() as d: print(list(d.images('Chongqing Hongyadong night', max_results=5)))
"
```

## Agent 6b：下载 + 视觉验证（强制关卡——每张必验）

**执行者**：terminal + visual model
**输入**：Agent 6a 搜索到的图片 URL 列表
**动作**：
1. `curl -x proxy` 逐张下载
2. `file *.jpg` 验证是 JPEG 非 HTML
3. **vision_analyze 逐张验证**：`"这是重庆XX场景吗？与<页面主题>相关吗？"`
4. 标记：✅ 相关 → 重命名为 `PXX_描述.jpg` / ❌ 不相关 → 删除，换备选 URL 重搜
**铁律**：禁止跳过视觉验证直接使用下载的图片。曾实测 Unsplash 直链返回故宫/西班牙别墅/新加坡鱼尾狮。

### 6c. AI 结构图（方案 A）

```bash
python image_gen.py "prompt" --backend openai --model gpt-image-2 --aspect_ratio 16:9 -o images/ -f PXX
```
**必须串行调用**——并行触发 429 rate limit。

### 6d. 手绘 SVG 结构图（方案 B）

AI API 限流或 key 失效时的备选。直接写 SVG（四象限/时间轴/流程图/齿轮图），嵌入 PPTX 与实景图同样有效，且无 API 依赖。

### 6e. 数据图表

matplotlib 从 Excel 生成 PNG（dpi=180）。
4. **数据图表**：matplotlib 从 Excel 生成 PNG（dpi=180）
4. matplotlib：从 Excel 生成 PNG（dpi=180）

---

## Agent 7：组装定稿（关卡 4）

**执行者**：python-pptx + ppt-master
**输入**：初稿 PPTX + Agent 6b 验证通过的配图文件

### 7a. 生成 PPTX
```bash
python skills/ppt-master/scripts/finalize_svg.py <project>
python skills/ppt-master/scripts/svg_to_pptx.py <project>
```

### 7b. 嵌入图片
用 python-pptx 的 `slide.shapes.add_picture()`。全幅背景：`(0, 0, 13.33)` 英寸；侧栏：`(7.5, 1.5, 5.5)` 或 `(0.5, 1.5, 5.5)` 英寸。

### 7c. 完成确认（强制）
**Agent 7 完成后必须输出以下三条**：
1. **文件路径**：终稿 PPTX 的完整绝对路径
2. **配图验证清单**：每页配图来源 + 视觉验证结果（✅/❌）
3. **完成消息**：明确告诉用户"已完成"

### 关键陷阱
- **不要**用 `read_file` + `write_file` 编辑 SVG——`read_file` 输出带行号前缀 `     1|`，写回会损坏 XML（`xml.etree.ParseError: line 1, column 5`）。用 Python `open()` 直接读写
- **不要**在 SVG 中嵌入 `<image>` 标签——ppt-master 的 XML 解析器不支持
- **不要**给无关页面配图——用户明确抱怨图文不匹配时，宁可留白
2. 用 `python-pptx` 的 `slide.shapes.add_picture()` 逐页嵌入图片
3. 全幅背景：`Inches(0), Inches(0), Inches(13.33)` 
4. 侧栏配图：`Inches(7.5), Inches(1.5), Inches(5.5)` 或 `Inches(0.5), Inches(1.5), Inches(5.5)`
5. 嵌入前 `file` 验证图片是有效 JPEG
**关卡**：⚠️ 用户最终确认

**⚠️ 不要**在 SVG 中嵌入 `<image>` 标签——ppt-master 的 XML 解析器报 `syntax error: line 1, column 5`。图片必须在 PPTX 层面嵌入。同样不要用 `read_file` + `write_file` 编辑 SVG——`read_file` 输出含行号前缀 `     1|`，写回会损坏 XML。用 Python `open()` 直接读写。
2. 用 `python-pptx` 的 `slide.shapes.add_picture()` 逐页嵌入图片
3. 全幅背景图：`(0, 0, 13.33)` 英寸覆盖整页
4. 侧栏配图：`(7.5, 1.5, 5.5)` 或 `(0.5, 1.5, 5.5)` 英寸
5. 校验：图片文件先 `file` 确认是 JPEG 再嵌入
**关卡**：⚠️ 用户最终确认

**注意**：不要尝试在 SVG 中嵌入 `<image>` 标签——ppt-master 的 XML 解析器会报 `syntax error: line 1, column 5`。图片必须在 PPTX 层面嵌入。

---

## 关键约束

| 约束 | 说明 |
|------|------|
| 文案 | 严格从原文提取，不增不减 |
| 标题 | 每个一二标题必须对应PPT页面 |
| 卡片递进 | 上页卡片要点 = 下页概括总起 |
| 封面底图 | 必须搜索真实照片，禁止AI生成 |
| 搜图 | 关键词必须带"重庆" |
| 关卡 | 用户确认不可跳过（Agent 2 → 2.5 → 5 → 7） |
| 图文匹配 | 只给内容相关的页配图，不对应的宁可留白 |

## 已知陷阱

| 陷阱 | 现象 | 对策 |
|------|------|------|
| `browser_navigate` + 中文URL | `'utf-8' codec can't decode byte 0xb2` | 用 `curl -x proxy` 下载；中文搜索用 DuckDuckGo Python 包 |
| Unsplash URL 图不对题 | 视觉验证出故宫/西班牙/新加坡而非重庆 | 不用 Unsplash 直链；用 DuckDuckGo 搜 + 视觉模型逐张验证 |
| SVG 中嵌入 `<image>` | `xml.etree.ParseError line 1, column 5` | 图片在 PPTX 层用 python-pptx 嵌入，不动 SVG |
| `read_file`→`write_file` 编辑 SVG | XML 损坏（行号前缀 `     1|` 污染） | 用 Python `open()` 直接读写文件 |
| AI 生图并行调用 | 429 rate limit | 必须串行调用 `image_gen.py` |
| 图片嵌入报 PIL 错误 | `UnidentifiedImageError` | `file *.jpg` 验证是 JPEG；损坏文件换有效源 |
| API key 截断/失效 | 401 无效令牌 | 用 `memory replace` 更新完整 key |
| 图文内容不匹配 | 用户指出图文无关 | 只配内容相关的图；不相关的页宁可无图

## 已知陷阱

| 陷阱 | 现象 | 对策 |
|------|------|------|
| browser_navigate + 中文URL | `'utf-8' codec can't decode byte` | 放弃浏览器，改用 `curl -x proxy` 下载 |
| Unsplash URL 返回404 | `file` 命令显示 `HTML document` | 下载后立即 `file *.jpg` 验证，损坏的换备选URL |
| SVG 中嵌入 `<image>` 标签 | `xml.etree.ParseError: syntax error: line 1, column 5` | 不要改 SVG；在 PPTX 层面用 python-pptx 嵌入图片 |
| AI 生图并行调用 | Rate limit 429 | 串行调用 `image_gen.py`，一个接一个 |
| API key 截断 | memory 中 key 不完整 | 用户提供完整 key 后立即用 `memory replace` 更新 |
| ppt-master finalize_svg 不匹配图片 | 输出 `No images` | 使用 `python-pptx` 的 `add_picture()` 替代自动对齐 |

---

## 依赖

- **ppt-master**：`git clone https://github.com/hugohe3/ppt-master.git`（需单独克隆）
- **Node.js**：pptxgenjs, playwright, sharp
- **Python**：python-pptx, matplotlib, pymupdf
- **API**：api.apiyi.com/v1（图片生成）, 高德地图（可选）

## 模板制作

要添加新模板，在 `templates/<name>/` 下放 `design_spec.md` + `svg/*.svg`。
Agent 2.5 会自动扫描 `templates/` 目录发现新模板。
