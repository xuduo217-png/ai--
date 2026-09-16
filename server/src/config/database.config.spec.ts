import { createDatabaseOptions } from "./database.config";

describe("createDatabaseOptions acceptance isolation", () => {
  const reader = (values: Record<string, unknown>) => ({
    get: (key: string, fallback?: unknown) => values[key] ?? fallback,
  });

  it("accepts a dedicated acceptance database", () => {
    const options = createDatabaseOptions(
      reader({
        NODE_ENV: "acceptance",
        DB_DATABASE: "pet_hospitals_acceptance",
      }),
    );

    expect(options.database).toBe("pet_hospitals_acceptance");
  });

  it("refuses to start acceptance against a non-acceptance database", () => {
    expect(() =>
      createDatabaseOptions(
        reader({ NODE_ENV: "acceptance", DB_DATABASE: "pet_hospitals" }),
      ),
    ).toThrow("requires an isolated database");
  });
});
