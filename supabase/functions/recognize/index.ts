// Прокси к Plant.id и Pl@ntNet: ключи хранятся в секретах Supabase, а не в приложении.
// Секреты: supabase secrets set PLANT_ID_API_KEY=... PLANTNET_API_KEY=...
// Вызывать может только вошедший пользователь (проверка JWT включена по умолчанию).

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PLANT_ID_ENDPOINTS = new Set(["identification", "health_assessment"]);
const MAX_IMAGES = 5;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

async function passthrough(res: Response) {
  // Pl@ntNet отвечает 404, если вид не найден, — это не ошибка для клиента.
  if (res.status === 404) return json({ results: [] });
  return new Response(await res.text(), {
    status: res.status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function base64ToBlob(b64: string) {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return new Blob([bytes], { type: "image/jpeg" });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST only" }, 405);

  let body: Record<string, any>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json" }, 400);
  }

  const query = new URLSearchParams(
    Object.entries(body.query ?? {}).map(([k, v]) => [k, String(v)]),
  );

  if (body.provider === "plantid") {
    const key = Deno.env.get("PLANT_ID_API_KEY");
    if (!key) return json({ error: "PLANT_ID_API_KEY is not set" }, 500);
    if (!PLANT_ID_ENDPOINTS.has(body.endpoint)) return json({ error: "unknown endpoint" }, 400);
    const images = body.body?.images ?? [];
    if (!Array.isArray(images) || images.length === 0 || images.length > MAX_IMAGES) {
      return json({ error: "1-5 images required" }, 400);
    }
    const res = await fetch(`https://plant.id/api/v3/${body.endpoint}?${query}`, {
      method: "POST",
      headers: { "Api-Key": key, "Content-Type": "application/json" },
      body: JSON.stringify(body.body),
    });
    return passthrough(res);
  }

  if (body.provider === "plantnet") {
    const key = Deno.env.get("PLANTNET_API_KEY");
    if (!key) return json({ error: "PLANTNET_API_KEY is not set" }, 500);
    const images: string[] = body.images ?? [];
    const organs: string[] = body.organs ?? [];
    if (images.length === 0 || images.length > MAX_IMAGES) return json({ error: "1-5 images required" }, 400);
    const form = new FormData();
    images.forEach((b64, i) => {
      form.append("images", base64ToBlob(b64), `photo${i}.jpg`);
      form.append("organs", organs[i] ?? "auto");
    });
    query.set("api-key", key);
    const res = await fetch(`https://my-api.plantnet.org/v2/identify/all?${query}`, { method: "POST", body: form });
    return passthrough(res);
  }

  return json({ error: "unknown provider" }, 400);
});
