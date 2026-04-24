---
description: Initialize a new FastAPI backend project
---

# FastAPI Backend Initializer

Ask the user:

1. **Project name**: What should the project be called?
2. **Database**: Which database? (postgresql/mysql/sqlite/mongodb/supabase)
3. **ORM**: Use an ORM? (sqlalchemy/tortoise/prisma/none)
4. **Authentication**: Include auth? (yes/no)
   - If yes: Method? (jwt/oauth2/api-keys/supabase)
5. **Additional features**:
   - CORS configuration
   - Redis for caching
   - Celery for background tasks
   - Docker setup
   - AWS S3 for file storage

## After gathering requirements:

1. Create project directory structure:
```
   app/
   ├── api/
   │   └── v1/
   │       └── endpoints/
   ├── core/
   │   ├── config.py
   │   └── security.py
   ├── models/
   ├── schemas/
   ├── services/
   ├── db/
   └── main.py
   tests/
   requirements.txt
   .env.example
```
2. Set up FastAPI with selected features
3. Configure database connection
4. Implement authentication system if selected
5. Create `.env.example` with all required variables
6. Set up Docker if requested
7. Create example endpoints
8. Add testing setup
9. Document API structure and setup in README.md
