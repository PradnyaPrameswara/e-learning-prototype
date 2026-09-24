import type { UserSupabaseClient } from '@lms/auth';
import type { Database } from '@lms/database';
import { z } from 'zod';
import type { SupabaseClient } from '@supabase/supabase-js';
import type { Env } from '../env';

type LessonAuthentication =
  | { client: UserSupabaseClient; status: 'ok'; userId: string }
  | { status: 'unauthenticated' }
  | { status: 'unavailable' };

type LessonBodyResult<Output> =
  | { status: 'valid'; data: Output }
  | { status: 'too_large' }
  | { status: 'invalid_json' }
  | { status: 'invalid_request'; fields: { path: string; message: string }[] };

interface LessonRouteDependencies {
  authenticate: (request: Request, env: Env) => Promise<LessonAuthentication>;
  boundedJson: <Schema extends z.ZodType>(
    request: Request,
    schema: Schema,
  ) => Promise<LessonBodyResult<z.output<Schema>>>;
  createAdminSupabaseClient: (env: Env) => SupabaseClient<Database> | null;
  response: (
    body: unknown,
    status: number,
    requestId: string,
    allowedOrigin: string | null,
  ) => Response;
}

const emptyBodySchema = z.object({}).strict();
const lessonIdSchema = z.uuid();

const RPC_FAILURE = {
  forbidden: { status: 403, error: 'forbidden' },
  notFound: { status: 404, error: 'not_found' },
  invalidRequest: { status: 400, error: 'invalid_request' },
  conflict: { status: 409, error: 'conflict' },
  internal: { status: 500, error: 'internal_error' },
} as const;

type RpcFailure = (typeof RPC_FAILURE)[keyof typeof RPC_FAILURE];

function rpcFailure(code: string): RpcFailure {
  if (code === '42501') return RPC_FAILURE.forbidden;
  if (code === 'P0002') return RPC_FAILURE.notFound;
  if (code === '22023') return RPC_FAILURE.invalidRequest;
  if (['23502', '23503', '23505', '23514'].includes(code)) {
    return RPC_FAILURE.conflict;
  }
  return RPC_FAILURE.internal;
}

export async function handleLessonRoute(
  request: Request,
  env: Env,
  requestId: string,
  allowedOrigin: string | null,
  dependencies: LessonRouteDependencies,
): Promise<Response | null> {
  const match = /^\/v1\/lessons\/([^/]+)\/(publish|unpublish|archive)$/.exec(
    new URL(request.url).pathname,
  );
  if (!match) return null;

  if (request.method !== 'POST') {
    return dependencies.response(
      { error: 'method_not_allowed', requestId },
      405,
      requestId,
      allowedOrigin,
    );
  }

  const lessonId = lessonIdSchema.safeParse(match[1]);
  if (!lessonId.success) {
    return dependencies.response(
      { error: 'invalid_request', requestId },
      400,
      requestId,
      allowedOrigin,
    );
  }

  const authentication = await dependencies.authenticate(request, env);
  if (authentication.status === 'unauthenticated') {
    return dependencies.response(
      { error: 'unauthenticated', requestId },
      401,
      requestId,
      allowedOrigin,
    );
  }
  if (authentication.status === 'unavailable') {
    return dependencies.response(
      { error: 'identity_service_unavailable', requestId },
      503,
      requestId,
      allowedOrigin,
    );
  }

  const body = await dependencies.boundedJson(request, emptyBodySchema);
  if (body.status === 'too_large') {
    return dependencies.response(
      { error: 'request_too_large', requestId },
      413,
      requestId,
      allowedOrigin,
    );
  }
  if (body.status === 'invalid_json') {
    return dependencies.response(
      { error: 'invalid_json', requestId },
      400,
      requestId,
      allowedOrigin,
    );
  }
  if (body.status === 'invalid_request') {
    return dependencies.response(
      { error: 'invalid_request', fields: body.fields, requestId },
      400,
      requestId,
      allowedOrigin,
    );
  }

  const { data: visibleLesson, error: authorizationError } =
    await authentication.client
      .from('lessons')
      .select('id')
      .eq('id', lessonId.data)
      .maybeSingle();
  if (authorizationError) {
    return dependencies.response(
      { error: 'authorization_service_unavailable', requestId },
      503,
      requestId,
      allowedOrigin,
    );
  }
  if (!visibleLesson) {
    return dependencies.response(
      { error: 'not_found', requestId },
      404,
      requestId,
      allowedOrigin,
    );
  }

  const privilegedClient = dependencies.createAdminSupabaseClient(env);
  if (!privilegedClient) {
    return dependencies.response(
      { error: 'database_service_unavailable', requestId },
      503,
      requestId,
      allowedOrigin,
    );
  }

  const action = match[2];
  let result: {
    data: string | null;
    error: { code: string; message: string } | null;
  };
  try {
    if (action === 'publish') {
      result = await privilegedClient.rpc('teacher_publish_lesson', {
        p_lesson_id: lessonId.data,
        p_actor_user_id: authentication.userId,
        p_request_id: requestId,
      });
    } else if (action === 'unpublish') {
      result = await privilegedClient.rpc('teacher_unpublish_lesson', {
        p_lesson_id: lessonId.data,
        p_actor_user_id: authentication.userId,
        p_request_id: requestId,
      });
    } else {
      result = await privilegedClient.rpc('teacher_archive_lesson', {
        p_lesson_id: lessonId.data,
        p_actor_user_id: authentication.userId,
        p_request_id: requestId,
      });
    }
  } catch {
    console.error(
      JSON.stringify({
        level: 'error',
        event: 'lesson.rpc.transport_failure',
        operation: action,
        requestId,
      }),
    );
    return dependencies.response(
      { error: 'database_unavailable', requestId },
      503,
      requestId,
      allowedOrigin,
    );
  }

  if (result.error) {
    const mapped = rpcFailure(result.error.code);
    if (mapped.status >= 500) {
      console.error(
        JSON.stringify({
          level: 'error',
          event: 'lesson.rpc.failure',
          operation: action,
          databaseCode: result.error.code,
          requestId,
        }),
      );
    }
    return dependencies.response(
      { error: mapped.error, requestId },
      mapped.status,
      requestId,
      allowedOrigin,
    );
  }
  if (!result.data) {
    console.error(
      JSON.stringify({
        level: 'error',
        event: 'lesson.rpc.empty_result',
        operation: action,
        requestId,
      }),
    );
    return dependencies.response(
      { error: 'internal_error', requestId },
      500,
      requestId,
      allowedOrigin,
    );
  }

  const status =
    action === 'publish'
      ? 'published'
      : action === 'archive'
        ? 'archived'
        : 'draft';
  return dependencies.response(
    { lessonId: result.data, status, requestId },
    200,
    requestId,
    allowedOrigin,
  );
}
