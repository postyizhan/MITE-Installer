#!/usr/bin/env bash
#
# Minecraft 1.6.4 MITE + FishModLoader 全自动安装脚本
#   curl -fsSL https://raw.githubusercontent.com/postyizhan/MITE-Installer/main/install.sh | bash
#
# 兼容基线: bash 3.2 (macOS 自带), 不使用关联数组 / ${var^^} / mapfile
# 支持: Linux (x64/arm64), macOS (Intel/Apple Silicon)

set -u

SCRIPT_VERSION="1.2.0"

MC_VERSION="1.6.4"
MITE_ID="1.6.4-MITE"

# 原版 1.6.4 (来自 Mojang version_manifest_v2, 已实测)
MC_JSON_SHA1="b71bae449192fbbe1582ff32fb3765edf0b9b0a8"
MC_CLIENT_SHA1="1703704407101cf72bd88e68579e3696ce733ecd"
MC_CLIENT_SIZE="4745096"
MC_ASSET_INDEX_ID="legacy"
MC_ASSET_INDEX_SHA1="770572e819335b6c0a053f8378ad88eda189fc14"
MC_ASSET_INDEX_SIZE="109634"
MC_ASSET_TOTAL_SIZE="153475165"

# MITE 官方包
MITE_ZIP_NAME="MITE 1.6.4 R196.zip"
MITE_ZIP_URL="https://avernite.ca/MITE/MITE%201.6.4%20R196.zip"
MITE_ZIP_SHA256="fb7ad265d05749e0cd1e54938f6c36ecbe9ea1d4d90d4a04c519615e1e0218c3"

# MITE 镜像源 (本仓库 GitHub / Gitee 的 release 资产, 与官方包逐字节一致, 已实测 sha256)
MITE_REPO="postyizhan/MITE-Installer"
MITE_RELEASE_TAG="MITE_1.6.4_R196"
MITE_RELEASE_FILE="MITE.1.6.4.R196.zip"

# MITE 简体中文翻译仓库 (镜像内容一致, 跟随 master 刷新)
# 顺序即 --no-speedtest 时的默认优先级。
TRANSLATION_SOURCES="gitee codeberg ghfast gh-proxy ghproxy hk github"

# FishModLoader 内置回退版本与已知哈希
FML_REPO="MinecraftIsTooEasy/FishModLoader"
FML_FALLBACK_VERSION="3.4.3"
FML_JAR_SHA256_343="88a19449f451b14f38373018be9fe1a77b60f25ed2dcf5a2068b81e7099a544a"
FML_HDS_SHA256_343="2fd7437ddca25a80c0e977c01f06bafcd0f541a974b28d8af9f4e0c0c553392f"

# FML 依赖的 guava (与 installer 内嵌版逐字节一致, 故从 Maven Central 取)
GUAVA_DEST_VERSION="28.0"
GUAVA_MAVEN_PATH="com/google/guava/guava/28.0-jre/guava-28.0-jre.jar"
GUAVA_SHA256="73e4d6ae5f0e8f9d292a4db83a2479b5468f83d972ac1ff36d6d0b43943b4f91"

# FML config 里 ASM 9.3 五个库既无 downloads 块也不在原版清单中, 无处取 sha1。
# 这里钉住 Maven Central 官方 .sha1 (已与本地复算比对一致), 避免无校验下载。
ASM_PINS="org/ow2/asm/asm/9.3/asm-9.3.jar=8e6300ef51c1d801a7ed62d07cd221aca3a90640=122176
org/ow2/asm/asm-analysis/9.3/asm-analysis-9.3.jar=4b071f211b37c38e0e9f5998550197c8593f6ad8=34276
org/ow2/asm/asm-commons/9.3/asm-commons-9.3.jar=1f2a432d1212f5c352ae607d7b61dcae20c20af5=72716
org/ow2/asm/asm-tree/9.3/asm-tree-9.3.jar=78d2ecd61318b5a58cd04fb237636c0e86b77d97=52669
org/ow2/asm/asm-util/9.3/asm-util-9.3.jar=9595bc05510d0bd4b610188b77333fe4851a1975=85682"

REQUIRED_JAVA_MAJOR="17"
MIN_DISK_MB="1536"
PARALLEL_MAX="16"
# 资源分批下载的每批数量: 批内用 curl -Z 并发, 每批结束即时回显进度
ASSETS_CHUNK="64"

# ============================== 多语言 ==============================
# 加语言只需新增一个 i18n_<locale> 函数并在 i18n_load 里挂上。

i18n_zh_CN() {
MSG_LANG_NAME="简体中文"
MSG_BANNER="MITE 1.6.4 + FishModLoader 安装器"
MSG_BADGE_REPO="仓库"
MSG_BADGE_COMMUNITY="社区入口"
MSG_BADGE_FREE="完全免费"
MSG_BADGE_TELEGRAM="TG"
MSG_BADGE_QQ="QQ群"
MSG_BADGE_CHANNEL="QQ频道"
MSG_BADGE_DISCORD="Discord"
MSG_LOGO=" __  __ ___ _____ _____
|  \/  |_ _|_   _| ____|
| |\/| || |  | | |  _|
| |  | || |  | | | |___
|_|  |_|___| |_| |_____|
"
MSG_REPO_URL="脚本仓库: https://github.com/postyizhan/MITE-Installer"
MSG_COMMUNITY_TELEGRAM="Telegram: https://t.me/moddedmite"
MSG_COMMUNITY_QQ1="1 群 (最大的 MITE Mod 群聊): 795728891"
MSG_COMMUNITY_QQ2="2 群: 1009606363"
MSG_COMMUNITY_QQ_CHANNEL="https://pd.qq.com/s/gti0oomau (频道号: ModdedMITE327)"
MSG_COMMUNITY_DISCORD=": https://discord.gg/2tSuFhZxS8"
MSG_FREE_NOTICE="MITE 本体、Mod、整合包与本脚本均完全免费, 如有发现倒卖请联系我们。"
MSG_USAGE_HEAD="用法"
MSG_USAGE_BODY="  bash install.sh [选项]
  curl -fsSL <脚本地址> | bash
  curl -fsSL <脚本地址> | bash -s -- [选项]

选项:
  --dir <路径>           游戏目录 (默认 ~/.minecraft)
  --server-dir <路径>    服务端目录 (默认 ./mite-server)
  --lang <代码>          界面语言: zh_CN | en_US
  --client               只装客户端
  --server               只装服务端
  --source <名称>        指定下载源 (见 --help 末尾)
  --vanilla-jar <路径>   使用指定的原版 1.6.4.jar
  --mite-zip <路径>      使用本地 MITE zip, 跳过下载
  --fml-version <版本>   锁定 FML 版本 (如 3.4.3)
  --fml-installer <路径> 使用本地 FML installer jar, 跳过下载
  --force-download       忽略本地已有原版 jar, 强制下载
  --no-speedtest         跳过测速, 用默认源
  --yes                  全部用默认值, 不交互
  --version              显示脚本版本
  --help                 显示本帮助

交互运行会依次询问: 安装内容 / 安装路径(留空用默认) / 下载源(含测速选项)。

下载源名称:
  原版: official | bmclapi
  FML : github | ghproxy | gh-proxy | ghfast | hk
  MITE: official | gitee | github | ghproxy | gh-proxy | ghfast | hk
  汉化: gitee | codeberg | ghfast | gh-proxy | ghproxy | hk | github
  多类可用逗号分隔, 例: --source bmclapi,hk"
MSG_ERR_PREFIX="错误"
MSG_WARN_PREFIX="警告"
MSG_INFO_PREFIX="信息"
MSG_OK_PREFIX="完成"
MSG_STEP_PREFIX="步骤"
MSG_DETECT_ENV="检测运行环境"
MSG_OS_UNSUPPORTED="不支持的操作系统: 本脚本仅支持 Linux 与 macOS"
MSG_MISSING_TOOLS="缺少必需工具:"
MSG_INSTALL_HINT="请先安装后重试。"
MSG_DISK_LOW="磁盘剩余空间不足, 需要至少 %s MB, 当前可用 %s MB"
MSG_NO_TTY="检测到管道模式且无法读取终端, 将全部使用默认值 (可用命令行选项覆盖)"
MSG_CHOOSE_MODE="请选择安装内容"
MSG_MODE_CLIENT="客户端 (完整游戏, 含 MITE + FML)"
MSG_MODE_SERVER="服务端 (HDS 整合包, 开箱即用)"
MSG_MODE_BOTH="客户端 + 服务端"
MSG_PROMPT_CHOICE="输入编号"
MSG_INVALID_CHOICE="无效选择, 请重新输入"
MSG_DEFAULT_TAG="(默认)"
MSG_ASK_MC_DIR="游戏安装目录 (不填则用默认)"
MSG_ASK_SERVER_DIR="服务端安装目录 (不填则用默认)"
MSG_SPEEDTEST_HEAD="正在测速下载源"
MSG_SPEEDTEST_CATEGORY="测速类别: %s"
MSG_SPEEDTEST_SKIP="已跳过测速"
MSG_SPEEDTEST_ITEM="  %-22s %s"
MSG_SPEEDTEST_FAIL="不可用"
MSG_SOURCE_ASK="请选择下载源"
MSG_SOURCE_AUTO="自动测速, 选最快 (推荐)"
MSG_SRC_LABEL_VANILLA="原版资源下载源"
MSG_SRC_LABEL_FML="FishModLoader 下载源"
MSG_SRC_LABEL_MITE="MITE 安装包下载源"
MSG_SRC_LABEL_TRANSLATION="简体中文语言包下载源"
MSG_FINAL_SOURCES="最终下载源: 原版=%s, FishModLoader=%s, MITE=%s, 汉化=%s"
MSG_SOURCE_FORCED="已指定下载源: %s"
MSG_ALL_SOURCES_FAIL="所有下载源均不可用, 请检查网络连接"
MSG_STEP_VANILLA="准备原版 %s 客户端"
MSG_FOUND_LOCAL_JAR="发现本地原版 jar: %s"
MSG_LOCAL_JAR_OK="校验通过, 将复用本地文件"
MSG_LOCAL_JAR_BAD="校验失败 (SHA-1 不符), 该文件可能已被修改"
MSG_ASK_USE_LOCAL="是否使用本地已有的原版 jar?"
MSG_ASK_YES="是"
MSG_ASK_NO="否, 重新下载"
MSG_NO_LOCAL_JAR="未发现本地原版 jar, 将下载"
MSG_STEP_META="拉取版本元数据"
MSG_STEP_LIBS="下载依赖库"
MSG_STEP_NATIVES="解压本地库 (natives)"
MSG_STEP_ASSETS="下载游戏资源 (legacy 布局, 约 146 MB)"
MSG_STEP_MITE="获取 MITE %s"
MSG_MITE_LOCAL="使用本地 MITE zip: %s"
MSG_STEP_REPACK="重打包 MITE 客户端 jar"
MSG_REPACK_STRIP="移除 META-INF (去签名)"
MSG_REPACK_MERGE="合并 MITE class 文件"
MSG_REPACK_ZIP="打包为 %s"
MSG_STEP_FML="注入 FishModLoader"
MSG_FML_LATEST="从 %s 获取最新版本: %s"
MSG_FML_API_FAIL="FishModLoader 源不可达, 回退到内置版本 %s"
MSG_STEP_JSON="生成版本配置 %s"
MSG_JSON_FIX_VER="已修正上游版本号错误: fishmodloader %s -> %s"
MSG_JSON_ADD_ASSETS="已补充缺失的 assets / assetIndex 字段"
MSG_STEP_RESPACK="安装 MITE 资源包"
MSG_TRANSLATION_FETCH="下载简体中文语言包"
MSG_TRANSLATION_MERGE="将简体中文翻译合并进 MITE 资源包"
MSG_TRANSLATION_MISSING="简体中文语言包缺少必需文件: %s"
MSG_TRANSLATION_FAILED="简体中文语言包安装失败, 原有 MITE 资源包未改动"
MSG_STEP_JAVA="准备 Java 运行环境"
MSG_JAVA_FOUND="已找到 Java %s: %s"
MSG_JAVA_NOT_FOUND="未找到 Java %s"
MSG_JAVA_DOWNLOAD="正在下载便携版 JRE %s (不会影响系统 Java)"
MSG_JAVA_DL_OK="便携版 JRE 已安装到 %s"
MSG_JAVA_DL_FAIL="便携版 JRE 下载失败, 请手动安装 Java %s 后重试"
MSG_ROSETTA_NEEDED="Apple Silicon 说明: 1.6.4 的 lwjgl 只有 x86_64 版本, 需通过 Rosetta 2 运行"
MSG_ROSETTA_OK="Rosetta 2 已就绪"
MSG_ROSETTA_MISSING="未检测到 Rosetta 2, 请执行: softwareupdate --install-rosetta"
MSG_NEED_JDK_FOR_JAR="打包需要 zip 或 python3, 两者均缺失, 将下载 JDK 而非 JRE"
MSG_STEP_LAUNCHER="生成启动脚本"
MSG_STEP_SERVER="安装服务端"
MSG_SERVER_DL="下载服务端核心 %s"
MSG_EULA_ASK="是否同意 Minecraft EULA (https://aka.ms/MinecraftEULA)?"
MSG_EULA_ACCEPTED="已写入 eula.txt (eula=true)"
MSG_EULA_DECLINED="未同意 EULA, 已跳过 eula.txt, 服务端首次启动会自行退出"
MSG_SERVER_PROPS_KEEP="server.properties 已存在, 保持不变"
MSG_SERVER_PROPS_NEW="已生成默认 server.properties"
MSG_DOWNLOADING="下载中"
MSG_DL_PROGRESS="  %s / %s"
MSG_DL_RETRY="下载失败, 换源重试: %s"
MSG_DL_FAIL_ALL="文件下载失败 (已尝试所有源): %s"
MSG_HASH_MISMATCH="校验失败: %s (期望 %s)"
MSG_SKIP_EXISTS="跳过已完成: %s"
MSG_VERIFY="正在自检安装结果"
MSG_VERIFY_OK="自检通过"
MSG_VERIFY_FAIL="自检发现问题:"
MSG_DONE_CLIENT="客户端安装完成"
MSG_DONE_SERVER="服务端安装完成"
MSG_NEXT_HEAD="后续操作"
MSG_NEXT_LAUNCH="直接启动游戏:
    %s"
MSG_NEXT_LAUNCHER="或在 HMCL / PCL 等启动器中刷新版本列表, 选择 %s"
MSG_NEXT_SERVER="启动服务端:
    %s"
MSG_TMP_KEPT="临时文件已保留以便排查: %s"
MSG_INTERRUPTED="已中断"
MSG_ELAPSED="耗时 %s 秒"
}

