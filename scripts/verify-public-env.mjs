const required = [
  ['VITE_SUPABASE_URL', process.env.VITE_SUPABASE_URL],
  ['VITE_SUPABASE_ANON_KEY', process.env.VITE_SUPABASE_ANON_KEY],
]

const optional = [
  ['VITE_VAPID_PUBLIC_KEY', process.env.VITE_VAPID_PUBLIC_KEY],
  ['VITE_TURN_URLS', process.env.VITE_TURN_URLS],
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
  const url = new URL(process.env.VITE_SUPABASE_URL)
  if (!url.protocol.startsWith('http') || !url.hostname.endsWith('.supabase.co')) {
    throw new Error('VITE_SUPABASE_URL does not look like a Supabase project URL')
  }
} catch (error) {
  console.error('Invalid VITE_SUPABASE_URL:', error instanceof Error ? error.message : error)
  process.exit(1)
}

console.log('YOMY public environment preflight: OK')
