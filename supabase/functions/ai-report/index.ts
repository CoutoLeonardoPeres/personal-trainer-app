import { authenticatedClients } from "../_shared/auth.ts";
import { corsHeaders, errorResponse, json } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Método não permitido" }, 405);
  }
  try {
    const { admin, user } = await authenticatedClients(req);
    const tenantId = user.app_metadata?.tenant_id as string | undefined;
    if (!tenantId) return json({ error: "Tenant ausente" }, 403);
    const { data: membership } = await admin.from("tenant_memberships").select(
      "status",
    )
      .eq("tenant_id", tenantId).eq("user_id", user.id).eq("status", "active")
      .maybeSingle();
    if (!membership) return json({ error: "Associação inválida" }, 403);
    const policyVersion = Deno.env.get("AI_CONSENT_POLICY_VERSION");
    const providerName = Deno.env.get("AI_PROVIDER_NAME");
    const purpose = "workout_report";
    if (!policyVersion || !providerName) {
      throw new Error("Política de consentimento de IA não configurada");
    }
    const { data: consent } = await admin.from("ai_consents").select("id").eq(
      "tenant_id",
      tenantId,
    )
      .eq("user_id", user.id).eq("policy_version", policyVersion).eq(
        "purpose",
        purpose,
      ).eq("provider", providerName)
      .is("revoked_at", null).order("granted_at", { ascending: false }).limit(1)
      .maybeSingle();
    if (!consent) {
      return json({ error: "Consentimento para IA não registrado" }, 403);
    }
    const contentLength = Number(req.headers.get("content-length") ?? 0);
    if (contentLength > 65536) {
      return json({ error: "Solicitação muito grande" }, 413);
    }
    const body = await req.json() as Record<string, unknown>;
    const safeInput = {
      exercises: body.exercises,
      total_sets: body.total_sets,
      total_repetitions: body.total_repetitions,
      total_load_kg: body.total_load_kg,
      duration_seconds: body.duration_seconds,
      score: body.score,
    };
    if (JSON.stringify(safeInput).length > 65536) {
      return json({ error: "Solicitação muito grande" }, 413);
    }
    const providerUrl = Deno.env.get("AI_PROVIDER_URL");
    const providerKey = Deno.env.get("AI_PROVIDER_API_KEY");
    if (!providerUrl || !providerKey) {
      throw new Error("Provedor de IA não configurado");
    }
    const { data: allowed, error: quotaError } = await admin.rpc(
      "server_consume_ai_quota",
      { p_user_id: user.id, p_limit: 10 },
    );
    if (quotaError) throw quotaError;
    if (!allowed) return json({ error: "Limite temporário atingido" }, 429);
    let providerResponse: Response;
    try {
      providerResponse = await fetch(providerUrl, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${providerKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ input: safeInput, language: "pt-BR" }),
      });
    } catch (error) {
      await admin.rpc("server_refund_ai_quota", { p_user_id: user.id });
      throw error;
    }
    if (!providerResponse.ok) {
      await admin.rpc("server_refund_ai_quota", { p_user_id: user.id });
      throw new Error("Falha ao gerar relatório");
    }
    return json(await providerResponse.json());
  } catch (error) {
    return errorResponse(error, 400);
  }
});
