import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";

/**
 * Liveness/readiness probe. Anonymous by design — it exposes no data and is used
 * by uptime checks. Every other endpoint should default to authLevel "function"
 * (or Entra token validation) per the spec.
 */
export async function health(
  _request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  context.log("health check");
  return {
    status: 200,
    jsonBody: {
      status: "ok",
      service: "fox-mill-woods-api",
      time: new Date().toISOString(),
    },
  };
}

app.http("health", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "health",
  handler: health,
});
