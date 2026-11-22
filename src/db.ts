import pg from "pg";

export type DbCheck = () => Promise<void>;

// The dev stack (compose.yaml) sets DATABASE_URL; tests, CI and the production
// image do not, and then the API runs without a database.
export function createDbCheck(url: string | undefined): DbCheck | undefined {
  if (!url) return undefined;
  const pool = new pg.Pool({ connectionString: url, max: 2 });
  return async () => {
    await pool.query("select 1");
  };
}