i18n_en_US() {
MSG_LANG_NAME="English"
MSG_BANNER="MITE 1.6.4 + FishModLoader Installer"
MSG_BADGE_REPO="REPO"
MSG_BADGE_COMMUNITY="COMMUNITY"
MSG_BADGE_FREE="FREE"
MSG_BADGE_TELEGRAM="TG"
MSG_BADGE_QQ="QQ"
MSG_BADGE_CHANNEL="QQ CHANNEL"
MSG_BADGE_DISCORD="DISCORD"
MSG_LOGO=" __  __ ___ _____ _____
|  \/  |_ _|_   _| ____|
| |\/| || |  | | |  _|
| |  | || |  | | | |___
|_|  |_|___| |_| |_____|
"
MSG_REPO_URL="Script repository: https://github.com/postyizhan/MITE-Installer"
MSG_COMMUNITY_TELEGRAM="Telegram: https://t.me/moddedmite"
MSG_COMMUNITY_QQ1="group 1 (largest MITE Mod group): 795728891"
MSG_COMMUNITY_QQ2="group 2: 1009606363"
MSG_COMMUNITY_QQ_CHANNEL="https://pd.qq.com/s/gti0oomau (channel: ModdedMITE327)"
MSG_COMMUNITY_DISCORD="https://discord.gg/2tSuFhZxS8"
MSG_FREE_NOTICE="MITE, Mods, modpacks, and this installer are completely free. Contact us about reselling."
MSG_USAGE_HEAD="Usage"
MSG_USAGE_BODY="  bash install.sh [options]
  curl -fsSL <script-url> | bash
  curl -fsSL <script-url> | bash -s -- [options]

Options:
  --dir <path>           Game directory (default ~/.minecraft)
  --server-dir <path>    Server directory (default ./mite-server)
  --lang <code>          UI language: zh_CN | en_US
  --client               Client only
  --server               Server only
  --source <name>        Pick download source (see below)
  --vanilla-jar <path>   Use a specific vanilla 1.6.4.jar
  --mite-zip <path>      Use a local MITE zip, skip download
  --fml-version <ver>    Pin FML version (e.g. 3.4.3)
  --fml-installer <path> Use a local FML installer jar, skip download
  --force-download       Ignore local vanilla jar, always download
  --no-speedtest         Skip speed test, use defaults
  --yes                  Non-interactive, accept all defaults
  --version              Print script version
  --help                 Show this help

Interactive mode asks: install mode / install paths (empty = default) / download sources (with speed-test option).

Source names:
  vanilla: official | bmclapi
  FML    : github | ghproxy | gh-proxy | ghfast | hk
  MITE   : official | gitee | github | ghproxy | gh-proxy | ghfast | hk
  Chinese: gitee | codeberg | ghfast | gh-proxy | ghproxy | hk | github
  Comma-separated, e.g. --source bmclapi,hk"
MSG_ERR_PREFIX="ERROR"
MSG_WARN_PREFIX="WARN"
MSG_INFO_PREFIX="INFO"
MSG_OK_PREFIX="DONE"
MSG_STEP_PREFIX="STEP"
MSG_DETECT_ENV="Detecting environment"
MSG_OS_UNSUPPORTED="Unsupported OS: this script supports Linux and macOS only"
MSG_MISSING_TOOLS="Missing required tools:"
MSG_INSTALL_HINT="Please install them and retry."
MSG_DISK_LOW="Not enough disk space: need at least %s MB, only %s MB available"
MSG_NO_TTY="Piped mode with no terminal available; using defaults (override with CLI options)"
MSG_CHOOSE_MODE="What would you like to install?"
MSG_MODE_CLIENT="Client (full game with MITE + FML)"
MSG_MODE_SERVER="Server (HDS bundle, ready to run)"
MSG_MODE_BOTH="Client + Server"
MSG_PROMPT_CHOICE="Enter number"
MSG_INVALID_CHOICE="Invalid choice, try again"
MSG_DEFAULT_TAG="(default)"
MSG_ASK_MC_DIR="Game install directory (leave empty for default)"
MSG_ASK_SERVER_DIR="Server install directory (leave empty for default)"
MSG_SPEEDTEST_HEAD="Testing download sources"
MSG_SPEEDTEST_CATEGORY="Speed-test category: %s"
MSG_SPEEDTEST_SKIP="Speed test skipped"
MSG_SPEEDTEST_ITEM="  %-22s %s"
MSG_SPEEDTEST_FAIL="unreachable"
MSG_SOURCE_ASK="Pick download sources"
MSG_SOURCE_AUTO="Auto speed-test, pick fastest (recommended)"
MSG_SRC_LABEL_VANILLA="Vanilla assets source"
MSG_SRC_LABEL_FML="FishModLoader source"
MSG_SRC_LABEL_MITE="MITE bundle source"
MSG_SRC_LABEL_TRANSLATION="Simplified Chinese translation source"
MSG_FINAL_SOURCES="Final sources: vanilla=%s, FishModLoader=%s, MITE=%s, Chinese=%s"
MSG_SOURCE_FORCED="Using source: %s"
MSG_ALL_SOURCES_FAIL="No download source reachable, please check your network"
MSG_STEP_VANILLA="Preparing vanilla %s client"
MSG_FOUND_LOCAL_JAR="Found local vanilla jar: %s"
MSG_LOCAL_JAR_OK="Checksum OK, reusing local file"
MSG_LOCAL_JAR_BAD="Checksum mismatch (SHA-1), this file may have been modified"
MSG_ASK_USE_LOCAL="Use the existing local vanilla jar?"
MSG_ASK_YES="Yes"
MSG_ASK_NO="No, download a fresh copy"
MSG_NO_LOCAL_JAR="No local vanilla jar found, will download"
MSG_STEP_META="Fetching version metadata"
MSG_STEP_LIBS="Downloading libraries"
MSG_STEP_NATIVES="Extracting natives"
MSG_STEP_ASSETS="Downloading assets (legacy layout, ~146 MB)"
MSG_STEP_MITE="Fetching MITE %s"
MSG_MITE_LOCAL="Using local MITE zip: %s"
MSG_STEP_REPACK="Repacking MITE client jar"
MSG_REPACK_STRIP="Removing META-INF (unsigning)"
MSG_REPACK_MERGE="Merging MITE class files"
MSG_REPACK_ZIP="Packing into %s"
MSG_STEP_FML="Injecting FishModLoader"
MSG_FML_LATEST="Latest version from %s: %s"
MSG_FML_API_FAIL="FishModLoader sources unreachable, falling back to bundled version %s"
MSG_STEP_JSON="Writing version config %s"
MSG_JSON_FIX_VER="Fixed upstream version mismatch: fishmodloader %s -> %s"
MSG_JSON_ADD_ASSETS="Added missing assets / assetIndex fields"
MSG_STEP_RESPACK="Installing MITE resource pack"
MSG_TRANSLATION_FETCH="Downloading Simplified Chinese translation"
MSG_TRANSLATION_MERGE="Merging Simplified Chinese translation into the MITE resource pack"
MSG_TRANSLATION_MISSING="Translation archive is missing required file: %s"
MSG_TRANSLATION_FAILED="Translation installation failed; the existing MITE resource pack was left unchanged"
MSG_STEP_JAVA="Preparing Java runtime"
MSG_JAVA_FOUND="Found Java %s: %s"
MSG_JAVA_NOT_FOUND="Java %s not found"
MSG_JAVA_DOWNLOAD="Downloading portable JRE %s (your system Java is untouched)"
MSG_JAVA_DL_OK="Portable JRE installed at %s"
MSG_JAVA_DL_FAIL="Portable JRE download failed, please install Java %s manually"
MSG_ROSETTA_NEEDED="Apple Silicon note: lwjgl for 1.6.4 is x86_64 only, it runs via Rosetta 2"
MSG_ROSETTA_OK="Rosetta 2 is ready"
MSG_ROSETTA_MISSING="Rosetta 2 not found, please run: softwareupdate --install-rosetta"
MSG_NEED_JDK_FOR_JAR="Packing needs zip or python3; neither found, downloading a JDK instead of a JRE"
MSG_STEP_LAUNCHER="Generating launch script"
MSG_STEP_SERVER="Installing server"
MSG_SERVER_DL="Downloading server core %s"
MSG_EULA_ASK="Do you accept the Minecraft EULA (https://aka.ms/MinecraftEULA)?"
MSG_EULA_ACCEPTED="Wrote eula.txt (eula=true)"
MSG_EULA_DECLINED="EULA not accepted, eula.txt skipped; the server will exit on first run"
MSG_SERVER_PROPS_KEEP="server.properties already exists, left unchanged"
MSG_SERVER_PROPS_NEW="Generated default server.properties"
MSG_DOWNLOADING="Downloading"
MSG_DL_PROGRESS="  %s / %s"
MSG_DL_RETRY="Download failed, trying next source: %s"
MSG_DL_FAIL_ALL="Download failed from every source: %s"
MSG_HASH_MISMATCH="Checksum mismatch: %s (expected %s)"
MSG_SKIP_EXISTS="Already complete, skipping: %s"
MSG_VERIFY="Verifying installation"
MSG_VERIFY_OK="Verification passed"
MSG_VERIFY_FAIL="Verification found problems:"
MSG_DONE_CLIENT="Client installation complete"
MSG_DONE_SERVER="Server installation complete"
MSG_NEXT_HEAD="Next steps"
MSG_NEXT_LAUNCH="Launch the game directly:
    %s"
MSG_NEXT_LAUNCHER="Or refresh the version list in HMCL / PCL and pick %s"
MSG_NEXT_SERVER="Start the server:
    %s"
MSG_TMP_KEPT="Temporary files kept for diagnosis: %s"
MSG_INTERRUPTED="Interrupted"
MSG_ELAPSED="Took %s seconds"
}

i18n_load() {
  case "$1" in
    zh_CN|zh|zh-CN|zh_TW|zh-TW|zh_HK) i18n_zh_CN ;;
    *) i18n_en_US ;;
  esac
}

detect_lang() {
  if [ -n "${OPT_LANG:-}" ]; then printf '%s\n' "$OPT_LANG"; return; fi
  _l="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
  case "$_l" in
    zh*) printf 'zh_CN\n' ;;
    "")  printf 'zh_CN\n' ;;
    *)   printf 'en_US\n' ;;
  esac
}

# ============================== 输出 ==============================

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$(printf '\033[0m'); C_BOLD=$(printf '\033[1m'); C_DIM=$(printf '\033[2m')
  C_RED=$(printf '\033[31m'); C_GREEN=$(printf '\033[32m')
  C_YELLOW=$(printf '\033[33m'); C_BLUE=$(printf '\033[36m'); C_MAGENTA=$(printf '\033[35m')
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_MAGENTA=""
fi

STEP_NO=0
STEP_TOTAL=0

log_info() { printf '%s\n' "${C_BLUE}[${MSG_INFO_PREFIX}]${C_RESET} $*"; }
log_warn() { printf '%s\n' "${C_YELLOW}[${MSG_WARN_PREFIX}]${C_RESET} $*" >&2; }
log_err()  { printf '%s\n' "${C_RED}[${MSG_ERR_PREFIX}]${C_RESET} $*" >&2; }
log_ok()   { printf '%s\n' "${C_GREEN}[${MSG_OK_PREFIX}]${C_RESET} $*"; }
log_dim()  { printf '%s\n' "${C_DIM}$*${C_RESET}"; }

log_step() {
  STEP_NO=$((STEP_NO + 1))
  printf '\n%s\n' "${C_BOLD}${C_BLUE}==>${C_RESET} ${C_BOLD}[${STEP_NO}/${STEP_TOTAL}] $*${C_RESET}"
}

die() { log_err "$*"; exit 1; }

# ============================== 交互 ==============================
# curl | bash 下 stdin 是脚本本身, 交互必须走 /dev/tty

TTY_OK=0
init_tty() {
  if [ "${OPT_YES:-0}" = "1" ]; then TTY_OK=0; return; fi
  if [ -e /dev/tty ] && (exec 3<>/dev/tty) 2>/dev/null; then TTY_OK=1; else TTY_OK=0; fi
}

# ask_choice <提示> <默认序号> <选项1> [选项2 ...]  -> 回显所选序号(1起)
ask_choice() {
  _prompt="$1"; shift
  _default="$1"; shift
  _n=$#
  if [ "$TTY_OK" != "1" ]; then printf '%s\n' "$_default"; return; fi
  printf '\n%s\n' "${C_BOLD}${_prompt}${C_RESET}" >/dev/tty
  _i=1
  for _o in "$@"; do
    if [ "$_i" = "$_default" ]; then
      printf '  %s) %s %s\n' "$_i" "$_o" "${C_DIM}${MSG_DEFAULT_TAG}${C_RESET}" >/dev/tty
    else
      printf '  %s) %s\n' "$_i" "$_o" >/dev/tty
    fi
    _i=$((_i + 1))
  done
  while :; do
    printf '%s [%s]: ' "$MSG_PROMPT_CHOICE" "$_default" >/dev/tty
    if ! IFS= read -r _ans </dev/tty; then printf '%s\n' "$_default"; return; fi
    [ -z "$_ans" ] && { printf '%s\n' "$_default"; return; }
    case "$_ans" in
      *[!0-9]*|"") : ;;
      *) if [ "$_ans" -ge 1 ] && [ "$_ans" -le "$_n" ]; then printf '%s\n' "$_ans"; return; fi ;;
    esac
    printf '%s\n' "${C_YELLOW}${MSG_INVALID_CHOICE}${C_RESET}" >/dev/tty
  done
}

# ask_yesno <提示> <默认 y|n> -> 0 表示 yes
ask_yesno() {
  _q="$1"; _d="$2"
  if [ "$TTY_OK" != "1" ]; then [ "$_d" = "y" ] && return 0 || return 1; fi
  _hint="[y/N]"; [ "$_d" = "y" ] && _hint="[Y/n]"
  while :; do
    printf '%s %s ' "${C_BOLD}${_q}${C_RESET}" "$_hint" >/dev/tty
    if ! IFS= read -r _a </dev/tty; then [ "$_d" = "y" ] && return 0 || return 1; fi
    [ -z "$_a" ] && { [ "$_d" = "y" ] && return 0 || return 1; }
    case "$_a" in
      y|Y|yes|YES|Yes|是) return 0 ;;
      n|N|no|NO|No|否)   return 1 ;;
      *) printf '%s\n' "${C_YELLOW}${MSG_INVALID_CHOICE}${C_RESET}" >/dev/tty ;;
    esac
  done
}

# ask_input <提示> <默认值> -> 回显输入 (空输入回显默认值; 自动展开开头的 ~)
ask_input() {
  local _prompt _default _ans
  _prompt="$1"; _default="$2"
  if [ "$TTY_OK" != "1" ]; then printf '%s\n' "$_default"; return; fi
  printf '%s [%s]: ' "${C_BOLD}${_prompt}${C_RESET}" "$_default" >/dev/tty
  if ! IFS= read -r _ans </dev/tty; then printf '%s\n' "$_default"; return; fi
  [ -z "$_ans" ] && _ans="$_default"
  if [ "${_ans#\~}" != "$_ans" ]; then _ans="$HOME${_ans#\~}"; fi
  printf '%s\n' "$_ans"
}

# ask_source_category <类别> <标题> <源列表> -> 回显 "auto" 或用户选中的源名
# 选项 1 固定为"自动测速选最快", 其余依次为列表里的源。空输入同选 1。
ask_source_category() {
  local _cat _label _list _i _s _n _ans
  _cat="$1"; _label="$2"; _list="$3"
  if [ "$TTY_OK" != "1" ]; then printf 'auto\n'; return; fi
  printf '\n%s\n' "${C_BOLD}${_label}${C_RESET}" >/dev/tty
  printf '  1) %s\n' "${C_GREEN}${MSG_SOURCE_AUTO}${C_RESET}" >/dev/tty
  _i=2
  for _s in $_list; do
    printf '  %s) %s\n' "$_i" "$_s" >/dev/tty
    _i=$((_i+1))
  done
  while :; do
    printf '%s [1]: ' "$MSG_PROMPT_CHOICE" >/dev/tty
    if ! IFS= read -r _ans </dev/tty; then printf 'auto\n'; return; fi
    [ -z "$_ans" ] && { printf 'auto\n'; return; }
    case "$_ans" in
      1)             printf 'auto\n'; return ;;
      *[!0-9]*|"")   : ;;
      *)
        _n=$((_ans - 1))
        _s=$(printf '%s\n' $_list | sed -n "${_n}p")
        [ -n "$_s" ] && { printf '%s\n' "$_s"; return; }
        ;;
    esac
    printf '%s\n' "${C_YELLOW}${MSG_INVALID_CHOICE}${C_RESET}" >/dev/tty
  done
}

# ============================== 临时目录与清理 ==============================

TMP_ROOT=""
KEEP_TMP=0

init_tmp() {
  TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/mite-install.XXXXXX") || die "mktemp failed"
}

cleanup() {
  _code=$?
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    if [ "$KEEP_TMP" = "1" ] || [ "$_code" != "0" ]; then
      printf '%s\n' "$(printf "$MSG_TMP_KEPT" "$TMP_ROOT")" >&2
    else
      rm -rf "$TMP_ROOT"
    fi
  fi
  return $_code
}

on_interrupt() { printf '\n%s\n' "${C_YELLOW}${MSG_INTERRUPTED}${C_RESET}" >&2; KEEP_TMP=1; exit 130; }

trap cleanup EXIT
trap on_interrupt INT TERM

# ============================== 工具函数 ==============================

have() { command -v "$1" >/dev/null 2>&1; }

sha1_of() {
  if have shasum; then shasum -a 1 "$1" 2>/dev/null | awk '{print $1}'
  elif have sha1sum; then sha1sum "$1" 2>/dev/null | awk '{print $1}'
  elif have openssl; then openssl dgst -sha1 "$1" 2>/dev/null | awk '{print $NF}'
  fi
}

sha256_of() {
  if have shasum; then shasum -a 256 "$1" 2>/dev/null | awk '{print $1}'
  elif have sha256sum; then sha256sum "$1" 2>/dev/null | awk '{print $1}'
  elif have openssl; then openssl dgst -sha256 "$1" 2>/dev/null | awk '{print $NF}'
  fi
}

size_of() {
  [ -f "$1" ] || { printf '0\n'; return; }
  if stat -f%z "$1" >/dev/null 2>&1; then stat -f%z "$1"
  else stat -c%s "$1" 2>/dev/null || printf '0\n'
  fi
}

# 大小人类可读
human_size() {
  _b="$1"
  if [ "$_b" -ge 1048576 ]; then awk -v b="$_b" 'BEGIN{printf "%.1f MB", b/1048576}'
  elif [ "$_b" -ge 1024 ]; then awk -v b="$_b" 'BEGIN{printf "%.0f KB", b/1024}'
  else printf '%s B\n' "$_b"
  fi
}

lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# ============================== 参数解析 ==============================

