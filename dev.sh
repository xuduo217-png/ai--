#!/bin/bash

# 启动 server 和 admin 开发环境的脚本
# 使用方法: ./dev.sh

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 清理函数：用于退出时关闭所有后台进程
cleanup() {
    echo -e "\n${YELLOW}正在停止所有服务...${NC}"

    # 杀掉所有子进程
    if [ -n "$SERVER_PID" ]; then
        echo -e "${YELLOW}停止 server (PID: $SERVER_PID)${NC}"
        kill $SERVER_PID 2>/dev/null
    fi

    if [ -n "$ADMIN_PID" ]; then
        echo -e "${YELLOW}停止 admin (PID: $ADMIN_PID)${NC}"
        kill $ADMIN_PID 2>/dev/null
    fi

    # 等待进程结束
    wait $SERVER_PID 2>/dev/null
    wait $ADMIN_PID 2>/dev/null

    echo -e "${GREEN}所有服务已停止${NC}"
    exit 0
}

# 捕获 Ctrl+C 信号
trap cleanup SIGINT SIGTERM

# 检查目录是否存在
check_dirs() {
    if [ ! -d "$SCRIPT_DIR/server" ]; then
        echo -e "${RED}错误: server 目录不存在${NC}"
        exit 1
    fi
    if [ ! -d "$SCRIPT_DIR/admin" ]; then
        echo -e "${RED}错误: admin 目录不存在${NC}"
        exit 1
    fi
}

# 启动 server
start_server() {
    echo -e "${BLUE}[1/2]${NC} 启动 server..."
    cd "$SCRIPT_DIR/server"

    # 检查 node_modules
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}server node_modules 不存在，正在安装依赖...${NC}"
        npm install
    fi

    # 后台启动 server
    npm run start:dev &
    SERVER_PID=$!
    echo -e "${GREEN}✓ server 已启动 (PID: $SERVER_PID)${NC}"
}

# 启动 admin
start_admin() {
    echo -e "${BLUE}[2/2]${NC} 启动 admin..."
    cd "$SCRIPT_DIR/admin"

    # 检查 node_modules
    if [ ! -d "node_modules" ]; then
        echo -e "${YELLOW}admin node_modules 不存在，正在安装依赖...${NC}"
        pnpm install
    fi

    # 后台启动 admin
    pnpm dev &
    ADMIN_PID=$!
    echo -e "${GREEN}✓ admin 已启动 (PID: $ADMIN_PID)${NC}"
}

# 主函数
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   宠物医院管理系统 - 开发环境启动${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    check_dirs

    # 启动服务
    start_server
    start_admin

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   所有服务已启动！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Server:${NC}  http://localhost:3000"
    echo -e "${BLUE}Admin:${NC}   http://localhost:4000"
    echo ""
    echo -e "${YELLOW}按 Ctrl+C 停止所有服务${NC}"
    echo ""

    # 等待子进程
    wait $SERVER_PID $ADMIN_PID
}

main
