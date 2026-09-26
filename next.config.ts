import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  agentRules: false,
  logging: {
    incomingRequests: false,
  },
};

export default nextConfig;