OPT_LANG=""
OPT_DIR=""
OPT_SERVER_DIR=""
OPT_MODE=""            # client | server | both
OPT_SOURCE=""
OPT_VANILLA_JAR=""
OPT_MITE_ZIP=""
OPT_FML_VERSION=""
OPT_FML_INSTALLER=""
OPT_FORCE_DOWNLOAD=0
OPT_NO_SPEEDTEST=0
OPT_YES=0
OPT_HELP=0
OPT_VERSION=0

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --dir)         OPT_DIR="${2:-}"; shift 2 ;;
      --dir=*)       OPT_DIR="${1#*=}"; shift ;;
      --server-dir)  OPT_SERVER_DIR="${2:-}"; shift 2 ;;
      --server-dir=*) OPT_SERVER_DIR="${1#*=}"; shift ;;
      --lang)        OPT_LANG="${2:-}"; shift 2 ;;
      --lang=*)      OPT_LANG="${1#*=}"; shift ;;
      --client)      OPT_MODE="client"; shift ;;
      --server)      OPT_MODE="server"; shift ;;
      --both)        OPT_MODE="both"; shift ;;
      --source)      OPT_SOURCE="${2:-}"; shift 2 ;;
      --source=*)    OPT_SOURCE="${1#*=}"; shift ;;
      --vanilla-jar) OPT_VANILLA_JAR="${2:-}"; shift 2 ;;
      --vanilla-jar=*) OPT_VANILLA_JAR="${1#*=}"; shift ;;
      --mite-zip)    OPT_MITE_ZIP="${2:-}"; shift 2 ;;
      --mite-zip=*)  OPT_MITE_ZIP="${1#*=}"; shift ;;
      --fml-version) OPT_FML_VERSION="${2:-}"; shift 2 ;;
      --fml-version=*) OPT_FML_VERSION="${1#*=}"; shift ;;
      --fml-installer) OPT_FML_INSTALLER="${2:-}"; shift 2 ;;
      --fml-installer=*) OPT_FML_INSTALLER="${1#*=}"; shift ;;
      --force-download) OPT_FORCE_DOWNLOAD=1; shift ;;
      --no-speedtest)   OPT_NO_SPEEDTEST=1; shift ;;
      --yes|-y)      OPT_YES=1; shift ;;
      --version|-V)  OPT_VERSION=1; shift ;;
      --help|-h)     OPT_HELP=1; shift ;;
      *) printf 'Unknown option: %s\n' "$1" >&2; OPT_HELP=1; shift ;;
    esac
  done
}

# ============================== 平台检测 ==============================

OS_NAME=""        # linux | osx
OS_ARCH=""        # x64 | aarch64
NATIVE_CLS=""     # natives-linux | natives-osx
IS_APPLE_SILICON=0

detect_platform() {
  case "$(uname -s)" in
    Linux)  OS_NAME="linux"; NATIVE_CLS="natives-linux" ;;
    Darwin) OS_NAME="osx";   NATIVE_CLS="natives-osx" ;;
    *) die "$MSG_OS_UNSUPPORTED" ;;
  esac
  case "$(uname -m)" in
    x86_64|amd64)  OS_ARCH="x64" ;;
    arm64|aarch64) OS_ARCH="aarch64" ;;
    *) OS_ARCH="x64" ;;
  esac
  if [ "$OS_NAME" = "osx" ] && [ "$OS_ARCH" = "aarch64" ]; then IS_APPLE_SILICON=1; fi
}

# 打包/解包能力: 影响是否需要 JDK
UNZIP_TOOL=""
ZIP_TOOL=""
HAS_PY3=0

detect_tools() {
  have python3 && HAS_PY3=1
  if have unzip; then UNZIP_TOOL="unzip"
  elif [ "$HAS_PY3" = "1" ]; then UNZIP_TOOL="python3"
  elif have jar; then UNZIP_TOOL="jar"
  fi
  if have zip; then ZIP_TOOL="zip"
  elif [ "$HAS_PY3" = "1" ]; then ZIP_TOOL="python3"
  elif have jar; then ZIP_TOOL="jar"
  fi
}

preflight() {
  log_step "$MSG_DETECT_ENV"
  detect_platform
  detect_tools

  _missing=""
  have curl || _missing="$_missing curl"
  [ -n "$UNZIP_TOOL" ] || _missing="$_missing unzip/python3"
  [ -n "$(sha1_of /dev/null)" ] || _missing="$_missing shasum/sha1sum/openssl"
  have awk || _missing="$_missing awk"
  if [ -n "$_missing" ]; then
    log_err "$MSG_MISSING_TOOLS$_missing"
    die "$MSG_INSTALL_HINT"
  fi

  log_dim "  OS=$OS_NAME arch=$OS_ARCH natives=$NATIVE_CLS unzip=$UNZIP_TOOL zip=${ZIP_TOOL:-none}"
  [ "$TTY_OK" = "1" ] || log_warn "$MSG_NO_TTY"
}

check_disk() {
  _dir="$1"
  _probe="$_dir"
  while [ ! -d "$_probe" ] && [ "$_probe" != "/" ]; do _probe=$(dirname "$_probe"); done
  _avail=$(df -k "$_probe" 2>/dev/null | awk 'NR==2{print int($4/1024)}')
  [ -z "$_avail" ] && return 0
  if [ "$_avail" -lt "$MIN_DISK_MB" ]; then
    log_warn "$(printf "$MSG_DISK_LOW" "$MIN_DISK_MB" "$_avail")"
  fi
}

# ============================== 下载源 ==============================
# bash 3.2 无关联数组, 用 name|field 的平铺函数代替。
#
# 原版源: official / bmclapi
#   BMCLAPI 必须跟随 302 (-L), 已实测。
# FML 源: github / ghproxy / gh-proxy / ghfast / hk
#   github.com 直连在国内常超时, 已实测, 故默认带镜像。
# MITE 源: official / gitee + FML 的 github 系镜像
#   gitee 与 github 均为本仓库 release 资产, 与官方包逐字节一致, 已实测。

VANILLA_SOURCES="official bmclapi"
# 顺序即 --no-speedtest 时的默认优先级, 按实测速度排(同一网络下对 45MB 的 HDS 核心):
#   ghfast 246 KB/s > gh-proxy 178 KB/s > hk 43 KB/s > github 直连 33 KB/s
# GitHub 直连放最后: 它在国内既慢又常超时, 不该是默认首选。
FML_SOURCES="ghfast gh-proxy ghproxy hk github"
# MITE 源: gitee(国内直连镜像) + FML 的 github 系镜像 + official(官网)。
# 顺序即 --no-speedtest 时的默认优先级: 国内源/代理在前, 官方站放最后。
MITE_SOURCES="gitee ghfast gh-proxy ghproxy hk github official"

# 简体中文翻译源: 国内镜像优先, GitHub 直连最后。
# master.zip 不提供固定哈希, 下载后会校验 ZIP 结构中的三个必需文件。

# 原版: meta 基址
src_meta_base() {
  case "$1" in
    official) printf 'https://piston-meta.mojang.com' ;;
    bmclapi)  printf 'https://bmclapi2.bangbang93.com' ;;
  esac
}
# 原版: launcher objects 基址 (client.jar)
src_object_base() {
  case "$1" in
    official) printf 'https://launcher.mojang.com' ;;
    bmclapi)  printf 'https://bmclapi2.bangbang93.com' ;;
  esac
}
# 原版: libraries 基址
src_lib_base() {
  case "$1" in
    official) printf 'https://libraries.minecraft.net' ;;
    bmclapi)  printf 'https://bmclapi2.bangbang93.com/maven' ;;
  esac
}
# 原版: assets 基址
src_asset_base() {
  case "$1" in
    official) printf 'https://resources.download.minecraft.net' ;;
    bmclapi)  printf 'https://bmclapi2.bangbang93.com/assets' ;;
  esac
}
# Maven Central (guava) 基址
src_maven_base() {
  case "$1" in
    bmclapi) printf 'https://bmclapi2.bangbang93.com/maven' ;;
    *)       printf 'https://repo1.maven.org/maven2' ;;
  esac
}
# FML: 把 github.com 的完整 URL 包装成镜像 URL
fml_wrap_url() {
  _s="$1"; _u="$2"
  case "$_s" in
    github)   printf '%s' "$_u" ;;
    ghproxy)  printf 'https://ghproxy.net/%s' "$_u" ;;
    gh-proxy) printf 'https://gh-proxy.com/%s' "$_u" ;;
    ghfast)   printf 'https://ghfast.top/%s' "$_u" ;;
    hk)       printf 'https://hk.gh-proxy.com/%s' "$_u" ;;
    *)        printf '%s' "$_u" ;;
  esac
}

# MITE: 各源实际 URL (official 为官网, gitee 为国内镜像, 其余走 github 系镜像)
mite_url() {
  case "$1" in
    official) printf '%s' "$MITE_ZIP_URL" ;;
    gitee)    printf 'https://gitee.com/%s/releases/download/%s/%s' "$MITE_REPO" "$MITE_RELEASE_TAG" "$MITE_RELEASE_FILE" ;;
    *)        fml_wrap_url "$1" "https://github.com/${MITE_REPO}/releases/download/${MITE_RELEASE_TAG}/${MITE_RELEASE_FILE}" ;;
  esac
}

# 简体中文翻译仓库: Gitee/Codeberg 直连, 其余为 GitHub 代理镜像。
translation_url() {
  case "$1" in
    gitee)   printf 'https://gitee.com/postyizhan/MITE-CN-Translation/repository/archive/master.zip' ;;
    codeberg) printf 'https://codeberg.org/postyizhan/MITE-CN-Translation/archive/master.zip' ;;
    github)  printf 'https://github.com/MinecraftIsTooEasy/MITE-CN-Translation/archive/refs/heads/master.zip' ;;
    *)        fml_wrap_url "$1" "https://github.com/MinecraftIsTooEasy/MITE-CN-Translation/archive/refs/heads/master.zip" ;;
  esac
}

# ============================== 测速 ==============================
# 对每个源发一个 256 KiB 的 Range 请求, 用实际收到的字节数 / 耗时算速度。
# 镜像若不支持 Range 会返回整文件, 此时被 --max-time 截断也无妨:
# 只要收到过字节就能算出速度, 只有 0 字节才判为不可用。

PROBE_BYTES="262143"
PROBE_TIMEOUT="8"

# probe_url <类别> <源>  -> 用于测速的 URL
probe_url() {
  case "$1" in
    vanilla) printf '%s/v1/objects/%s/client.jar' "$(src_object_base "$2")" "$MC_CLIENT_SHA1" ;;
    fml)     fml_wrap_url "$2" "https://github.com/${FML_REPO}/releases/download/${FML_FALLBACK_VERSION}/FishModLoader-v${FML_FALLBACK_VERSION}.jar" ;;
    mite)    mite_url "$2" ;;
    translation) translation_url "$2" ;;
  esac
}

# 回显 "<KB/s>" , 不可用回显空
measure_source() {
  local _url _out _bytes _time
  _url="$1"
  _out=$(curl -sL --max-time "$PROBE_TIMEOUT" -r "0-${PROBE_BYTES}" \
              -o /dev/null -w '%{size_download} %{time_total}' "$_url" 2>/dev/null)
  _bytes=$(printf '%s' "$_out" | awk '{print $1+0}')
  _time=$(printf '%s' "$_out" | awk '{print $2+0}')
  [ "${_bytes:-0}" -gt 0 ] || return 1
  awk -v b="$_bytes" -v t="$_time" 'BEGIN{ if (t<=0) t=0.001; printf "%.0f", (b/1024)/t }'
}

SPEED_BEST_VANILLA=""
SPEED_BEST_FML=""
SPEED_BEST_MITE=""
SPEED_BEST_TRANSLATION=""

# speedtest_category <类别> <源列表>  -> 设置 SPEED_BEST_*
speedtest_category() {
  local _cat _list _best _best_kbps _s _u _kbps
  _cat="$1"; _list="$2"
  _best=""; _best_kbps=0
  case "$_cat" in
    vanilla) log_dim "$(printf "$MSG_SPEEDTEST_CATEGORY" "$MSG_SRC_LABEL_VANILLA")" ;;
    fml)     log_dim "$(printf "$MSG_SPEEDTEST_CATEGORY" "$MSG_SRC_LABEL_FML")" ;;
    mite)    log_dim "$(printf "$MSG_SPEEDTEST_CATEGORY" "$MSG_SRC_LABEL_MITE")" ;;
    translation) log_dim "$(printf "$MSG_SPEEDTEST_CATEGORY" "$MSG_SRC_LABEL_TRANSLATION")" ;;
  esac
  for _s in $_list; do
    _u=$(probe_url "$_cat" "$_s")
    _kbps=$(measure_source "$_u") || _kbps=""
    if [ -n "$_kbps" ]; then
      printf "$MSG_SPEEDTEST_ITEM\n" "$_s" "$(awk -v k="$_kbps" 'BEGIN{if(k>=1024)printf "%.1f MB/s", k/1024; else printf "%s KB/s", k}')"
      if [ "$_kbps" -gt "$_best_kbps" ]; then _best_kbps="$_kbps"; _best="$_s"; fi
    else
      printf "$MSG_SPEEDTEST_ITEM\n" "$_s" "${C_DIM}${MSG_SPEEDTEST_FAIL}${C_RESET}"
    fi
  done
  case "$_cat" in
    vanilla) SPEED_BEST_VANILLA="$_best" ;;
    fml)     SPEED_BEST_FML="$_best" ;;
    mite)    SPEED_BEST_MITE="$_best" ;;
    translation) SPEED_BEST_TRANSLATION="$_best" ;;
  esac
}

# 最终生效的源顺序 (第一个为首选, 其余为回退)
VANILLA_ORDER=""
FML_ORDER=""
MITE_ORDER=""
TRANSLATION_ORDER=""

# 把 <首选> 提到列表最前
promote_first() {
  local _pick _list _out _s
  _pick="$1"; _list="$2"; _out="$_pick"
  for _s in $_list; do [ "$_s" = "$_pick" ] || _out="$_out $_s"; done
  printf '%s' "$_out"
}

# 从 --source 的逗号列表里挑出属于某类别的源
source_from_opt() {
  local _list _tok _s
  _list="$1"
  for _tok in $(printf '%s' "$OPT_SOURCE" | tr ',' ' '); do
    for _s in $_list; do
      [ "$(lower "$_tok")" = "$_s" ] && { printf '%s' "$_s"; return 0; }
    done
  done
  return 1
}

