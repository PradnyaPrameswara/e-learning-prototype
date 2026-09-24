export interface Env {
  FILES_BUCKET: R2Bucket;
  APP_ORIGINS?: string;
  SUPABASE_PUBLISHABLE_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_URL?: string;
}
