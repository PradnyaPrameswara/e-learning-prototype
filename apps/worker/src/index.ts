export interface Env {
  FILES_BUCKET: R2Bucket;
}

const jsonHeaders = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
};

function response(body: unknown, status: number, requestId: string): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...jsonHeaders, 'x-request-id': requestId },
  });
}

export default {
  async fetch(request: Request): Promise<Response> {
    const requestId = crypto.randomUUID();
    const url = new URL(request.url);

    try {
      if (url.pathname === '/health') {
        if (request.method !== 'GET') {
          return response(
            { error: 'method_not_allowed', requestId },
            405,
            requestId,
          );
        }

        return response({ status: 'ok', requestId }, 200, requestId);
      }

      return response({ error: 'not_found', requestId }, 404, requestId);
    } catch {
      console.error(
        JSON.stringify({ level: 'error', event: 'request.failure', requestId }),
      );
      return response({ error: 'internal_error', requestId }, 500, requestId);
    }
  },
} satisfies ExportedHandler<Env>;