select_sources() {
  local _v_pick _f_pick _m_pick _t_pick _force_ready _all_failed
  _v_forced=""; _f_forced=""; _m_forced=""; _t_forced=""
  _v_pick=""; _f_pick=""; _m_pick=""; _t_pick=""
  if [ -n "$OPT_SOURCE" ]; then
    _v_forced=$(source_from_opt "$VANILLA_SOURCES") || _v_forced=""
    _f_forced=$(source_from_opt "$FML_SOURCES") || _f_forced=""
    _m_forced=$(source_from_opt "$MITE_SOURCES") || _m_forced=""
    _t_forced=$(source_from_opt "$TRANSLATION_SOURCES") || _t_forced=""
  fi

  _force_ready=0
  case "$MODE" in
    server) [ -n "$_f_forced" ] && _force_ready=1 ;;
    client|both)
      if [ -n "$_v_forced" ] && [ -n "$_f_forced" ] && [ -n "$_m_forced" ] && \
         { [ "$TRANSLATION_ENABLED" != "1" ] || [ -n "$_t_forced" ]; }; then
        _force_ready=1
      fi
      ;;
  esac
  if [ "$_force_ready" = "1" ]; then
    log_info "$(printf "$MSG_SOURCE_FORCED" "$_v_forced, $_f_forced, $_m_forced, $_t_forced")"
    VANILLA_ORDER=$(promote_first "$_v_forced" "$VANILLA_SOURCES")
    FML_ORDER=$(promote_first "$_f_forced" "$FML_SOURCES")
    MITE_ORDER=$(promote_first "$_m_forced" "$MITE_SOURCES")
    TRANSLATION_ORDER=$(promote_first "$_t_forced" "$TRANSLATION_SOURCES")
    log_info "$(final_sources_summary)"
    return
  fi

  # --- 交互询问: 每类可选手动指定源, 或选 1) 自动测速选最快。
  # 只问当前模式实际用得到的类别; --source 已定死的类别不再问。
  if [ "$TTY_OK" = "1" ] && [ "$OPT_YES" != "1" ] && [ "$OPT_NO_SPEEDTEST" != "1" ]; then
    log_info "$MSG_SOURCE_ASK"
    case "$MODE" in
      client|both)
        [ -z "$_v_forced" ] && _v_pick=$(ask_source_category vanilla "$MSG_SRC_LABEL_VANILLA" "$VANILLA_SOURCES")
        [ -z "$_m_forced" ] && _m_pick=$(ask_source_category mite "$MSG_SRC_LABEL_MITE" "$MITE_SOURCES")
        [ "$TRANSLATION_ENABLED" = "1" ] && [ -z "$_t_forced" ] && _t_pick=$(ask_source_category translation "$MSG_SRC_LABEL_TRANSLATION" "$TRANSLATION_SOURCES")
        ;;
    esac
    [ -z "$_f_forced" ] && _f_pick=$(ask_source_category fml "$MSG_SRC_LABEL_FML" "$FML_SOURCES")
  fi

  # --- 测速 / 默认顺序 ---
  SPEED_BEST_VANILLA=""; SPEED_BEST_FML=""; SPEED_BEST_MITE=""; SPEED_BEST_TRANSLATION=""
  if [ "$OPT_NO_SPEEDTEST" = "1" ]; then
    log_info "$MSG_SPEEDTEST_SKIP"
    VANILLA_ORDER="$VANILLA_SOURCES"
    FML_ORDER="$FML_SOURCES"
    MITE_ORDER="$MITE_SOURCES"
    TRANSLATION_ORDER="$TRANSLATION_SOURCES"
  else
    # 需要测速的类别: 交互下是选了"自动测速"的; 非交互下是模式用得到的全部。
    # 交互下手动指定了具体源的类别不测速。
    _do_v=0; _do_f=0; _do_m=0; _do_t=0
    if [ "$TTY_OK" = "1" ] && [ "$OPT_YES" != "1" ]; then
      case "$MODE" in
        client|both)
          [ "$_v_pick" = "auto" ] && _do_v=1
          [ "$_m_pick" = "auto" ] && _do_m=1
          [ "$TRANSLATION_ENABLED" = "1" ] && [ "$_t_pick" = "auto" ] && _do_t=1
          ;;
      esac
      [ "$_f_pick" = "auto" ] && _do_f=1
    else
      case "$MODE" in
        server) _do_f=1 ;;
        *)      _do_v=1; _do_f=1; _do_m=1; [ "$TRANSLATION_ENABLED" = "1" ] && _do_t=1 ;;
      esac
    fi

    if [ "$_do_v" = "1" ] || [ "$_do_f" = "1" ] || [ "$_do_m" = "1" ] || [ "$_do_t" = "1" ]; then
      log_info "$MSG_SPEEDTEST_HEAD"
      [ "$_do_v" = "1" ] && speedtest_category vanilla "$VANILLA_SOURCES"
      [ "$_do_f" = "1" ] && speedtest_category fml "$FML_SOURCES"
      [ "$_do_m" = "1" ] && speedtest_category mite "$MITE_SOURCES"
      [ "$_do_t" = "1" ] && speedtest_category translation "$TRANSLATION_SOURCES"
      # 非交互全自动: 全部不可用才报错 (保持旧行为)。交互下单项失败就回退默认顺序。
      if [ "$TTY_OK" != "1" ] || [ "$OPT_YES" = "1" ]; then
        _all_failed=0
        case "$MODE" in
          server) [ -z "$SPEED_BEST_FML" ] && _all_failed=1 ;;
          client|both)
            if [ -z "$SPEED_BEST_VANILLA" ] && [ -z "$SPEED_BEST_FML" ] && [ -z "$SPEED_BEST_MITE" ] && \
               { [ "$TRANSLATION_ENABLED" != "1" ] || [ -z "$SPEED_BEST_TRANSLATION" ]; }; then
              _all_failed=1
            fi
            ;;
        esac
        [ "$_all_failed" = "1" ] && die "$MSG_ALL_SOURCES_FAIL"
      fi
    fi

    VANILLA_ORDER="$VANILLA_SOURCES"; FML_ORDER="$FML_SOURCES"; MITE_ORDER="$MITE_SOURCES"; TRANSLATION_ORDER="$TRANSLATION_SOURCES"
    [ -n "$SPEED_BEST_VANILLA" ] && VANILLA_ORDER=$(promote_first "$SPEED_BEST_VANILLA" "$VANILLA_SOURCES")
    [ -n "$SPEED_BEST_FML" ] && FML_ORDER=$(promote_first "$SPEED_BEST_FML" "$FML_SOURCES")
    [ -n "$SPEED_BEST_MITE" ] && MITE_ORDER=$(promote_first "$SPEED_BEST_MITE" "$MITE_SOURCES")
    [ -n "$SPEED_BEST_TRANSLATION" ] && TRANSLATION_ORDER=$(promote_first "$SPEED_BEST_TRANSLATION" "$TRANSLATION_SOURCES")
  fi

  # --- 手动指定 (交互选中或 --source 指定) 提到最前 ---
  [ -n "$_v_pick" ] && [ "$_v_pick" != "auto" ] && VANILLA_ORDER=$(promote_first "$_v_pick" "$VANILLA_SOURCES")
  [ -n "$_f_pick" ] && [ "$_f_pick" != "auto" ] && FML_ORDER=$(promote_first "$_f_pick" "$FML_SOURCES")
  [ -n "$_m_pick" ] && [ "$_m_pick" != "auto" ] && MITE_ORDER=$(promote_first "$_m_pick" "$MITE_SOURCES")
  [ -n "$_t_pick" ] && [ "$_t_pick" != "auto" ] && TRANSLATION_ORDER=$(promote_first "$_t_pick" "$TRANSLATION_SOURCES")
  [ -n "$_v_forced" ] && VANILLA_ORDER=$(promote_first "$_v_forced" "$VANILLA_SOURCES")
  [ -n "$_f_forced" ] && FML_ORDER=$(promote_first "$_f_forced" "$FML_SOURCES")
  [ -n "$_m_forced" ] && MITE_ORDER=$(promote_first "$_m_forced" "$MITE_SOURCES")
  [ -n "$_t_forced" ] && TRANSLATION_ORDER=$(promote_first "$_t_forced" "$TRANSLATION_SOURCES")

  log_info "$(final_sources_summary)"
}

# 回显最终生效的源 (首选 / 首选 / 首选 / 首选)
final_sources_summary() {
  local _t_summary
  _t_summary="$(printf '%s' "$TRANSLATION_ORDER" | awk '{print $1}')"
  [ "$TRANSLATION_ENABLED" = "1" ] && [ "$MODE" != "server" ] || _t_summary="disabled"
  printf "$MSG_FINAL_SOURCES" \
    "$(printf '%s' "$VANILLA_ORDER" | awk '{print $1}')" \
    "$(printf '%s' "$FML_ORDER" | awk '{print $1}')" \
    "$(printf '%s' "$MITE_ORDER" | awk '{print $1}')" \
    "$_t_summary"
}

# ============================== 下载 ==============================

# --speed-limit/--speed-time 是关键: 只有 --connect-timeout 时, 某个源若"连上了但
# 几乎不传数据"会永久挂住(实测 GitHub 直连 33 KB/s 下 45 MB 要跑近 2 小时, 脚本
# 既不放弃也不换源, 表现和死机一样)。低于 20 KB/s 持续 20 秒即放弃该源, 换下一个。
CURL_SPEED_GUARD="--speed-limit 20480 --speed-time 20"
CURL_COMMON="--fail --location --show-error --connect-timeout 15 --retry 2 --retry-delay 1 $CURL_SPEED_GUARD"
CURL_BASE="--silent $CURL_COMMON"
# 显示进度条时不能带 --silent, 两者冲突(-s 会把进度条一起静音)
CURL_PROGRESS="--progress-bar $CURL_COMMON"

# file_ok <路径> <sha1|""> <sha256|""> <size|"">  -> 0 表示已就绪
file_ok() {
  local _p _s1 _s256 _sz
  _p="$1"; _s1="${2:-}"; _s256="${3:-}"; _sz="${4:-}"
  [ -f "$_p" ] || return 1
  if [ -n "$_sz" ] && [ "$_sz" != "0" ]; then
    [ "$(size_of "$_p")" = "$_sz" ] || return 1
  fi
  if [ -n "$_s1" ]; then
    [ "$(sha1_of "$_p")" = "$_s1" ] || return 1
  fi
  if [ -n "$_s256" ]; then
    [ "$(sha256_of "$_p")" = "$_s256" ] || return 1
  fi
  # 无任何校验信息时, 至少要求非空
  if [ -z "$_s1" ] && [ -z "$_s256" ] && { [ -z "$_sz" ] || [ "$_sz" = "0" ]; }; then
    [ -s "$_p" ] || return 1
  fi
  return 0
}

# fetch_one <URL> <目标路径> [sha1] [sha256] [size]  单 URL 下载 + 校验
fetch_one() {
  local _url _dest _s1 _s256 _sz _tmp
  _url="$1"; _dest="$2"; _s1="${3:-}"; _s256="${4:-}"; _sz="${5:-}"
  mkdir -p "$(dirname "$_dest")" || return 1
  _tmp="${_dest}.part"
  # 大文件(>1MB 或体积未知)显示进度条: 否则 45MB 的服务端核心全程零输出, 用户
  # 无法区分"正在下载"和"卡死"。小文件仍保持静默, 免得刷屏。
  if [ -z "$_sz" ] || [ "${_sz:-0}" -gt 1048576 ]; then
    # shellcheck disable=SC2086
    if ! curl $CURL_PROGRESS -o "$_tmp" "$_url"; then
      rm -f "$_tmp"; return 1
    fi
  else
    # shellcheck disable=SC2086
    if ! curl $CURL_BASE -o "$_tmp" "$_url" 2>/dev/null; then
      rm -f "$_tmp"; return 1
    fi
  fi
  if ! file_ok "$_tmp" "$_s1" "$_s256" "$_sz"; then
    rm -f "$_tmp"; return 2
  fi
  mv -f "$_tmp" "$_dest" || return 1
  return 0
}

# fetch_multi <目标路径> <sha1> <sha256> <size> <URL...>  逐个 URL 尝试
fetch_multi() {
  local _dest _s1 _s256 _sz _last _u _rc
  _dest="$1"; shift; _s1="$1"; shift; _s256="$1"; shift; _sz="$1"; shift
  if file_ok "$_dest" "$_s1" "$_s256" "$_sz"; then return 0; fi
  _last=""
  for _u in "$@"; do
    fetch_one "$_u" "$_dest" "$_s1" "$_s256" "$_sz" && return 0
    _rc=$?
    _last="$_u"
    if [ "$_rc" = "2" ]; then
      log_warn "$(printf "$MSG_HASH_MISMATCH" "$(basename "$_dest")" "${_s1:-$_s256}")"
    fi
    [ $# -gt 1 ] && log_dim "$(printf "$MSG_DL_RETRY" "$_u")"
  done
  log_err "$(printf "$MSG_DL_FAIL_ALL" "$(basename "$_dest") <- $_last")"
  return 1
}

# 并行批量下载。清单格式为每行: <URL><TAB><目标路径>
# 优先用 curl -Z -K (单进程多路并发), 不支持时回退 xargs -P。
CURL_HAS_PARALLEL=0
detect_curl_parallel() {
  curl --help all 2>/dev/null | grep -q -- '--parallel-max' && CURL_HAS_PARALLEL=1
}

fetch_batch() {
  local _manifest _label _total _cfg _u _p _rc _runner
  _manifest="$1"; _label="${2:-$MSG_DOWNLOADING}"
  _total=$(awk 'END{print NR}' "$_manifest")
  [ "${_total:-0}" -gt 0 ] || return 0

  if [ "$CURL_HAS_PARALLEL" = "1" ]; then
    _cfg="$TMP_ROOT/curl-$$.cfg"
    : >"$_cfg"
    while IFS="$(printf '\t')" read -r _u _p; do
      [ -n "$_u" ] || continue
      mkdir -p "$(dirname "$_p")"
      printf 'url = "%s"\noutput = "%s"\n' "$_u" "$_p" >>"$_cfg"
    done <"$_manifest"
    # shellcheck disable=SC2086
    curl $CURL_BASE -Z --parallel-max "$PARALLEL_MAX" -K "$_cfg" 2>/dev/null
    _rc=$?
    rm -f "$_cfg"
    return $_rc
  fi

  # 回退: xargs -P
  _runner="$TMP_ROOT/dl-one.sh"
  cat >"$_runner" <<'RUNNER'
#!/bin/sh
u="$1"; p="$2"
mkdir -p "$(dirname "$p")"
curl --fail --location --silent --connect-timeout 15 --retry 2 --retry-delay 1 \
     --speed-limit 20480 --speed-time 20 -o "$p" "$u"
RUNNER
  chmod +x "$_runner"
  awk -F'\t' '{print $1"\n"$2}' "$_manifest" | xargs -P "$PARALLEL_MAX" -n 2 "$_runner"
  return 0
}

# ============================== JSON 解析 (awk) ==============================
# 不依赖 python3: 全新 macOS 的 /usr/bin/python3 只是会弹出 Xcode CLT 安装框的
# 存根, curl|bash 场景下不可依赖。以下用 awk 处理本项目需要的两种固定结构。

JFLAT=""   # 由 init_json 写出的 awk 程序路径

init_json() {
  JFLAT="$TMP_ROOT/jflat.awk"
  cat >"$JFLAT" <<'JFLATEOF'
{ s = s $0 "\n" }
END { len = length(s); pos = 1; parse_value("") }
function skipws(   c) {
  while (pos <= len) {
    c = substr(s, pos, 1)
    if (c == " " || c == "\t" || c == "\n" || c == "\r") pos++
    else break
  }
}
function parse_string(   out, c, c2) {
  pos++
  out = ""
  while (pos <= len) {
    c = substr(s, pos, 1)
    if (c == "\\") {
      pos++; c2 = substr(s, pos, 1)
      if (c2 == "n") out = out "\n"
      else if (c2 == "t") out = out "\t"
      else if (c2 == "r") out = out "\r"
      else if (c2 == "u") { out = out "\\u" substr(s, pos + 1, 4); pos += 4 }
      else out = out c2
      pos++
      continue
    }
    if (c == "\"") { pos++; return out }
    out = out c
    pos++
  }
  return out
}
function parse_value(path,   c, key, n, v, np) {
  skipws()
  c = substr(s, pos, 1)
  if (c == "{") {
    pos++
    while (pos <= len) {
      skipws()
      c = substr(s, pos, 1)
      if (c == "}") { pos++; return }
      if (c == ",") { pos++; continue }
      if (c != "\"") { pos++; continue }
      key = parse_string()
      skipws()
      if (substr(s, pos, 1) == ":") pos++
      if (path == "") np = key; else np = path "." key
      parse_value(np)
    }
    return
  }
  if (c == "[") {
    pos++; n = 0
    while (pos <= len) {
      skipws()
      c = substr(s, pos, 1)
      if (c == "]") { pos++; return }
      if (c == ",") { pos++; continue }
      if (path == "") np = n; else np = path "." n
      parse_value(np)
      n++
    }
    return
  }
  if (c == "\"") { print path "=" parse_string(); return }
  v = ""
  while (pos <= len) {
    c = substr(s, pos, 1)
    if (c == "," || c == "}" || c == "]" || c == " " || c == "\t" || c == "\n" || c == "\r") break
    v = v c; pos++
  }
  print path "=" v
}
JFLATEOF
}

# json_flatten <文件>  -> 逐行 "点分路径=值"
json_flatten() { awk -f "$JFLAT" "$1"; }

# jget <扁平化文件> <精确路径>  -> 值 (无则空)
jget() {
  awk -F= -v k="$2" '$1==k { sub(/^[^=]*=/, ""); print; exit }' "$1"
}

# ============================== library 解析 ==============================

# lib_allowed <扁平化文件> <前缀 libraries.N>  -> 0 表示当前平台允许
# 规则语义: 无 rules 则允许; 有 rules 则默认拒绝, 按顺序求值, 后者覆盖前者。
# 带 os.version 的分支(仅 osx 10.5 老机型)一律跳过。
lib_allowed() {
  local _f _p _has _verdict _i _act _osn _osv
  _f="$1"; _p="$2"
  _has=$(awk -F= -v p="${_p}.rules." 'index($1,p)==1{print "y"; exit}' "$_f")
  [ -z "$_has" ] && return 0
  _verdict="deny"
  _i=0
  while :; do
    _act=$(jget "$_f" "${_p}.rules.${_i}.action")
    [ -z "$_act" ] && break
    _osn=$(jget "$_f" "${_p}.rules.${_i}.os.name")
    _osv=$(jget "$_f" "${_p}.rules.${_i}.os.version")
    if [ -n "$_osv" ]; then _i=$((_i+1)); continue; fi
    if [ -z "$_osn" ] || [ "$_osn" = "$OS_NAME" ]; then _verdict="$_act"; fi
    _i=$((_i+1))
  done
  [ "$_verdict" = "allow" ]
}

# maven_path <name> [classifier]  -> group/artifact/ver/artifact-ver[-cls].jar
maven_path() {
  printf '%s' "${1:-}" | awk -F: -v cls="${2:-}" '{
    gsub(/\./, "/", $1)
    f = $2 "-" $3
    if (cls != "") f = f "-" cls
    printf "%s/%s/%s/%s.jar", $1, $2, $3, f
  }'
}

# url_mirror <源> <原始URL>  -> 把 libraries.minecraft.net 换成该源的镜像
url_mirror() {
  case "$1" in
    bmclapi)
      case "$2" in
        https://libraries.minecraft.net/*)
          printf 'https://bmclapi2.bangbang93.com/maven/%s' "${2#https://libraries.minecraft.net/}" ;;
        *) printf '%s' "$2" ;;
      esac ;;
    *) printf '%s' "$2" ;;
  esac
}

