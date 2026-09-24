# `@lms/ui`

The single shared owner for role-neutral presentation assets and future shared shadcn/ui components. The package currently exposes the Tailwind CSS 4 entry point only; it intentionally contains no generated or role-specific components.

When the first real component is selected, use the official shadcn CLI Base UI path (`shadcn init -b base`) and verify that generated dependencies contain no `@radix-ui/*` package. Do not initialize the default primitive path or add app-specific business logic here.
