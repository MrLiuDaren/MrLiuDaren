---
name: ppt-full-pipeline
description: "7-Agent complete PPT generation pipeline from source document to professional PPTX with image planning and generation"
version: 1.0.0
metadata:
  hermes:
    tags: [ppt, pipeline, government, multi-agent]
    category: productivity
    requires_toolsets: [terminal, file, browser, web]
---

# PPT 全流程生成 · 七 Agent 流水线

从公文材料（DOCX/PDF/Excel）到专业政务PPTX的端到端流水线。可复用于任何章节，也可分享给其他 Hermes 实例。

## 触发条件

用户要求"生成PPT"/"出章节PPT"/"做汇报PPT"时加载。如果用户提供 DOCX/PDF/Excel 源文件，直接走流水线。

## 流水线总览

```
Agent 1         Agent 2          Agent 3           Agent 4          Agent 5         Agent 6          Agent 7
需求理解  ->    文案创作   ->    提示词细化   ->    PPT生成    ->    配图规划   ->    搜图生图   ->    组装定稿
(Hermes)       (v0.1提示词)     (PPT-Pro)        (PPT-Master)      (Hermes)        (Browser+DALL-E)  (pptxgenjs)
 读取源文件      输出逐页文案      输出SVG指令       输出初稿PPTX      输出配图清单      下载所有图片       嵌入图片->终稿
```

三个用户确认关卡：Agent 2 文案确认 -> Agent 5 配图确认 -> Agent 7 终稿确认

---

## Agent 1：需求理解

**执行者**：Hermes（当前对话）
**输入**：用户指令 + 源文件路径（DOCX / PDF / Excel）
**动作**：
1. 读取源文件，提取全文结构（一二级标题、页码范围）
2. 确定本章节范围（用户指定或从前章续接）
3. 从 memory 读取项目规范：配色、字体、编号规则、PPT风格
4. 如无 memory 则从上一章 PPTX 的 theme1.xml 提取配色
**输出**：章节结构摘要 + 页码范围 + 配色/字体规范
**不要**在这一步做任何文案创作。

---

## Agent 2：文案创作（关卡1）

**执行者**：v0.1 提示词（PPT文案架构师）
**输入**：Agent 1 的章节结构 + 公文原文
**提示词**（直接使用）：
```
你现在是专职政府工作人员政务工作汇报PPT文案架构师，严格按以下标准处理给到的公文材料：

1.整体逻辑规则：严格保留公文原有一级、二级标题，不修改、不合并、不新增标题；PPT一级章节对应公文一级标题，单页主标题对应公文二级标题。

2.单页内容固定三段结构：
第一段：概括性内容，提炼上级指示、工作目标、核心任务、总体成效；
第二段：卡片式条目，拆分为3-4个独立卡片要点，条目化、短句化、工作化表述；
第三段：注释内容，补充政策依据、数据备注、情况说明，无则不添加。

3.排版布局：简约大气政务风卡片式布局，版式对称规整、留白充足；党政庄重低饱和色系。

4.配图规则：每页必须输出配图提示词：
【配图】
类型：意向照片 / 结构示意图 / 数据图表 / 母版底图
搜图关键词：中文，不超过10字，必须带"重庆"
AI提示词：英文，含风格+构图+色调，仅结构图使用
位置：左侧 / 右侧 / 全幅背景
铁律：实景照片必须搜索真实图片，禁止AI生成；结构示意图可用AI。

5.输出形式：按PPT分页输出，标注页码、主标题，依次给出概括、卡片条目、注释、配图提示词。
```
**输出**：逐页文案包（每页 = 概括 + 卡片条目 + 注释 + 配图提示词）
**关卡**：必须呈交用户确认后再进入 Agent 3

---

## Agent 3：提示词细化

