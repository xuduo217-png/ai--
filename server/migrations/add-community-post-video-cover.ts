/**
 * 为 community_posts 表补充视频封面字段
 *
 * 运行方式：ts-node migrations/add-community-post-video-cover.ts
 */

import { DataSource } from "typeorm";
import { Post } from "../src/community/entities/post.entity";

async function addCommunityPostVideoCover() {
  console.log("开始为 community_posts 表添加 videoCover 字段...");

  const AppDataSource = new DataSource({
    type: "mysql",
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT || "3306", 10),
    username: process.env.DB_USERNAME || "root",
    password: process.env.DB_PASSWORD || "",
    database: process.env.DB_DATABASE || "pet_hospitals",
    entities: [Post],
    synchronize: false,
  });

  try {
    await AppDataSource.initialize();
    console.log("数据库连接成功");

    const queryRunner = AppDataSource.createQueryRunner();

    try {
      const table = await queryRunner.getTable("community_posts");
      const videoCoverColumn = table?.findColumnByName("videoCover");

      if (!videoCoverColumn) {
        await queryRunner.query(
          "ALTER TABLE community_posts ADD COLUMN videoCover VARCHAR(500) NULL COMMENT '视频封面图URL' AFTER video",
        );
        console.log("✅ 字段 videoCover 添加成功");
      } else {
        console.log("⚠️  字段 videoCover 已存在，跳过");
      }
    } finally {
      await queryRunner.release();
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : "未知错误";
    console.error("❌ 添加 videoCover 字段失败:", errorMessage);
    console.error("详细错误:", error);
  } finally {
    await AppDataSource.destroy();
  }
}

void addCommunityPostVideoCover();
