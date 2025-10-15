import { RedisClient } from "bun";
import { describe, expect, test } from "bun:test";

/**
 * Regression test for invalid port number handling in Redis client URLs
 *
 * Issue: Redis client falls back to default URL if invalid parameters are provided
 * Expected: Client should throw an error for invalid port numbers
 *
 * Port numbers must be in the range 0-65535. Values outside this range
 * should be rejected immediately during client construction.
 */
describe("RedisClient: Invalid Port Handling", () => {
  test("should throw error for port number exceeding 65535", () => {
    // Port 130000 exceeds the maximum valid port number (65535)
    expect(() => {
      new RedisClient("redis://localhost:130000");
    }).toThrow(/(invalid port number|invalid url format)/i);
  });

  test("should throw error for negative port number", () => {
    expect(() => {
      new RedisClient("redis://localhost:-1");
    }).toThrow(/(invalid port number|invalid url format)/i);
  });

  test("should throw error for explicit port 0 when using TCP (not unix socket)", () => {
    // Port 0 is invalid for TCP connections when explicitly specified
    expect(() => {
      new RedisClient("redis://localhost:0");
    }).toThrow(/port 0 is not valid/i);
  });

  test("should accept valid port numbers", () => {
    // These should not throw during construction (though connection will fail without a server)
    expect(() => {
      const client = new RedisClient("redis://localhost:6379");
      client.close();
    }).not.toThrow();

    expect(() => {
      const client = new RedisClient("redis://localhost:1234");
      client.close();
    }).not.toThrow();

    expect(() => {
      const client = new RedisClient("redis://localhost:65535");
      client.close();
    }).not.toThrow();
  });

  test("should use default port 6379 when port is omitted", () => {
    // When no port is specified, default to 6379
    // This should not throw
    expect(() => {
      const client = new RedisClient("redis://localhost");
      client.close();
    }).not.toThrow();
  });

  test("should throw error for malformed port in URL", () => {
    expect(() => {
      new RedisClient("redis://localhost:abc");
    }).toThrow(/(invalid port number|invalid url format)/i);

    expect(() => {
      new RedisClient("redis://localhost:12.34");
    }).toThrow(/(invalid port number|invalid url format)/i);
  });
});
