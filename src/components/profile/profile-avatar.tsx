type ProfileAvatarProps = {
  fullName: string;
  avatarUrl: string | null;
  isPrivate?: boolean;
  size?: "small" | "large";
};

function initials(fullName: string): string {
  return fullName
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toLocaleUpperCase("pt-BR"))
    .join("");
}

export function ProfileAvatar({
  fullName,
  avatarUrl,
  isPrivate = false,
  size = "large",
}: ProfileAvatarProps) {
  const sizeClass = size === "large" ? "h-24 w-24 text-2xl" : "h-14 w-14 text-base";

  if (avatarUrl && !isPrivate) {
    return (
      // The URL is an authorized read-model field. Upload and optimization are outside Gate 3.
      // eslint-disable-next-line @next/next/no-img-element
      <img
        alt={`Avatar de ${fullName}`}
        className={`${sizeClass} rounded-full border border-border object-cover`}
        height={size === "large" ? 96 : 56}
        referrerPolicy="no-referrer"
        src={avatarUrl}
        width={size === "large" ? 96 : 56}
      />
    );
  }

  return (
    <div
      aria-label={`Avatar padrão de ${fullName}`}
      className={`${sizeClass} grid shrink-0 place-items-center rounded-full bg-primary font-black text-on-primary`}
      role="img"
    >
      {initials(fullName) || "CH"}
    </div>
  );
}