# build_lib_table <扁平化文件> <输出表>
# 每行: KIND<TAB>相对路径<TAB>sha1<TAB>size<TAB>显式URL<TAB>排除项
#   KIND = ART (进 classpath) | NAT (解压到 natives)
# 注: FML config 里 gson 的 path 写的是 2.10.1 而 url/sha1/size 都是 2.11.0。
# 三者互相一致(文件名只是名字不符), 所以 path 照用, 不改。
build_lib_table() {
  local _f _out _i _name _pfx _custom _apath _asha _asize _aurl _nat _mp _u _cp _cs _cz _cu _ex _j _e
  _f="$1"; _out="$2"
  : >"$_out"
  _i=0
  while :; do
    _name=$(jget "$_f" "libraries.${_i}.name")
    [ -z "$_name" ] && break
    _pfx="libraries.${_i}"
    _i=$((_i+1))

    case "$_name" in
      net.xiaoyu233.fishmodloader:*) continue ;;   # 单独安装
    esac
    lib_allowed "$_f" "$_pfx" || continue

    _custom=$(jget "$_f" "${_pfx}.url")

    # --- artifact ---
    _apath=$(jget "$_f" "${_pfx}.downloads.artifact.path")
    _asha=$(jget "$_f" "${_pfx}.downloads.artifact.sha1")
    _asize=$(jget "$_f" "${_pfx}.downloads.artifact.size")
    _aurl=$(jget "$_f" "${_pfx}.downloads.artifact.url")
    _nat=$(jget "$_f" "${_pfx}.natives.${OS_NAME}")

    if [ -n "$_apath" ]; then
      printf 'ART\t%s\t%s\t%s\t%s\t\n' "$_apath" "$_asha" "$_asize" "$_aurl" >>"$_out"
    elif [ -z "$_nat" ]; then
      # 无 downloads 块且非 natives 库: 按 maven 布局推路径
      _mp=$(maven_path "$_name")
      _u=""
      [ -n "$_custom" ] && _u="${_custom%/}/$_mp"
      printf 'ART\t%s\t\t\t%s\t\n' "$_mp" "$_u" >>"$_out"
    fi

    # --- natives ---
    if [ -n "$_nat" ]; then
      _cp=$(jget "$_f" "${_pfx}.downloads.classifiers.${_nat}.path")
      _cs=$(jget "$_f" "${_pfx}.downloads.classifiers.${_nat}.sha1")
      _cz=$(jget "$_f" "${_pfx}.downloads.classifiers.${_nat}.size")
      _cu=$(jget "$_f" "${_pfx}.downloads.classifiers.${_nat}.url")
      [ -n "$_cp" ] || _cp=$(maven_path "$_name" "$_nat")
      _ex=""
      _j=0
      while :; do
        _e=$(jget "$_f" "${_pfx}.extract.exclude.${_j}")
        [ -z "$_e" ] && break
        [ -n "$_ex" ] && _ex="$_ex,$_e" || _ex="$_e"
        _j=$((_j+1))
      done
      printf 'NAT\t%s\t%s\t%s\t%s\t%s\n' "$_cp" "$_cs" "$_cz" "$_cu" "$_ex" >>"$_out"
    fi
  done
}

# merge_lib_hashes <目标表> <参考表>
# FML config 里部分库(paulscode / argo / jinput 等)没有 downloads 块, 因此没有 sha1。
# 这些库原版 1.6.4.json 里都有, 按相对路径把 sha1/size 补进去。
merge_lib_hashes() {
  local _t _ref _tmp
  _t="$1"; _ref="$2"; _tmp="$TMP_ROOT/libmerge.$$"
  awk -F'\t' -v OFS='\t' '
    NR==FNR { if ($3 != "") { h[$2]=$3; z[$2]=$4 }; next }
    {
      if ($3 == "" && $2 in h) { $3 = h[$2]; $4 = z[$2] }
      print
    }
  ' "$_ref" "$_t" >"$_tmp" && mv -f "$_tmp" "$_t"
}

# apply_pins <表>  把 ASM_PINS 里的 sha1/size 填进仍缺失的行
apply_pins() {
  local _t _tmp
  _t="$1"; _tmp="$TMP_ROOT/libpin.$$"
  printf '%s\n' "$ASM_PINS" >"$TMP_ROOT/pins.$$"
  awk -F'\t' -v OFS='\t' -v pins="$TMP_ROOT/pins.$$" '
    BEGIN {
      while ((getline line < pins) > 0) {
        n = split(line, a, "=")
        if (n >= 3) { h[a[1]] = a[2]; z[a[1]] = a[3] }
      }
    }
    { if ($3 == "" && $2 in h) { $3 = h[$2]; $4 = z[$2] }; print }
  ' "$_t" >"$_tmp" && mv -f "$_tmp" "$_t"
  rm -f "$TMP_ROOT/pins.$$"
}

# lib_urls <源> <相对路径> <显式URL>  -> 候选 URL 列表(空格分隔, 已按优先级排)
lib_urls() {
  local _s _rel _explicit _list _cand
  _s="$1"; _rel="$2"; _explicit="$3"
  _list=""
  if [ -n "$_explicit" ]; then
    _list="$(url_mirror "$_s" "$_explicit") $_explicit"
  fi
  for _cand in $VANILLA_ORDER; do
    _list="$_list $(src_lib_base "$_cand")/$_rel"
  done
  _list="$_list https://repo1.maven.org/maven2/$_rel https://maven.fabricmc.net/$_rel"
  printf '%s' "$_list"
}

# 下载 library 表里的全部条目
download_libs() {
  local _table _libdir _n _idx _kind _rel _sha _size _url _ex _dest
  _table="$1"; _libdir="$2"
  _n=$(awk 'END{print NR}' "$_table")
  _idx=0
  while IFS="$(printf '\t')" read -r _kind _rel _sha _size _url _ex; do
    [ -n "$_rel" ] || continue
    _idx=$((_idx+1))
    _dest="$_libdir/$_rel"
    if file_ok "$_dest" "$_sha" "" "$_size"; then continue; fi
    printf '\r  %s/%s %-52s' "$_idx" "$_n" "$(basename "$_rel")"
    # shellcheck disable=SC2046
    fetch_multi "$_dest" "$_sha" "" "$_size" $(lib_urls "$(printf '%s' "$VANILLA_ORDER" | awk '{print $1}')" "$_rel" "$_url") \
      || { printf '\n'; return 1; }
  done <"$_table"
  printf '\r  %s/%s%-52s\n' "$_n" "$_n" ""
  return 0
}

# 解压 natives (排除 extract.exclude 指定的前缀)
extract_natives() {
  local _table _libdir _natdir _kind _rel _sha _size _url _ex _jar _stage _oldifs _pat
  _table="$1"; _libdir="$2"; _natdir="$3"
  mkdir -p "$_natdir"
  while IFS="$(printf '\t')" read -r _kind _rel _sha _size _url _ex; do
    [ "$_kind" = "NAT" ] || continue
    _jar="$_libdir/$_rel"
    [ -f "$_jar" ] || continue
    _stage="$TMP_ROOT/nat.$$"
    rm -rf "$_stage"; mkdir -p "$_stage"
    unpack_zip "$_jar" "$_stage" || return 1
    _oldifs="$IFS"; IFS=','
    for _pat in $_ex; do
      IFS="$_oldifs"
      [ -n "$_pat" ] || continue
      case "$_pat" in
        */) rm -rf "$_stage/${_pat%/}" ;;
        *)  rm -rf "$_stage/$_pat" ;;
      esac
      IFS=','
    done
    IFS="$_oldifs"
    (cd "$_stage" && find . -type f -exec cp -f {} "$_natdir/" \;) 2>/dev/null
    rm -rf "$_stage"
  done <"$_table"
  return 0
}

# ============================== 压缩包读写 ==============================
# 优先 unzip/zip; 缺失时用 python3; 再退到 jar(需 JDK)。

# unpack_zip <zip> <目标目录> [仅解压的条目...]
unpack_zip() {
  local _z _d
  _z="$1"; _d="$2"; shift 2
  mkdir -p "$_d" || return 1
  case "$UNZIP_TOOL" in
    unzip)
      if [ $# -gt 0 ]; then unzip -o -q "$_z" "$@" -d "$_d"
      else unzip -o -q "$_z" -d "$_d"; fi ;;
    python3)
      MITE_ZIP="$_z" MITE_DST="$_d" MITE_ONLY="$*" python3 -c '
import os, sys, zipfile
z = os.environ["MITE_ZIP"]; d = os.environ["MITE_DST"]
only = [x for x in os.environ.get("MITE_ONLY", "").split() if x]
with zipfile.ZipFile(z) as f:
    f.extractall(d, members=only or None)
' ;;
    jar)
      if [ $# -gt 0 ]; then (cd "$_d" && jar xf "$_z" "$@")
      else (cd "$_d" && jar xf "$_z"); fi ;;
    *) return 1 ;;
  esac
}

# pack_zip <目标zip> <源目录>   目录内容打成 zip (不含顶层目录本身)
# MITE 客户端 jar 用 `jar cf` 语义: 不保留原 MANIFEST。
pack_zip() {
  local _out _src
  _out="$1"; _src="$2"
  # 下面要 cd 进 _src, 所以输出路径必须先转成绝对路径
  case "$_out" in
    /*) : ;;
    *)  _out="$(pwd)/$_out" ;;
  esac
  rm -f "$_out"
  case "$ZIP_TOOL" in
    zip) (cd "$_src" && zip -q -r -X "$_out" .) ;;
    python3)
      MITE_OUT="$_out" MITE_SRC="$_src" python3 -c '
import os, zipfile
out = os.environ["MITE_OUT"]; src = os.environ["MITE_SRC"]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(src):
        for fn in files:
            p = os.path.join(root, fn)
            z.write(p, os.path.relpath(p, src))
' ;;
    jar) (cd "$_src" && jar cf "$_out" .) ;;
    *) return 1 ;;
  esac
}

# ============================== 简体中文翻译包 ==============================

TRANSLATION_ZIP=""
TRANSLATION_STAGE_DIR=""
TRANSLATION_LANG_FILE=""
TRANSLATION_META_FILE=""
TRANSLATION_ICON_FILE=""

# translation_extract <zip> <目标目录>
# 解压并定位仓库构建所需的三个文件。仓库根目录名随 ZIP 下载方式变化,
# 所以只按稳定的相对路径查找。
translation_extract() {
  local _zip _stage _missing
  _zip="$1"; _stage="$2"
  rm -rf "$_stage"; mkdir -p "$_stage"
  unpack_zip "$_zip" "$_stage" || return 1

  TRANSLATION_LANG_FILE=$(find "$_stage" -type f -path '*/zh_cn/MITE.lang' 2>/dev/null | head -1)
  TRANSLATION_META_FILE=$(find "$_stage" -type f -path '*/build_assets/pack.mcmeta' 2>/dev/null | head -1)
  TRANSLATION_ICON_FILE=$(find "$_stage" -type f -path '*/build_assets/pack.png' 2>/dev/null | head -1)

  _missing=""
  [ -s "$TRANSLATION_LANG_FILE" ] || _missing="$_missing zh_cn/MITE.lang"
  [ -s "$TRANSLATION_META_FILE" ] || _missing="$_missing build_assets/pack.mcmeta"
  [ -s "$TRANSLATION_ICON_FILE" ] || _missing="$_missing build_assets/pack.png"
  if [ -n "$_missing" ]; then
    log_warn "$(printf "$MSG_TRANSLATION_MISSING" "${_missing# }")"
    return 1
  fi

  TRANSLATION_STAGE_DIR="$_stage"
  return 0
}

# 下载 master.zip。每个候选源都先解压验证, 避免 HTTP 200 的错误页面
# 被当成有效 ZIP 后阻断后续镜像回退。
prepare_translation() {
  local _s _url _candidate _stage _last
  log_dim "$MSG_TRANSLATION_FETCH"
  TRANSLATION_ZIP=""; TRANSLATION_STAGE_DIR=""
  _last=""
  for _s in $TRANSLATION_ORDER; do
    _url=$(translation_url "$_s")
    _candidate="$TMP_ROOT/MITE-CN-Translation.${_s}.zip"
    _stage="$TMP_ROOT/translation.${_s}"
    rm -f "$_candidate"
    if fetch_one "$_url" "$_candidate" "" "" "" && translation_extract "$_candidate" "$_stage"; then
      TRANSLATION_ZIP="$_candidate"
      return 0
    fi
    rm -f "$_candidate"
    rm -rf "$_stage"
    _last="$_url"
    [ -n "$TRANSLATION_ORDER" ] && log_dim "$(printf "$MSG_DL_RETRY" "$_url")"
  done
  log_err "$(printf "$MSG_DL_FAIL_ALL" "MITE-CN-Translation.zip <- $_last")"
  return 1
}

# merge_translation_resource_pack <原始资源包> <临时输出 ZIP>
merge_translation_resource_pack() {
  local _base _out _stage
  _base="$1"; _out="$2"
  _stage="$TMP_ROOT/respack-merge"
  rm -rf "$_stage"; mkdir -p "$_stage"
  unpack_zip "$_base" "$_stage" || return 1

  mkdir -p "$_stage/assets/minecraft/lang"
  cp -f "$TRANSLATION_LANG_FILE" "$_stage/assets/minecraft/lang/MITE.lang" || return 1
  cp -f "$TRANSLATION_META_FILE" "$_stage/pack.mcmeta" || return 1
  cp -f "$TRANSLATION_ICON_FILE" "$_stage/pack.png" || return 1

  pack_zip "$_out" "$_stage" || return 1
  [ -s "$_out" ] || return 1
  return 0
}

# ============================== assets (legacy) ==============================
# 1.6.4 的 assetIndex.id == "legacy": 资源必须按原始相对路径落到
# assets/virtual/legacy/<path>, 而不是新版的 assets/objects/<hash前2位>/<hash>。
# 启动参数用 --assetsDir ${game_assets} 指向该 virtual 目录。

download_assets() {
  local _flat _adir _vdir _src _base _manifest _total _have _need _path _hash _size _dest _key _fail _urls _s _chunk _line _end _done _sub
  _flat="$1"; _adir="$2"
  _vdir="$_adir/virtual/$MC_ASSET_INDEX_ID"
  _src=$(printf '%s' "$VANILLA_ORDER" | awk '{print $1}')
  _base=$(src_asset_base "$_src")
  _manifest="$TMP_ROOT/assets.manifest"
  : >"$_manifest"
  _total=0; _have=0; _need=0

  # 扁平化后每个资源有两行: objects.<路径>.hash / objects.<路径>.size
  # 路径本身可能含 '.', 所以按后缀切而不是按第一个点切。
  awk -F= '
    /^objects\./ {
      key = $1
      sub(/^objects\./, "", key)
      val = $0; sub(/^[^=]*=/, "", val)
      if (key ~ /\.hash$/) { sub(/\.hash$/, "", key); h[key] = val }
      else if (key ~ /\.size$/) { sub(/\.size$/, "", key); z[key] = val }
    }
    END { for (k in h) printf "%s\t%s\t%s\n", k, h[k], z[k] }
  ' "$_flat" >"$TMP_ROOT/assets.list"

  while IFS="$(printf '\t')" read -r _path _hash _size; do
    [ -n "$_path" ] || continue
    _total=$((_total+1))
    _dest="$_vdir/$_path"
    if file_ok "$_dest" "$_hash" "" "$_size"; then
      _have=$((_have+1)); continue
    fi
    _need=$((_need+1))
    printf '%s/%s/%s\t%s\n' "$_base" "$(printf '%s' "$_hash" | cut -c1-2)" "$_hash" "$_dest" >>"$_manifest"
  done <"$TMP_ROOT/assets.list"

  if [ "$_need" = "0" ]; then
    log_dim "  $(printf "$MSG_DL_PROGRESS" "$_have" "$_total")"
    return 0
  fi

  # 分批并行下载: 每批结束即时回显已完成数。若整批一次性静默下载, 进度会一直
  # 停在开头 "0 / N" 不动, 用户分不清"正在下载"还是"卡死"。
  _done=0
  while [ "$_done" -lt "$_need" ]; do
    _line=$((_done + 1))
    _end=$((_done + ASSETS_CHUNK))
    [ "$_end" -gt "$_need" ] && _end="$_need"
    _sub="$TMP_ROOT/assets.chunk"
    sed -n "${_line},${_end}p" "$_manifest" >"$_sub"
    fetch_batch "$_sub" >/dev/null 2>&1 || true
    _done="$_end"
    printf '\r'; printf "$MSG_DL_PROGRESS" "$((_have + _done))" "$_total"
  done
  printf '\n'

  # 复核并对失败项逐个重试(可换源)
  _fail=0
  while IFS="$(printf '\t')" read -r _path _hash _size; do
    [ -n "$_path" ] || continue
    _dest="$_vdir/$_path"
    file_ok "$_dest" "$_hash" "" "$_size" && continue
    _key="$(printf '%s' "$_hash" | cut -c1-2)/$_hash"
    _urls=""
    for _s in $VANILLA_ORDER; do _urls="$_urls $(src_asset_base "$_s")/$_key"; done
    # shellcheck disable=SC2086
    fetch_multi "$_dest" "$_hash" "" "$_size" $_urls || _fail=$((_fail+1))
  done <"$TMP_ROOT/assets.list"

  [ "$_fail" = "0" ] || return 1
  return 0
}

# ============================== 原版 jar ==============================

# 常见启动器的 1.6.4.jar 位置
vanilla_candidates() {
  printf '%s\n' \
    "$MC_DIR/versions/$MC_VERSION/$MC_VERSION.jar" \
    "$HOME/.minecraft/versions/$MC_VERSION/$MC_VERSION.jar" \
    "$HOME/Library/Application Support/minecraft/versions/$MC_VERSION/$MC_VERSION.jar" \
    "$HOME/.local/share/multimc/libraries/net/minecraft/$MC_VERSION/$MC_VERSION.jar" \
    "$HOME/.local/share/PrismLauncher/libraries/net/minecraft/$MC_VERSION/$MC_VERSION.jar" \
    "$HOME/Library/Application Support/PrismLauncher/libraries/net/minecraft/$MC_VERSION/$MC_VERSION.jar" \
    "$HOME/.hmcl/versions/$MC_VERSION/$MC_VERSION.jar" \
    "$HOME/minecraft/versions/$MC_VERSION/$MC_VERSION.jar"
}

# -> 回显可用的本地 jar 路径, 无则空
find_local_vanilla() {
  local _c
  if [ -n "$OPT_VANILLA_JAR" ]; then
    if [ -f "$OPT_VANILLA_JAR" ]; then printf '%s' "$OPT_VANILLA_JAR"; fi
    return
  fi
  vanilla_candidates | while IFS= read -r _c; do
    [ -f "$_c" ] || continue
    printf '%s' "$_c"; break
  done
}

# 确保 versions/1.6.4/1.6.4.jar 就位, 结果写入全局 VANILLA_JAR。
# 不能用 $(...) 捕获返回值: log_info/log_ok 走 stdout, 会混进结果里。
VANILLA_JAR=""
prepare_vanilla_jar() {
  local _dest _local _sha _use _urls _s
  _dest="$MC_DIR/versions/$MC_VERSION/$MC_VERSION.jar"
  _use=""

  if [ "$OPT_FORCE_DOWNLOAD" != "1" ]; then
    _local=$(find_local_vanilla)
    if [ -n "$_local" ]; then
      log_info "$(printf "$MSG_FOUND_LOCAL_JAR" "$_local")"
      _sha=$(sha1_of "$_local")
      if [ "$_sha" = "$MC_CLIENT_SHA1" ]; then
        log_ok "$MSG_LOCAL_JAR_OK"
        _use="$_local"
      else
        log_warn "$MSG_LOCAL_JAR_BAD"
        if ask_yesno "$MSG_ASK_USE_LOCAL" n; then _use="$_local"; fi
      fi
    else
      log_info "$MSG_NO_LOCAL_JAR"
    fi
  fi

  if [ -n "$_use" ]; then
    if [ "$_use" != "$_dest" ]; then
      mkdir -p "$(dirname "$_dest")"
      cp -f "$_use" "$_dest" || return 1
    fi
    VANILLA_JAR="$_dest"
    return 0
  fi

  _urls=""
  for _s in $VANILLA_ORDER; do
    case "$_s" in
      official) _urls="$_urls $(src_object_base "$_s")/v1/objects/$MC_CLIENT_SHA1/client.jar" ;;
      bmclapi)  _urls="$_urls $(src_object_base "$_s")/version/$MC_VERSION/client" ;;
    esac
  done
  # shellcheck disable=SC2086
  fetch_multi "$_dest" "$MC_CLIENT_SHA1" "" "$MC_CLIENT_SIZE" $_urls || return 1
  VANILLA_JAR="$_dest"
}

