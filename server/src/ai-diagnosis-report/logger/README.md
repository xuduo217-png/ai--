# AI 诊断日志系统使用说明

## 概述

AI 诊断日志系统专门用于记录 AI 问诊过程中的所有关键操作，包括任务开始、API 调用、数据库更新、错误处理等。所有日志都会写入独立的文件，便于调试和问题追踪。

## 日志文件位置

日志文件存储在：`server/logs/ai-diagnosis/` 目录下

文件命名格式：`ai-diagnosis-YYYY-MM-DD.log`

例如：`ai-diagnosis-2025-01-25.log`

## 日志格式

每条日志都是 JSON 格式，包含以下字段：

```json
{
  "timestamp": "2025-01-25T10:30:45.123Z",
  "level": "INFO",
  "reportId": 123,
  "type": "WESTERN",
  "message": "西医诊断任务开始",
  "data": {
    "jobId": "123",
    "symptoms": "宠物呕吐、食欲不振...",
    "symptomsLength": 250
  }
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| timestamp | string | ISO 8601 格式的时间戳 |
| level | string | 日志级别（INFO/SUCCESS/ERROR/WARNING） |
| reportId | number | 报告 ID |
| type | string | 诊断类型（WESTERN/TCM/REPORT） |
| message | string | 日志消息 |
| data | object | 附加数据（可选） |
| error | string | 错误信息（可选） |
| stackTrace | string | 错误堆栈（可选） |

## 日志级别

- **INFO**: 一般信息（任务开始、准备调用 API 等）
- **SUCCESS**: 成功操作（API 调用成功、数据保存成功等）
- **ERROR**: 错误信息（API 调用失败、处理失败等）
- **WARNING**: 警告信息

## 日志内容示例

### 1. 任务开始日志
```json
{
  "timestamp": "2025-01-25T10:30:45.123Z",
  "level": "INFO",
  "reportId": 123,
  "type": "WESTERN",
  "message": "西医诊断任务开始",
  "data": {
    "jobId": "456",
    "symptoms": "宠物出现呕吐症状，已经持续2天...",
    "symptomsLength": 350
  }
}
```

### 2. API 调用成功日志
```json
{
  "timestamp": "2025-01-25T10:31:15.456Z",
  "level": "SUCCESS",
  "reportId": 123,
  "type": "WESTERN",
  "message": "API 调用成功",
  "data": {
    "apiUrl": "http://152.32.128.33:18082/api/v1/vet/diagnose",
    "requestData": {
      "description": "宠物呕吐、食欲不振"
    },
    "responseData": {
      "diagnosis": "急性胃炎",
      "recommendation": "建议禁食24小时..."
    },
    "duration": "30250ms"
  }
}
```

### 3. 错误日志
```json
{
  "timestamp": "2025-01-25T10:32:00.789Z",
  "level": "ERROR",
  "reportId": 123,
  "type": "TCM",
  "message": "中医诊断失败",
  "error": "Connection timeout",
  "stackTrace": "Error: Connection timeout\n    at ...",
  "data": {
    "duration": "30000ms",
    "jobAttempts": 1
  }
}
```

## 查看日志

### 方法 1：直接查看文件
```bash
# 查看今天的日志
cat server/logs/ai-diagnosis/ai-diagnosis-$(date +%Y-%m-%d).log

# 实时监控日志
tail -f server/logs/ai-diagnosis/ai-diagnosis-$(date +%Y-%m-%d).log

# 查看特定报告的日志
grep '"reportId":123' server/logs/ai-diagnosis/ai-diagnosis-$(date +%Y-%m-%d).log
```

### 方法 2：使用 jq 格式化输出
```bash
# 格式化并查看今天的日志
cat server/logs/ai-diagnosis/ai-diagnosis-$(date +%Y-%m-%d).log | jq '.'

# 查看特定报告的日志（格式化）
grep '"reportId":123' server/logs/ai-diagnosis/ai-diagnosis-$(date +%Y-%m-%d).log | jq '.'

# 查看所有错误日志
grep '"level":"ERROR"' server/logs/ai-diagnosis/ai-diagnosis-*.log | jq '.'
```

### 方法 3：只查看特定类型的日志
```bash
# 只查看西医诊断日志
grep '"type":"WESTERN"' server/logs/ai-diagnosis/ai-diagnosis-$(date +%Y-%m-%d).log | jq '.'

# 只查看错误日志
grep '"level":"ERROR"' server/logs/ai-diagnosis/ai-diagnosis-*.log | jq '.'

# 只查看成功日志
grep '"level":"SUCCESS"' server/logs/ai-diagnosis/ai-diagnosis-*.log | jq '.'
```

## 日志记录的时机

### Western（西医）处理器记录的日志：

1. ✅ **任务开始** - 记录报告 ID、症状描述
2. ✅ **准备调用 API** - 记录 API 地址、超时时间
3. ✅ **API 调用成功** - 记录请求、响应、耗时
4. ✅ **数据库更新成功** - 记录 Job ID、是否有诊断结果
5. ✅ **API 调用失败** - 记录错误信息、耗时、重试次数

### TCM（中医）处理器记录的日志：

1. ✅ **任务开始** - 记录报告 ID、症状描述
2. ✅ **准备调用 API** - 记录 API 地址、超时时间
3. ✅ **API 调用成功** - 记录请求、响应、耗时
4. ✅ **数据库更新成功** - 记录 Job ID、是否有诊断结果
5. ✅ **API 调用失败** - 记录错误信息、耗时、重试次数

## 日志文件管理

### 日志轮转
- 每天自动创建新的日志文件
- 建议定期清理旧日志文件（保留最近 30 天即可）

### 清理旧日志
```bash
# 删除 30 天前的日志
find server/logs/ai-diagnosis/ -name "ai-diagnosis-*.log" -mtime +30 -delete

# 或使用归档压缩
find server/logs/ai-diagnosis/ -name "ai-diagnosis-*.log" -mtime +7 -gzip
```

## 故障排查

### 没有生成日志文件？
1. 检查 `server/logs/ai-diagnosis/` 目录是否有写入权限
2. 检查 NestJS 服务进程是否有文件系统访问权限
3. 查看控制台是否有 "写入日志失败" 的错误信息

### 日志格式混乱？
- 所有日志都是 JSON 格式，每行一个 JSON 对象
- 使用 `jq` 或其他 JSON 工具可以格式化查看

## 最佳实践

1. **定期查看日志** - 每天检查一次日志文件，及时发现异常
2. **设置监控** - 可以根据 ERROR 日志的数量设置告警
3. **日志分析** - 可以编写脚本分析日志，统计成功率、平均耗时等指标
4. **保留重要日志** - 对于出现问题的报告，可以将相关日志保存到单独文件

## 示例：查看特定诊断流程

```bash
# 查看报告 ID 为 123 的完整诊断流程
grep '"reportId":123' server/logs/ai-diagnosis/ai-diagnosis-$(date +%Y-%m-%d).log | \
  jq '{timestamp, level, type, message, data}' | \
  less
```

这样可以清楚地看到一个报告从开始到完成的整个过程。
