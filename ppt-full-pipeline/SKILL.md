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
 (Hermes)     (cn.bing+DuckDuckGo+Vision)   (python-pptx)
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

**执行者**：PPT-Pro（加载 `ppt-pro` skill）**或 Hermes 直接批量生成 SVG**

**输入**：Agent 2 文案 + Agent 2.5 模板 design_spec

**路径 A — PPT-Pro 逐页细化**（标准路径）：
1. 将每页文案转为 ppt-master SVG 生成指令，嵌入模板配色/字体/布局模式
2. 图片占位规则见下文

**路径 B — Hermes 直接批量生成 SVG**（快速路径，适用于 15+ 页项目）：
当 ppt-master 的 Strategist 8 确认步骤过于繁琐时，可跳过 Strategist，用 Python 脚本按模板 design_spec 直接批量生成所有 SVG 页面。步骤：
1. 从模板的 `design_spec.md` 和 `svg-patterns.md` 提取配色/字体/页面类型模板
2. 写 Python 脚本，用 f-string 填充文案到 SVG 模板
3. 批量输出到 `svg_output/` 目录
4. 跑 `finalize_svg.py` + `svg_to_pptx.py` 转换
5. 之后走 Agent 7 嵌图

每个 SVG 类型的关键参数见对应模板的 `svg-patterns.md`。
**内容页卡片布局要求**：见 [`references/card-layout-pattern.md`](references/card-layout-pattern.md) —— 独立卡片、内容密度、字体规格、XML 转义。
**动作**：
1. 将每页文案转为 ppt-master SVG 生成指令，嵌入模板配色/字体/布局模式
2. **图片占位（必须）**——完整工作流见 [`references/image-placeholder-workflow.md`](references/image-placeholder-workflow.md)：

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
**输入**：Agent 2 文案 + Agent 2.5 模板 design_spec

### 路径 A：直接 SVG 批量生成（推荐，跳过 Strategist）

当设计规范明确（模板已选定），直接写 Python 脚本生成 SVG 更快：
```bash
# 1. 生成 SVG（一个脚本输出全部页面）
python projects/<project>/gen_svgs.py

# 2. 转换
python skills/ppt-master/scripts/finalize_svg.py <project>
python skills/ppt-master/scripts/svg_to_pptx.py <project>
```

SVG 页面类型及尺寸（1280×720px）：
| 页面类型 | 背景色 | 关键元素 |
|----------|--------|---------|
| 封面 | 渐变 `url(#cg)` | 标题36-48pt居中 + 底部5卡片 + 4px顶部色条 |
| 目录 | 渐变 + 左侧8px色条 | 编号+标题+副标题，每行120px间距 |
| 章节页 | 渐变 + 大号淡化数字(400pt opacity 0.05) | 编号72pt + 标题48pt + 3卡片 |
| 内容页 | 暖白 `#FFFAF5` | 顶部导航条(56px) + 卡片(左金色竖线6px) + 注释11pt |
| 封底 | 渐变 | 祝福语42pt居中 + 金色横线分隔 |

**内容页导航条规范（用户硬性要求）**：
- 顶部4px主色线
- 56px高白色条：左→项目名(14pt主色) | 分隔线 | 章节路径(14pt金色)  /  右→页码
- 下方1px灰色分隔线

**红金政务风配色（老干局/党委汇报）**：
```python
'primary': '#B71C1C', 'accent': '#D4A017', 'bg': '#FFFAF5'
'text': '#2C1810', 'text2': '#8B7355'
# 渐变：B71C1C → 6D0000
```

### 路径 B：Strategist（8 确认，适合无预设模板的项目）

```bash
cd ppt-master/
python skills/ppt-master/scripts/source_to_md/doc_to_md.py <source.docx>
python skills/ppt-master/scripts/project_manager.py init <name> --format ppt169
python skills/ppt-master/scripts/project_manager.py import-sources <project> <source.md> --move
# → Strategist 8 confirmations
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

注意：`browser_navigate` 到 cn.bing 可能因编码问题失败（UTF-8 解码错误），此时用 `terminal(curl)` 或 `execute_code` 替代浏览器搜索。`browser_get_images` 也可能报 `SyntaxError`。

备选方法 1 — ddgs（Python 库，稳定可用）：
```python
# pip install ddgs -q
from ddgs import DDGS
with DDGS() as d:
    results = list(d.images('Chongqing city skyline Raffles City', max_results=3))
    for r in results:
        print(r['image'])  # direct image URL