**执行者**：PPT-Pro skill（加载 `ppt-pro` skill）
**输入**：Agent 2 的逐页文案 + 项目配色规范
**动作**：
1. 将每页【概括->卡片->注释】转为 ppt-master 可执行的 SVG 生成指令
2. 指定每页布局模式（A 左文右图 / B 上流程下卡片 / C 全幅架构图）
3. 嵌入配色值、字体、卡片阴影、渐变参数
4. 输出每页的完整 design_spec 格式
**输出**：逐页SVG生成指令包

---

## Agent 4：PPT 生成

**执行者**：PPT-Master（`ppt-master/svg_to_pptx.py`）
**输入**：Agent 3 的SVG生成指令
**动作**：
1. 按指令逐页生成 SVG（`svg_output/`）
2. 运行 `finalize_svg.py` 后处理
3. 运行 `svg_to_pptx.py` 导出初稿 PPTX
**输出**：初稿 PPTX（`exports/` 目录）
**命令**：
```bash
cd ppt-master/
python skills/ppt-master/scripts/finalize_svg.py <project>
python skills/ppt-master/scripts/svg_to_pptx.py <project>
```

---

## Agent 5：配图规划（关卡2）

**执行者**：Hermes
**输入**：Agent 4 的初稿 PPTX + Agent 2 的配图提示词
**动作**：
1. 逐页审查配图需求
2. 按类型分流：
   - 意向照片/底图 -> cn.bing.com 搜真实图
   - 结构图/示意图 -> DALL-E（api.apiyi.com/v1）
   - 数据图表 -> matplotlib 从 Excel 生成
3. 输出配图清单表格：
   | 页码 | 类型 | 搜图关键词 | AI提示词 | 尺寸 | 位置 |
4. 封面底图：必须搜实景照片，禁止AI生成
**关卡**：必须呈交用户确认后再进入 Agent 6

---

## Agent 6：搜图生图

**执行者**：Browser + DALL-E + matplotlib
**输入**：Agent 5 的配图清单
**动作**：
1. **意向照片**：`browser_navigate` -> cn.bing.com，搜索"重庆 + 关键词"，逐个下载
2. **结构图**：`terminal` 调用 `image_gen.py` 或直接 curl api.apiyi.com
3. **数据图表**：Python matplotlib 生成 PNG（dpi=180）
4. 全部存入 `images/`，按 `P01_xxx.jpg` 命名
**输出**：配图文件包

搜索示例：
```
browser_navigate("https://cn.bing.com/images/search?q=重庆+三峡广场+街景")
```

生图示例：
```bash
export OPENAI_API_KEY="sk-xxx"
export OPENAI_BASE_URL="https://api.apiyi.com/v1"
python skills/ppt-master/scripts/image_gen.py "prompt" --backend openai --model gpt-image-2 --aspect_ratio 16:9 -o images/ -f P03_xxx
```

---

## Agent 7：组装定稿（关卡3）

**执行者**：Hermes + pptxgenjs
**输入**：Agent 4 的初稿 PPTX + Agent 6 的配图文件
**动作**：
1. 将图片嵌入对应页面
2. 调整位置/尺寸/蒙版
3. 校验：标题对应、数据一致、配图匹配
4. 输出终稿 PPTX
**关卡**：呈交用户最终确认

---

## 关键约束

| 约束 | 说明 |
|------|------|
| 文案提取 | 严格从原文提取，不自行增加或编撰文字 |
| 标题保留 | 公文的每个一二标题必须在PPT中有对应页 |
| 卡片递进 | 上一页卡片要点 = 下一页概括总起 |
| 配图铁律 | 封面/实景照片禁止AI生成，必须搜真实图 |
| 搜图地域 | 关键词必须带"重庆" |
| 用户确认 | Agent 2/5/7 三处不可跳过 |

---

## 分享给其他 Hermes

将此 skill 目录打包发送即可：

```bash
# 导出
cp -r ~/AppData/Local/hermes/skills/productivity/ppt-full-pipeline /path/to/share/

# 导入（接收方）
cp -r ppt-full-pipeline ~/AppData/Local/hermes/skills/productivity/
```

Skill 完全自包含，不依赖项目特定路径。配色/字体等从 memory 或项目主题提取，无需硬编码。
