import { createClient } from "npm:@supabase/supabase-js@2";

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const notificationTitles: Record<string, Record<string, string>> = {
  new_inquiry: {
    uz: "Yangi so‘rov",
    ru: "Новый запрос",
    en: "New inquiry",
  },
  product_approved: {
    uz: "E’loningiz tasdiqlandi",
    ru: "Ваше объявление одобрено",
    en: "Your listing was approved",
  },
  product_rejected: {
    uz: "E’loningiz rad etildi",
    ru: "Ваше объявление отклонено",
    en: "Your listing was rejected",
  },
};

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemBytes(pem: string): Uint8Array {
  const encoded = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  return Uint8Array.from(atob(encoded), (char) => char.charCodeAt(0));
}

async function fcmAccessToken(account: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${base64Url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })))}.${base64Url(
    new TextEncoder().encode(JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    })),
  )}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!response.ok) throw new Error(`FCM OAuth failed (${response.status})`);
  const payload = await response.json();
  if (typeof payload.access_token !== "string") throw new Error("FCM OAuth returned no access token");
  return payload.access_token;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const projectUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const expectedAuthorization = `Bearer ${serviceRoleKey ?? ""}`;
  if (!serviceRoleKey || request.headers.get("authorization") !== expectedAuthorization) {
    return new Response("Unauthorized", { status: 401 });
  }
  if (!projectUrl) return new Response("Push service unavailable", { status: 503 });

  let input: Record<string, unknown>;
  try {
    input = await request.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }
  const record = input.record && typeof input.record === "object" && !Array.isArray(input.record)
    ? input.record as Record<string, unknown>
    : input;
  const notificationId = record.id ?? input.notification_id;
  const recipientId = record.user_id ?? input.recipient_user_id;
  const titleKey = record.title ?? input.title;
  const body = record.body ?? input.body ?? "";
  if (
    typeof notificationId !== "string" || !uuidPattern.test(notificationId) ||
    typeof recipientId !== "string" || !uuidPattern.test(recipientId) ||
    typeof titleKey !== "string" || titleKey.trim().length < 1 || titleKey.length > 120 ||
    typeof body !== "string" || body.length > 1000
  ) {
    return new Response("Invalid push payload", { status: 400 });
  }
  const rawData = record.data ?? input.data;
  const allowedKeys = new Set(["route", "inquiry_id", "product_id", "type"]);
  const safeData: Record<string, string> = { notification_id: notificationId };
  if (typeof record.type === "string" && record.type.length <= 200) safeData.type = record.type;
  if (rawData && typeof rawData === "object" && !Array.isArray(rawData)) {
    for (const [key, value] of Object.entries(rawData as Record<string, unknown>)) {
      if (allowedKeys.has(key) && typeof value === "string" && value.length <= 200) safeData[key] = value;
    }
  }

  const serviceClient = createClient(projectUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    const { data: claimed, error: claimError } = await serviceClient.rpc("claim_push_delivery", {
      p_notification_id: notificationId,
    });
    if (claimError) throw claimError;
    if (claimed !== true) return Response.json({ status: "duplicate_ignored" });

    const { data: recipient, error: recipientError } = await serviceClient
      .from("profiles")
      .select("language")
      .eq("id", recipientId)
      .maybeSingle();
    if (recipientError) throw recipientError;
    const language = typeof recipient?.language === "string" && ["uz", "ru", "en"].includes(recipient.language)
      ? recipient.language
      : "uz";
    const title = notificationTitles[titleKey]?.[language] ?? "Hosil X";

    const rawAccount = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!rawAccount) throw new Error("FCM service account is not configured");
    const account = JSON.parse(rawAccount) as Record<string, string>;
    if (!account.project_id || !account.client_email || !account.private_key) {
      throw new Error("FCM service account configuration is invalid");
    }
    const accessToken = await fcmAccessToken(account);
    const { data: devices, error: devicesError } = await serviceClient
      .from("device_tokens")
      .select("token,user_id")
      .eq("user_id", recipientId)
      .is("disabled_at", null)
      .limit(500);
    if (devicesError) throw devicesError;

    let delivered = 0;
    let removed = 0;
    let sendFailures = 0;
    for (const device of devices ?? []) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,
        {
          method: "POST",
          headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: { title, body },
              data: safeData,
              android: { priority: "high", notification: { channel_id: "hosilx_main" } },
            },
          }),
        },
      );
      if (response.ok) {
        delivered++;
        continue;
      }
      const errorBody = await response.text();
      if (errorBody.includes("UNREGISTERED") || errorBody.includes("registration-token-not-registered")) {
        const { error: deleteError } = await serviceClient
          .from("device_tokens")
          .delete()
          .eq("token", device.token)
          .eq("user_id", recipientId);
        if (deleteError) console.error("Could not remove expired FCM token", deleteError);
        else removed++;
      } else {
        sendFailures++;
        console.error("FCM send failed", response.status, errorBody.slice(0, 500));
      }
    }
    if (sendFailures > 0 && delivered === 0 && removed === 0) {
      throw new Error("FCM delivery failed for all registered devices");
    }

    const { error: completeError } = await serviceClient.rpc("complete_push_delivery", {
      p_notification_id: notificationId,
      p_status: "sent",
      p_error: null,
    });
    if (completeError) throw completeError;
    return Response.json({ status: "sent", delivered, expiredTokensRemoved: removed });
  } catch (error) {
    console.error("Push dispatch failed", error);
    const { error: completionError } = await serviceClient.rpc("complete_push_delivery", {
      p_notification_id: notificationId,
      p_status: "failed",
      p_error: "push_dispatch_failed",
    });
    if (completionError) console.error("Could not record push failure", completionError);
    return new Response("Push dispatch failed", { status: 503 });
  }
});
