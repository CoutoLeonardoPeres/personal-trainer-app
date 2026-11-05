import { authenticatedClients, type Clients, uuidV7 } from "../_shared/auth.ts";
import { corsHeaders, errorResponse, json } from "../_shared/http.ts";

async function recoverPartialInvite(
  admin: Clients["admin"],
  email: string,
  requestId: string,
): Promise<string | null> {
  for (let page = 1; page <= 10; page++) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;
    const user = data.users.find((candidate) =>
      candidate.email?.toLowerCase() === email &&
      candidate.user_metadata?.invitation_request_id === requestId
    );
    if (user) return user.id;
    if (data.users.length < 1000) break;
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Método não permitido" }, 405);
  }
  try {
    const { admin, user } = await authenticatedClients(req);
    const { name, email } = await req.json() as {
      name?: string;
      email?: string;
    };
    const cleanName = name?.trim();
    const cleanEmail = email?.trim().toLowerCase();
    if (!cleanName || !cleanEmail || !/^\S+@\S+\.\S+$/.test(cleanEmail)) {
      return json({ error: "Nome e e-mail válidos são obrigatórios" }, 422);
    }
    const tenantId = user.app_metadata?.tenant_id as string | undefined;
    const role = user.app_metadata?.role as string | undefined;
    if (!tenantId || !["personal", "org_admin"].includes(role ?? "")) {
      return json({ error: "Sem permissão" }, 403);
    }
    const { data: membership } = await admin.from("tenant_memberships").select(
      "role_name,status",
    )
      .eq("tenant_id", tenantId).eq("user_id", user.id).eq("status", "active")
      .maybeSingle();
    if (!membership || membership.role_name !== role) {
      return json({ error: "Associação inválida" }, 403);
    }
    const profileId = (user.app_metadata?.profile_id as string | undefined) ??
      tenantId;
    const [{ data: personal }, { count: studentCount }] = await Promise.all([
      admin.from("personals").select("max_students_cap").eq(
        "tenant_id",
        tenantId,
      ).eq("id", profileId).maybeSingle(),
      admin.from("students").select("id", { count: "exact", head: true }).eq(
        "tenant_id",
        tenantId,
      ).is("deleted_at", null),
    ]);
    if (
      personal?.max_students_cap != null &&
      (studentCount ?? 0) >= personal.max_students_cap
    ) {
      return json({ error: "Limite de alunos atingido" }, 409);
    }
    const { data: existing } = await admin.from("invitation_requests").select(
      "*",
    )
      .eq("tenant_id", tenantId).eq("email", cleanEmail).maybeSingle();
    if (existing?.status === "completed") {
      return json({ student_id: existing.student_id, status: "completed" });
    }
    let requestRow = existing;
    if (!requestRow) {
      const { data, error } = await admin.from("invitation_requests").insert({
        tenant_id: tenantId,
        requested_by: user.id,
        student_id: uuidV7(),
        email: cleanEmail,
        name: cleanName,
        status: "pending",
        updated_at: new Date().toISOString(),
      }).select("*").single();
      if (error) throw error;
      requestRow = data;
    }
    let invitedUserId = requestRow.auth_user_id as string | null;
    if (!invitedUserId) {
      invitedUserId = await recoverPartialInvite(
        admin,
        cleanEmail,
        requestRow.id,
      );
      if (!invitedUserId) {
        const { data: invited, error: inviteError } = await admin.auth.admin
          .inviteUserByEmail(cleanEmail, {
            data: { invitation_request_id: requestRow.id },
          });
        if (inviteError || !invited.user) {
          throw inviteError ?? new Error("Convite não criado");
        }
        invitedUserId = invited.user.id;
      }
      const { error: persistError } = await admin.from("invitation_requests")
        .update({
          status: "invited",
          auth_user_id: invitedUserId,
          updated_at: new Date().toISOString(),
        }).eq("id", requestRow.id);
      if (persistError) throw persistError;
    }
    const { error: metadataError } = await admin.auth.admin.updateUserById(
      invitedUserId,
      {
        app_metadata: {
          role: "student",
          tenant_id: tenantId,
          student_id: requestRow.student_id,
          profile_id: requestRow.student_id,
        },
      },
    );
    if (metadataError) throw metadataError;
    const { data: synced, error: syncError } = await admin.rpc(
      "server_create_invited_student",
      {
        p_tenant: tenantId,
        p_personal_id: profileId,
        p_student_id: requestRow.student_id,
        p_auth_user_id: invitedUserId,
        p_name: requestRow.name,
        p_email: cleanEmail,
      },
    );
    if (syncError) throw syncError;
    const { error: completeError } = await admin.from("invitation_requests")
      .update({
        status: "completed",
        updated_at: new Date().toISOString(),
      }).eq("id", requestRow.id);
    if (completeError) throw completeError;
    return json({
      status: "completed",
      student_id: requestRow.student_id,
      sync: synced,
    }, 201);
  } catch (error) {
    return errorResponse(error, 400);
  }
});
