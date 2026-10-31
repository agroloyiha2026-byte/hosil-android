import { createClient } from "npm:@supabase/supabase-js@2";

const headers = {
  "content-type": "text/html; charset=utf-8",
  "cache-control": "no-store",
  "x-content-type-options": "nosniff",
  "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
  "referrer-policy": "no-referrer",
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, OPTIONS",
  "access-control-allow-headers": "authorization, apikey, content-type, x-client-info",
};

function escapeHtml(value: unknown): string {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;",
  })[char]!);
}

function page(title: string, content: string, status = 200): Response {
  return new Response(
    `<!doctype html><html lang="uz"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)} · Hosil X</title><style>body{font:16px system-ui,sans-serif;background:#f5f2e8;color:#26332a;margin:0;padding:24px}.card{max-width:560px;margin:5vh auto;background:#fff;border-radius:18px;padding:24px;box-shadow:0 4px 18px #173f2d18}h1{font-size:1.4rem;color:#245c36}.tag{font-weight:700;color:#245c36}.notice{padding:12px;border-radius:10px;background:#e7f0df;margin-top:18px}.muted{color:#62715f}</style><main class="card">${content}<p class="notice">Bu sahifa mahsulot e’loni ma’lumotlarini tekshiradi. Laboratoriya tahlili, mahsulot sifati yoki sertifikat tasdig‘i emas.</p><p class="muted">Hosil X · Ommaviy pasport tekshiruvi</p></main></html>`,
    { status, headers },
  );
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (request.method !== "GET") return new Response("Method not allowed", { status: 405, headers: { ...headers, "content-type": "text/plain" } });

  const token = new URL(request.url).searchParams.get("token") ?? "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(token)) {
    return page("Pasport topilmadi", "<h1>Yaroqsiz havola</h1><p>Pasport identifikatori noto‘g‘ri.</p>", 400);
  }

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!url || !anonKey) {
    console.error("Passport verification is not configured");
    return page("Tekshirib bo‘lmadi", "<h1>Tekshiruv hozircha mavjud emas</h1><p>Keyinroq qayta urinib ko‘ring.</p>", 503);
  }

  try {
    const supabase = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
    const { data, error } = await supabase.rpc("verify_harvest_passport", { p_public_id: token });
    if (error) throw error;
    if (!data || typeof data !== "object") {
      return page("Pasport topilmadi", "<h1>Pasport topilmadi</h1><p>Bu identifikator bo‘yicha pasport mavjud emas.</p>", 404);
    }

    const record = data as Record<string, unknown>;
    const status = record.status;
    if (status === "revoked") {
      return page(
        "Pasport bekor qilingan",
        `<h1>Pasport bekor qilingan</h1><p>Identifikator: <code>${escapeHtml(record.id)}</code></p><p>Bekor qilingan sana: ${escapeHtml(record.revoked_at)}</p>`,
      );
    }
    if (status !== "active") {
      return page(
        "Mahsulot ma’lumoti mavjud emas",
        `<h1>Pasport faol emas</h1><p>Bu pasportning mahsulot e’loni endi ommaga ochiq emas.</p><p>Identifikator: <code>${escapeHtml(record.id)}</code></p>`,
      );
    }

    return page(
      "Pasport tekshirildi",
      `<h1>Hosil X pasporti</h1><p class="tag">Pasport mavjud va faol</p><dl><dt>Mahsulot</dt><dd>${escapeHtml(record.product_title)}</dd><dt>Turi</dt><dd>${escapeHtml(record.product_type)}</dd><dt>Kategoriya</dt><dd>${escapeHtml(record.category)}</dd><dt>Hudud</dt><dd>${escapeHtml(record.product_region)}</dd><dt>Fermer</dt><dd>${escapeHtml(record.farmer_name)}</dd><dt>Fermer hududi</dt><dd>${escapeHtml(record.farmer_region)}</dd><dt>Pasport yaratilgan</dt><dd>${escapeHtml(record.issued_at)}</dd></dl>`,
    );
  } catch (error) {
    console.error("Passport verification request failed", error);
    return page("Tekshirib bo‘lmadi", "<h1>Tekshiruv amalga oshmadi</h1><p>Keyinroq qayta urinib ko‘ring.</p>", 503);
  }
});
