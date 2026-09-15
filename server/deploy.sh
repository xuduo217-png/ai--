#!/bin/bash

# ========================================
# Pet Hospitals API 一键部署脚本
# 适用于宝塔面板环境
# ========================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目配置
PROJECT_DIR="/www/wwwroot/api.zuoyongyoubao.com"
PROJECT_NAME="pet-hospitals-api"
NODE_VERSION="22"  # 使用 Node.js 22.x 最新版本
NVM_VERSION="v0.39.7"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Pet Hospitals API 部署脚本${NC}"
echo -e "${GREEN}========================================${NC}\n"

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用 root 用户运行此脚本${NC}"
    echo "使用命令: sudo bash deploy.sh"
    exit 1
fi

# ========================================
# 函数定义
# ========================================

# 安装 nvm
install_nvm() {
    echo -e "${YELLOW}正在安装 nvm ${NVM_VERSION}...${NC}"

    # 下载并安装 nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash

    # 等待安装完成
    sleep 2

    # 配置环境变量（立即在当前会话生效）
    export NVM_DIR="$HOME/.nvm"

    # 添加到 .bashrc（如果不存在）
    if ! grep -q "NVM_DIR" ~/.bashrc 2>/dev/null; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc
        echo -e "${GREEN}✓ 已添加 nvm 配置到 ~/.bashrc${NC}"
    fi

    # 添加到 .zshrc（如果不存在，兼容 zsh 用户）
    if [ -f ~/.zshrc ] && ! grep -q "NVM_DIR" ~/.zshrc 2>/dev/null; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
        echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.zshrc
        echo -e "${GREEN}✓ 已添加 nvm 配置到 ~/.zshrc${NC}"
    fi

    # 加载 nvm（关键步骤）
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    fi

    # 验证安装
    if command -v nvm &> /dev/null; then
        echo -e "${GREEN}✓ nvm 安装成功: $(nvm --version)${NC}\n"
        return 0
    else
        echo -e "${RED}✗ nvm 安装失败${NC}"
        echo -e "${YELLOW}尝试手动加载: export NVM_DIR=\"$HOME/.nvm\" && source \$NVM_DIR/nvm.sh${NC}"
        return 1
    fi
}

# 安装 Node.js
install_nodejs() {
    echo -e "${YELLOW}正在安装 Node.js ${NODE_VERSION}.x 最新版本...${NC}"

    # 确保 nvm 已加载
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        \. "$NVM_DIR/nvm.sh"
    else
        echo -e "${RED}错误: nvm.sh 文件不存在${NC}"
        return 1
    fi

    # 安装 Node.js 22.x 最新版本
    nvm install ${NODE_VERSION}

    # 设置为默认版本
    nvm alias default ${NODE_VERSION}

    # 使用新安装的版本
    nvm use ${NODE_VERSION}

    # 更新 PATH 确保新版本的 node/npm 可用
    export PATH="$NVM_DIR/versions/node/$(nvm version ${NODE_VERSION})/bin:$PATH"

    echo -e "${GREEN}✓ Node.js 安装成功: $(node -v)${NC}"
    echo -e "${GREEN}✓ npm 版本: $(npm -v)${NC}\n"
}

# 配置 npm 淘宝镜像
configure_npm_registry() {
    echo -e "${YELLOW}配置 npm 淘宝镜像...${NC}"

    # 设置淘宝镜像
    npm config set registry https://registry.npmmirror.com

    echo -e "${GREEN}✓ npm 镜像配置完成: $(npm config get registry)${NC}\n"
}

# ========================================
# 主流程
# ========================================

# 1. 检查并安装 Node.js
echo -e "${YELLOW}[1/9] 检查 Node.js 环境...${NC}"

if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}未检测到 Node.js，准备安装 nvm 和 Node.js...${NC}"

    # 检查是否已安装 nvm
    if [ ! -d "$HOME/.nvm" ]; then
        install_nvm
        if [ $? -ne 0 ]; then
            echo -e "${RED}错误: nvm 安装失败，无法继续${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}✓ 检测到 nvm 已安装${NC}"
        # 加载 nvm
        export NVM_DIR="$HOME/.nvm"
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            \. "$NVM_DIR/nvm.sh"
            echo -e "${GREEN}✓ nvm 已加载: $(nvm --version)${NC}"
        else
            echo -e "${RED}错误: 无法加载 nvm.sh${NC}"
            exit 1
        fi
    fi

    # 安装 Node.js
    install_nodejs
else
    CURRENT_NODE_VERSION=$(node -v | cut -d'.' -f1 | sed 's/v//')
    echo -e "${GREEN}✓ Node.js 已安装: $(node -v)${NC}"

    # 检查版本是否符合要求（最低 18.x）
    if [ "$CURRENT_NODE_VERSION" -lt 18 ]; then
        echo -e "${YELLOW}Node.js 版本过低（$(node -v)），建议升级到 ${NODE_VERSION}.x${NC}"
        read -p "是否现在安装 Node.js ${NODE_VERSION}.x？(y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ ! -d "$HOME/.nvm" ]; then
                install_nvm
            else
                echo -e "${GREEN}✓ 加载已安装的 nvm${NC}"
                export NVM_DIR="$HOME/.nvm"
                if [ -s "$NVM_DIR/nvm.sh" ]; then
                    \. "$NVM_DIR/nvm.sh"
                else
                    echo -e "${RED}错误: 无法加载 nvm.sh${NC}"
                    exit 1
                fi
            fi
            install_nodejs
        fi
    else
        echo -e "${GREEN}✓ Node.js 版本符合要求${NC}\n"
    fi
fi

