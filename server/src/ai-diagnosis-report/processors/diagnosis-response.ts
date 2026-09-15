import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

type JsonObject = Record<string, any>;
const object = (value: unknown): JsonObject =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as JsonObject)
    : {};

/** 保持西医原字段位置；中医仅在有增量信息时使用 APP 已兼容的 data 包装。 */
export function diagnosisResult(response: JsonObject, western: boolean) {
  const metadata = {
    ...(Object.keys(object(response.assessment)).length
      ? { assessment: response.assessment }
      : {}),
    ...(typeof response.disclaimer === 'string' && response.disclaimer.trim()
      ? { disclaimer: response.disclaimer }
      : {}),
  };
  if (western) return { ...object(response.data), ...metadata };
  if (!Object.keys(metadata).length) return response.data;
  return { data: response.data, ...metadata };
}

export function diagnosisComplete(value: unknown): boolean {
  if (!value) return false;
  const json = object(value);
  return json.taskStatus !== 'pending' && json.taskStatus !== 'failed';
}

/** 评估可以先完成；只有主诊断 data 返回后才结束轮询。 */
export async function requestDiagnosis(
  http: HttpService,
  apiUrl: string,
  body: { description: string },
  timeout: number,
  western: boolean,
  onProgress: (value: JsonObject) => Promise<void>,
  previous?: unknown,
): Promise<JsonObject> {
  const saved = object(previous);
  const resumed =
    typeof saved.taskId === 'string' && saved.taskStatus === 'pending';
  let response: JsonObject = resumed
    ? {
        data: { task_id: saved.taskId, status: 'pending' },
        assessment: saved.assessment,
        disclaimer: saved.disclaimer,
      }
    : (
        await firstValueFrom(
          http.post(apiUrl, body, { timeout, params: { async_mode: true } }),
        )
      ).data;
  let taskId = resumed ? saved.taskId : undefined;
  let latestAssessment = object(response).assessment;
  let latestDisclaimer = object(response).disclaimer;
  let latestResult: unknown;
  for (let attempt = 0; attempt <= 240; attempt += 1) {
    if (!response || typeof response !== 'object')
      throw new Error('AI 诊断响应格式异常');
    const data = object(response.data);
    const status = String(data.status ?? response.status ?? '').toLowerCase();
    taskId = typeof data.task_id === 'string' ? data.task_id : taskId;
    if (
      ['failed', 'error', 'timeout', 'cancelled'].includes(status) ||
      Number(response.code) >= 400
    ) {
      await onProgress({
        ...object(
          diagnosisResult(
            {
              ...response,
              assessment: latestAssessment,
              disclaimer: latestDisclaimer,
              data: western ? {} : [],
            },
            western,
          ),
        ),
        taskId,
        taskStatus: 'failed',
      });
      throw new Error('AI 诊断任务失败');
    }
    if (Object.keys(object(response.assessment)).length)
      latestAssessment = response.assessment;
    if (typeof response.disclaimer === 'string')
      latestDisclaimer = response.disclaimer;
    response = {
      ...response,
      assessment: latestAssessment,
      disclaimer: latestDisclaimer,
    };
    const hasResult = western
      ? Array.isArray(data.diagnosis) || Array.isArray(data.medications)
      : Array.isArray(response.data);
    if (hasResult && !['pending', 'processing', 'running'].includes(status))
      latestResult = response.data;
    const assessmentPending =
      object(latestAssessment).status === 'pending' ||
      ['emergency', 'recommended_tests', 'temporary_care'].some(
        (key) => object(object(latestAssessment)[key]).status === 'pending',
      );
    if (latestResult !== undefined && (!assessmentPending || !taskId))
      return { ...response, data: latestResult };

    if (!taskId) throw new Error('AI 异步响应缺少 task_id 或诊断结果');
    const interim = diagnosisResult(
      { ...response, data: latestResult ?? (western ? {} : []) },
      western,
    );
    await onProgress({
      ...(western ? {} : { data: [] }),
      ...object(interim),
      taskId,
      taskStatus: 'pending',
    });
    if (attempt === 240) throw new Error('AI 诊断轮询超时');
    await new Promise((resolve) => setTimeout(resolve, 2000));
    response = (
      await firstValueFrom(
        http.get(`${apiUrl}/task/${encodeURIComponent(taskId)}`, { timeout }),
      )
    ).data;
  }
  throw new Error('AI 诊断轮询超时');
}
