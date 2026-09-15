#!/bin/bash

# React Native 无线 ADB 调试工具
# 统一管理设备连接、应用运行、日志查看等功能

set -e  # 遇到错误立即退出

# 配置
PORT="5555"
PACKAGE_NAME="com.awesomeproject"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数（输出到 stderr 避免污染函数返回值）
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}" >&2
}

log_error() {
    echo -e "${RED}❌ $1${NC}" >&2
}

log_step() {
    echo -e "${CYAN}➜ $1${NC}" >&2
}

# 检查 adb 是否安装
check_adb() {
    if ! command -v adb &> /dev/null; then
        log_error "ADB 未安装或不在 PATH 中"
        log_info "请先安装 Android SDK 或配置 adb"
        exit 1
    fi
}

# 获取 USB 连接设备的 IP 地址
get_usb_device_ip() {
    # 检查是否有 USB 连接的设备
    local usb_device=$(adb devices | grep -v "List" | grep "device" | grep -v ":" | awk '{print $1}' | head -n 1)

    if [ -z "$usb_device" ]; then
        return 1
    fi

    log_step "检测到 USB 连接设备: $usb_device"

    # 尝试多种方法获取 IP
    local device_ip=""

    # 方法1: 通过 ip route 获取（推荐）
    device_ip=$(adb -s "$usb_device" shell ip route 2>/dev/null | grep wlan0 | grep -oE 'src [0-9.]+' | awk '{print $2}' | head -n 1)

    # 方法2: 通过 ifconfig 获取（备用）
    if [ -z "$device_ip" ]; then
        device_ip=$(adb -s "$usb_device" shell ifconfig wlan0 2>/dev/null | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
    fi

    # 方法3: 通过 ip addr 获取（备用）
    if [ -z "$device_ip" ]; then
        device_ip=$(adb -s "$usb_device" shell ip addr show wlan0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
    fi

    if [ -z "$device_ip" ]; then
        log_error "无法获取设备 IP 地址"
        log_info "请确保设备已连接到 Wi-Fi"
        return 1
    fi

    echo "$device_ip"
    return 0
}

# 获取当前连接的无线设备 IP
get_wireless_device_ip() {
    # 从 adb devices 中提取无线连接的设备 IP
    local wireless_device=$(adb devices | grep "$PORT" | grep "device" | awk '{print $1}' | cut -d':' -f1 | head -n 1)

    if [ -z "$wireless_device" ]; then
        return 1
    fi

    echo "$wireless_device"
    return 0
}

# 自动检测设备 IP
auto_detect_device_ip() {
    log_step "自动检测设备 IP 地址..."

    # 优先检查是否已有无线连接
    local wireless_ip=$(get_wireless_device_ip)
    if [ -n "$wireless_ip" ]; then
        log_success "检测到已连接的无线设备: $wireless_ip"
        echo "$wireless_ip"
        return 0
    fi

    # 尝试从 USB 设备获取 IP
    local usb_ip=$(get_usb_device_ip)
    if [ -n "$usb_ip" ]; then
        log_success "从 USB 设备获取 IP: $usb_ip"
        echo "$usb_ip"
        return 0
    fi

    return 1
}

# 手动输入 IP 地址
manual_input_ip() {
    echo "" >&2
    log_warn "无法自动检测设备 IP"
    echo "" >&2
    echo "请手动输入设备 IP 地址：" >&2
    echo "（可在设备的 设置 → 关于手机 → 状态信息 → IP 地址 中查看）" >&2
    echo "" >&2
    read -p "设备 IP: " manual_ip

    if [ -z "$manual_ip" ]; then
        log_error "IP 地址不能为空"
        return 1
    fi

    echo "$manual_ip"
    return 0
}

# 检查设备是否已连接
check_device_connected() {
    local device_ip=$1
    adb devices | grep -F "$device_ip:$PORT" | grep -q "device"
    return $?
}

# 连接设备
connect_device() {
    local device_ip=$1

    log_step "正在连接到设备 $device_ip:$PORT ..."

    # 检查是否已经连接
    if check_device_connected "$device_ip"; then
        log_success "设备已连接"
        return 0
    fi

    # 尝试连接
    adb connect "$device_ip:$PORT" > /dev/null 2>&1

    # 等待连接建立
    sleep 1

    # 验证连接
    if check_device_connected "$device_ip"; then
        log_success "设备连接成功"
        return 0
    else
        log_error "设备连接失败"
        log_info "请检查："
        log_info "  1. 设备和电脑在同一 Wi-Fi 网络"
        log_info "  2. 设备已开启 USB 调试"
        log_info "  3. 首次使用需通过 USB 执行设置（选择菜单中的 setup 选项）"
        return 1
    fi
}

# 断开设备连接
disconnect_device() {
    local device_ip=$1

    log_step "正在断开设备连接..."
    adb disconnect "$device_ip:$PORT" > /dev/null 2>&1
    sleep 1
    log_success "设备已断开"
}

# 首次设置无线 ADB
setup_wireless_adb() {
    echo "" >&2
    echo -e "${CYAN}=====================================${NC}" >&2
    echo -e "${CYAN}  无线 ADB 调试 - 首次设置${NC}" >&2
    echo -e "${CYAN}=====================================${NC}" >&2
    echo "" >&2
    echo "前置条件：" >&2
    echo "  ✓ 设备已通过 USB 连接到电脑" >&2
    echo "  ✓ 已启用 USB 调试" >&2
    echo "  ✓ 设备和电脑在同一 Wi-Fi 网络" >&2
    echo "" >&2

    # 检查 USB 连接
    log_step "检查 USB 连接..."
    if ! adb devices | grep -v "List" | grep "device" | grep -v ":" | grep -q "device"; then
        log_error "未检测到通过 USB 连接的设备"
        echo "" >&2
        echo "请确保：" >&2
        echo "  - 设备已通过 USB 连接" >&2
        echo "  - 已启用 USB 调试" >&2
        echo "  - 已允许电脑调试（设备上会弹出授权提示）" >&2
        exit 1
    fi

    log_success "设备已连接"
    echo "" >&2

    # 获取设备 IP
    local device_ip=$(get_usb_device_ip)
    if [ -z "$device_ip" ]; then
        device_ip=$(manual_input_ip)
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi

    echo "" >&2
    log_info "设备 IP: $device_ip"
    echo "" >&2

    # 启用 TCP 模式
    log_step "启用无线调试模式（端口 $PORT）..."
    adb tcpip "$PORT"

    if [ $? -eq 0 ]; then
        log_success "无线调试模式已启用"
    else
        log_error "启用无线调试模式失败"
        exit 1
    fi

    sleep 2
    echo "" >&2

    # 连接到设备
    log_step "连接到设备 $device_ip:$PORT..."
    adb connect "$device_ip:$PORT"

    if [ $? -eq 0 ]; then
        log_success "连接成功！"
    else
        log_error "连接失败"
        exit 1
    fi

    echo "" >&2
    log_success "设置完成！"
    echo "" >&2
    echo "现在可以：" >&2
    echo "  ✓ 拔掉 USB 线" >&2
    echo "  ✓ 使用 ./adb-dev.sh 管理开发环境" >&2
    echo "" >&2
    log_info "验证连接："
    adb devices
    echo "" >&2
}

# 检查 Metro Bundler 是否运行
check_metro() {
    pgrep -f "react-native start" > /dev/null 2>&1
    return $?
}

# 启动 Metro Bundler
start_metro() {
    if check_metro; then
        log_success "Metro Bundler 已在运行"
    else
        log_step "正在启动 Metro Bundler ..."
        npm start &

        # 等待 Metro 启动（最多 30 秒）
        log_info "等待 Metro Bundler 启动..."
        for i in {1..30}; do
            sleep 1
            if curl -s http://localhost:8081/status > /dev/null 2>&1; then
                log_success "Metro Bundler 启动成功"
                return 0
            fi
            printf "."
        done
        echo ""
        log_warn "Metro Bundler 启动超时，但继续执行..."
    fi
}

# 停止 Metro Bundler
stop_metro() {
    if check_metro; then
        log_step "正在停止 Metro Bundler..."
        pkill -f "react-native start"
        sleep 1
        log_success "Metro Bundler 已停止"
    else
        log_info "Metro Bundler 未运行"
    fi
}

# 运行应用（开发模式）
run_dev() {
    log_step "正在运行应用（开发模式）..."

    # 检查应用是否已安装
    if adb shell pm list packages | grep -q "$PACKAGE_NAME"; then
        log_info "应用已安装"
    else
        log_warn "应用未安装，将自动安装"
    fi

    npm run android:dev
    log_success "应用运行成功！"
}

# 运行应用（生产模式）
run_prod() {
    log_step "正在运行应用（生产模式）..."
    npm run android:prod
    log_success "应用运行成功！"
}

# 构建并安装 Release APK
install_release() {
    log_step "构建并安装 Release APK..."
    npm run android:release
    log_success "安装完成！"
}

# 查看日志
show_logs() {
    log_info "查看实时日志（按 Ctrl+C 退出）..."
    echo ""
    adb logcat | grep -E "ReactNative|AwesomeProject|KeyboardMode"
}

# 显示帮助信息
show_help() {
    cat << EOF
${CYAN}=====================================${NC}
${CYAN}  React Native 无线 ADB 调试工具${NC}
${CYAN}=====================================${NC}

${YELLOW}用法:${NC}
  $0 [选项]

${YELLOW}选项:${NC}
  setup           首次设置无线 ADB（需要 USB 连接）
  connect         连接设备（自动检测 IP）
  disconnect      断开设备连接
  dev             运行开发模式（默认）
  prod            运行生产模式
  metro           仅启动 Metro Bundler
  stop-metro      停止 Metro Bundler
  logs            查看实时日志
  install         构建并安装 Release APK
  status          查看设备连接状态
  help            显示帮助信息

${YELLOW}示例:${NC}
  $0              # 交互式菜单
  $0 setup        # 首次设置（USB 连接）
  $0 dev          # 运行开发模式
  $0 logs         # 查看日志
  $0 disconnect   # 断开连接

${YELLOW}工作流程:${NC}
  1. 首次使用: ./adb-dev.sh setup
  2. 运行应用: ./adb-dev.sh dev
  3. 查看日志: ./adb-dev.sh logs

EOF
}

# 显示交互式菜单
show_menu() {
    clear
    echo -e "${CYAN}=====================================${NC}"
    echo -e "${CYAN}  React Native 无线 ADB 调试工具${NC}"
    echo -e "${CYAN}=====================================${NC}"
    echo ""
    echo "请选择操作："
    echo ""
    echo "  1) 首次设置无线 ADB（需 USB 连接）"
    echo "  2) 连接设备"
    echo "  3) 运行开发模式"
    echo "  4) 运行生产模式"
    echo "  5) 仅启动 Metro"
    echo "  6) 查看实时日志"
    echo "  7) 构建并安装 Release APK"
    echo "  8) 查看设备状态"
    echo "  9) 断开设备连接"
    echo "  0) 退出"
    echo ""
    read -p "请输入选项 [0-9]: " choice

    case $choice in
        1)
            setup_wireless_adb
            ;;
        2)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                device_ip=$(manual_input_ip)
            fi
            if [ -n "$device_ip" ]; then
                connect_device "$device_ip"
            fi
            ;;
        3)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                log_error "未检测到设备，请先连接或设置设备"
                exit 1
            fi
            start_metro
            sleep 2
            run_dev
            ;;
        4)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                log_error "未检测到设备，请先连接或设置设备"
                exit 1
            fi
            start_metro
            sleep 2
            run_prod
            ;;
        5)
            start_metro
            log_info "按 Ctrl+C 停止"
            wait
            ;;
        6)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                log_error "未检测到设备，请先连接或设置设备"
                exit 1
            fi
            show_logs
            ;;
        7)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                log_error "未检测到设备，请先连接或设置设备"
                exit 1
            fi
            install_release
            ;;
        8)
            log_info "设备连接状态："
            adb devices
            ;;
        9)
            local device_ip=$(auto_detect_device_ip)
            if [ -n "$device_ip" ]; then
                disconnect_device "$device_ip"
            else
                log_warn "未检测到已连接的设备"
            fi
            ;;
        0)
            echo "退出"
            exit 0
            ;;
        *)
            log_error "无效选项"
            exit 1
            ;;
    esac
}

