# 行情通 · 腾讯云轻量服务器部署清单（上海机房 / 一年 ≤100 元）

站点是**纯静态单页**（`index.html` + `config/` + `skills/` + `strategies.json`，共 300KB），
无后端、无数据库。所以服务器只做一件事：**把文件放到 nginx 里**。

---

## 一、买什么（照着选，别选错）

| 选项 | 选这个 | 别选这个 |
|---|---|---|
| 产品 | **轻量应用服务器 Lighthouse** | 云服务器 CVM（贵 3-5 倍、配置繁琐） |
| 规格 | **2核2G / 3-4M 峰值带宽 / 40-50G SSD / 200-300G 月流量** | 4核8G（用不上，多花钱） |
| 地域 | **上海**（华东-上海） | 中国香港（贵 3-5 倍，自用调试没必要） |
| 镜像 | **Ubuntu 22.04 或 24.04**（想点鼠标就选「宝塔面板」镜像） | Windows（镜像 License 加钱） |
| 时长 | 1 年 | 3 年（续费会恢复原价，先买一年试） |

### 100 元预算怎么落地（按优先级抢）

1. **首选：新用户活动「2核2G 4M / 300G 月流量」≈ 79-99 元/年**
   腾讯云官网「轻量应用服务器」活动页常年挂着，个人实名用户常是 79 元档，上海地域通常可选。
2. **次选：秒杀款「2核2G 3M / 200G 月流量」≈ 38-68 元/年**
   限量、定时放，抢不到就走第 1 项。
3. **保底：活动页无上海库存时**
   - 换**南京/广州**（同华东/华南，延迟与上海接近，活动价常更低）；
   - 或上海地域日常价（约 600-900 元/年）超预算 → 此时建议改走 **GitHub Pages 免费托管**（本目录 `deploy-github-pages.md` 备选说明见文末），
     服务器的事等大促（618 / 双11 / 春节）再买。

> 价格随活动实时变动，下单前以腾讯云官网活动页显示为准。核心判断标准只有一条：
> **首年实付 ≤ 100 元、上海或华东地域、2核2G、Ubuntu。**

### 买的时候顺手确认两件事
- **公网 IP**：买完在控制台能看到，后面脚本要用。
- **防火墙/安全组**：轻量控制台 → 服务器 → 防火墙 → **添加规则放行 `22 / 80 / 443`**（TCP）。
  腾讯云轻量有独立的防火墙页面，光配系统内 ufw 不够。

---

## 二、部署（3 步，约 5 分钟）

### 第 1 步：填一次服务器信息

编辑 `deploy/deploy.conf`：

```bash
SERVER_IP="1.2.3.4"      # 换成你的公网 IP
SERVER_USER="root"
SSH_PORT=22
```

### 第 2 步：服务器上跑一次初始化脚本

```bash
# 本地：把脚本传上去
scp -P 22 deploy/server-setup.sh root@1.2.3.4:/root/

# 服务器：执行一次
ssh root@1.2.3.4
chmod +x /root/server-setup.sh && /root/server-setup.sh
```

脚本会做：装 nginx → 建 `/var/www/hahastock` → 写站点配置 → 生成自签 HTTPS 证书 → 启动。
跑完终端会打印访问地址。

### 第 3 步：本地推代码

```bash
cd stock-quotes
./deploy/deploy.sh
```

改完任何文件，重跑这一条即可（rsync 增量 + 自动排除 `deploy/` 和 `.DS_Store`）。

访问地址：
- `http://1.2.3.4`（HTTP，全能，但浏览器系统通知不可用）
- `https://1.2.3.4`（HTTPS，自签证书要点一次「继续访问」，**通知/预警功能正常**）

---

## 三、关于 HTTPS：为什么值得点那一下「继续访问」

页面的**持仓价格预警**用的是浏览器 Notification API，浏览器只在 **安全上下文**（`https://` 或 `localhost`）下才给授权。
所以：

