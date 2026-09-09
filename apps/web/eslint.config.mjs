import { defineConfig, globalIgnores } from 'eslint/config'
import nextVitals from 'eslint-config-next/core-web-vitals'

// Next.js 16 removed `next lint`, so the lint script calls the ESLint CLI and
// the ignores that used to come with `next lint` have to be spelled out here.
export default defineConfig([
  ...nextVitals,
  globalIgnores(['.next/**', 'out/**', 'build/**', 'next-env.d.ts']),
])
