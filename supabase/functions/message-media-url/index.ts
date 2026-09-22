import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
    },
  })

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json(405, { error: 'Method not allowed' })

  const auth = req.headers.get('Authorization')
  if (!auth?.startsWith('Bearer ')) return json(401, { error: 'Missing authorization' })

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const token = auth.slice(7)
  const {
    data: { user },
    error: authError,
  } = await admin.auth.getUser(token)

  if (authError || !user) return json(401, { error: 'Invalid session' })

  const body = (await req.json().catch(() => null)) as Record<string, unknown> | null
  const messageId = typeof body?.message_id === 'string' ? body.message_id : ''
  const expiresRequested = Math.floor(Number(body?.expires_in) || 3600)
  const expiresIn = Math.max(60, Math.min(3600, expiresRequested))

  if (!messageId) return json(400, { error: 'message_id is required' })

  const { data: message, error: messageError } = await admin
    .from('messages')
    .select('id,sender_id,receiver_id,media_bucket,media_path,media_url,media_type,deleted_for_everyone')
    .eq('id', messageId)
    .maybeSingle()

  if (messageError) return json(500, { error: 'Could not load message media' })
  if (!message || ![message.sender_id, message.receiver_id].includes(user.id)) {
    return json(404, { error: 'Message not found' })
  }
  if (message.deleted_for_everyone) return json(404, { error: 'Message media was deleted' })

  if (message.media_bucket === 'messages-private' && message.media_path) {
    const { data, error } = await admin.storage
      .from('messages-private')
      .createSignedUrl(message.media_path, expiresIn)

    if (error || !data?.signedUrl) {
      console.error('Private message signed URL failed:', error?.message || 'missing URL')
      return json(502, { error: 'Could not create private media URL' })
    }

    return json(200, {
      url: data.signedUrl,
      expires_in: expiresIn,
      expires_at: new Date(Date.now() + expiresIn * 1000).toISOString(),
      legacy: false,
    })
  }

  if (typeof message.media_url === 'string' && /^https?:\/\//i.test(message.media_url)) {
    return json(200, {
      url: message.media_url,
      expires_in: null,
      expires_at: null,
      legacy: true,
    })
  }

  return json(404, { error: 'Message media not available' })
})
