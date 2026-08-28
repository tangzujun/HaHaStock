# 分析师角色扩展指南

本目录下的每个 `.md` 文件定义一位 AI 分析师角色（SKILL 机制）。
网站运行时会读取 `index.json` 清单，逐个加载并解析角色文件。

## 新增自定义分析师（三步）

1. 复制任意现有角色文件，改名为如 `my-analyst.md`
2. 修改 YAML frontmatter（见下方字段说明）与正文方法论
3. 在 `index.json` 的 `skills` 数组中加入 `"my-analyst.md"`

刷新页面即可在分析师标签栏看到新角色，无需修改任何代码。

## Frontmatter 字段

| 字段 | 必填 | 说明 |
|---|---|---|
| id | 是 | 角色唯一标识（字母数字） |
| name | 是 | 显示名称，如「情绪派分析师」 |
| icon | 是 | 单个 emoji |
| style | 是 | 分析风格一句话 |
| tagline | 否 | 角色格言，显示在报告头部 |
| focus | 否 | 关注维度列表，格式 `[维度1, 维度2]` |
| engine | 否 | 分析引擎：`technical` / `fundamental` / `capital` / `news` / `master`，缺省按 id 匹配，都不匹配则用 `master` |
| dataNeeds | 否 | 数据需求声明（文档用途）：`kline` / `quote` / `fundflow` / `announcement` |
| order | 否 | 标签栏排序，数字越小越靠前 |

## 统一报告格式

所有角色的报告由系统统一包装为三段：

- **分析结论**：一句话结论 + 信号标签（偏多/中性/偏空）
- **关键依据**：引擎生成的详细数据与论证
- **风险提示**：该视角固有的局限性说明

自定义角色自动获得统一格式；`engine` 决定结论与依据的内容来源，
角色文件的 frontmatter 与正文（方法论）会显示在报告头部。

## 示例

```markdown
---
id: sentiment
name: 情绪派分析师
icon: 🌡️
style: 以市场情绪与超买超卖为核心
tagline: 别人贪婪时我恐惧
focus: [RSI, KDJ, 换手率, 量比]
engine: technical
dataNeeds: [kline]
order: 6
---

# 情绪派分析师

（这里写方法论，会显示在报告头部……）
```
