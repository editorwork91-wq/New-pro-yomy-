import fs from 'node:fs'
import path from 'node:path'

function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return {}
  const result = {}
  for (const rawLine of fs.readFileSync(filePath, 'utf8').split(/\r?\n/)) {
    const line = rawLine.trim()
    if (!line || line.startsWith('#')) continue
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/)
    if (!match) continue
    let value = match[2].trim()
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1)
    }
    result[match[1]] = value
  }
  return result
}

const fileEnv = loadEnvFile(path.resolve(process.cwd(), '.env'))
const get = name => process.env[name] || fileEnv[name] || ''

const required = [
  ['VITE_SUPABASE_URL', get('VITE_SUPABASE_URL')],
  ['VITE_SUPABASE_ANON_KEY', get('VITE_SUPABASE_ANON_KEY')],
]

const optional = [
  ['VITE_VAPID_PUBLIC_KEY', get('VITE_VAPID_PUBLIC_KEY')],
  ['VITE_TURN_URLS', get('VITE_TURN_URLS')],
]

const missing = required.filter(([, value]) => !value || value === 'undefined').map(([name]) => name)
if (missing.length) {
  console.error('YOMY build configuration is incomplete. Missing:', missing.join(', '))
  process.exit(1)
}

for (const [name, value] of optional) {
  if (!value) console.warn(`YOMY optional runtime setting is not configured: ${name}`)
}

try {
  const url = new URL(get('VITE_SUPABASE_URL'))
  if (!/^https?:$/.test(url.protocol) || !url.hostname.endsWith('.supabase.co')) {
    throw new Error('VITE_SUPABASE_URL does not look like a Supabase project URL')
  }
} catch (error) {
  console.error('Invalid VITE_SUPABASE_URL:', error instanceof Error ? error.message : error)
  process.exit(1)
}

console.log('YOMY public environment preflight: OK')
