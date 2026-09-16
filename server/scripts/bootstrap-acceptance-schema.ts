import "reflect-metadata";
import { DataSource } from "typeorm";
import { join } from "path";

async function bootstrapAcceptanceSchema() {
  const database = process.env.DB_DATABASE || "";
  if (process.env.NODE_ENV !== "acceptance") {
    throw new Error("NODE_ENV must be acceptance");
  }
  if (!database.endsWith("_acceptance")) {
    throw new Error("DB_DATABASE must end with _acceptance");
  }

  const dataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 3306),
    username: process.env.DB_USERNAME || "",
    password: process.env.DB_PASSWORD || "",
    database,
    entities: [join(__dirname, "..", "src", "**", "*.entity{.ts,.js}")],
    synchronize: true,
    logging: false,
  });

  await dataSource.initialize();
  try {
    await dataSource.synchronize(false);
    console.log(`Acceptance schema is ready: ${database}`);
  } finally {
    await dataSource.destroy();
  }
}

void bootstrapAcceptanceSchema();
