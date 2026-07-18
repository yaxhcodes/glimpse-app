import { withSupabase } from "npm:@supabase/server@1.4.0";

function jsonResponse(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(
  withSupabase({ auth: "user" }, async (request, context) => {
    if (request.method !== "POST") {
      return jsonResponse({ error: "Method not allowed." }, 405);
    }

    const {
      data: { user },
      error: userError,
    } = await context.supabase.auth.getUser();
    if (userError || !user) {
      console.warn("Account deletion rejected an invalid user session.");
      return jsonResponse(
        { error: "Your session has expired. Sign in again and retry." },
        401,
      );
    }

    const { error: deletionError } =
      await context.supabaseAdmin.auth.admin.deleteUser(user.id);
    if (deletionError) {
      console.error("Account deletion failed:", deletionError.message);
      return jsonResponse(
        { error: "Could not delete your account. Please try again." },
        500,
      );
    }

    return jsonResponse({ deleted: true }, 200);
  }),
);
