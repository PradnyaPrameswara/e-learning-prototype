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
});
