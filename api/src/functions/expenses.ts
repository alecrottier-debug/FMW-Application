import { app, HttpRequest } from "@azure/functions";
import { randomUUID } from "crypto";
import { assertRole, requireUser } from "../lib/auth";
import { getPool, sql } from "../lib/db";
import { audit } from "../lib/audit";
import { errorResponse, HttpError, json } from "../lib/http";
import { blobNameFromUrl, downloadReceipt, uploadReceipt } from "../lib/blob";

// Expenses are money OUT — a receipt a volunteer paid for, tracked to an event so
// "owed back to volunteers" reconciles (spec §5, Expenses table). Coordinator+ only;
// every write is logged to AuditLog (financial change). The receipt image lands in
// the private receipts blob container and is served back only via the proxy below.

const MAX_RECEIPT_BYTES = 8 * 1024 * 1024; // 8 MB decoded — receipts are small JPEGs
const ALLOWED_CONTENT_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/jpg": "jpg",
  "image/png": "png",
  "image/heic": "heic",
  "application/pdf": "pdf",
};

interface CreateExpenseBody {
  eventId?: string | null;
  paidByUserId?: string | null;
  merchant?: string | null;
  date?: string | null; // "YYYY-MM-DD" or ISO
  amount: number;
  tax?: number | null;
  category?: string | null;
  receiptBase64?: string | null;
  receiptContentType?: string | null;
}

// POST /api/expenses — record an expense (coordinator+), optionally with a receipt image.
app.http("createExpense", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "expenses",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      assertRole(user, "eventCoordinator");

      const body = (await request.json()) as CreateExpenseBody;
      const amount = Number(body.amount);
      if (!Number.isFinite(amount) || amount <= 0) {
        throw new HttpError(400, "A positive amount is required");
      }

      const id = randomUUID();
      const paidBy = body.paidByUserId ?? user.id;

      // Upload the receipt image first (if present) so the row always points at a real blob.
      let receiptUrl: string | null = null;
      if (body.receiptBase64) {
        const contentType = (body.receiptContentType ?? "image/jpeg").toLowerCase();
        const ext = ALLOWED_CONTENT_TYPES[contentType];
        if (!ext) throw new HttpError(415, "Unsupported receipt type");
        const buffer = Buffer.from(body.receiptBase64, "base64");
        if (buffer.length === 0) throw new HttpError(400, "Receipt image is empty");
        if (buffer.length > MAX_RECEIPT_BYTES) throw new HttpError(413, "Receipt image too large");
        const folder = body.eventId ?? "general";
        receiptUrl = await uploadReceipt(`${folder}/${id}.${ext}`, buffer, contentType);
      }

      const pool = await getPool();
      const created = await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .input("eventId", sql.UniqueIdentifier, body.eventId ?? null)
        .input("paidBy", sql.UniqueIdentifier, paidBy)
        .input("merchant", sql.NVarChar, body.merchant ?? null)
        .input("date", sql.Date, body.date ? new Date(body.date) : null)
        .input("amount", sql.Decimal(10, 2), amount)
        .input("tax", sql.Decimal(10, 2), body.tax ?? null)
        .input("category", sql.NVarChar, body.category ?? null)
        .input("receiptBlobUrl", sql.NVarChar, receiptUrl)
        .query(
          `INSERT INTO dbo.Expenses
             (id, eventId, paidByUserId, merchant, [date], amount, tax, category, receiptBlobUrl)
           OUTPUT INSERTED.*
           VALUES (@id, @eventId, @paidBy, @merchant, @date, @amount, @tax, @category, @receiptBlobUrl)`
        );

      await audit(
        user.id,
        "expense.create",
        `expense:${id}`,
        `${body.merchant ?? "—"} $${amount.toFixed(2)} → event:${body.eventId ?? "none"}${
          receiptUrl ? " (receipt)" : ""
        }`
      );

      return json(201, mapExpense(created.recordset[0]));
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// GET /api/expenses?eventId=... — list expenses for reconciliation (coordinator+).
app.http("listExpenses", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "expenses",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      assertRole(user, "eventCoordinator");

      const eventId = request.query.get("eventId");
      const pool = await getPool();
      const req = pool.request();
      let where = "";
      if (eventId) {
        req.input("eventId", sql.UniqueIdentifier, eventId);
        where = "WHERE x.eventId = @eventId";
      }
      const result = await req.query(
        `SELECT x.*, u.name AS paidByName
         FROM dbo.Expenses x
         LEFT JOIN dbo.Users u ON u.id = x.paidByUserId
         ${where}
         ORDER BY x.[date] DESC`
      );
      return json(200, { expenses: result.recordset.map(mapExpense) });
    } catch (e) {
      return errorResponse(e);
    }
  },
});

// GET /api/expenses/{id}/receipt — stream the private receipt image (coordinator+).
app.http("getExpenseReceipt", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "expenses/{id}/receipt",
  handler: async (request: HttpRequest) => {
    try {
      const user = await requireUser(request);
      assertRole(user, "eventCoordinator");

      const pool = await getPool();
      const res = await pool
        .request()
        .input("id", sql.UniqueIdentifier, request.params.id)
        .query("SELECT receiptBlobUrl FROM dbo.Expenses WHERE id = @id");
      if (res.recordset.length === 0) throw new HttpError(404, "Expense not found");

      const url = res.recordset[0].receiptBlobUrl as string | null;
      const blobName = url ? blobNameFromUrl(url) : null;
      if (!blobName) throw new HttpError(404, "No receipt on file");

      const { data, contentType } = await downloadReceipt(blobName);
      return {
        status: 200,
        body: data,
        headers: { "Content-Type": contentType, "Cache-Control": "private, max-age=300" },
      };
    } catch (e) {
      return errorResponse(e);
    }
  },
});

function mapExpense(r: Record<string, unknown>) {
  const id = r.id as string;
  const date = r.date as Date | null;
  return {
    id,
    eventId: (r.eventId as string) ?? null,
    paidByUserId: r.paidByUserId as string,
    paidByName: (r.paidByName as string) ?? null,
    merchant: (r.merchant as string) ?? null,
    date: date ? new Date(date).toISOString().slice(0, 10) : null,
    amount: r.amount as number,
    tax: (r.tax as number) ?? null,
    category: (r.category as string) ?? null,
    reimbursedStatus: r.reimbursedStatus as string,
    // Relative path the app resolves against API_BASE_URL; null when no image.
    receiptPath: r.receiptBlobUrl ? `expenses/${id}/receipt` : null,
  };
}
