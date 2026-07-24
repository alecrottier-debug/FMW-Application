import { app, HttpRequest } from "@azure/functions";
import { issueSession } from "../lib/auth";
import { errorResponse, HttpError, json } from "../lib/http";

// POST /api/auth/session  { provider: "apple"|"google", idToken, name? }
// Exchanges a provider identity token for an app session token (+ the user record).
app.http("authSession", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "auth/session",
  handler: async (request: HttpRequest) => {
    try {
      const body = (await request.json()) as {
        provider?: string;
        idToken?: string;
        name?: string;
      };
      if (!body.provider || !body.idToken) {
        throw new HttpError(400, "provider and idToken are required");
      }
      const result = await issueSession(body.provider, body.idToken, body.name);
      return json(200, result);
    } catch (e) {
      return errorResponse(e);
    }
  },
});
