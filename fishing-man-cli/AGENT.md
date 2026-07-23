# 钓鱼佬 (fishing-man) — 项目说明

钓鱼佬是一款模拟钓鱼收集的游戏：

**核心循环：** 码头待命 → 出海驾驶 → 靠近鱼点抛竿 → 时机收线 → 捕获 → 返港卖鱼 / 购买装备

- 海鲜市场（动态今日价）
- 鱼缸图鉴系统
- 工具店购买 / 装备渔船与钓竿（船上组合显示）

## 复刻玩法参考图

| 文件 | 内容 |
|------|------|
| `docs/example/场景1.jpg` | 码头：卖货/升级、HUD、航海图 |
| `docs/example/场景2-抛竿.jpg` | 出海靠近鱼点，出现「抛竿」按钮 |
| `docs/example/场景-捕鱼进度条时机.jpg` | 「收线时机」：白线落入亮色区 |
| `docs/example/海鲜市场.jpg` | 海鲜市场行情列表（涨跌、稀有度） |
| `docs/example/捕获弹窗.jpg` | 捕获成功弹窗（NEW、今日价格、继续） |
| `docs/example/图鉴.jpg` | 鱼缸与图鉴（已发现彩色 / 未发现灰色） |
| `docs/example/图鉴-详情.jpg` | 单鱼详情（单价、出现区域） |

## 技术栈

| 项目 | 选型 |
|------|------|
| 引擎 | Godot 4.6（GL Compatibility renderer） |
| 语言 | GDScript |
| 呈现 | **2D 俯视**（非 3D） |
| 平台 | 微信小游戏（目标） |
| 分辨率 | 竖版 720 × 1280 |
| 世界地图 | **2880 × 2560**（见 `docs/map-system.md`） |
| 输入 | 移动端触控优先 |
| 用户文本 | 中文（源码 / `.tscn` 须 **UTF-8**） |

## 文档索引

| 文档 | 用途 |
|------|------|
| `docs/map-system.md` | 地图、建筑布局、迷你地图、HUD |
| `docs/art-style.md` | 美术风格、配色、UI 组件 |
| `docs/tide-system.md` | 潮汐系统（后台影响稀有/行情） |
| `docs/gameplay.md` | 核心玩法、状态机、装备与升级 |
| `docs/fish-data.md` | 鱼类数据表（12 种） |
| `docs/assets.md` | 美术素材目录与接入说明 |
| `docs/controls.md` | 试玩操作说明 |
| `prompt/fish-pro.md` | 鱼类美术提示词 |

## 场景与脚本入口

| 路径 | 说明 |
|------|------|
| `scenes/main.tscn` | 主场景 |
| `scripts/autoload/world_config.gd` | 世界尺寸、岸线、停靠坐标 |
| `scripts/autoload/game_state.gd` | 金币/货舱/油/船竿目录与存档 |
| `scripts/autoload/fish_db.gd` | 鱼类静态数据 |
| `scripts/autoload/market.gd` | 海鲜市场价格波动 |
| `scripts/autoload/tide.gd` | 潮汐（后台，HUD 不显示） |
| `scripts/ocean_world.gd` | 地图环境、建筑、风景、渔船视觉 |
| `scripts/ui/game_ui.gd` | HUD / 码头菜单 / 捕获 / Toast |
| `scripts/ui/market_panel.gd` | 海鲜市场（可滑动） |
| `scripts/ui/encyclopedia_panel.gd` | 图鉴网格 + 详情 |
| `scripts/ui/tool_shop_panel.gd` | 工具店买船/买竿 |
| `scripts/ui/ui_theme.gd` | 主题与列表按钮样式（`UiThemeFactory`） |

## 编码注意

- 所有 `.gd` / `.tscn` / `.md` 必须保存为 **UTF-8**
- 非法 UTF-8（如误存 GBK）会导致按钮乱码、脚本加载失败、甚至界面卡死
