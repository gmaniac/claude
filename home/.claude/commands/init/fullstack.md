---
description: Initialize a full-stack project with frontend and backend
---

# Full-Stack Project Initializer

Ask the user:

1. **Project name**: What's the project called?
2. **Frontend**: Which framework? (nextjs/react/flutter/react-native)
3. **Backend**: Which framework? (fastapi/django/flask/nextjs-api)
4. **Database**: Which database? (supabase/postgresql/mongodb)
5. **Authentication**: Auth provider? (supabase/clerk/next-auth/jwt-custom)
6. **Monorepo setup**: Use monorepo? (yes-turborepo/yes-nx/no)

## After gathering requirements:

1. Create appropriate directory structure (monorepo or separate)
2. Initialize frontend with `/init-{framework}` command
3. Initialize backend with `/init-{framework}` command
4. Set up shared configurations and environment variables
5. Create docker-compose.yml for local development
6. Configure CORS and API connection
7. Set up shared types/interfaces if using TypeScript
8. Create comprehensive README.md with:
   - Project structure
   - Development setup
   - Environment variables needed
   - How to run frontend and backend
   - Deployment guide
