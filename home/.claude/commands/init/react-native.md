---
description: Initialize a new React Native project with customizable features
---

# React Native Project Initializer

Ask the user these questions one at a time:

1. **Project name**: What should the project be called?
2. **Template**: Use Expo or bare React Native? (expo/bare)
3. **TypeScript**: Use TypeScript? (yes/no)
4. **Navigation**: Which navigation library? (react-navigation/expo-router)
5. **State management**: Which solution? (redux/zustand/context/mobx/none)
6. **Authentication**: Include auth? (yes/no)
   - If yes: Provider? (supabase/firebase/auth0/custom)
7. **Backend/Database**: Which service? (supabase/firebase/none)
8. **UI Library**: Use a component library? (react-native-paper/native-base/tamagui/none)

## After gathering requirements:

1. Initialize the project with appropriate command
2. Install dependencies based on selections
3. Create project structure:
```
   src/
   ├── components/
   ├── screens/
   ├── navigation/
   ├── services/
   ├── store/ (if state management selected)
   ├── utils/
   ├── types/ (if TypeScript)
   └── config/
```
4. Set up navigation structure
5. Configure selected services
6. Create `.env.example` with required credentials
7. Set up any selected state management
8. Create basic app shell with navigation
9. Document setup in README.md
