import { HttpResponseInit } from "@azure/functions";

export const json = (status: number, body: unknown): HttpResponseInit => ({
  status,
  jsonBody: body,
});

/** Thrown by handlers to produce a specific HTTP status. */
export class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export function errorResponse(err: unknown): HttpResponseInit {
  if (err instanceof HttpError) return json(err.status, { error: err.message });
  const message = err instanceof Error ? err.message : "Internal error";
  return json(500, { error: message });
}
