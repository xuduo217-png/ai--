import { DataSource } from "typeorm";

async function migrate() {
  const database = process.env.DB_DATABASE || "";
  if (
    process.env.NODE_ENV === "acceptance" &&
    !database.endsWith("_acceptance")
  ) {
    throw new Error(
      "Refusing acceptance migration on a non-acceptance database",
    );
  }

  const dataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: Number(process.env.DB_PORT || 3306),
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database,
    synchronize: false,
  });

  await dataSource.initialize();
  const runner = dataSource.createQueryRunner();
  try {
    if (!(await runner.hasTable("agent_sessions"))) {
      await runner.query(`
        CREATE TABLE agent_sessions (
          id INT NOT NULL AUTO_INCREMENT,
          sessionId VARCHAR(36) NOT NULL,
          userId INT NOT NULL,
          petId INT NULL,
          title VARCHAR(80) NOT NULL DEFAULT '新对话',
          status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
          lastMessageAt TIMESTAMP NULL,
          createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          updatedAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
          PRIMARY KEY (id),
          UNIQUE INDEX UQ_agent_sessions_session_id (sessionId),
          INDEX IDX_agent_sessions_user_updated (userId, updatedAt)
        ) COMMENT='用户 Agent 会话'
      `);
    }
    if (!(await runner.hasTable("agent_messages"))) {
      await runner.query(`
        CREATE TABLE agent_messages (
          id INT NOT NULL AUTO_INCREMENT,
          sessionId VARCHAR(36) NOT NULL,
          userId INT NOT NULL,
          role ENUM('USER','AGENT') NOT NULL,
          content TEXT NOT NULL,
          intent VARCHAR(20) NULL,
          destination JSON NULL,
          createdAt DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (id),
          INDEX IDX_agent_messages_session_created (sessionId, createdAt),
          INDEX IDX_agent_messages_user_created (userId, createdAt)
        ) COMMENT='Agent 会话消息与路由结果'
      `);
    }
  } finally {
    await runner.release();
    await dataSource.destroy();
  }
}

void migrate();
