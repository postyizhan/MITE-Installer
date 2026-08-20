# MITE 1.6.4 + FishModLoader 一键安装脚本

Minecraft 1.6.4 + MITE R196 + FishModLoader 的全自动安装脚本，支持 Linux 与 macOS（含 Apple Silicon）。单文件、零外部依赖、多语言。

```bash
# Codeberg
curl -fsSL https://codeberg.org/postyizhan/MITE-Installer/raw/branch/main/install.sh | bash

# GitHub
curl -fsSL https://raw.githubusercontent.com/postyizhan/MITE-Installer/main/install.sh | bash

# jsDelivr CDN
curl -fsSL https://cdn.jsdelivr.net/gh/postyizhan/MITE-Installer@main/install.sh | bash

# ghproxy 镜像
curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/postyizhan/MITE-Installer/main/install.sh | bash
```

## 它做什么

- 下载原版 1.6.4，或**复用你本地已有的** `1.6.4.jar`（自动扫描 HMCL / PCL / MultiMC / Prism 等常见路径并校验 SHA-1）
- 下载 MITE R196，按官方手动安装步骤重打包出 `1.6.4-MITE.jar`（去签名 + 覆盖 class）
- 注入 FishModLoader 与其依赖，生成可被第三方启动器识别的版本 JSON
- 补齐 1120 项 legacy 布局资源（约 146 MB）、依赖库、平台 natives
- 需要时自动下载便携 JRE 17 到安装目录内，**不动系统 Java**
- 生成 `launch-mite.sh`，离线可直接启动，不依赖任何启动器
- 服务端：下载开箱即用的 HDS 整合包并生成 `start.sh`

## 用法

```bash
# 交互式(会问装客户端还是服务端)
curl -fsSL <脚本地址> | bash

# 传参数要用 bash -s --
curl -fsSL <脚本地址> | bash -s -- --client --yes

# 本地运行
bash install.sh --client --dir ~/mc-mite
```

### 常用选项

| 选项 | 说明 |
|---|---|
| `--dir <路径>` | 游戏目录，默认 `~/.minecraft` |
| `--server-dir <路径>` | 服务端目录，默认 `./mite-server` |
| `--client` / `--server` | 只装客户端 / 只装服务端 |
| `--lang zh_CN\|en_US` | 界面语言，默认按 `$LANG` 判定 |
| `--source <名称>` | 指定下载源，逗号分隔，如 `--source bmclapi,ghfast` |
| `--no-speedtest` | 跳过测速，用默认源顺序 |
| `--vanilla-jar <路径>` | 指定原版 `1.6.4.jar` |
| `--force-download` | 忽略本地已有原版 jar，强制下载 |
| `--mite-zip <路径>` | 用本地 MITE zip，跳过下载 |
| `--fml-installer <路径>` | 用本地 FML installer jar，跳过下载 |
| `--fml-version 3.4.3` | 锁定 FML 版本，默认取 GitHub 最新 release |
| `--yes` | 全部用默认值，不交互 |

### 下载源

三类产物各自独立选源，默认测速后自动挑最快的。

**原版**（meta / jar / libraries / assets）
- `official` — Mojang 官方
- `bmclapi` — BMCLAPI 镜像

**FishModLoader**（GitHub 直连在国内常超时，故默认走镜像）
- `ghfast` · `gh-proxy` · `ghproxy` · `hk` · `github`

顺序即 `--no-speedtest` 时的优先级，按实测速度排（同一网络下对 45 MB 的 HDS 核心）：ghfast 246 KB/s > gh-proxy 178 KB/s > hk 43 KB/s > github 直连 33 KB/s。

**MITE**（官网 + 本仓库 GitHub/Gitee 镜像，内容与官方包逐字节一致，已实测 sha256 校验通过）
- `official` — 官网 `avernite.ca`
- `gitee` — Gitee release 镜像（国内直连）
- `github` · `ghfast` · `gh-proxy` · `ghproxy` · `hk` — GitHub release 直连 / 代理镜像

也可用 `--mite-zip` 直接指定本地文件跳过下载。

## 产物

```
~/.minecraft/
├── versions/1.6.4/1.6.4.jar
├── versions/1.6.4-MITE/
│   ├── 1.6.4-MITE.jar              原版去签名 + MITE class
│   ├── 1.6.4-MITE.json             版本配置
│   └── 1.6.4-MITE-natives/         按平台解压的 natives
├── libraries/                      含 FishModLoader 与 guava-28.0
├── assets/virtual/legacy/           1120 项，约 146 MB
├── resourcepacks/MITE Resource Pack 1.6.4.zip
├── runtime/jre-17-x64/             仅在系统缺 Java 17 时下载
└── launch-mite.sh                  离线可直接启动
```

启动方式二选一：

```bash
~/.minecraft/launch-mite.sh 玩家名 内存MB     # 直接跑
```

或在 HMCL / PCL 等启动器里刷新版本列表，选 `1.6.4-MITE`。

服务端：

```bash
./mite-server/start.sh 2048
```

