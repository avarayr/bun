import { RedisClient } from "bun";
import { describe, expect, test } from "bun:test";

/**
 * Regression test for invalid URL handling in Redis/Valkey client
 *
 * Issue: Redis client silently falls back to localhost:6379 when given an invalid URL
 * Expected: Client should throw an error for invalid URLs while still allowing no URL
 *          (which correctly defaults to localhost:6379)
 *
 * This test ensures that:
 * 1. Invalid URLs throw errors immediately during construction
 * 2. No URL (undefined) correctly defaults to localhost:6379
 * 3. Valid URLs are accepted
 */
describe("RedisClient: Invalid URL Handling", () => {
  test("should throw error for completely malformed URLs", () => {
    expect(() => {
      new RedisClient("not a valid url at all");
    }).toThrow(/invalid url/i);

    expect(() => {
      new RedisClient("://no-protocol");
    }).toThrow(/invalid url/i);

    expect(() => {
      new RedisClient("redis://[invalid-ipv6");
    }).toThrow(/invalid url/i);
  });

  test("should throw error for empty string URL", () => {
    expect(() => {
      new RedisClient("");
    }).toThrow(/invalid url/i);
  });

  test("should throw error for URLs with invalid port formats in the URL itself", () => {
    // These should be caught by URL validation before port parsing
    expect(() => {
      new RedisClient("redis://localhost:not-a-number");
    }).toThrow();
  });

  test("should accept valid URLs with proper format", () => {
    // These should not throw during construction
    expect(() => {
      const client = new RedisClient("redis://localhost:6379");
      client.close();
    }).not.toThrow();

    expect(() => {
      const client = new RedisClient("valkey://127.0.0.1:6379");
      client.close();
    }).not.toThrow();

    expect(() => {
      const client = new RedisClient("redis://user:pass@localhost:6379");
      client.close();
    }).not.toThrow();
  });

  test("should allow undefined/no URL (defaults to localhost:6379)", () => {
    // When no URL is provided, it should use the default
    expect(() => {
      const client = new RedisClient();
      client.close();
    }).not.toThrow();

    expect(() => {
      const client = new RedisClient(undefined);
      client.close();
    }).not.toThrow();
  });

  test("should distinguish between no URL (valid) and invalid URL (error)", () => {
    // No URL should work (uses default)
    const clientNoUrl = new RedisClient();
    clientNoUrl.close();

    // But an explicitly invalid URL should fail
    expect(() => {
      new RedisClient("this is not a url");
    }).toThrow(/invalid url/i);
  });

  test("should handle URLs with valid special cases", () => {
    expect(() => {
      const client = new RedisClient("redis://localhost");
      client.close();
    }).not.toThrow();

    expect(() => {
      const client = new RedisClient("rediss://localhost:6380");
      client.close();
    }).not.toThrow();

    expect(() => {
      const client = new RedisClient("valkey+unix:///tmp/redis.sock");
      client.close();
    }).not.toThrow();
  });
});
