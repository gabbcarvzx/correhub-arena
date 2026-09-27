## Frontend quality

For every task that creates or modifies user-facing UI, you MUST load and use:

- `$ui-ux`
- `$frontend-production-shadcn`

Required sequence:

1. `$ui-ux` — product cognition, UX, information hierarchy, user journey, copy, accessibility and anti-AI/template review.
2. `$frontend-production-shadcn` — production-quality implementation using the existing CorreHub design system, React/Next.js, Tailwind and shadcn/ui.
3. Browser visual verification — desktop and mobile.
4. `$ui-ux` — final quality gate.
5. Fix all relevant findings before completion.

Avoid generic AI-generated interface patterns:

- excessive cards;
- unnecessary gradients;
- excessive rounded containers;
- decorative shadows;
- generic SaaS dashboard layouts;
- repetitive centered sections;
- generic marketing copy;
- meaningless icons;
- excessive whitespace without hierarchy;
- uniform component rhythm that makes the UI look templated.

Preserve CorreHub branding, semantic tokens, architecture and existing visual language.

Do not invoke these skills for backend-only, database-only or infrastructure-only tasks where no user-facing UI is affected.
