---
description: Initialize a new Flutter project with customizable features
---

# Flutter Project Initializer

You are helping initialize a new Flutter project. Ask the user the following questions one at a time, then create the project based on their answers:

1. **Project name**: What should the project be called?
2. **State management**: Which state management solution? (bloc/riverpod/provider/getx)
3. **Authentication**: Include authentication? (yes/no)
   - If yes: Which provider? (supabase/firebase/custom)
4. **Database**: Which database? (supabase/firebase/sqlite/none)
5. **Routing**: Which navigation solution? (go_router/auto_route/none)
6. **Additional features**: Any of these? (multiple choice)
   - Internationalization (i18n)
   - Dark mode support
   - Analytics
   - Push notifications

## After gathering requirements:

1. Create the Flutter project with `flutter create {project_name}`
2. Add all required dependencies to `pubspec.yaml`
3. Create the standard directory structure:
```
   lib/
   ├── core/
   │   ├── config/
   │   ├── theme/
   │   └── utils/
   ├── features/
   ├── shared/
   │   ├── widgets/
   │   └── models/
   └── main.dart
```
4. Create configuration files for selected services (Supabase, Firebase, etc.)
5. Create `.env.example` file with required environment variables
6. Set up the chosen state management structure
7. Configure routing if selected
8. Create a README.md documenting the project structure and setup steps

## Environment File Template

Always create a `.env.example` with placeholders for any services chosen.
