import { SELF } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';

describe('Worker foundation', () => {
  it('returns a safe health response with a request ID', async () => {
    const result = await SELF.fetch('https://worker.test/health');
    const body: unknown = await result.json();

    expect(result.status).toBe(200);
    expect(result.headers.get('x-request-id')).toBeTruthy();
    expect(body).toMatchObject({ status: 'ok' });
    expect(JSON.stringify(body)).not.toContain('FILES_BUCKET');
  });

  it('returns a safe not-found response for unimplemented routes', async () => {
    const result = await SELF.fetch('https://worker.test/not-implemented');

    expect(result.status).toBe(404);
    await expect(result.json()).resolves.toMatchObject({ error: 'not_found' });
  });

  it('rejects non-GET health checks', async () => {
    const result = await SELF.fetch('https://worker.test/health', {
      method: 'POST',
    });

    expect(result.status).toBe(405);
  });

  it('rejects an unconfigured browser origin before processing protected routes', async () => {
    const result = await SELF.fetch('https://worker.test/v1/admin/classes', {
      method: 'POST',
      headers: {
        Origin: 'https://untrusted.example',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });
    const body: unknown = await result.json();

    expect(result.status).toBe(403);
    expect(body).toMatchObject({ error: 'origin_not_allowed' });
    expect(result.headers.get('access-control-allow-origin')).toBeNull();
  });

  it('requires a Supabase bearer token for school administration mutations', async () => {
    const result = await SELF.fetch('https://worker.test/v1/admin/classes', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        schoolId: '20000000-0000-4000-8000-000000000001',
        name: 'Class 10',
      }),
    });
    const body: unknown = await result.json();

    expect(result.status).toBe(401);
    expect(body).toMatchObject({ error: 'unauthenticated' });
    expect(JSON.stringify(body)).not.toContain('SUPABASE_PUBLISHABLE_KEY');
  });

  it('does not expose database RPCs through unsupported HTTP methods', async () => {
    const result = await SELF.fetch('https://worker.test/v1/admin/classes', {
      method: 'GET',
    });

    expect(result.status).toBe(405);
    await expect(result.json()).resolves.toMatchObject({
      error: 'method_not_allowed',
    });
  });
});
