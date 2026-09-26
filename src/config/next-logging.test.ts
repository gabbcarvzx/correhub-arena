import { describe, expect, it } from "vitest";

import nextConfig from "../../next.config";

describe("Next logging", () => {
  it("does not log incoming OAuth callback URLs in development", () => {
    expect(nextConfig.logging).toEqual({ incomingRequests: false });
  });
});