# ============================== MITE ==============================

MITE_SRC_DIR=""   # 解压后含 class/ 与资源包的那层目录

# 取得 MITE 包并解压, 结果目录写入 MITE_SRC_DIR
prepare_mite() {
  local _zip _stage _found
  _stage="$TMP_ROOT/mite"
  mkdir -p "$_stage"

  if [ -n "$OPT_MITE_ZIP" ] && [ -f "$OPT_MITE_ZIP" ]; then
    log_info "$(printf "$MSG_MITE_LOCAL" "$OPT_MITE_ZIP")"
    _zip="$OPT_MITE_ZIP"
  else
    _zip="$TMP_ROOT/$MITE_ZIP_NAME"
    _urls=""
    for _s in $MITE_ORDER; do _urls="$_urls $(mite_url "$_s")"; done
    # shellcheck disable=SC2086
    fetch_multi "$_zip" "" "$MITE_ZIP_SHA256" "" $_urls || return 1
  fi

  unpack_zip "$_zip" "$_stage" || return 1

  # zip 内层级可能带一层 "MITE 1.6.4 Installation Files/", 找到含 class/ 的目录
  _found=$(find "$_stage" -maxdepth 4 -type d -name class 2>/dev/null | head -1)
  [ -n "$_found" ] || { log_err "MITE class/ not found in archive"; return 1; }
  MITE_SRC_DIR=$(dirname "$_found")
  log_dim "  MITE: $(basename "$MITE_SRC_DIR")"
  return 0
}

# 重打包: 原版 jar 去签名 + 覆盖 MITE class -> versions/1.6.4-MITE/1.6.4-MITE.jar
# 依据 MITE 官方 Manual Installation Steps.txt 与 Setup.command:
#   1) 解压原版 jar  2) 删 META-INF/(去签名, 否则改过的 jar 会因签名校验失败)
#   3) 覆盖 class/   4) jar cf 重打包(客户端不保留 MANIFEST, 只有 HDS 服务端用 cmf)
repack_mite_jar() {
  local _vanilla _out _stage
  _vanilla="$1"; _out="$2"
  _stage="$TMP_ROOT/repack"
  rm -rf "$_stage"; mkdir -p "$_stage"

  unpack_zip "$_vanilla" "$_stage" || return 1

  log_dim "  $MSG_REPACK_STRIP"
  rm -rf "$_stage/META-INF"

  log_dim "  $MSG_REPACK_MERGE"
  # cp -R src/. dest/ 把 src 内容合并进 dest 并覆盖同名文件, BSD/GNU 行为一致。
  # 不用 while 循环: 管道里的 exit 只退出子 shell, 传不出失败。
  cp -R "$MITE_SRC_DIR/class/." "$_stage/" || return 1

  log_dim "  $(printf "$MSG_REPACK_ZIP" "$(basename "$_out")")"
  mkdir -p "$(dirname "$_out")"
  pack_zip "$_out" "$_stage" || return 1
  rm -rf "$_stage"
  [ -s "$_out" ] || return 1
  return 0
}

# ============================== FishModLoader ==============================
# installer 是纯 GUI (net.xiaoyu233.fmlinstaller.Main 只 new 一个 JFrame), 无 CLI
# 参数, 所以不能调用它, 只能复刻它的行为。它做的事只有两件:
#   1) 把内嵌 FishModLoader.jar 放到
#      libraries/net/xiaoyu233/fishmodloader/fishmodloader/<版本>/FishModLoader.jar
#      并解压内嵌 guava-28.0.jar 到 libraries/com/google/guava/guava/28.0/
#   2) 把内嵌 config.json 写成 versions/1.6.4-MITE/1.6.4-MITE.json
# 版本 JSON 模板只存在于 installer 内(FishModLoader-vX.Y.Z.jar 里没有),
# 所以必须取 installer。好在一个 installer(12.7MB) 就同时含 FML 本体(10.9MB)、
# guava(2.7MB)、config.json 与 version.properties, 比分开下更省。

FML_VERSION=""        # 形如 3.4.3
FML_LIB_VERSION=""    # 形如 v3.4.3, 取自 version.properties
FML_INSTALLER=""      # 本地 installer jar 路径

# 查询最新 release tag
fml_query_latest() {
  local _api _tag _s _url
  for _s in $FML_ORDER; do
    _url=$(fml_wrap_url "$_s" "https://api.github.com/repos/${FML_REPO}/releases/latest")
    case "$_s" in github) _url="https://api.github.com/repos/${FML_REPO}/releases/latest" ;; esac
    _api=$(curl -sL --max-time 15 "$_url" 2>/dev/null) || continue
    _tag=$(printf '%s' "$_api" | awk -F'"' '/"tag_name"/{print $4; exit}')
    [ -n "$_tag" ] && { printf '%s|%s' "$_tag" "$_s"; return 0; }
  done
  return 1
}

fml_asset_urls() {
  local _file _s _list
  _file="$1"; _list=""
  for _s in $FML_ORDER; do
    _list="$_list $(fml_wrap_url "$_s" "https://github.com/${FML_REPO}/releases/download/${FML_VERSION}/${_file}")"
  done
  printf '%s' "$_list"
}

# 确定版本并取得 installer
prepare_fml() {
  local _tag _latest _latest_source _name _sha _urls
  if [ -n "$OPT_FML_VERSION" ]; then
    FML_VERSION="$OPT_FML_VERSION"
  else
    _latest=$(fml_query_latest) || _latest=""
    _tag="${_latest%%|*}"
    _latest_source="${_latest#*|}"
    if [ -n "$_tag" ] && [ "$_tag" != "$_latest" ]; then
      FML_VERSION="${_tag#v}"
      log_info "$(printf "$MSG_FML_LATEST" "$_latest_source" "$FML_VERSION")"
    else
      FML_VERSION="$FML_FALLBACK_VERSION"
      log_warn "$(printf "$MSG_FML_API_FAIL" "$FML_VERSION")"
    fi
  fi

  _name="FishModLoader-v${FML_VERSION}-installer-universal.jar"
  if [ -n "${OPT_FML_INSTALLER:-}" ] && [ -f "$OPT_FML_INSTALLER" ]; then
    FML_INSTALLER="$OPT_FML_INSTALLER"
    log_info "$(printf "$MSG_MITE_LOCAL" "$FML_INSTALLER")"
    return 0
  fi

  FML_INSTALLER="$TMP_ROOT/$_name"
  # shellcheck disable=SC2086
  fetch_multi "$FML_INSTALLER" "" "" "" $(fml_asset_urls "$_name") || return 1
  return 0
}

FML_CONFIG_JSON=""   # 从 installer 解出的 config.json 路径

# 解出 installer 内的四样东西并按 installer 的落盘规则安装
install_fml_payload() {
  local _libdir _stage _fmljar _guava _dest _gdest
  _libdir="$1"
  _stage="$TMP_ROOT/fmlx"
  rm -rf "$_stage"; mkdir -p "$_stage"

  unpack_zip "$FML_INSTALLER" "$_stage" \
    "config.json" "version.properties" \
    "net/xiaoyu233/fmlinstaller/FishModLoader.jar" \
    "net/xiaoyu233/fmlinstaller/guava-28.0.jar" || return 1

  [ -f "$_stage/config.json" ] || { log_err "config.json not found in installer"; return 1; }
  FML_CONFIG_JSON="$_stage/config.json"

  # version.properties 形如 "version = v3.4.3"
  if [ -f "$_stage/version.properties" ]; then
    FML_LIB_VERSION=$(awk -F= '/version/{gsub(/[ \t\r]/,"",$2); print $2; exit}' "$_stage/version.properties")
  fi
  [ -n "$FML_LIB_VERSION" ] || FML_LIB_VERSION="v${FML_VERSION}"

  _fmljar="$_stage/net/xiaoyu233/fmlinstaller/FishModLoader.jar"
  _guava="$_stage/net/xiaoyu233/fmlinstaller/guava-28.0.jar"
  [ -f "$_fmljar" ] || { log_err "FishModLoader.jar not found in installer"; return 1; }

  _dest="$_libdir/net/xiaoyu233/fishmodloader/fishmodloader/${FML_LIB_VERSION}/FishModLoader.jar"
  mkdir -p "$(dirname "$_dest")"
  cp -f "$_fmljar" "$_dest" || return 1

  if [ -f "$_guava" ]; then
    _gdest="$_libdir/com/google/guava/guava/${GUAVA_DEST_VERSION}/guava-${GUAVA_DEST_VERSION}.jar"
    mkdir -p "$(dirname "$_gdest")"
    cp -f "$_guava" "$_gdest" || return 1
  fi

  log_dim "  fishmodloader/${FML_LIB_VERSION}/FishModLoader.jar  ($(human_size "$(size_of "$_dest")"))"
  return 0
}

# 写 versions/1.6.4-MITE/1.6.4-MITE.json
# 在 installer 的 config.json 基础上做三件事:
#   a) 替换 ${miteVersion} 占位符
#   b) 修正上游写死的 fishmodloader 版本号 (v3.4.3 的 config 里仍写 v3.4.2,
#      与 version.properties 不一致, 照抄会让启动器找不到库)
#   c) 补上缺失的 assets / assetIndex 字段 (原 config 没有, 第三方启动器因此
#      不知道该拉哪份资源索引, 会导致没声音/没语言文件)
write_version_json() {
  local _out _src _declared _tmp
  _out="$1"
  _src="$FML_CONFIG_JSON"
  mkdir -p "$(dirname "$_out")"
  _tmp="$TMP_ROOT/verjson.$$"

  _declared=$(awk -F'"' '/net\.xiaoyu233\.fishmodloader:fishmodloader:/{
      n = split($4, a, ":"); print a[3]; exit }' "$_src")

  sed -e "s/\${miteVersion}/${MITE_ID}/g" "$_src" >"$_tmp" || return 1

  if [ -n "$_declared" ] && [ "$_declared" != "$FML_LIB_VERSION" ]; then
    log_warn "$(printf "$MSG_JSON_FIX_VER" "$_declared" "$FML_LIB_VERSION")"
    sed -e "s|net\.xiaoyu233\.fishmodloader:fishmodloader:${_declared}|net.xiaoyu233.fishmodloader:fishmodloader:${FML_LIB_VERSION}|g" \
        "$_tmp" >"$_tmp.2" && mv -f "$_tmp.2" "$_tmp"
  fi

  # 在顶层 "id" 之后插入 assets / assetIndex
  if ! grep -q '"assetIndex"' "$_tmp"; then
    log_info "$MSG_JSON_ADD_ASSETS"
    awk -v aid="$MC_ASSET_INDEX_ID" -v ash="$MC_ASSET_INDEX_SHA1" \
        -v asz="$MC_ASSET_INDEX_SIZE" -v ats="$MC_ASSET_TOTAL_SIZE" '
      /^[ \t]*"id"[ \t]*:/ && !done {
        print
        printf "  \"assets\": \"%s\",\n", aid
        printf "  \"assetIndex\": {\n"
        printf "    \"id\": \"%s\",\n", aid
        printf "    \"sha1\": \"%s\",\n", ash
        printf "    \"size\": %s,\n", asz
        printf "    \"totalSize\": %s,\n", ats
        printf "    \"url\": \"https://launchermeta.mojang.com/v1/packages/%s/%s.json\"\n", ash, aid
        printf "  },\n"
        done = 1
        next
      }
      { print }
    ' "$_tmp" >"$_tmp.3" && mv -f "$_tmp.3" "$_tmp"
  fi

  mv -f "$_tmp" "$_out" || return 1
  return 0
}

# ============================== Java ==============================
# FML 3.x 需要 Java 17 运行游戏(纯 MITE 才是 Java 8)。
#
# Apple Silicon 注意: 1.6.4 的 lwjgl (macOS 分支是 2.9.2-nightly-20140822) 只有
# x86_64 native, 没有 arm64 版本, 所以 ARM Mac 上必须用 x86_64 的 JRE 经
# Rosetta 2 运行, 否则 JVM 加载 natives 时会因架构不符失败。

JAVA_BIN=""       # 最终使用的 java 可执行文件
JAVA_NEED_ARCH="" # 便携 JRE 要下的架构
# 是否必须 x86_64 的 Java。只有客户端需要: 它要加载 lwjgl 的 x86_64 native。
# 服务端不含任何 native, ARM Mac 上用原生 aarch64 JRE 更快, 不必过 Rosetta。
NEED_X86_JAVA=0

# java_major <java可执行文件>  -> 主版本号(如 17), 取不到则空
java_major() {
  local _j _v
  _j="$1"
  [ -x "$_j" ] || return 1
  _v=$("$_j" -version 2>&1 | awk -F'"' '/version/{print $2; exit}')
  [ -n "$_v" ] || return 1
  printf '%s' "$_v" | awk -F'[."]' '{ if ($1 == "1") print $2; else print $1 }'
}

# java_arch <java可执行文件>  -> x86_64 | aarch64
java_arch() {
  local _j _a
  _j="$1"
  _a=$("$_j" -XshowSettings:properties -version 2>&1 | awk -F'= *' '/os\.arch/{print $2; exit}')
  printf '%s' "$_a"
}

# 判断某个 java 是否满足需求(版本 + 架构)
java_suitable() {
  local _j _m _a
  _j="$1"
  _m=$(java_major "$_j") || return 1
  [ "$_m" = "$REQUIRED_JAVA_MAJOR" ] || return 1
  if [ "$IS_APPLE_SILICON" = "1" ] && [ "$NEED_X86_JAVA" = "1" ]; then
    _a=$(java_arch "$_j")
    # arm64 的 JRE 跑不了 x86_64 native, 客户端必须用 x86_64 的
    [ "$_a" = "x86_64" ] || return 1
  fi
  return 0
}

find_java() {
  local _c _cands _h
  # 先看本脚本此前下过的便携 JRE (目录名带架构后缀)
  _cands="
${JAVA_HOME:-}/bin/java
"
  for _h in "$MC_DIR"/runtime/*/bin/java; do
    [ -x "$_h" ] && _cands="$_cands
$_h"
  done
  if [ "$OS_NAME" = "osx" ]; then
    for _h in $(/usr/libexec/java_home -V 2>&1 | awk '/\/Library\/Java|\/Contents\/Home/{print $NF}' | grep '^/' ); do
      _cands="$_cands
$_h/bin/java"
    done
    _cands="$_cands
$(/usr/libexec/java_home -v "$REQUIRED_JAVA_MAJOR" 2>/dev/null)/bin/java"
  else
    for _h in /usr/lib/jvm/*/bin/java /usr/java/*/bin/java /opt/java/*/bin/java; do
      [ -x "$_h" ] && _cands="$_cands
$_h"
    done
  fi
  _cands="$_cands
$(command -v java 2>/dev/null)"

  printf '%s\n' "$_cands" | while IFS= read -r _c; do
    [ -n "$_c" ] || continue
    [ -x "$_c" ] || continue
    if java_suitable "$_c"; then printf '%s' "$_c"; break; fi
  done
}

