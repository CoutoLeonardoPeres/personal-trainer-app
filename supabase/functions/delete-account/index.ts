import { authenticatedClients } from "../_shared/auth.ts";
import { corsHeaders, errorResponse, json } from "../_shared/http.ts";

async function removeTree(
  admin: Awaited<ReturnType<typeof authenticatedClients>>["admin"],
  bucket: string,
  prefix: string,
): Promise<void> {
  for (;;) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit: 100,
      offset: 0,
    });
    if (error) throw error;
    if (!data?.length) break;
    const files = data.filter((item) => item.id).map((item) =>
      `${prefix}/${item.name}`
    );
    if (files.length) {
      const { error: removeError } = await admin.storage.from(bucket).remove(
        files,
      );
      if (removeError) throw removeError;
    }
    for (const folder of data.filter((item) => !item.id)) {
      await removeTree(admin, bucket, `${prefix}/${folder.name}`);
    }
    if (data.length < 100) break;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Método não permitido" }, 405);
  }
  try {
    const { admin, userClient, user } = await authenticatedClients(req);
    const lastSignIn = user.last_sign_in_at
      ? Date.parse(user.last_sign_in_at)
      : 0;
    if (Date.now() - lastSignIn > 15 * 60 * 1000) {
      return json({ error: "Faça login novamente para excluir a conta" }, 401);
    }
    let { data: deletion } = await admin.from("account_deletion_requests")
      .select("*").eq("user_id", user.id).maybeSingle();
    if (!deletion) {
      const { data, error } = await userClient.rpc("delete_my_account");
      if (error) throw error;
      const requestId = data.request_id as string;
      const result = await admin.from("account_deletion_requests").select("*")
        .eq("id", requestId).single();
      if (result.error) throw result.error;
      deletion = result.data;
    }
    if (["requested", "failed", "storage_deleted"].includes(deletion.status)) {
      const { data: membership } = await admin.from("tenant_memberships")
        .select("role_name,student_id,status")
        .eq("tenant_id", deletion.tenant_id).eq("user_id", user.id).eq(
          "status",
          "active",
        ).maybeSingle();
      if (
        !membership || membership.role_name !== deletion.role_name ||
        (deletion.role_name === "student" &&
          membership.student_id !== deletion.student_id)
      ) {
        return json({
          error: "A autorização da conta mudou; inicie uma nova solicitação",
        }, 409);
      }
    }
    if (deletion.status === "requested" || deletion.status === "failed") {
      const { data: buckets, error: bucketsError } = await admin.storage
        .listBuckets();
      if (bucketsError) throw bucketsError;
      for (const bucket of buckets ?? []) {
        await removeTree(admin, bucket.id, user.id);
      }
      const { error } = await admin.rpc("server_mark_deletion_storage", {
        p_request_id: deletion.id,
      });
      if (error) throw error;
      deletion.status = "storage_deleted";
    }
    if (deletion.status === "storage_deleted") {
      const { error } = await admin.rpc("server_finalize_account_deletion", {
        p_request_id: deletion.id,
      });
      if (error) throw error;
      deletion.status = "db_deleted";
    }
    const { error: completeError } = await admin.rpc(
      "server_complete_account_deletion",
      { p_request_id: deletion.id },
    );
    if (completeError) throw completeError;
    const { error: authError } = await admin.auth.admin.deleteUser(user.id);
    if (authError) throw authError;
    return json({ deleted: true });
  } catch (error) {
    return errorResponse(error, 400);
  }
});
