#!/bin/bash

# Swift-DocC 文档生成脚本 - 直接方法
# 直接基于 target 生成完整 API 文档，不依赖 .docc 目录

set -e

# 配置
SCHEME_NAME="AtomicXCore"
WORKSPACE_OR_PROJECT="../tuikit_engine/atomicx/swift/AtomicXCore.xcworkspace"
HOSTING_BASE_PATH="TUIKit_iOS"
OUTPUT_DIR="./docs"
TARGET_MODULE="AtomicXCore"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== AtomicXCore 文档生成工具 (直接方法) ===${NC}"
echo -e "${BLUE}模式: 基于符号图生成完整 API 文档${NC}"
echo -e "${BLUE}Target: ${TARGET_MODULE}${NC}"
echo ""

# 清理旧文档
if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${YELLOW}清理旧文档目录...${NC}"
    rm -rf "$OUTPUT_DIR"
fi

# 清理旧的构建文件
if [ -d "./DerivedData" ]; then
    rm -rf ./DerivedData
fi

echo -e "${GREEN}步骤 1: 构建项目并生成符号图...${NC}"

# 首先构建项目以生成符号图
xcodebuild build \
    -workspace "$WORKSPACE_OR_PROJECT" \
    -scheme "$SCHEME_NAME" \
    -destination 'generic/platform=iOS' \
    -derivedDataPath ./DerivedData \
    OTHER_SWIFT_FLAGS="-emit-symbol-graph -emit-symbol-graph-dir ./symbol-graphs"

echo ""
echo -e "${GREEN}步骤 2: 查找符号图文件...${NC}"

# 查找生成的符号图
SYMBOL_GRAPH_DIR="./symbol-graphs"
if [ ! -d "$SYMBOL_GRAPH_DIR" ]; then
    # 尝试在 DerivedData 中查找
    SYMBOL_GRAPH_DIR=$(find ./DerivedData -name "*.symbols.json" -exec dirname {} \; | head -1)
fi

if [ ! -d "$SYMBOL_GRAPH_DIR" ] || [ -z "$(ls -A $SYMBOL_GRAPH_DIR 2>/dev/null)" ]; then
    echo -e "${RED}错误: 未找到符号图文件${NC}"
    echo -e "${YELLOW}尝试使用 swift-docc convert 直接处理源码...${NC}"
    
    # 创建临时的符号图
    mkdir -p ./temp-symbols
    
    # 使用 swift-docc 直接处理
    swift-docc convert \
        ../tuikit_engine/atomicx/swift/AtomicXCore \
        --fallback-display-name "$TARGET_MODULE" \
        --fallback-bundle-identifier "com.tencent.$TARGET_MODULE" \
        --fallback-bundle-version "1.0.0" \
        --additional-symbol-graph-dir ./temp-symbols \
        --output-path "$OUTPUT_DIR" \
        --hosting-base-path "/$HOSTING_BASE_PATH" \
        --transform-for-static-hosting
else
    echo -e "${GREEN}✓ 找到符号图目录: $SYMBOL_GRAPH_DIR${NC}"
    
    echo ""
    echo -e "${GREEN}步骤 3: 使用 swift-docc 生成文档...${NC}"
    
    # 使用 swift-docc 生成文档
    swift-docc convert \
        "$SYMBOL_GRAPH_DIR" \
        --fallback-display-name "$TARGET_MODULE" \
        --fallback-bundle-identifier "com.tencent.$TARGET_MODULE" \
        --fallback-bundle-version "1.0.0" \
        --output-path "$OUTPUT_DIR" \
        --hosting-base-path "/$HOSTING_BASE_PATH" \
        --transform-for-static-hosting
fi

# 添加 .nojekyll 文件
touch "$OUTPUT_DIR/.nojekyll"

# 清理临时文件
rm -rf ./DerivedData ./temp-symbols ./symbol-graphs

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ 文档生成完成！${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}输出目录:${NC} $OUTPUT_DIR"
echo -e "${BLUE}Hosting Base Path:${NC} /$HOSTING_BASE_PATH/"

if [ -d "$OUTPUT_DIR/data/documentation" ]; then
    echo -e "${BLUE}文档数量:${NC} $(find $OUTPUT_DIR/data/documentation -name "*.json" | wc -l | tr -d ' ') 个 JSON 文件"
fi

echo ""
echo -e "${YELLOW}📚 GitHub Pages URL:${NC}"
echo -e "  https://tencent-rtc.github.io/$HOSTING_BASE_PATH/documentation/atomicxcore"
echo ""
echo -e "${YELLOW}🔍 本地预览:${NC}"
echo -e "  运行: ${GREEN}./local_preview.sh${NC}"
echo -e "  访问: http://localhost:8080/$HOSTING_BASE_PATH/documentation/atomicxcore"
echo ""