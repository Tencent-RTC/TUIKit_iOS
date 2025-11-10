#!/bin/bash

# 本地预览文档脚本
# 用于在合入 GitHub 前本地验证文档是否能正常访问

set -e

# 配置
DOCS_DIR="./docs"
PORT=8080
BASE_PATH="/TUIKit_iOS"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== 本地文档预览服务 ===${NC}"
echo ""

# 检查 docs 目录是否存在
if [ ! -d "$DOCS_DIR" ]; then
    echo -e "${YELLOW}错误: docs 目录不存在${NC}"
    echo "请先运行 ./build_docs.sh 生成文档"
    exit 1
fi

# 检查 Python 是否安装
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}错误: 未找到 python3${NC}"
    echo "请先安装 Python 3"
    exit 1
fi

echo -e "${BLUE}文档目录:${NC} $DOCS_DIR"
echo -e "${BLUE}服务端口:${NC} $PORT"
echo -e "${BLUE}Base Path:${NC} $BASE_PATH"
echo ""

# 检查端口是否被占用
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo -e "${YELLOW}警告: 端口 $PORT 已被占用${NC}"
    echo "正在尝试停止占用该端口的进程..."
    lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
    sleep 1
fi

echo -e "${GREEN}启动本地服务器...${NC}"
echo ""

# 创建临时目录结构来模拟 GitHub Pages 的路径
TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR$BASE_PATH"

# 复制文档文件到临时目录（使用复制而非符号链接以确保兼容性）
cp -r "$(pwd)/$DOCS_DIR"/* "$TEMP_DIR$BASE_PATH/"

# 创建根目录的重定向页面
cat > "$TEMP_DIR/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=/TUIKit_iOS/">
    <title>Redirecting...</title>
</head>
<body>
    <p>Redirecting to <a href="/TUIKit_iOS/">/TUIKit_iOS/</a>...</p>
</body>
</html>
EOF

echo -e "${GREEN}✅ 服务器已启动！${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📚 访问以下 URL 预览文档：${NC}"
echo ""
echo -e "  ${BLUE}主页:${NC}"
echo -e "  http://localhost:$PORT$BASE_PATH/"
echo ""
echo -e "  ${BLUE}AtomicXCore 文档:${NC}"
echo -e "  http://localhost:$PORT$BASE_PATH/documentation/atomicxcore"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}提示:${NC}"
echo -e "  • 这个环境模拟了 GitHub Pages 的路径结构"
echo -e "  • 按 ${GREEN}Ctrl+C${NC} 停止服务器"
echo -e "  • 服务器日志将显示在下方"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 清理函数
cleanup() {
    echo ""
    echo -e "${YELLOW}正在停止服务器...${NC}"
    rm -rf "$TEMP_DIR"
    echo -e "${GREEN}✅ 服务器已停止${NC}"
    exit 0
}

# 捕获 Ctrl+C
trap cleanup INT TERM

# 启动 Python HTTP 服务器
cd "$TEMP_DIR"
python3 -m http.server $PORT

# 清理临时目录
cleanup
