import sql from "mssql";
import { DefaultAzureCredential } from "@azure/identity";

// Azure SQL connection pool. In Azure the Function's managed identity gets a
// token for the database; locally, set SQL_CONNECTION_STRING (SQL auth).
let poolPromise: Promise<sql.ConnectionPool> | null = null;

async function createPool(): Promise<sql.ConnectionPool> {
  const conn = process.env.SQL_CONNECTION_STRING;
  if (conn) {
    return new sql.ConnectionPool(conn).connect();
  }

  const server = process.env.SQL_SERVER_FQDN;
  const database = process.env.SQL_DATABASE ?? "foxmillwoods";
  if (!server) {
    throw new Error("Set SQL_CONNECTION_STRING (local) or SQL_SERVER_FQDN (managed identity).");
  }

  const credential = new DefaultAzureCredential();
  const accessToken = await credential.getToken("https://database.windows.net/.default");
  if (!accessToken) throw new Error("Failed to acquire a SQL access token");

  const pool = new sql.ConnectionPool({
    server,
    database,
    options: { encrypt: true, trustServerCertificate: false },
    authentication: {
      type: "azure-active-directory-access-token",
      options: { token: accessToken.token },
    },
  });
  return pool.connect();
}

export function getPool(): Promise<sql.ConnectionPool> {
  if (!poolPromise) {
    poolPromise = createPool().catch((err) => {
      poolPromise = null; // allow retry on next call
      throw err;
    });
  }
  return poolPromise;
}

export { sql };
