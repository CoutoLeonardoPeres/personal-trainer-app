export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function errorResponse(error: unknown, status = 400): Response {
  console.error(error instanceof Error ? error.name : "EdgeFunctionError");
  return json({ error: "Não foi possível concluir a solicitação" }, status);
}
