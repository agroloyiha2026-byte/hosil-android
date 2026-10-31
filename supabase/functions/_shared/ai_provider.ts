export interface AiMessage {
  role: "user" | "assistant";
  content: string;
}

export async function requestOpenAi(input: {
  apiKey: string;
  model: string;
  system: string;
  messages: AiMessage[];
  timeoutMs: number;
}): Promise<string> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), input.timeoutMs);
  try {
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        authorization: `Bearer ${input.apiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: input.model,
        store: false,
        instructions: input.system,
        input: input.messages.map(({ role, content }) => ({ role, content })),
        max_output_tokens: 1200,
      }),
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`provider_status_${response.status}`);
    const body = await response.json();
    const text = (body.output ?? [])
      .flatMap((item: { content?: Array<{ type?: string; text?: string }> }) => item.content ?? [])
      .filter((item: { type?: string }) => item.type === "output_text")
      .map((item: { text?: string }) => item.text ?? "")
      .join("\n")
      .trim();
    if (!text) throw new Error("provider_empty_response");
    return text;
  } finally {
    clearTimeout(timeout);
  }
}