# jre_try_azul <os> <arch> <img> <目标tar>
# Azul 的 os 用 macos/linux, arch 用 x64/aarch64, 与我们的取值基本一致。
jre_try_azul() {
  local _os _arch _img _tar _q _uuid _url _sha _size _aos
  _os="$1"; _arch="$2"; _img="$3"; _tar="$4"
  _aos="$_os"; [ "$_aos" = "mac" ] && _aos="macos"
  _q="$TMP_ROOT/azul.json"
  curl -sL --max-time 25 \
    "https://api.azul.com/metadata/v1/zulu/packages/?java_version=${REQUIRED_JAVA_MAJOR}&os=${_aos}&arch=${_arch}&java_package_type=${_img}&archive_type=tar.gz&latest=true&release_status=ga&availability_types=CA" \
    -o "$_q" 2>/dev/null || return 1
  [ -s "$_q" ] || return 1
  json_flatten "$_q" >"$TMP_ROOT/azul.flat" 2>/dev/null || return 1
  _url=$(jget "$TMP_ROOT/azul.flat" "0.download_url")
  _uuid=$(jget "$TMP_ROOT/azul.flat" "0.package_uuid")
  [ -n "$_url" ] || return 1

  # detail 接口给 sha256_hash, 用来校验
  if [ -n "$_uuid" ]; then
    curl -sL --max-time 25 "https://api.azul.com/metadata/v1/zulu/packages/${_uuid}" \
      -o "$TMP_ROOT/azul-d.json" 2>/dev/null || true
    if [ -s "$TMP_ROOT/azul-d.json" ]; then
      json_flatten "$TMP_ROOT/azul-d.json" >"$TMP_ROOT/azul-d.flat" 2>/dev/null || true
      _sha=$(jget "$TMP_ROOT/azul-d.flat" "sha256_hash")
    fi
  fi
  log_dim "  Azul Zulu: $(basename "$_url")"
  fetch_multi "$_tar" "" "$_sha" "" "$_url"
}

# jre_try_tuna <os> <arch> <img> <目标tar>
# 清华镜像版本会滞后于 Adoptium API, 所以列目录取实际存在的文件名。
# 校验: 该镜像副本与官方发布 sha256 一致(已实测), 用 Adoptium API 按该版本查 sha256。
jre_try_tuna() {
  local _os _arch _img _tar _dir _file _ver _sha _api
  _os="$1"; _arch="$2"; _img="$3"; _tar="$4"
  _dir="https://mirrors.tuna.tsinghua.edu.cn/Adoptium/${REQUIRED_JAVA_MAJOR}/${_img}/${_arch}/${_os}/"
  _file=$(curl -sL --max-time 25 "$_dir" 2>/dev/null \
    | grep -oE "OpenJDK${REQUIRED_JAVA_MAJOR}U-${_img}_${_arch}_${_os}_hotspot_[0-9._]+\.tar\.gz" \
    | sort -u | tail -1)
  [ -n "$_file" ] || return 1

  # 从文件名反推版本(如 17.0.20_8 -> 17.0.20+8)并查官方 sha256
  _ver=$(printf '%s' "$_file" | sed -e 's/.*hotspot_//' -e 's/\.tar\.gz$//' -e 's/_/+/')
  _api="$TMP_ROOT/adoptium-ver.json"
  curl -sL --max-time 25 \
    "https://api.adoptium.net/v3/assets/version/${_ver}?architecture=${_arch}&image_type=${_img}&os=${_os}&vendor=eclipse" \
    -o "$_api" 2>/dev/null || true
  if [ -s "$_api" ]; then
    json_flatten "$_api" >"$TMP_ROOT/adoptium-ver.flat" 2>/dev/null || true
    _sha=$(jget "$TMP_ROOT/adoptium-ver.flat" "0.binaries.0.package.checksum")
  fi
  log_dim "  TUNA: $_file"
  fetch_multi "$_tar" "" "$_sha" "" "${_dir}${_file}"
}

# jre_try_adoptium <os> <arch> <img> <目标tar>
# 走 GitHub release assets, 部分网络下不可达, 作最后回退。
# 注意: API 响应里 "installer"(.pkg) 块排在 "package"(.tar.gz) 之前, 不能用全局
# awk 抓第一个 checksum —— 那是 .pkg 的, 会导致 .tar.gz 每次校验失败并重试所有源。
jre_try_adoptium() {
  local _os _arch _img _tar _api _sha _size _link
  _os="$1"; _arch="$2"; _img="$3"; _tar="$4"
  _api="$TMP_ROOT/adoptium.json"
  curl -sL --max-time 25 \
    "https://api.adoptium.net/v3/assets/latest/${REQUIRED_JAVA_MAJOR}/hotspot?architecture=${_arch}&image_type=${_img}&os=${_os}&vendor=eclipse" \
    -o "$_api" 2>/dev/null || return 1
  [ -s "$_api" ] || return 1
  json_flatten "$_api" >"$TMP_ROOT/adoptium.flat" 2>/dev/null || return 1
  _sha=$(jget "$TMP_ROOT/adoptium.flat" "0.binary.package.checksum")
  _size=$(jget "$TMP_ROOT/adoptium.flat" "0.binary.package.size")
  _link=$(jget "$TMP_ROOT/adoptium.flat" "0.binary.package.link")
  [ -n "$_link" ] || return 1
  log_dim "  Adoptium: $(basename "$_link")"
  fetch_multi "$_tar" "" "$_sha" "$_size" "$_link" \
    "https://api.adoptium.net/v3/binary/latest/${REQUIRED_JAVA_MAJOR}/ga/${_os}/${_arch}/${_img}/hotspot/normal/eclipse"
}

# 下载便携 JRE 到 $MC_DIR/runtime/, 不动系统 Java。
#
# 多源策略(实测得出, 顺序即优先级):
#   1) Azul Zulu  — metadata API 给 download_url + sha256_hash, CDN 实测 4.3 MB/s
#                   可达, 且版本与官方同步。首选。
#   2) 清华 Adoptium 镜像 — 实测副本与官方逐字节一致(sha256 相同), 但版本会滞后
#                   (API 给 17.0.20.1 时镜像只有 17.0.20), 所以要列目录取实际
#                   文件名, 不能照抄 API 的文件名, 否则 404。
#   3) Adoptium 官方 — 走 GitHub release assets, 部分网络下不可达(实测 45s 超时),
#                   仅作最后回退。
#
# 每个源都自带可校验的 sha256, 不做无校验下载。
download_portable_jre() {
  local _os _arch _img _rt _tar _top _ok
  _os="$OS_NAME"; [ "$_os" = "osx" ] && _os="mac"
  _arch="$JAVA_NEED_ARCH"
  _img="jre"
  # 无 zip 也无 python3 时, 打包要靠 jar, 那就得下 JDK
  if [ -z "$ZIP_TOOL" ]; then
    log_warn "$MSG_NEED_JDK_FOR_JAR"
    _img="jdk"
  fi

  # 目录名带架构: 同一台 ARM Mac 上客户端要 x64、服务端要 aarch64, 不能互相覆盖
  _rt="$MC_DIR/runtime/${_img}-${REQUIRED_JAVA_MAJOR}-${_arch}"
  if [ -x "$_rt/bin/java" ] && java_suitable "$_rt/bin/java"; then
    JAVA_BIN="$_rt/bin/java"; return 0
  fi

  log_info "$(printf "$MSG_JAVA_DOWNLOAD" "$REQUIRED_JAVA_MAJOR")"

  _tar="$TMP_ROOT/jre-dl.tar.gz"
  _ok=0
  jre_try_azul     "$_os" "$_arch" "$_img" "$_tar" && _ok=1
  [ "$_ok" = "1" ] || { jre_try_tuna     "$_os" "$_arch" "$_img" "$_tar" && _ok=1; }
  [ "$_ok" = "1" ] || { jre_try_adoptium "$_os" "$_arch" "$_img" "$_tar" && _ok=1; }
  if [ "$_ok" != "1" ]; then
    log_err "$(printf "$MSG_JAVA_DL_FAIL" "$REQUIRED_JAVA_MAJOR")"; return 1
  fi

  rm -rf "$_rt"; mkdir -p "$_rt"
  tar -xzf "$_tar" -C "$_rt" || return 1

  # 压缩包内有一层顶层目录; macOS 的包还多一层 Contents/Home
  _top=$(find "$_rt" -maxdepth 1 -mindepth 1 -type d | head -1)
  if [ -n "$_top" ]; then
    if [ -d "$_top/Contents/Home" ]; then
      (cd "$_top/Contents/Home" && tar cf - .) | (cd "$_rt" && tar xf -)
    else
      (cd "$_top" && tar cf - .) | (cd "$_rt" && tar xf -)
    fi
    rm -rf "$_top"
  fi

  [ -x "$_rt/bin/java" ] || { log_err "$(printf "$MSG_JAVA_DL_FAIL" "$REQUIRED_JAVA_MAJOR")"; return 1; }
  JAVA_BIN="$_rt/bin/java"
  log_ok "$(printf "$MSG_JAVA_DL_OK" "$_rt")"
  return 0
}

check_rosetta() {
  [ "$IS_APPLE_SILICON" = "1" ] || return 0
  log_info "$MSG_ROSETTA_NEEDED"
  if /usr/bin/pgrep -q oahd 2>/dev/null || [ -f /Library/Apple/usr/libexec/oah/libRosettaRuntime ]; then
    log_dim "  $MSG_ROSETTA_OK"
    return 0
  fi
  log_warn "$MSG_ROSETTA_MISSING"
  return 1
}

prepare_java() {
  local _found _m
  # ARM Mac 上客户端需要 x86_64 JRE (lwjgl 只有 x86_64 native);
  # 服务端无 native, 用原生 aarch64 更快。
  if [ "$IS_APPLE_SILICON" = "1" ] && [ "$NEED_X86_JAVA" = "1" ]; then
    JAVA_NEED_ARCH="x64"
    check_rosetta || true
  elif [ "$OS_ARCH" = "aarch64" ]; then
    JAVA_NEED_ARCH="aarch64"
  else
    JAVA_NEED_ARCH="x64"
  fi

  _found=$(find_java)
  if [ -n "$_found" ]; then
    JAVA_BIN="$_found"
    log_ok "$(printf "$MSG_JAVA_FOUND" "$REQUIRED_JAVA_MAJOR" "$JAVA_BIN")"
    return 0
  fi

  log_warn "$(printf "$MSG_JAVA_NOT_FOUND" "$REQUIRED_JAVA_MAJOR")"
  download_portable_jre
}

# ============================== 启动脚本 ==============================

# 离线 UUID: 与主流做法一致, 取 md5("OfflinePlayer:<名字>") 并打上版本3标记
offline_uuid() {
  local _name _md5
  _name="$1"
  if have md5; then _md5=$(printf 'OfflinePlayer:%s' "$_name" | md5)
  elif have md5sum; then _md5=$(printf 'OfflinePlayer:%s' "$_name" | md5sum | awk '{print $1}')
  elif have openssl; then _md5=$(printf 'OfflinePlayer:%s' "$_name" | openssl dgst -md5 | awk '{print $NF}')
  else printf '00000000000040008000000000000000'; return; fi
  # 置版本位为 3(第13位), variant 位为 8(第17位)
  printf '%s' "$_md5" | awk '{
    o = substr($0,1,12) "3" substr($0,14,3) "8" substr($0,18)
    printf "%s-%s-%s-%s-%s", substr(o,1,8), substr(o,9,4), substr(o,13,4), substr(o,17,4), substr(o,21,12)
  }'
}

# 生成 launch-mite.sh
write_launcher() {
  local _out _table _libdir _mitejar _natdir _cp _rel _kind _sha _size _url _ex _vdir
  _out="$1"; _table="$2"; _libdir="$3"; _mitejar="$4"; _natdir="$5"
  _vdir="$MC_DIR/assets/virtual/$MC_ASSET_INDEX_ID"

  # classpath 顺序至关重要: MITE jar 必须排在 FishModLoader.jar 之前。
  #
  # 原因(已实测确认): MITE 的 FontRenderer 用
  #   charWidth[ChatAllowedCharacters.getAllowedCharacters().indexOf(c) + 32]
  # 取字符宽度, 而 charWidth 只有 256 项。该字符表来自 classpath 上的
  # /font.txt, 由 getResourceAsStream 取"最靠前"的那一份:
  #   - MITE jar 的 font.txt  = 144 字符 -> 最大索引 175, 安全
  #   - FML jar 的 font.txt   = 28157 字符(含 CJK) -> 最大索引 28188, 必越界
  # 若 FML 排在前面, 一打开语言选择界面就抛
  # ArrayIndexOutOfBoundsException: Index 7493 out of bounds for length 256
  # 直接崩游戏。把 MITE jar 放首位即可避免。
  _cp="\$MITE_JAR:"
  while IFS="$(printf '\t')" read -r _kind _rel _sha _size _url _ex; do
    [ "$_kind" = "ART" ] || continue
    _cp="$_cp\$LIBS/$_rel:"
  done <"$_table"
  _cp="$_cp\$LIBS/net/xiaoyu233/fishmodloader/fishmodloader/${FML_LIB_VERSION}/FishModLoader.jar:"
  _cp="$_cp\$LIBS/com/google/guava/guava/${GUAVA_DEST_VERSION}/guava-${GUAVA_DEST_VERSION}.jar"

  cat >"$_out" <<LAUNCHEOF
#!/usr/bin/env bash
# 由 MITE + FishModLoader 安装脚本生成, 可直接运行, 不依赖任何启动器。
# 用法: ./$(basename "$_out") [玩家名] [内存MB]
set -u

GAME_DIR="$MC_DIR"
LIBS="\$GAME_DIR/libraries"
MITE_JAR="$_mitejar"
NATIVES="$_natdir"
ASSETS_DIR="$_vdir"
JAVA_BIN="$JAVA_BIN"

PLAYER="\${1:-Player}"
MEM="\${2:-2048}"
UUID="\$(printf 'OfflinePlayer:%s' "\$PLAYER" | { md5 2>/dev/null || md5sum | awk '{print \$1}'; } \\
  | awk '{ s=\$0; o=substr(s,1,12) "3" substr(s,14,3) "8" substr(s,18);
          printf "%s-%s-%s-%s-%s", substr(o,1,8), substr(o,9,4), substr(o,13,4), substr(o,17,4), substr(o,21,12) }')"

CP="$_cp"

cd "\$GAME_DIR" || exit 1
# -Duser.language=en -Duser.country=US 是必需的, 不是可选优化:
# MITE 1.6.4 的 FontRenderer.charWidth 只有 256 项, 在中文 locale 下渲染
# 主菜单列表时会取到索引 7493 而抛 ArrayIndexOutOfBoundsException 直接崩游戏
# (实测: LANG=zh_CN.UTF-8 必崩; 加上这两个属性后同样环境稳定运行)。
# 系统 LANG 不受影响, 只改 JVM 内的 locale。游戏内语言仍可在设置里选中文。
# -Dmixin.debug.countInjections=true 触发 Mixin 的注入数量校验。
#
# 为什么需要它(实测得出, 与直觉相反):
# FML v3.4.3 有三个 mixin 在 MITE R196 上是坏的 —— 其中 MinecraftServerTrans
# 的 @Inject 描述符里写死了混淆名 Ljv;(即 net/minecraft/ServerPlayer), 而 FML
# 自己已经把 jar 重映射成 named, 于是描述符对不上。这是 FML 的上游 bug。
#   不开这个校验: Mixin 不做数量核对, 这三个坏 mixin 被"静默应用", 产出的字节码
#     有问题, 表现为 JVM 退出码 0、零异常输出、游戏根本不启动(最难查的那种)。
#   开了这个校验: Mixin 检出它们无效, 打印 warning 后跳过不应用, 游戏正常启动。
# 这三个 mixin 分别负责 mod 入口点调用与玩家登录回调, 对无 mod 的纯净 MITE
# 客户端没有实际影响。实测连续 3 次均稳定跑到 OpenAL 初始化。
exec "\$JAVA_BIN" \\
  -Xmx"\${MEM}"M \\
  -Duser.language=en \\
  -Duser.country=US \\
  -Dfile.encoding=UTF-8 \\
  -Dmixin.debug.countInjections=true \\
  -Djava.library.path="\$NATIVES" \\
  -Dorg.lwjgl.librarypath="\$NATIVES" \\
  -cp "\$CP" \\
  net.xiaoyu233.fml.relaunch.client.Main \\
  --username "\$PLAYER" \\
  --session "\$UUID" \\
  --version "$MITE_ID" \\
  --gameDir "\$GAME_DIR" \\
  --assetsDir "\$ASSETS_DIR" \\
  --accessToken "\$UUID" \\
  --uuid "\$UUID"
LAUNCHEOF
  chmod +x "$_out"
}

# ============================== 服务端 ==============================
# 服务端走另一条路: 直接下 1.6.4-MITE-HDS_FMLvX.jar, 它是开箱即用的整合包
# (主类 net.xiaoyu233.fml.relaunch.server.JarMain), 不需要原版 jar、不需要
# 注入 FML, 也不需要 assets。

