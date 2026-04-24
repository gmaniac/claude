---
description: Initialize a new Next.js project with customizable features
---

# Next.js Project Initializer

Ask the user these questions:

1. **Project name**: What should the project be called?
2. **TypeScript**: Use TypeScript? (yes/no)
3. **Router**: App Router or Pages Router? (app/pages)
4. **Styling**: Which solution? (tailwind/css-modules/styled-components/sass)
5. **UI Components**: Use a library? (shadcn-ui/mui/chakra/none)
6. **Authentication**: Include auth? (yes/no)
   - If yes: Provider? (next-auth/clerk/supabase/custom)
7. **Database**: Which database/ORM? (prisma+postgres/drizzle/supabase/mongodb/none)
8. **API**: API routes or separate backend? (next-api/separate)
9. **Additional features**:
   - ESLint/Prettier setup
   - Husky pre-commit hooks
   - Testing setup (jest/vitest)

## After gathering requirements:

1. Run `npx create-next-app@latest` with appropriate flags
2. Install selected dependencies
3. Create project structure based on router choice
4. Set up authentication if selected
5. Configure database connection
6. Create `.env.example` and `.env.local` template
7. Set up UI component library if selected
8. Configure linting/formatting if requested
9. Create example pages/components demonstrating the setup
10. Document everything in README.md
