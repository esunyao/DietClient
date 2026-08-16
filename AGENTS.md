# Repository Guidelines

## Project Structure & Module Organization

This React Native 0.86.0 app uses TypeScript, React 19, and npm. The root component is `App.tsx`; native and web entry points are `index.js` and `index.web.js`.

### Directory conventions

- **Features** live under `src/features/{auth,diet,profile}` with `api/`, `screens/`, `services/`, and `store/` modules as needed.
- **Services**: each service keeps its own folder under `services/<service-name>/` (e.g. `diet/services/mealImage/`), with platform variants and colocated tests inside; each folder exports a public barrel `index.ts`. Single-file services may stay flat.
- **Shared**: `src/shared/` holds cross-feature code. `src/shared/api/` (HTTP client, token storage), `src/shared/components/` split into `fields/` (inputs), `overlays/` (sheets/toast), `surfaces/` (glass), plus `ui.tsx` primitives; `src/shared/upload/` is the shared upload manager (native file parsing + PUT). Import shared components from the `src/shared/components` barrel.
- **Navigation** is in `src/navigation/`; native code is in `android/` and `ios/`; Webpack assets and configuration are in `web/`. Tests are colocated as `*.test.ts(x)`, with Android unit tests under `android/app/src/test/`.

## Build, Test, and Development Commands

Use Node `>=22.11.0` and install with `npm ci`.

```sh
npm start             # Start Metro
npm run android       # Build and launch Android
npm run ios           # Build and launch iOS
npm run start:web     # Start Webpack on port 8080
npm run build:web     # Build to dist/web/
npm run lint          # Run ESLint
npm test              # Run Jest
npx tsc --noEmit      # Type-check without emitting
```

After native dependency changes, run `bundle exec pod install` before iOS builds. On Windows, use `android\gradlew.bat test` for Android unit tests.

## Coding Style & Naming Conventions

Follow ESLint and Prettier: two-space indentation, single quotes, trailing commas, and no unnecessary arrow-function parentheses. Use PascalCase for components/screens and camelCase for functions/variables. Preserve platform suffixes such as `.native.tsx`, `.web.tsx`, `.android.tsx`, and `.ios.tsx`. Keep comments in Chinese, matching the project convention.

## Testing Guidelines

Jest uses the React Native preset through Babel. Add or update a colocated `*.test.ts` or `*.test.tsx` for behavior changes, especially API parsing, validation, storage, and service logic. No coverage threshold is enforced; cover normal, boundary, and error paths. Use `npm test -- --runInBand` when diagnosing ordering issues.

## Commit & Pull Request Guidelines

Use short, imperative English commit subjects, matching recent history: `Add ...`, `Fix ...`, `Drop ...`, or `Optimize ...`. Keep commits focused. Pull requests should explain user-visible or native impact, list verification commands, link issues when applicable, and include screenshots or recordings for UI changes. Call out platform differences and required local configuration.

## Security & Configuration Tips

Start local configuration from `src/shared/config/appConfig.ts.template`. The real `src/shared/config/appConfig.ts` is ignored; never commit secrets, tokens, or machine-specific endpoints. Keep `dist/`, build directories, Pods, and coverage files out of commits.