install_server() {
  local _name _jar _sha _start
  mkdir -p "$SERVER_DIR" || return 1

  _name="1.6.4-MITE-HDS_FMLv${FML_VERSION}.jar"
  _jar="$SERVER_DIR/$_name"
  _sha=""
  [ "$FML_VERSION" = "$FML_FALLBACK_VERSION" ] && _sha="$FML_HDS_SHA256_343"

  log_info "$(printf "$MSG_SERVER_DL" "$_name")"
  # shellcheck disable=SC2086
  fetch_multi "$_jar" "" "$_sha" "" $(fml_asset_urls "$_name") || return 1

  _start="$SERVER_DIR/start.sh"
  cat >"$_start" <<SRVEOF
#!/usr/bin/env bash
# 由 MITE + FishModLoader 安装脚本生成
# 用法: ./start.sh [内存MB]
set -u
cd "\$(dirname "\$0")" || exit 1
MEM="\${1:-2048}"
exec "$JAVA_BIN" -Xmx"\${MEM}"M -jar "$_name" nogui
SRVEOF
  chmod +x "$_start"

  if [ -f "$SERVER_DIR/eula.txt" ] && grep -qi 'eula[ ]*=[ ]*true' "$SERVER_DIR/eula.txt"; then
    :
  elif ask_yesno "$MSG_EULA_ASK" n; then
    printf '# https://aka.ms/MinecraftEULA\neula=true\n' >"$SERVER_DIR/eula.txt"
    log_ok "$MSG_EULA_ACCEPTED"
  else
    log_warn "$MSG_EULA_DECLINED"
  fi

  if [ -f "$SERVER_DIR/server.properties" ]; then
    log_dim "  $MSG_SERVER_PROPS_KEEP"
  else
    cat >"$SERVER_DIR/server.properties" <<'PROPEOF'
level-name=world
gamemode=0
difficulty=2
max-players=20
online-mode=true
server-port=25565
view-distance=10
spawn-protection=16
PROPEOF
    log_dim "  $MSG_SERVER_PROPS_NEW"
  fi
  return 0
}

# ============================== 客户端总流程 ==============================

install_client() {
  local _vdir _libdir _natdir _mitejar _verjson _fmlflat _mcflat _mcjson _idxjson _table _launcher _respack _respack_dest _respack_tmp _urls _s

  _vdir="$MC_DIR/versions/$MITE_ID"
  _libdir="$MC_DIR/libraries"
  _natdir="$_vdir/${MITE_ID}-natives"
  _mitejar="$_vdir/${MITE_ID}.jar"
  _verjson="$_vdir/${MITE_ID}.json"
  _launcher="$MC_DIR/launch-mite.sh"
  mkdir -p "$_vdir" "$_libdir" "$MC_DIR/assets/indexes" "$MC_DIR/resourcepacks"

  # --- 原版 jar ---
  log_step "$(printf "$MSG_STEP_VANILLA" "$MC_VERSION")"
  prepare_vanilla_jar || return 1
  log_dim "  $VANILLA_JAR ($(human_size "$(size_of "$VANILLA_JAR")"))"

  # --- 元数据 ---
  log_step "$MSG_STEP_META"
  _mcjson="$MC_DIR/versions/$MC_VERSION/$MC_VERSION.json"
  _urls=""
  for _s in $VANILLA_ORDER; do
    case "$_s" in
      official) _urls="$_urls $(src_meta_base "$_s")/v1/packages/$MC_JSON_SHA1/$MC_VERSION.json" ;;
      bmclapi)  _urls="$_urls $(src_meta_base "$_s")/version/$MC_VERSION/json" ;;
    esac
  done
  # shellcheck disable=SC2086
  fetch_multi "$_mcjson" "$MC_JSON_SHA1" "" "" $_urls || return 1

  _idxjson="$MC_DIR/assets/indexes/${MC_ASSET_INDEX_ID}.json"
  _urls=""
  for _s in $VANILLA_ORDER; do
    case "$_s" in
      official) _urls="$_urls https://launchermeta.mojang.com/v1/packages/$MC_ASSET_INDEX_SHA1/${MC_ASSET_INDEX_ID}.json" ;;
      bmclapi)  _urls="$_urls $(src_meta_base "$_s")/v1/packages/$MC_ASSET_INDEX_SHA1/${MC_ASSET_INDEX_ID}.json" ;;
    esac
  done
  # shellcheck disable=SC2086
  fetch_multi "$_idxjson" "$MC_ASSET_INDEX_SHA1" "" "$MC_ASSET_INDEX_SIZE" $_urls || return 1

  # --- FML installer (版本 JSON 模板在里面) ---
  log_step "$MSG_STEP_FML"
  prepare_fml || return 1
  install_fml_payload "$_libdir" || return 1

  # --- library 表 ---
  _fmlflat="$TMP_ROOT/fml.flat"
  _mcflat="$TMP_ROOT/mc.flat"
  _table="$TMP_ROOT/libs.tbl"
  json_flatten "$FML_CONFIG_JSON" >"$_fmlflat" || return 1
  json_flatten "$_mcjson" >"$_mcflat" || return 1
  build_lib_table "$_fmlflat" "$_table" || return 1
  build_lib_table "$_mcflat" "$TMP_ROOT/mc.tbl" || return 1
  merge_lib_hashes "$_table" "$TMP_ROOT/mc.tbl"
  apply_pins "$_table"

  log_step "$MSG_STEP_LIBS"
  download_libs "$_table" "$_libdir" || return 1

  log_step "$MSG_STEP_NATIVES"
  extract_natives "$_table" "$_libdir" "$_natdir" || return 1
  log_dim "  $_natdir ($(find "$_natdir" -type f 2>/dev/null | awk 'END{print NR+0}') files)"

  # --- assets ---
  log_step "$MSG_STEP_ASSETS"
  json_flatten "$_idxjson" >"$TMP_ROOT/idx.flat" || return 1
  download_assets "$TMP_ROOT/idx.flat" "$MC_DIR/assets" || return 1

  # --- MITE ---
  log_step "$(printf "$MSG_STEP_MITE" "R196")"
  prepare_mite || return 1

  log_step "$MSG_STEP_REPACK"
  repack_mite_jar "$VANILLA_JAR" "$_mitejar" || return 1
  log_dim "  $_mitejar ($(human_size "$(size_of "$_mitejar")"))"

  # --- 版本 JSON ---
  log_step "$(printf "$MSG_STEP_JSON" "$(basename "$_verjson")")"
  write_version_json "$_verjson" || return 1

  # --- 资源包 ---
  log_step "$MSG_STEP_RESPACK"
  _respack=$(find "$MITE_SRC_DIR" -maxdepth 1 -name 'MITE Resource Pack*.zip' 2>/dev/null | head -1)
  if [ -n "$_respack" ]; then
    _respack_dest="$MC_DIR/resourcepacks/$(basename "$_respack")"
    if [ "$TRANSLATION_ENABLED" = "1" ]; then
      prepare_translation || { log_err "$MSG_TRANSLATION_FAILED"; return 1; }
      log_dim "$MSG_TRANSLATION_MERGE"
      _respack_tmp="$TMP_ROOT/$(basename "$_respack").merged.zip"
      rm -f "$_respack_tmp"
      if ! merge_translation_resource_pack "$_respack" "$_respack_tmp"; then
        log_err "$MSG_TRANSLATION_FAILED"
        return 1
      fi
      mv -f "$_respack_tmp" "$_respack_dest" || return 1
      log_dim "  $(basename "$_respack_dest") (含简体中文翻译)"
    else
      cp -f "$_respack" "$_respack_dest" || return 1
      log_dim "  $(basename "$_respack_dest")"
    fi
  else
    if [ "$TRANSLATION_ENABLED" = "1" ]; then
      log_err "$MSG_TRANSLATION_FAILED"
      return 1
    fi
    log_warn "MITE Resource Pack not found in archive"
  fi

  # --- Java ---
  log_step "$MSG_STEP_JAVA"
  NEED_X86_JAVA=1   # 客户端要加载 lwjgl 的 x86_64 native
  prepare_java || return 1

  # --- 启动脚本 ---
  log_step "$MSG_STEP_LAUNCHER"
  write_launcher "$_launcher" "$_table" "$_libdir" "$_mitejar" "$_natdir" || return 1
  log_dim "  $_launcher"

  CLIENT_LAUNCHER="$_launcher"
  CLIENT_VERJSON="$_verjson"
  CLIENT_MITEJAR="$_mitejar"
  return 0
}

# ============================== 自检 ==============================

CLIENT_LAUNCHER=""
CLIENT_VERJSON=""
CLIENT_MITEJAR=""
TRANSLATION_ENABLED=0
UI_LANG=""

verify_client() {
  local _p _bad _n
  _bad=""
  for _p in "$CLIENT_MITEJAR" "$CLIENT_VERJSON" "$CLIENT_LAUNCHER" \
            "$MC_DIR/libraries/net/xiaoyu233/fishmodloader/fishmodloader/${FML_LIB_VERSION}/FishModLoader.jar"; do
    [ -s "$_p" ] || _bad="$_bad\n  missing: $_p"
  done

  # MITE class 必须真的进了 jar
  if [ -s "$CLIENT_MITEJAR" ]; then
    if ! unzip -l "$CLIENT_MITEJAR" 2>/dev/null | grep -q 'net/minecraft'; then
      _bad="$_bad\n  MITE jar has no net/minecraft classes"
    fi
    if unzip -l "$CLIENT_MITEJAR" 2>/dev/null | grep -q 'META-INF/MOJANG'; then
      _bad="$_bad\n  MITE jar still contains Mojang signature (META-INF not stripped)"
    fi
  fi

  # 版本 JSON 的两处修正必须生效
  if [ -s "$CLIENT_VERJSON" ]; then
    grep -q '"assetIndex"' "$CLIENT_VERJSON" || _bad="$_bad\n  version json lacks assetIndex"
    grep -q "fishmodloader:${FML_LIB_VERSION}" "$CLIENT_VERJSON" \
      || _bad="$_bad\n  version json fishmodloader version not corrected"
  fi

  # natives 必须有内容
  _n=$(find "$MC_DIR/versions/$MITE_ID/${MITE_ID}-natives" -type f 2>/dev/null | awk 'END{print NR+0}')
  [ "${_n:-0}" -gt 0 ] || _bad="$_bad\n  natives directory is empty"

  if [ -n "$_bad" ]; then
    log_err "$MSG_VERIFY_FAIL"
    printf "$_bad\n" >&2
    return 1
  fi
  log_ok "$MSG_VERIFY_OK"
  return 0
}

# ============================== 主流程 ==============================

MC_DIR=""
SERVER_DIR=""
MODE=""

default_mc_dir() {
  if [ "$OS_NAME" = "osx" ] && [ -d "$HOME/Library/Application Support/minecraft" ]; then
    printf '%s' "$HOME/Library/Application Support/minecraft"
  else
    printf '%s' "$HOME/.minecraft"
  fi
}

print_banner() {
  printf '\n%s\n' "${C_BOLD}${C_BLUE}${MSG_LOGO}${C_RESET}"
  printf '%s\n' "${C_BOLD}${C_GREEN}${MSG_BANNER}${C_RESET}  ${C_DIM}v${SCRIPT_VERSION}${C_RESET}"
  printf '%s\n' "${C_DIM}────────────────────────────────────────────────${C_RESET}"
  printf '%s  %s\n' "${C_BOLD}${C_YELLOW}[${MSG_BADGE_REPO}]${C_RESET}" "$MSG_REPO_URL"
  printf '%s\n' "${C_BOLD}${C_MAGENTA}[${MSG_BADGE_COMMUNITY}]${C_RESET}"
  printf '  %s %s\n' "${C_BLUE}[${MSG_BADGE_TELEGRAM}]${C_RESET}" "$MSG_COMMUNITY_TELEGRAM"
  printf '  %s %s\n' "${C_BLUE}[${MSG_BADGE_QQ}]${C_RESET}" "$MSG_COMMUNITY_QQ1"
  printf '  %s %s\n' "${C_BLUE}[${MSG_BADGE_QQ}]${C_RESET}" "$MSG_COMMUNITY_QQ2"
  printf '  %s %s\n' "${C_BLUE}[${MSG_BADGE_CHANNEL}]${C_RESET}" "$MSG_COMMUNITY_QQ_CHANNEL"
  printf '  %s %s\n' "${C_BLUE}[${MSG_BADGE_DISCORD}]${C_RESET}" "$MSG_COMMUNITY_DISCORD"
  printf '\n%s %s\n\n' "${C_BOLD}${C_GREEN}[${MSG_BADGE_FREE}]${C_RESET}" "$MSG_FREE_NOTICE"
}

choose_mode() {
  local _c
  if [ -n "$OPT_MODE" ]; then MODE="$OPT_MODE"; return; fi
  _c=$(ask_choice "$MSG_CHOOSE_MODE" 1 "$MSG_MODE_CLIENT" "$MSG_MODE_SERVER" "$MSG_MODE_BOTH")
  case "$_c" in
    1) MODE="client" ;;
    2) MODE="server" ;;
    3) MODE="both" ;;
    *) MODE="client" ;;
  esac
}

main() {
  local _t0 _t1
  _t0=$(date +%s)

  parse_args "$@"
  UI_LANG="$(detect_lang)"
  i18n_load "$UI_LANG"
  case "$UI_LANG" in
    zh*) TRANSLATION_ENABLED=1 ;;
    *)   TRANSLATION_ENABLED=0 ;;
  esac

  if [ "$OPT_VERSION" = "1" ]; then printf '%s\n' "$SCRIPT_VERSION"; exit 0; fi
  if [ "$OPT_HELP" = "1" ]; then
    printf '%s\n\n%s\n' "${C_BOLD}${MSG_USAGE_HEAD}${C_RESET}" "$MSG_USAGE_BODY"
    exit 0
  fi

  init_tty
  init_tmp
  init_json
  detect_curl_parallel

  print_banner

  # 先定模式再算步数, 否则 preflight 会打印 [1/0]
  choose_mode
  # 服务端没有资源包, 即使界面语言为中文也不下载客户端翻译。
  [ "$MODE" = "server" ] && TRANSLATION_ENABLED=0
  # preflight(1) + install_client(12) + verify(1) + server(1)
  case "$MODE" in
    client) STEP_TOTAL=14 ;;
    server) STEP_TOTAL=2 ;;
    both)   STEP_TOTAL=15 ;;
  esac

  preflight   # 内含 detect_platform, default_mc_dir 依赖其结果

  MC_DIR="${OPT_DIR:-$(default_mc_dir)}"
  SERVER_DIR="${OPT_SERVER_DIR:-$(pwd)/mite-server}"

  # --- 交互: 开始执行前询问安装路径, 提示里明确写出不填时的默认路径 ---
  if [ "$TTY_OK" = "1" ] && [ "$OPT_YES" != "1" ]; then
    case "$MODE" in
      client|both) MC_DIR=$(ask_input "$MSG_ASK_MC_DIR" "$MC_DIR") ;;
    esac
    case "$MODE" in
      server|both) SERVER_DIR=$(ask_input "$MSG_ASK_SERVER_DIR" "$SERVER_DIR") ;;
    esac
    # 交互输入允许写 ~ 或相对路径, 统一归一化为绝对路径 (默认值本身已是绝对路径)
    case "$MC_DIR" in
      "~"*) MC_DIR="$HOME${MC_DIR#\~}" ;;
    esac
    case "$SERVER_DIR" in
      "~"*) SERVER_DIR="$HOME${SERVER_DIR#\~}" ;;
    esac
    case "$MC_DIR" in
      /*) : ;;
      *)  MC_DIR="$(pwd)/$MC_DIR" ;;
    esac
    case "$SERVER_DIR" in
      /*) : ;;
      *)  SERVER_DIR="$(pwd)/$SERVER_DIR" ;;
    esac
  fi

  check_disk "$MC_DIR"
  select_sources

  case "$MODE" in
    client|both)
      install_client || die "client installation failed"
      log_step "$MSG_VERIFY"
      verify_client || die "verification failed"
      ;;
  esac

  case "$MODE" in
    server|both)
      log_step "$MSG_STEP_SERVER"
      # 单独装服务端时 FML 版本与 Java 还没准备过
      [ -n "$FML_VERSION" ] || prepare_fml_version_only
      [ -n "$JAVA_BIN" ] || prepare_java || die "java setup failed"
      install_server || die "server installation failed"
      ;;
  esac

  _t1=$(date +%s)
  printf '\n'
  case "$MODE" in
    client|both) log_ok "$MSG_DONE_CLIENT" ;;
  esac
  case "$MODE" in
    server|both) log_ok "$MSG_DONE_SERVER" ;;
  esac
  log_dim "$(printf "$MSG_ELAPSED" "$((_t1 - _t0))")"

  printf '\n%s\n' "${C_BOLD}${MSG_NEXT_HEAD}${C_RESET}"
  case "$MODE" in
    client|both)
      printf '  %s\n' "$(printf "$MSG_NEXT_LAUNCH" "$CLIENT_LAUNCHER Player 2048")"
      printf '  %s\n' "$(printf "$MSG_NEXT_LAUNCHER" "$MITE_ID")"
      ;;
  esac
  case "$MODE" in
    server|both) printf '  %s\n' "$(printf "$MSG_NEXT_SERVER" "$SERVER_DIR/start.sh 2048")" ;;
  esac
  printf '\n'
}

# 只解析 FML 版本号(服务端单独安装时用, 不下 installer)
prepare_fml_version_only() {
  local _tag _latest _latest_source
  if [ -n "$OPT_FML_VERSION" ]; then FML_VERSION="$OPT_FML_VERSION"; return; fi
  _latest=$(fml_query_latest) || _latest=""
  _tag="${_latest%%|*}"
  _latest_source="${_latest#*|}"
  if [ -n "$_tag" ] && [ "$_tag" != "$_latest" ]; then
    FML_VERSION="${_tag#v}"
    log_info "$(printf "$MSG_FML_LATEST" "$_latest_source" "$FML_VERSION")"
  else
    FML_VERSION="$FML_FALLBACK_VERSION"
    log_warn "$(printf "$MSG_FML_API_FAIL" "$FML_VERSION")"
  fi
}

main "$@"
