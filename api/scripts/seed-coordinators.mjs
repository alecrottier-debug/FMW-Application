// One-off: pre-provision event coordinators by email. If a matching account
// already exists it's promoted; otherwise an 'invite:' row is seeded and claimed
// on first sign-in (see getOrCreateUser email-linking). Run with SQL_CONNECTION_STRING set.
import sql from "mssql";

const conn = process.env.SQL_CONNECTION_STRING;
if (!conn) {
  console.error("SQL_CONNECTION_STRING is not set");
  process.exit(1);
}

const people = [
  { name: "Jason Goldberg", email: "goldjay@hotmail.com" },
  { name: "Jim Betz", email: "jimbetz10@gmail.com" },
  { name: "Tim Carlson", email: "timcarlson1@gmail.com" },
  { name: "James & Jena Pierce", email: "jamesandjenapierce@gmail.com" },
];

const pool = await new sql.ConnectionPool(conn).connect();
try {
  for (const p of people) {
    const existing = await pool
      .request()
      .input("email", sql.NVarChar, p.email)
      .query("SELECT id FROM dbo.Users WHERE email = @email");
    if (existing.recordset.length > 0) {
      await pool
        .request()
        .input("email", sql.NVarChar, p.email)
        .query("UPDATE dbo.Users SET role = 'eventCoordinator', status = 'active' WHERE email = @email");
      console.log(`promoted existing account → coordinator: ${p.email}`);
    } else {
      await pool
        .request()
        .input("name", sql.NVarChar, p.name)
        .input("email", sql.NVarChar, p.email)
        .input("sub", sql.NVarChar, `invite:${p.email}`)
        .query(
          `INSERT INTO dbo.Users (name, email, role, status, authProviderSub)
           VALUES (@name, @email, 'eventCoordinator', 'active', @sub)`
        );
      console.log(`seeded invite (coordinator, active): ${p.email}`);
    }
  }
  console.log("done");
} finally {
  await pool.close();
}
