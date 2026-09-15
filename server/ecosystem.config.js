/**
 * PM2 配置文件
 * 用于宝塔面板进程管理
 *
 * 使用方法：
 * 1. 开发环境启动: pm2 start ecosystem.config.js --env development
 * 2. 生产环境启动: pm2 start ecosystem.config.js --env production
 * 3. 查看日志: pm2 logs pet-hospitals-api
 * 4. 重启服务: pm2 restart pet-hospitals-api
 * 5. 停止服务: pm2 stop pet-hospitals-api
 * 6. 删除服务: pm2 delete pet-hospitals-api
 */

module.exports = {
  apps: [
    {
      name: 'pet-hospitals-api', // 应用名称
      script: './dist/src/main.js', // 启动脚本（构建后的文件）
      instances: 1, // 实例数量（根据服务器配置调整，建议使用 'max' 自动匹配 CPU 核心数）
      exec_mode: 'cluster', // 集群模式（可选：fork 或 cluster）
      autorestart: true, // 自动重启
      watch: false, // 生产环境不需要监听文件变化
      max_memory_restart: '1G', // 内存超过 1G 自动重启（根据服务器配置调整）
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      // 错误日志和输出日志
      error_file: './logs/pm2-error.log',
      out_file: './logs/pm2-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      // 日志文件大小限制（避免日志文件过大）
      log_file_pattern: './logs/<app_name>-<date>.log',
      merge_logs: true,
    },
  ],
};
