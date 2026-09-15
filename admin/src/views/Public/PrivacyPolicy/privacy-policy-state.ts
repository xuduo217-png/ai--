export type PrivacyPolicyState =
  | { status: 'ready'; content: string; updatedAt: string }
  | { status: 'empty'; content: ''; updatedAt: '' }
  | { status: 'error'; content: ''; updatedAt: '' }

interface PrivacyPolicyResponse {
  data?: {
    content?: string | null
    updatedAt?: string | null
  } | null
}

type FetchPrivacyPolicy = () => Promise<PrivacyPolicyResponse>

const emptyState: PrivacyPolicyState = {
  status: 'empty',
  content: '',
  updatedAt: ''
}

export const loadPrivacyPolicy = async (
  fetchPrivacyPolicy: FetchPrivacyPolicy
): Promise<PrivacyPolicyState> => {
  try {
    const response = await fetchPrivacyPolicy()
    const content = response.data?.content?.trim()

    if (!content) {
      return emptyState
    }

    return {
      status: 'ready',
      content,
      updatedAt: response.data?.updatedAt || ''
    }
  } catch {
    return {
      status: 'error',
      content: '',
      updatedAt: ''
    }
  }
}
