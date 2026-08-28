# 行情通 · 股票行情查询系统

纯前端单页应用（无后端），覆盖行情查询、K线走势、AI分析、条件选股、持仓管理、资讯中心六大模块。

## 非功能性需求对照

### 1. 性能
| 指标 | 目标 | 实现 |
|---|---|---|
| 行情查询 | ≤2s | 单次查询仅 1 个 JSONP 请求，页面显示实测耗时（ms） |
| 条件选股 | ≤5s | 股票池 5 页 3 路并发拉取、技术面 6 路并发复筛（runPool） |
| AI 分析 | ≤10s | 数据 1-3 个请求 + 本地引擎计算（毫秒级） |
| 资讯刷新 | ≤30s | 30 秒统一轮询 tick，页面隐藏时自动暂停省流 |
| 并发 | 100+ | 纯静态站，无服务端瓶颈，CDN/静态托管天然水平扩展 |

### 2. 可用性
- 无自建后端，可用性取决于静态托管与公共数据源；所有数据源均有重试（×3）与降级路径（东财限流时资金面降级为量价分析、K线 CDN 双源）。
- 数据源不可用时页面给出明确提示而非静默失败。

### 3. 兼容性
- 视口 meta + 三档媒体查询（900px/768px/560px），适配 Chrome/Edge/Safari/Firefox 及 iOS/Android 主流机型。
- 表格在窄屏下横向滚动，图表高度自适应。

### 4. 数据准确性
- 行情来自腾讯行情接口（与行情软件同源，延迟以数据源为准）。
- 异常检测机制：价格无效、高低价倒挂、现价越界、涨跌幅超 30%、行情时间滞后超 4 天，均触发页面「⚠️ 数据异常提示」标注（不静默修正）；K线高低价倒挂的 bar 自动剔除。

### 5. 可扩展性
| 扩展点 | 配置文件 | 方式 |
|---|---|---|
| 分析师角色 | `skills/*.md` + `skills/index.json` | 新增 md 文件即新角色（frontmatter 声明 engine） |
| 选股条件 | `config/screen-conditions.json` | extra 数组追加条件（field 映射东财字段 / techEval 复用评估器） |
| 选股策略 | `strategies.json` | 追加策略对象（conds 引用条件 id） |
| 资讯源 | `config/news-sources.json` | sources 数组增删（type 决定抓取引擎，enabled 开关） |

### 6. 预留开放接口（URL API）
供第三方系统/浏览器书签/ iframe 集成调用：

```
index.html?view=quote|screen|portfolio|news   打开指定视图
index.html?code=600519                         打开行情页并查询（支持 00700、AAPL）
index.html?view=screen                         直达条件选股
```

## 数据源与口径说明
- 行情/K线：腾讯行情（qt.gtimg.cn、proxy.finance.qq.com），script 标签跨域 + GBK 解码
- 选股/资金流/公告/行业：东方财富（push2/np-anotice/np-listapi/search-api-web，JSONP 或 CORS）
- 资讯：东方财富 7×24 快讯、华尔街见闻快讯
- 雪球/新浪/财联社等 Tushare 聚合源：需 token 且不支持浏览器跨域，未接入（详见 config/news-sources.json 中禁用项）
- ROE/营收增长/北向资金：免费跨域源未覆盖，UI 中显式标注，不做臆测

## 本地运行
```bash
python3 -m http.server 3005
# 打开 http://localhost:3005/index.html
```

## 免责声明
行情可能存在延迟，所有分析与建议仅供参考，不构成投资建议。市场有风险，投资需谨慎。
