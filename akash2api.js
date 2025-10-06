// Token 将通过 Cloudflare Workers 环境变量传入
const getToken = (env) => env?.TOKEN || "XXXXXXXXXXXXXXXXXXX";
const DEFAULT_HEADERS = {
  "sec-ch-ua":
    '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"',
  "sec-ch-ua-mobile": "?0",
  "user-agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  accept: "*/*",
  "content-type": "text/plain;charset=UTF-8",
  origin: "https://chat.akash.network/",
  "sec-fetch-site": "same-site",
  "sec-fetch-mode": "cors",
  "accept-encoding": "gzip, deflate, br, zstd",
  "accept-language": "zh-CN,zh;q=0.9",
  priority: "u=1, i",
};

async function handleStreamResponse(response, model) {
  // 设置响应头
  const headers = new Headers({
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
    "Access-Control-Allow-Origin": "*",
  });
  try {
    const { readable, writable } = new TransformStream();
    const writer = writable.getWriter();
    const encoder = new TextEncoder();
    const decoder = new TextDecoder("utf-8");

    // 创建错误响应函数
    const createErrorResponse = (error, model) => ({
      id: crypto.randomUUID(),
      object: "chat.completion.chunk",
      created: new Date().getTime(),
      choices: [
        {
          index: 0,
          delta: {
            content: `流式处理错误: ${error}`,
            role: "assistant",
          },
          finish_reason: "stop"
        },
      ],
      model: model
    });

    // 创建响应流
    const stream = response.body;
    let buffer = "";
    // 处理响应流
    const reader = stream.getReader();
    (async () => {
      try {
        while (true) {
          const { done, value } = await reader.read();
          if (done) {
            await writer.write(encoder.encode("data: [DONE]\n\n"));
            await writer.close();
            break;
          }
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";
          for (const line of lines) {
            if (!line.trim()) continue;
            if (line.includes(":")) {
              const [_, ...rest] = line.split(":");
              const content = rest.join(":");
              const data = JSON.parse(content);
              if (typeof data === "string") {
                let content = data;
                const obj = `data: ${JSON.stringify({
                  id: crypto.randomUUID(),
                  object: "chat.completion.chunk",
                  created: new Date().getTime(),
                  choices: [
                    {
                      index: 0,
                      delta: {
                        content: content,
                        role: "assistant",
                      },
                    },
                  ],
                })}\n\n`;
                await writer.write(encoder.encode(obj));
              }
            }
          }
        }
      } catch (error) {
        console.error("流处理错误:", error);
        await writer.write(
          encoder.encode(
            `data: ${JSON.stringify(createErrorResponse(error, model))}\n\n`
          )
        );
        await writer.write(encoder.encode("data: [DONE]\n\n"));
        await writer.close();
      }
    })();

    // 返回新的响应对象
    return new Response(readable, { headers });
  } catch (error) {
    console.error("处理响应错误:", error);
    return new Response("data: [DONE]\n\n", { headers });
  }
}

async function handleRequest(request, env) {
  const url = new URL(request.url);
  // CORS 预检请求处理
  if (request.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "*",
      },
    });
  }

  // 模型列表路由 - 从Akash后端实时获取
  if (url.pathname === "/v1/models" && request.method === "GET") {
    try {
      const res = await fetch("https://chat.akash.network/api/auth/session", {
        headers: DEFAULT_HEADERS,
      });
      const cookie = res.headers.get("set-cookie")?.split(";")[0];

      // 获取真实的模型列表
      const modelsResponse = await fetch("https://chat.akash.network/api/models", {
        headers: {
          ...DEFAULT_HEADERS,
          cookie,
        },
      });

      if (!modelsResponse.ok) {
        throw new Error(`Failed to fetch models: ${modelsResponse.status}`);
      }

      const akashModels = await modelsResponse.json();

      // 转换为OpenAI兼容格式
      const response = {
        object: "list",
        data: akashModels.map(model => ({
          id: model.id,
          object: "model",
          created: model.created || 1686935002,
          owned_by: model.owned_by || "akash",
        })),
      };

      return new Response(JSON.stringify(response), {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
      });
    } catch (error) {
      // 如果获取失败，返回备用模型列表或错误
      return new Response(
        JSON.stringify({
          error: {
            message: `Unable to fetch model list: ${error.message}`,
            type: "server_error",
            code: "model_list_fetch_failed",
          },
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }
  }

  if (url.pathname === "/v1/chat/completions" && request.method === "POST") {
    const authToken = request.headers
      .get("authorization")
      ?.replace("Bearer ", "");

    if (authToken !== getToken(env)) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
      });
    }

    const body = await request.json();
    try {
      const res = await fetch("https://chat.akash.network/api/auth/session", {
        headers: DEFAULT_HEADERS,
      });
      const cookie = res.headers.get("set-cookie")?.split(";")[0];

      const response = await fetch("https://chat.akash.network/api/chat", {
        method: "POST",
        headers: {
          ...DEFAULT_HEADERS,
          "Content-Type": "application/json",
          cookie,
        },
        body: JSON.stringify(body),
      });
      return await handleStreamResponse(response, body.model);
    } catch (error) {
      return new Response(
        JSON.stringify({
          error: {
            message: `${error.message}`,
            type: "server_error",
            param: null,
            code: error.code || null,
          },
        }),
        {
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        }
      );
    }
  }

  return new Response(JSON.stringify({ message: "请使用正确请求路径" }), {
    status: 404,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

// Workers 入口点
export default {
  async fetch(request, env, ctx) {
    return handleRequest(request, env);
  },
};
