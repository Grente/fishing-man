# 美术素材索引

根目录：`assets/`

## 鱼类 `assets/fish/`

12 张立绘 PNG（透明底），ID 与 `docs/fish-data.md` / `data/fish.json` 一致：

`sardine` `mackerel` `sea_bream` `clownfish` `pufferfish` `butterflyfish`
`tuna` `sailfish` `mahi` `snapper` `grouper` `king_mackerel`

备份（白盘旧版）：`assets/fish/_bak_whiteplate/`

## 世界 `assets/world/`

| 路径 | 用途 |
|------|------|
| `water_tile.png` / `sand_strip.png` | 海水 / 沙滩 |
| `pier_dock.png` / `pier_plain.png` | 码头木栏 |
| `buoy_near.png` / `buoy_mid.png` / `buoy_far.png` | 近/中/远海浮标 |
| `building_toolshop.png` | 工具店 |
| `building_market.png` | 海鲜市场 |
| `building_encyclopedia.png` | 图鉴馆 |
| `palm_*.png` / `bush*.png` / `beach_umbrella.png` | 陆地风景 |
| `boat.png` | 渔船回退图 |
| `gear/boat_basic.png` `boat_speed.png` `boat_cargo.png` | 可购船体 |
| `gear/rod_bamboo.png` `rod_carbon.png` `rod_legend.png` | 可购钓竿（覆盖在船上） |

其它道具 / 切图：`props/`、`crates.png`、`rocks.png` 等。

## UI `assets/ui/`

| 路径 | 用途 |
|------|------|
| `btn_list_primary.png` (+ `_pressed`) | 列表主按钮（胶囊） |
| `btn_list_secondary.png` (+ `_pressed`) | 列表次按钮 |
| `catch_sunburst.png` | 捕获弹窗背景光芒 |
| `icons/coin.png` `crate.png` `fuel.png` `new.png` `ripple.png` | HUD / 徽章 |
| `ui_icons.png` | 图标合集（历史） |

列表按钮样式由 `UiThemeFactory.apply_list_primary/secondary` 应用。

## Audio ssets/audio/

| Path | Use |
|------|------|
| sfx/ui_*.ogg etc. | Kenney Interface Sounds (CC0) |
| sfx/cast.wav splash.wav 
eel.wav ite.wav | Fishing SFX |
| sfx/ambient_sea.wav oat_hum.wav | Ambient / boat loop |
| CREDITS.txt | License notes |

Autoload: Sfx (scripts/autoload/sfx.gd).