```

备选方法 2 — terminal curl 直接搜 Bing：
```bash
curl -x http://127.0.0.1:7890 -sL "https://cn.bing.com/images/search?q=URLENCODED_QUERY" -A "Mozilla/5.0" | python -c "import sys,re; html=sys.stdin.read(); urls=re.findall(r'murl&quot;:&quot;(https?://[^&]+)&quot;', html); print('\n'.join(urls[:5]))"
```

**备选 DuckDuckGo**（cn.bing 不可用时。注意：ddgs 是免费网页抓取，无限流限制，不是付费 API。报"额度用完"说明短时间内请求太多，换 IP 或等几分钟即可）：

```bash
pip install ddgs -q
python -c "
from ddgs import DDGS
with DDGS() as d: print(list(d.images('Chongqing Hongyadong night', max_results=5)))
"
```

### 6b. 下载 + 视觉验证（强制关卡——每张必验，含无水印检查）

**水印铁律**：有水印/Logo/版权标识的图片一律不可用。验证时必须检查画面四角+中央是否有文字覆盖、半透明Logo、gettyimages/shutterstock署名等。发现水印立即删除重搜。

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
完整占位框工作流见 [`references/image-placeholder-workflow.md`](references/image-placeholder-workflow.md)。核心三步：

- **全幅背景页**：`add_picture(0, 0, prs.slide_width, prs.slide_height)` + 将图片移至底层 z-order：
  ```python
  pic = slide.shapes.add_picture(img_path, Inches(0), Inches(0), prs.slide_width, prs.slide_height)
  sp = pic._element
  sp.getparent().remove(sp)
  slide.shapes._spTree.insert(2, sp)  # 插入到树的最前面 = 最底层
  ```
- **侧栏插图页**：解析 SVG 中的 `<!-- IMAGE_PLACEHOLDER: x=... y=... w=... h=... -->` 注释，提取坐标，嵌入图片。坐标转换：`px_to_in = lambda px: Emu(int(px) * 12700)`，然后 `slide.shapes.add_picture(img, px_to_in(x), px_to_in(y), px_to_in(w), px_to_in(h))`。
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
| 卡片递进 | 上页卡片要点 = 下页概括总起 | 卡片渲染 | **每个要点=独立视觉卡片**（独立`<g>`+圆角白底+金色左条），每卡≥4行原文，字体≥14pt，**严禁所有要点挤一个框** |
| 配图 | 只给内容相关的页配图，不对应的宁可留白 |
| 图片占位 | **SVG生成时必须预留占位框**：卡片收窄至430px，右侧放虚线`<rect stroke-dasharray="8,4">`+`<!-- IMAGE_PLACEHOLDER: x= y= w= h= -->`注释。Agent 7解析注释取坐标替换真图，严禁硬贴导致重叠 |
| 封面底图 | 必须搜索真实照片，禁止 AI 生成 |
| 关卡 | 四个用户确认点不可跳过 |

---

## 已知陷阱

| 陷阱 | 现象 | 对策 |
|------|------|------|
| **SVG `<image>` 在 `<rect>` 前面** | 封面/内容页有图但被不透明色块完全盖住 | `<image>` 必须放在背景 `<rect>` **后面**；全幅背景 rect 加 `opacity="0.65"` |
| **章节页渐变rect遮挡背景图** | 章节页嵌了图但看不到，被渐变 `<rect fill="url(#sg)">` 盖住 | 章节页SVG的渐变rect必须加 `opacity="0.65"`；或在python-pptx中注入alpha通道 |
| **内容页右侧无图** | 配图规划写了右侧插图但PPT里没有 | Agent 7 必须为每页内容页调用 `slide.shapes.add_picture(img, right_x, right_y, right_w, right_h)` |
| **`cell.text = ''` 产生空 run** | python-docx 表格字体检测失败，`runs[0]` 是空 run | 用 `cell.paragraphs[0].clear()` 替代 `cell.text = ''`；或检测 `run.text.strip()` 跳过空 run |
| **`read_file` + `write_file` 污染 SVG** | `svg_to_pptx` 报 `syntax error: line 1, column 5`，文件以空格开头 | **禁止**用 `read_file`/`write_file` 编辑 SVG。用 `terminal` + Python `open()`。详见 `references/file-io-pitfalls.md` |
| 未验证图片直接使用 | | |
| DuckDuckGo 报"额度用完" | ddgs 限流 | ddgs 是免费网页抓取，非付费 API。等几分钟或换 IP 即可。首选 cn.bing.com 无频率限制 |
| Unsplash URL 图不对题 | 视觉验证出故宫/西班牙/新加坡而非重庆 | 视觉模型逐张验证后再用；不可跳过 |
| `read_file`→`write_file` 编辑 SVG | XML 损坏（行号前缀 `     1\|` 污染文件头） | **禁止用 hermes_tools 的 read_file/write_file 编辑 SVG**；必须用 Python `open()` 直接读写 |
| AI 生图并行调用 | 429 rate limit | 必须串行调用 |
| **内容页单一大框（非卡片）** | 所有条目挤在一个大白框里，无独立卡片 | 每个条目必须是独立 `<g filter="url(#cs)">` + `<path fill="#FFFFFF">` + 金色左条。**禁止**用一个 `<g>` 包裹全部 `<text>`。见 `references/card-layout-pattern.md` |
| **卡片内容单薄** | 每卡仅 1 行概括，投影后空洞 | 每卡至少 3-4 行实质性文字，**从原始 DOCX 提取**，不自编不精简。见 `references/card-layout-pattern.md` 内容密度铁律 |
| **卡片字体太小** | 13pt 正文投影完全看不清 | 卡片标签 ≥16pt bold，卡片正文 ≥14pt。注释 11pt 例外 |
| **SVG 中 `<` 未转义** | `svg_to_pptx` 报 `not well-formed (invalid token)` | 所有 XML 特殊字符转义：`<` → `&lt;`，`>` → `&gt;`，`&` → `&amp;` |
| API key 截断/失效 | 401 无效令牌 | 用 `memory replace` 更新完整 key |

---

## 依赖

- **ppt-master**：`git clone https://github.com/hugohe3/ppt-master.git`（需单独克隆）
- **Python**：python-pptx, matplotlib, pymupdf, duckduckgo-search
- **API**：api.apiyi.com/v1（图片生成）, 高德地图（可选）

## 模板制作

要添加新模板，在 `templates/<name>/` 下放 `design_spec.md` + `svg/*.svg`。
Agent 2.5 会自动扫描 `templates/` 目录发现新模板。
