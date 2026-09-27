import { ConnectionListPage } from "@/components/social/connection-list-page";

export const dynamic = "force-dynamic";

export default async function FollowersPage({
  params,
  searchParams,
}: {
  params: Promise<{ username: string }>;
  searchParams: Promise<{ cursor?: string | string[] }>;
}) {
  const [{ username }, query] = await Promise.all([params, searchParams]);
  return ConnectionListPage({
    username: username.toLowerCase(),
    direction: "followers",
    cursor: typeof query.cursor === "string" ? query.cursor : undefined,
  });
}