# 2. 配置 npm 淘宝镜像
echo -e "${YELLOW}[2/9] 配置 npm 镜像源...${NC}"
configure_npm_registry

# 3. 检查项目目录
echo -e "${YELLOW}[3/9] 检查项目目录...${NC}"
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}错误: 项目目录不存在: $PROJECT_DIR${NC}"
    echo "请先在宝塔面板创建网站或手动创建目录"
    exit 1
fi
echo -e "${GREEN}✓ 项目目录: $PROJECT_DIR${NC}\n"

# 4. 进入项目目录
echo -e "${YELLOW}[4/9] 进入项目目录...${NC}"
cd "$PROJECT_DIR"
echo -e "${GREEN}✓ 已进入项目目录${NC}\n"

# 5. 检查并安装依赖
echo -e "${YELLOW}[5/9] 检查依赖...${NC}"
if [ -f "package.json" ]; then
    # 检查 node_modules 是否存在
    if [ ! -d "node_modules" ] || [ -z "$(ls -A node_modules 2>/dev/null)" ]; then
        echo -e "${YELLOW}未检测到 node_modules，开始安装依赖...${NC}"
        echo -e "${BLUE}使用淘宝镜像源: https://registry.npmmirror.com${NC}"
        npm install
        echo -e "${GREEN}✓ 依赖安装完成${NC}\n"
    else
        echo -e "${GREEN}✓ node_modules 已存在，跳过安装${NC}"
        echo -e "${YELLOW}提示: 如需重新安装，请先执行 rm -rf node_modules${NC}\n"
    fi
else
    echo -e "${RED}错误: 未找到 package.json${NC}"
    exit 1
fi

# 6. 构建项目
echo -e "${YELLOW}[6/9] 构建项目...${NC}"
if [ -f "nest-cli.json" ] || grep -q '"build"' package.json; then
    # 清理旧的构建目录，避免权限问题
    if [ -d "dist" ]; then
        echo -e "${YELLOW}清理旧的构建目录...${NC}"
        rm -rf dist
    fi

    npm run build

    # 验证构建产物
    if [ ! -f "dist/src/main.js" ]; then
        echo -e "${RED}错误: 构建失败，dist/src/main.js 不存在${NC}"
        echo -e "${YELLOW}请检查构建日志${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ 项目构建完成${NC}"
    echo -e "${GREEN}✓ 构建产物: dist/src/main.js ($(ls -lh dist/src/main.js | awk '{print $5}'))${NC}\n"
else
    echo -e "${RED}错误: 未找到构建脚本${NC}"
    exit 1
fi

# 7. 创建必要目录
echo -e "${YELLOW}[7/9] 创建必要目录...${NC}"
mkdir -p uploads logs
chmod 755 uploads logs
echo -e "${GREEN}✓ 目录创建完成${NC}\n"

# 8. 检查环境配置
echo -e "${YELLOW}[8/9] 检查环境配置...${NC}"
if [ ! -f ".env" ]; then
    if [ -f ".env.production" ]; then
        echo -e "${YELLOW}未找到 .env 文件，从 .env.production 复制...${NC}"
        cp .env.production .env
        echo -e "${YELLOW}⚠ 请编辑 .env 文件，配置数据库连接和其他敏感信息！${NC}"
    else
        echo -e "${RED}错误: 未找到 .env 或 .env.production 文件${NC}"
        echo "请创建 .env 文件并配置环境变量"
        exit 1
    fi
fi
echo -e "${GREEN}✓ 环境配置检查完成${NC}\n"

# 9. 使用 PM2 启动/重启应用
echo -e "${YELLOW}[9/9] 启动应用...${NC}"
if ! command -v pm2 &> /dev/null; then
    echo -e "${YELLOW}未检测到 PM2，正在安装...${NC}"
    npm install -g pm2
fi

# 检查是否已存在进程
if pm2 list | grep -q "$PROJECT_NAME"; then
    echo -e "${YELLOW}检测到已运行的进程，正在重启...${NC}"
    pm2 restart $PROJECT_NAME
else
    echo -e "${YELLOW}启动新进程...${NC}"
    pm2 start ecosystem.config.js --env production
fi

# 设置开机自启
pm2 startup > /dev/null 2>&1
pm2 save > /dev/null 2>&1

echo -e "${GREEN}✓ 应用启动完成${NC}\n"

# 显示部署信息
echo -e "${YELLOW}部署完成！${NC}\n"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署信息${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "项目目录: ${GREEN}$PROJECT_DIR${NC}"
echo -e "项目名称: ${GREEN}$PROJECT_NAME${NC}"
echo -e "Node版本: ${GREEN}$(node -v)${NC}"
echo -e "PM2状态: ${GREEN}$(pm2 list | grep $PROJECT_NAME | awk '{print $10}')${NC}"
echo ""
echo -e "${YELLOW}常用命令:${NC}"
echo -e "  查看日志:  ${GREEN}pm2 logs $PROJECT_NAME${NC}"
echo -e "  重启应用:  ${GREEN}pm2 restart $PROJECT_NAME${NC}"
echo -e "  停止应用:  ${GREEN}pm2 stop $PROJECT_NAME${NC}"
echo -e "  查看状态:  ${GREEN}pm2 status${NC}"
echo ""
echo -e "${YELLOW}下一步操作:${NC}"
echo -e "  1. 编辑 .env 文件，配置数据库连接"
echo -e "  2. 在宝塔面板配置 Nginx 反向代理"
echo -e "  3. 配置 SSL 证书（推荐使用 Let's Encrypt）"
echo -e "  4. 访问 https://api.zuoyongyoubao.com/api-docs 查看 API 文档"
echo ""
echo -e "${GREEN}========================================${NC}"
