import { createClient } from '@supabase/supabase-js';
import { env } from './env';

export function getSupabaseBrowserClient() {
  if (!env.supabaseUrl || !env.supabaseAnon) {
    throw new Error('Supabase public env vars are required.');
  }
  return createClient(env.supabaseUrl, env.supabaseAnon);
}

export function getSupabaseServiceClient() {
  if (!env.supabaseUrl || !env.supabaseServiceRole) {
    throw new Error('Supabase service env vars are required.');
  }
  return createClient(env.supabaseUrl, env.supabaseServiceRole);
}