# 主函数
main() {
    # 检查 adb
    check_adb

    # 如果没有参数，显示交互式菜单
    if [ $# -eq 0 ]; then
        show_menu
        exit 0
    fi

    # 解析命令行参数
    case $1 in
        setup)
            setup_wireless_adb
            ;;
        connect)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                device_ip=$(manual_input_ip)
            fi
            if [ -n "$device_ip" ]; then
                connect_device "$device_ip"
            fi
            ;;
        disconnect)
            local device_ip=$(auto_detect_device_ip)
            if [ -n "$device_ip" ]; then
                disconnect_device "$device_ip"
            else
                log_warn "未检测到已连接的设备"
            fi
            ;;
        dev)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                log_error "未检测到设备，请先运行: $0 setup 或 $0 connect"
                exit 1
            fi
            connect_device "$device_ip"
            start_metro
            sleep 2
            run_dev
            ;;
        prod)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                log_error "未检测到设备，请先运行: $0 setup 或 $0 connect"
                exit 1
            fi
            connect_device "$device_ip"
            start_metro
            sleep 2
            run_prod
            ;;
        metro)
            start_metro
            log_info "按 Ctrl+C 停止"
            wait
            ;;
        stop-metro)
            stop_metro
            ;;
        logs)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                log_error "未检测到设备，请先运行: $0 setup 或 $0 connect"
                exit 1
            fi
            show_logs
            ;;
        install)
            local device_ip=$(auto_detect_device_ip)
            if [ -z "$device_ip" ]; then
                log_error "未检测到设备，请先运行: $0 setup 或 $0 connect"
                exit 1
            fi
            connect_device "$device_ip"
            install_release
            ;;
        status)
            log_info "设备连接状态："
            adb devices
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            echo ""
            echo "使用 $0 help 查看帮助"
            exit 1
            ;;
    esac
}

# 捕获 Ctrl+C
trap 'echo -e "\n${YELLOW}操作已中断${NC}"; exit 0' INT

# 运行主函数
main "$@"
