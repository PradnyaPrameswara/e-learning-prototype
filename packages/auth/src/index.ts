import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@lms/database';

export interface UserSupabaseClientOptions {
  accessToken: string;
  publishableKey: string;
  url: string;
}

export type UserSupabaseClient = SupabaseClient<Database>;

/** Create a request-scoped Supabase client that forwards the caller's verified token. */
export function createUserSupabaseClient({
  accessToken,
  publishableKey,
  url,
}: UserSupabaseClientOptions): UserSupabaseClient {
  return createClient<Database>(url, publishableKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  });
}