| 访问方式 | 行情/选股/K线/资讯 | 持仓预警系统通知 |
|---|---|---|
| `http://IP` | ✅ 正常 | ❌ 授权按钮无效 |
| `https://IP`（自签） | ✅ 正常 | ✅ 正常（首次信任后） |

自签证书已由 `server-setup.sh` 自动生成，有效期 10 年，够用到服务器到期。

**想彻底没有证书警告**（可选）：本地装 `mkcert`，用它签发证书再上传，本机浏览器全信任。

```bash
brew install mkcert && mkcert -install
mkcert 1.2.3.4                      # 生成 1.2.3.4.pem / 1.2.3.4-key.pem
scp 1.2.3.4.pem root@1.2.3.4:/etc/nginx/ssl/server.crt
scp 1.2.3.4-key.pem root@1.2.3.4:/etc/nginx/ssl/server.key
ssh root@1.2.3.4 "systemctl reload nginx"
```

---

## 四、⚠️ 上线后最可能踩的坑：ECharts 走的是国外 CDN

`index.html` 里 K 线图的 ECharts 和 Excel 导入的 SheetJS 现在从 CDN 拉：

```
https://cdn.jsdelivr.net/npm/echarts@5.5.1/dist/echarts.min.js   （K线图）
https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js   （CSV/Excel 导入）
```

国内网络访问 jsdelivr **时快时慢、偶尔超时**，症状是「K 线图一片空白 / 导入按钮点了没反应」。
`deploy/localize-cdn.sh` 会把这两个文件下载到 `vendor/` 并**自动改 index.html 优先用本地文件**（改前自动备份 `.bak`，随时可回滚）：

```bash
./deploy/localize-cdn.sh     # 下载 + 打补丁
./deploy/deploy.sh           # 再推一次
```

跑完 `vendor/` 约 1.5MB，对 300G 月流量毫无压力。

---

## 五、日常维护

| 想做什么 | 命令 |
|---|---|
| 更新站点 | 本地 `./deploy/deploy.sh` |
| 看 nginx 日志 | `ssh root@IP "tail -f /var/log/nginx/hahastock.access.log"` |
| 重启 nginx | `ssh root@IP "systemctl restart nginx"` |
| 服务器上改文件 | `/var/www/hahastock/` 就是站点根目录 |

### 几个提醒
- **数据只在浏览器本地**：持仓、预警、自选、对话历史全在 localStorage。
  换电脑 / 换域名 = 看不到之前录的持仓，这是设计如此，不是 bug。
- **不要绑域名**：只要域名一解析到这台上海机器，就必须 ICP 备案，否则腾讯云会拦截 80/443。
  自用调试阶段老实走 `IP` 访问。真要绑域名，先去腾讯云提交备案（通常 3-20 个工作日）。
- **续费**：活动价只管首年，到期前会按日常价续费。不需要了就在到期前手动销毁，避免自动续费扣款。
- **月流量**：300GB/月，自用调试完全用不完（整站 300KB/次，全量刷新 100 万次才到 300GB）。

---

## 六、备选：不买服务器也行

如果活动页抢不到 ≤100 元的上海配置，这两个免费的先顶上：

| 方案 | 做法 | 国内访问 |
|---|---|---|
| **GitHub Pages** | `git push` 到 `tangzujun/HaHaStock`，Settings → Pages → 选 `main` 分支根目录 | 慢且不稳（时不时被墙），但调试够用，自带 HTTPS |
| **Cloudflare Pages** | 导入同一个 GitHub 仓库，构建命令留空，输出目录 `/` | 国内访问比 GitHub Pages 稳 |

注意：仓库 `tangzujun/HaHaStock` 上的 `index.html` 目前是 **218KB 的旧版本**，
比本地的 232KB 少了「市场切换隔离」「缩写注释浮窗」「预警栏置顶」等今日新功能。
走这两条路之前，需要先把本地最新代码推进去（本地目录还不是 git 仓库，我可以帮你初始化并推）。