首次启动需先同意 EULA（脚本会询问，或手动在 `eula.txt` 写 `eula=true`）。

## 环境要求

- **Java 17**（FML 3.x 需要）。缺失时脚本自动下载便携版到安装目录，不影响系统 Java。
- 必需命令：`curl`、`unzip`（或 `python3`）、`awk`、`shasum`/`sha1sum`/`openssl`
- 打包 MITE jar 需要 `zip`、`python3` 或 `jar` 三者之一
- 磁盘约 1.5 GB
- 兼容 bash 3.2（macOS 自带版本）

### Apple Silicon

1.6.4 的 lwjgl native 只有 x86_64 切片（`lipo -archs` 实测：`i386 x86_64`，无 arm64），所以**客户端**必须用 x86_64 的 JRE 经 Rosetta 2 运行 —— 脚本会自动下 x86_64 JRE 并检测 Rosetta，缺失时提示 `softwareupdate --install-rosetta`。

**服务端**不含任何 native，脚本会直接用原生 aarch64 Java，不走 Rosetta。

## 脚本绕过的上游问题

以下都是实测踩到并已在脚本里处理的，记下来免得以后重复排查。

**1. classpath 顺序决定语言界面会不会崩**

MITE 的 `FontRenderer` 用 `charWidth[getAllowedCharacters().indexOf(c) + 32]` 取字符宽度，而 `charWidth` 只有 256 项。那张字符表来自 classpath 上**最靠前**的 `/font.txt`：

| 来源 | 字符数 | 最大索引 | 结果 |
|---|---|---|---|
| MITE jar | 144 | 175 | 安全 |
| FML jar | 28157（含 CJK） | 28188 | 越界 |

若 FML 排在前面，一打开语言选择界面就抛 `ArrayIndexOutOfBoundsException: Index 7493 out of bounds for length 256` 直接崩。脚本把 MITE jar 放在 classpath 首位。

**2. FML v3.4.3 有三个坏 mixin，且默认配置下是静默失败**

`MinecraftServerTrans` 的 `@Inject` 描述符里写死了混淆名 `Ljv;`（即 `net/minecraft/ServerPlayer`），而 FML 自己已把 jar 重映射为 named，于是描述符对不上。

反直觉的是失败方式：不开注入数量校验时，Mixin 不做核对，这三个坏 mixin 被**静默应用**、产出坏字节码，表现为 **JVM 退出码 0、零异常输出、游戏根本不启动**。加 `-Dmixin.debug.countInjections=true` 后 Mixin 检出它们无效、打印警告并跳过，游戏正常启动。

这三个 mixin 分别负责 mod 入口点调用与玩家登录回调，对无 mod 的纯净 MITE 客户端无实际影响。启动脚本已带该参数。

**3. FML config.json 的 library 版本号写错**

v3.4.3 的 `config.json` 里写的是 `fishmodloader:v3.4.2`，与 `version.properties` 不一致。照抄会让启动器去找不存在的目录。脚本按实际版本修正（FML 的 GUI 安装器自己也做同样的修正）。

**4. FML config.json 缺 assets / assetIndex**

第三方启动器靠这两个字段决定拉哪份资源索引，缺失会导致资源不下载（表现为没声音、没语言文件）。脚本补全为 `legacy`。

**5. 其他**

- gson 条目的 `path` 写的是 2.10.1 而 `url`/`sha1`/`size` 都是 2.11.0。三者互相一致（只是文件名不符），照用即可，无需修。
- ASM 9.3 五个库在 config 里既无 `downloads` 块也不在原版清单中，无处取哈希。脚本内置了 Maven Central 官方 sha1，避免无校验下载。
- 下载加了低速中断（低于 20 KB/s 持续 20 秒即换源）。否则某个源"连上了但几乎不传数据"会永久挂住 —— GitHub 直连 33 KB/s 下载 45 MB 要跑近 2 小时，而脚本既不放弃也不换源，看起来和死机一样。

## 加语言

脚本里每种语言是一个 `i18n_<locale>` 函数，各自给一组 `MSG_*` 赋值。新增语言只要复制 `i18n_en_US`、翻译内容、再在 `i18n_load` 的 `case` 里挂上即可。目前有 `zh_CN`（全量）与 `en_US`（兜底）。

## 已验证范围

在 macOS 26.6（Apple M5, arm64）上实测通过：

- 客户端完整安装：1120/1120 资源、24 个依赖库全部哈希校验通过、natives 解压正确
- MITE 重打包：META-INF 已去签名，class 数 1562 → 1868
- 版本 JSON：合法，两处上游修正均生效
- 客户端启动：进入主菜单，语言选择界面可正常打开（此前会崩）
- 服务端启动：`Done (2.127s)`，世界生成正常，FML mixin 正常应用
- 便携 JRE 自动下载：Azul 源约 20 秒
- 幂等性：重复执行跳过已完成项，约 16 秒结束

未验证：Linux 实机（代码按 `uname` 分支处理，逻辑对称但未在 Linux 上跑过）、Intel Mac、正版账号登录（测试用的是离线参数）。
