#!/bin/bash

# Swift-DocC 文档生成脚本
# 用于生成 AtomicXCore 的完整 API 文档并配置正确的 hosting base path
# 注意：此脚本会临时禁用 .docc 目录以生成完整的 API 文档（类似 Xcode Build Documentation）

set -e

# 配置
SCHEME_NAME="AtomicXCore"  # Scheme 名称
WORKSPACE_OR_PROJECT="../tuikit_engine/atomicx/swift/AtomicXCore.xcworkspace"  # workspace 路径
HOSTING_BASE_PATH="TUIKit_iOS"
OUTPUT_DIR="./docs"
TARGET_MODULE="AtomicXCore"  # 目标模块名称
DOCC_DIR="../tuikit_engine/atomicx/swift/AtomicXCore/AtomicXCore.docc"  # .docc 目录路径

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 清理函数
cleanup() {
    # 恢复 .docc 目录
    if [ -n "$DOCC_BACKUP" ] && [ -d "$DOCC_BACKUP" ]; then
        echo -e "${BLUE}恢复 .docc 目录...${NC}"
        mv "$DOCC_BACKUP" "$DOCC_DIR"
    fi
    
    # 清理临时文件
    if [ -d "./DerivedData" ]; then
        rm -rf ./DerivedData
    fi
}

# 捕获错误和退出信号
trap cleanup EXIT INT TERM

echo -e "${GREEN}=== AtomicXCore 文档生成工具 ===${NC}"
echo -e "${BLUE}模式: 完整 API 文档（自动生成所有 public 符号）${NC}"
echo ""

# 清理旧文档
if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${YELLOW}清理旧文档目录...${NC}"
    rm -rf "$OUTPUT_DIR"
fi

# 临时重命名 .docc 目录以生成完整的 API 文档
DOCC_BACKUP=""
if [ -d "$DOCC_DIR" ]; then
    echo -e "${BLUE}临时禁用 .docc 目录以生成完整 API 文档...${NC}"
    echo -e "${BLUE}（这样可以让 DocC 自动包含所有 public 类、结构体、枚举等）${NC}"
    DOCC_BACKUP="${DOCC_DIR}.backup"
    mv "$DOCC_DIR" "$DOCC_BACKUP"
fi

# 查找 .xcodeproj 或 .xcworkspace
if [ -n "$WORKSPACE_OR_PROJECT" ]; then
    # 使用指定的 workspace/project
    if [[ "$WORKSPACE_OR_PROJECT" == *.xcworkspace ]]; then
        BUILD_FLAG="-workspace"
    else
        BUILD_FLAG="-project"
    fi
else
    # 自动检测
    if [ -f "*.xcworkspace" ]; then
        WORKSPACE_OR_PROJECT=$(find . -maxdepth 2 -name "*.xcworkspace" | head -1)
        BUILD_FLAG="-workspace"
    else
        WORKSPACE_OR_PROJECT=$(find . -maxdepth 2 -name "*.xcodeproj" | head -1)
        BUILD_FLAG="-project"
    fi
fi

echo -e "${GREEN}使用项目: $WORKSPACE_OR_PROJECT${NC}"
echo ""

# 构建文档（设置 hosting base path）
echo -e "${GREEN}开始构建文档...${NC}"
xcodebuild docbuild \
    $BUILD_FLAG "$WORKSPACE_OR_PROJECT" \
    -scheme "$SCHEME_NAME" \
    -destination 'generic/platform=iOS' \
    -derivedDataPath ./DerivedData \
    DOCC_HOSTING_BASE_PATH="/$HOSTING_BASE_PATH"

echo ""
echo -e "${GREEN}查找生成的文档归档...${NC}"

# 查找生成的 .doccarchive（优先查找目标模块的文档）
DOCC_ARCHIVE=$(find ./DerivedData -path "*/AtomicXCore/AtomicXCore.doccarchive" | head -1)

# 如果没找到，尝试其他路径
if [ -z "$DOCC_ARCHIVE" ]; then
    echo -e "${YELLOW}未在标准路径找到，搜索所有 ${TARGET_MODULE}.doccarchive...${NC}"
    DOCC_ARCHIVE=$(find ./DerivedData -name "${TARGET_MODULE}.doccarchive" | head -1)
fi

if [ -z "$DOCC_ARCHIVE" ]; then
    echo -e "${RED}错误: 未找到 .doccarchive 文件${NC}"
    echo -e "${YELLOW}可用的 .doccarchive 文件:${NC}"
    find ./DerivedData -name "*.doccarchive"
    exit 1
fi

echo -e "${GREEN}✓ 找到文档归档: $DOCC_ARCHIVE${NC}"
echo ""

# 转换为静态网站，设置 hosting-base-path
echo -e "${GREEN}转换文档为静态网站...${NC}"
xcrun docc process-archive transform-for-static-hosting \
    "$DOCC_ARCHIVE" \
    --output-path "$OUTPUT_DIR" \
    --hosting-base-path "/$HOSTING_BASE_PATH"

# 添加 .nojekyll 文件
touch "$OUTPUT_DIR/.nojekyll"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 文档生成完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}输出目录:${NC} $OUTPUT_DIR"
echo -e "${BLUE}Hosting Base Path:${NC} /$HOSTING_BASE_PATH/"
echo -e "${BLUE}文档数量:${NC} $(find $OUTPUT_DIR/data/documentation -name "*.json" | wc -l | tr -d ' ') 个 JSON 文件"
echo ""
echo -e "${YELLOW}📚 GitHub Pages URL:${NC}"
echo -e "  https://tencent-rtc.github.io/$HOSTING_BASE_PATH/documentation/atomicxcore"
echo ""
echo -e "${YELLOW}🔍 本地预览:${NC}"
echo -e "  运行: ${GREEN}./local_preview.sh${NC}"
echo -e "  访问: http://localhost:8080/$HOSTING_BASE_PATH/documentation/atomicxcore"
echo ""
