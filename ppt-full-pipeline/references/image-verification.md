# 配图搜图验证工作流

本文件记录从两江四岸 PPT 项目中提炼的最佳实践。

## 问题
Unsplash 直链与搜索词无关（Chongqing riverside 返回故宫/西班牙别墅/新加坡）。

## 流程
1. **DuckDuckGo 搜**：`pip install duckduckgo-search` → `DDGS().images('Chongqing Hongyadong', max_results=5)`
2. **curl 下载**：`curl -x http://127.0.0.1:7890 -sL "<url>" -o photo.jpg`
3. **file 验证**：`file photo.jpg` 必须是 JPEG，不能是 HTML
4. **vision 验证**：`vision_analyze(image_url, "这是重庆场景吗?")` 逐张确认内容

## 教训
- 不用 Unsplash 直链做地域搜索
- 必须逐张视觉验证
- 验证通过后再重命名