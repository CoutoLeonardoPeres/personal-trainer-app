import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2.95.0";

export type Clients = {
  admin: SupabaseClient;
  userClient: SupabaseClient;
  user: User;
};

export async function authenticatedClients(req: Request): Promise<Clients> {
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) throw new Error("Não autenticado");
  const url = Deno.env.get("SUPABASE_URL")!;
  const publishable = Deno.env.get("SUPABASE_ANON_KEY")!;
  const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const admin = createClient(url, secret, { auth: { persistSession: false } });
  const userClient = createClient(url, publishable, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data, error } = await admin.auth.getUser(
    authorization.slice("Bearer ".length),
  );
  if (error || !data.user) throw new Error("Sessão inválida");
  return { admin, userClient, user: data.user };
}

export function uuidV7(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  const now = BigInt(Date.now());
  for (let i = 0; i < 6; i++) {
    bytes[5 - i] = Number((now >> BigInt(i * 8)) & 0xffn);
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x70;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const h = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${
    h.slice(16, 20)
  }-${h.slice(20)}`;
}
