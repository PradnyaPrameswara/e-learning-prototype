import type { Env } from '../env';
import { createClient } from '@supabase/supabase-js';
import type { Database } from '@lms/database';
import { describe, expect, it } from 'vitest';
import { handleLessonRoute } from './lessons';

const lessonId = '80000000-0000-4000-8000-000000000001';
const actorUserId = '10000000-0000-4000-8000-000000000002';
const requestId = '11000000-0000-4000-8000-000000000001';

interface RouteOptions {
  visibleLesson: boolean;
  rpcError?: { code: string; message: string } | null;
}

function createRoute(options: RouteOptions) {
  const rpcCalls: { name: string; body: string }[] = [];
  let privilegedClientCreated = false;

  const fetcher: typeof fetch = async (input, init) => {
    const request = input instanceof Request ? input : new Request(input, init);
    const url = new URL(request.url);

    if (url.pathname === '/rest/v1/lessons') {
      return Response.json(options.visibleLesson ? [{ id: lessonId }] : []);
    }
    if (url.pathname.startsWith('/rest/v1/rpc/')) {
      const body = await request.text();
      rpcCalls.push({ name: url.pathname.split('/').at(-1) ?? '', body });
      if (options.rpcError) {
        return Response.json(
          {
            code: options.rpcError.code,
            message: options.rpcError.message,
            details: null,
            hint: null,
          },
          { status: options.rpcError.code === '42501' ? 403 : 400 },
        );
      }
      return Response.json(lessonId);
    }
    return Response.json({ message: 'Not found' }, { status: 404 });
  };

  const userClient = createClient<Database>(
    'https://supabase.test',
    'test-publishable-key',
    { global: { fetch: fetcher } },
  );
  const privilegedClient = createClient<Database>(
    'https://supabase.test',
    'test-service-key',
    { global: { fetch: fetcher } },
  );

  const dependencies = {
    authenticate: async () => ({
      status: 'ok' as const,
      userId: actorUserId,
      client: userClient,
    }),
    boundedJson: async <Schema extends import('zod').ZodType>(
      request: Request,
      schema: Schema,
    ) => {
      const input: unknown = await request.json();
      const parsed = schema.safeParse(input);
      return parsed.success
        ? { status: 'valid' as const, data: parsed.data }
        : { status: 'invalid_request' as const, fields: [] };
    },
    createAdminSupabaseClient: () => {
      privilegedClientCreated = true;
      return privilegedClient;
    },
    response: (body: unknown, status: number) =>
      new Response(JSON.stringify(body) ?? 'null', {
        status,
        headers: { 'Content-Type': 'application/json' },
      }),
  };

  return {
    dependencies,
    rpcCalls,
    get privilegedClientCreated() {
      return privilegedClientCreated;
    },
  };
}

function request(action: string): Request {
  return new Request(`https://worker.test/v1/lessons/${lessonId}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{}',
  });
}

describe('Lesson lifecycle Worker route', () => {
  it('calls only the named publish RPC with the verified actor identity', async () => {
    const route = createRoute({ visibleLesson: true });

    // SAFETY: the route receives injected auth and Supabase clients, so these tests do not read Worker bindings.
    const env = {} as Env;
    const response = await handleLessonRoute(
      request('publish'),
      env,
      requestId,
      null,
      route.dependencies,
    );

    expect(response?.status).toBe(200);
    await expect(response?.json()).resolves.toMatchObject({
      lessonId,
      status: 'published',
      requestId,
    });
    expect(route.rpcCalls).toHaveLength(1);
    expect(route.rpcCalls[0]?.name).toBe('teacher_publish_lesson');
    const rpcBody: unknown = JSON.parse(route.rpcCalls[0]?.body ?? '{}');
    expect(rpcBody).toEqual({
      p_lesson_id: lessonId,
      p_actor_user_id: actorUserId,
      p_request_id: requestId,
    });
  });

  it('does not create a privileged client when the caller cannot see the Lesson under RLS', async () => {
    const route = createRoute({ visibleLesson: false });

    // SAFETY: the route receives injected auth and Supabase clients, so these tests do not read Worker bindings.
    const env = {} as Env;
    const response = await handleLessonRoute(
      request('publish'),
      env,
      requestId,
      null,
      route.dependencies,
    );

    expect(response?.status).toBe(404);
    expect(route.privilegedClientCreated).toBe(false);
    expect(route.rpcCalls).toHaveLength(0);
  });

  it('maps the transactional authorization denial without returning database details', async () => {
    const route = createRoute({
      visibleLesson: true,
      rpcError: {
        code: '42501',
        message: 'active assigned Teacher membership required',
      },
    });

    // SAFETY: the route receives injected auth and Supabase clients, so these tests do not read Worker bindings.
    const env = {} as Env;
    const response = await handleLessonRoute(
      request('archive'),
      env,
      requestId,
      null,
      route.dependencies,
    );
    const body: unknown = await response?.json();

    expect(response?.status).toBe(403);
    expect(body).toMatchObject({ error: 'forbidden', requestId });
    expect(JSON.stringify(body)).not.toContain('active assigned Teacher');
    expect(route.rpcCalls[0]?.name).toBe('teacher_archive_lesson');
  });
});
