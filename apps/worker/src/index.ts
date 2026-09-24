import { createUserSupabaseClient, type UserSupabaseClient } from '@lms/auth';
import type { Database } from '@lms/database';
import {
  assignTeacherRequestSchema,
  createAcademicYearRequestSchema,
  createClassRequestSchema,
  createCourseRequestSchema,
  createSubjectRequestSchema,
  enrollStudentRequestSchema,
  revokeTeacherAssignmentRequestSchema,
  setMembershipRoleRequestSchema,
  setMembershipStatusRequestSchema,
  unenrollStudentRequestSchema,
} from '@lms/schemas/identity';
import { z } from 'zod';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

export interface Env {
  FILES_BUCKET: R2Bucket;
  APP_ORIGINS?: string;
  SUPABASE_PUBLISHABLE_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_URL?: string;
}

const jsonHeaders = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
};
const maxBodyBytes = 16 * 1024;

type RpcError = { code: string; message: string };
type RpcResponse = { data: string | null; error: RpcError | null };
type AdminSupabaseClient = SupabaseClient<Database>;
type BodyResult<Output> =
  | { status: 'valid'; data: Output }
  | { status: 'too_large' }
  | { status: 'invalid_json' }
  | { status: 'invalid_request'; fields: { path: string; message: string }[] };
type RpcOperation<Input> = (
  client: AdminSupabaseClient,
  input: Input,
  actorUserId: string,
  requestId: string,
) => PromiseLike<RpcResponse>;

function corsOrigin(request: Request, env: Env): string | null | false {
  const origin = request.headers.get('origin');
  if (!origin) return null;

  let parsedOrigin: string;
  try {
    parsedOrigin = new URL(origin).origin;
  } catch {
    return false;
  }
  if (origin !== parsedOrigin) return false;

  const allowlist = (env.APP_ORIGINS ?? '')
    .split(',')
    .map((allowedOrigin) => allowedOrigin.trim())
    .filter(Boolean);
  return allowlist.includes(parsedOrigin) ? parsedOrigin : false;
}

function response(
  body: unknown,
  status: number,
  requestId: string,
  allowedOrigin: string | null,
): Response {
  const headers = new Headers({
    ...jsonHeaders,
    'x-request-id': requestId,
    vary: 'Origin',
  });
  if (allowedOrigin) {
    headers.set('access-control-allow-origin', allowedOrigin);
    headers.set('access-control-allow-headers', 'authorization, content-type');
    headers.set(
      'access-control-allow-methods',
      'GET, POST, PATCH, DELETE, OPTIONS',
    );
  }
  return new Response(JSON.stringify(body), { status, headers });
}

function preflight(requestId: string, allowedOrigin: string | null): Response {
  const headers = new Headers({
    'cache-control': 'no-store',
    'x-request-id': requestId,
    vary: 'Origin',
  });
  if (allowedOrigin) {
    headers.set('access-control-allow-origin', allowedOrigin);
    headers.set('access-control-allow-headers', 'authorization, content-type');
    headers.set(
      'access-control-allow-methods',
      'GET, POST, PATCH, DELETE, OPTIONS',
    );
    headers.set('access-control-max-age', '600');
  }
  return new Response(null, { status: 204, headers });
}

function bearerToken(request: Request): string | null {
  const authorization = request.headers.get('authorization');
  const match = authorization?.match(/^Bearer ([^\s]+)$/i);
  return match?.[1] ?? null;
}

type Authentication =
  | { client: UserSupabaseClient; status: 'ok'; userId: string }
  | { status: 'unauthenticated' }
  | { status: 'unavailable' };

async function authenticate(
  request: Request,
  env: Env,
): Promise<Authentication> {
  const token = bearerToken(request);
  if (!token) return { status: 'unauthenticated' };
  if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
    return { status: 'unavailable' };
  }

  const client = createUserSupabaseClient({
    accessToken: token,
    publishableKey: env.SUPABASE_PUBLISHABLE_KEY,
    url: env.SUPABASE_URL,
  });
  try {
    const { data, error } = await client.auth.getUser(token);
    if (error?.name === 'AuthRetryableFetchError')
      return { status: 'unavailable' };
    if (error || !data.user) return { status: 'unauthenticated' };
    return { client, status: 'ok', userId: data.user.id };
  } catch {
    return { status: 'unavailable' };
  }
}

type AdminAuthorization = 'allowed' | 'denied' | 'unavailable';

async function authorizeSchoolAdmin(
  client: UserSupabaseClient,
  userId: string,
  schoolId: string,
): Promise<AdminAuthorization> {
  const { data: membership, error: membershipError } = await client
    .from('school_memberships')
    .select('id')
    .eq('school_id', schoolId)
    .eq('user_id', userId)
    .eq('status', 'active')
    .maybeSingle();
  if (membershipError) return 'unavailable';
  if (!membership) return 'denied';

  const { data: role, error: roleError } = await client
    .from('membership_roles')
    .select('role')
    .eq('school_id', schoolId)
    .eq('membership_id', membership.id)
    .eq('role', 'admin')
    .eq('status', 'active')
    .maybeSingle();
  if (roleError) return 'unavailable';
  return role ? 'allowed' : 'denied';
}

function createAdminSupabaseClient(env: Env): AdminSupabaseClient | null {
  if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) return null;
  return createClient<Database>(
    env.SUPABASE_URL,
    env.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        autoRefreshToken: false,
        detectSessionInUrl: false,
        persistSession: false,
      },
    },
  );
}

async function boundedJson<Schema extends z.ZodType>(
  request: Request,
  schema: Schema,
): Promise<BodyResult<z.output<Schema>>> {
  const contentLength = request.headers.get('content-length');
  if (contentLength !== null) {
    const declaredLength = Number(contentLength);
    if (!Number.isSafeInteger(declaredLength) || declaredLength < 0)
      return { status: 'invalid_json' };
    if (declaredLength > maxBodyBytes) return { status: 'too_large' };
  }

  if (!request.body) return { status: 'invalid_json' };
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > maxBodyBytes) {
        await reader.cancel();
        return { status: 'too_large' };
      }
      chunks.push(value);
    }
  } catch {
    return { status: 'invalid_json' };
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  try {
    const body: unknown = JSON.parse(new TextDecoder().decode(bytes));
    const parsed = schema.safeParse(body);
    if (!parsed.success) {
      return {
        status: 'invalid_request',
        fields: parsed.error.issues.map((issue) => ({
          path: issue.path.join('.'),
          message: issue.message,
        })),
      };
    }
    return { status: 'valid', data: parsed.data };
  } catch {
    return { status: 'invalid_json' };
  }
}

type RpcHttpError = {
  status: number;
  error:
    | 'forbidden'
    | 'not_found'
    | 'invalid_request'
    | 'conflict'
    | 'internal_error';
};

function rpcStatus(code: string): RpcHttpError {
  if (code === '42501') return { status: 403, error: 'forbidden' };
  if (code === 'P0002') return { status: 404, error: 'not_found' };
  if (code === '22023') return { status: 400, error: 'invalid_request' };
  if (['23502', '23503', '23505', '23514'].includes(code)) {
    return { status: 409, error: 'conflict' };
  }
  return { status: 500, error: 'internal_error' };
}

async function adminMutation<Schema extends z.ZodType<{ schoolId: string }>>(
  request: Request,
  env: Env,
  requestId: string,
  allowedOrigin: string | null,
  operationName: string,
  schema: Schema,
  invoke: RpcOperation<z.infer<Schema>>,
): Promise<Response> {
  const auth = await authenticate(request, env);
  if (auth.status === 'unauthenticated') {
    return response(
      { error: 'unauthenticated', requestId },
      401,
      requestId,
      allowedOrigin,
    );
  }
  if (auth.status === 'unavailable') {
    return response(
      { error: 'identity_service_unavailable', requestId },
      503,
      requestId,
      allowedOrigin,
    );
  }

  const body = await boundedJson(request, schema);
  if (body.status === 'too_large') {
    return response(
      { error: 'request_too_large', requestId },
      413,
      requestId,
      allowedOrigin,
    );
  }
  if (body.status === 'invalid_json') {
    return response(
      { error: 'invalid_json', requestId },
      400,
      requestId,
      allowedOrigin,
    );
  }
  if (body.status === 'invalid_request') {
    return response(
      {
        error: 'invalid_request',
        fields: body.fields,
        requestId,
      },
      400,
      requestId,
      allowedOrigin,
    );
  }

  const authorization = await authorizeSchoolAdmin(
    auth.client,
    auth.userId,
    body.data.schoolId,
  );
  if (authorization === 'unavailable') {
    return response(
      { error: 'authorization_service_unavailable', requestId },
      503,
      requestId,
      allowedOrigin,
    );
  }
  if (authorization === 'denied') {
    return response(
      { error: 'forbidden', requestId },
      403,
      requestId,
      allowedOrigin,
    );
  }

  const adminClient = createAdminSupabaseClient(env);
  if (!adminClient) {
    return response(
      { error: 'database_service_unavailable', requestId },
      503,
      requestId,
      allowedOrigin,
    );
  }

  let result: RpcResponse;
  try {
    result = await invoke(adminClient, body.data, auth.userId, requestId);
  } catch {
    console.error(
      JSON.stringify({
        level: 'error',
        event: 'admin.rpc.transport_failure',
        operationName,
        requestId,
      }),
    );
    return response(
      { error: 'database_unavailable', requestId },
      503,
      requestId,
      allowedOrigin,
    );
  }
  if (result.error) {
    const mapped = rpcStatus(result.error.code);
    if (mapped.status >= 500) {
      console.error(
        JSON.stringify({
          level: 'error',
          event: 'admin.rpc.failure',
          operationName,
          databaseCode: result.error.code,
          requestId,
        }),
      );
    }
    return response(
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
        event: 'admin.rpc.empty_result',
        operationName,
        requestId,
      }),
    );
    return response(
      { error: 'internal_error', requestId },
      500,
      requestId,
      allowedOrigin,
    );
  }

  return response(
    { id: result.data, requestId },
    200,
    requestId,
    allowedOrigin,
  );
}

function methodNotAllowed(
  requestId: string,
  allowedOrigin: string | null,
): Response {
  return response(
    { error: 'method_not_allowed', requestId },
    405,
    requestId,
    allowedOrigin,
  );
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const requestId = crypto.randomUUID();
    const url = new URL(request.url);
    const origin = corsOrigin(request, env);

    if (origin === false) {
      return response(
        { error: 'origin_not_allowed', requestId },
        403,
        requestId,
        null,
      );
    }
    if (request.method === 'OPTIONS') return preflight(requestId, origin);

    try {
      if (url.pathname === '/health') {
        if (request.method !== 'GET')
          return methodNotAllowed(requestId, origin);
        return response({ status: 'ok', requestId }, 200, requestId, origin);
      }

      if (url.pathname === '/v1/admin/academic-years') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'academic_year.create',
          createAcademicYearRequestSchema,
          (client, input, actorUserId, id) =>
            client.rpc('admin_create_academic_year', {
              p_school_id: input.schoolId,
              p_actor_user_id: actorUserId,
              p_label: input.label,
              p_starts_on: input.startsOn,
              p_ends_on: input.endsOn,
              p_request_id: id,
            }),
        );
      }
      if (url.pathname === '/v1/admin/classes') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'class.create',
          createClassRequestSchema,
          (client, input, actorUserId, id) => {
            const args: Database['public']['Functions']['admin_create_class']['Args'] =
              {
                p_school_id: input.schoolId,
                p_actor_user_id: actorUserId,
                p_name: input.name,
                p_request_id: id,
              };
            if (input.gradeLevel !== undefined && input.gradeLevel !== null) {
              args.p_grade_level = input.gradeLevel;
            }
            if (input.section !== undefined && input.section !== null) {
              args.p_section = input.section;
            }
            return client.rpc('admin_create_class', args);
          },
        );
      }
      if (url.pathname === '/v1/admin/subjects') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'subject.create',
          createSubjectRequestSchema,
          (client, input, actorUserId, id) => {
            const args: Database['public']['Functions']['admin_create_subject']['Args'] =
              {
                p_school_id: input.schoolId,
                p_actor_user_id: actorUserId,
                p_name: input.name,
                p_request_id: id,
              };
            if (input.code !== undefined && input.code !== null) {
              args.p_code = input.code;
            }
            return client.rpc('admin_create_subject', args);
          },
        );
      }
      if (url.pathname === '/v1/admin/courses') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'course.create',
          createCourseRequestSchema,
          (client, input, actorUserId, id) =>
            client.rpc('admin_create_course', {
              p_school_id: input.schoolId,
              p_actor_user_id: actorUserId,
              p_academic_year_id: input.academicYearId,
              p_class_id: input.classId,
              p_subject_id: input.subjectId,
              p_title: input.title,
              p_request_id: id,
            }),
        );
      }
      if (url.pathname === '/v1/admin/membership-roles') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'membership.role.change',
          setMembershipRoleRequestSchema,
          (client, input, actorUserId, id) =>
            client.rpc('admin_set_membership_role', {
              p_school_id: input.schoolId,
              p_actor_user_id: actorUserId,
              p_user_id: input.userId,
              p_role: input.role,
              p_status: input.status,
              p_request_id: id,
            }),
        );
      }
      if (url.pathname === '/v1/admin/memberships/status') {
        if (request.method !== 'PATCH')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'membership.status.change',
          setMembershipStatusRequestSchema,
          (client, input, actorUserId, id) =>
            client.rpc('admin_set_membership_status', {
              p_school_id: input.schoolId,
              p_actor_user_id: actorUserId,
              p_membership_id: input.membershipId,
              p_status: input.status,
              p_request_id: id,
            }),
        );
      }
      if (url.pathname === '/v1/admin/teacher-assignments') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'teacher.assign',
          assignTeacherRequestSchema,
          (client, input, actorUserId, id) =>
            client.rpc('admin_assign_teacher', {
              p_school_id: input.schoolId,
              p_actor_user_id: actorUserId,
              p_course_id: input.courseId,
              p_teacher_membership_id: input.teacherMembershipId,
              p_request_id: id,
            }),
        );
      }
      if (url.pathname === '/v1/admin/teacher-assignments/revoke') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'teacher.unassign',
          revokeTeacherAssignmentRequestSchema,
          (client, input, actorUserId, id) =>
            client.rpc('admin_revoke_teacher_assignment', {
              p_school_id: input.schoolId,
              p_actor_user_id: actorUserId,
              p_assignment_id: input.assignmentId,
              p_request_id: id,
            }),
        );
      }
      if (url.pathname === '/v1/admin/student-enrollments') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'student.enroll',
          enrollStudentRequestSchema,
          (client, input, actorUserId, id) =>
            client.rpc('admin_enroll_student', {
              p_school_id: input.schoolId,
              p_actor_user_id: actorUserId,
              p_academic_year_id: input.academicYearId,
              p_class_id: input.classId,
              p_student_membership_id: input.studentMembershipId,
              p_request_id: id,
            }),
        );
      }
      if (url.pathname === '/v1/admin/student-enrollments/unenroll') {
        if (request.method !== 'POST')
          return methodNotAllowed(requestId, origin);
        return await adminMutation(
          request,
          env,
          requestId,
          origin,
          'student.unenroll',
          unenrollStudentRequestSchema,
          (client, input, actorUserId, id) =>
            client.rpc('admin_unenroll_student', {
              p_school_id: input.schoolId,
              p_actor_user_id: actorUserId,
              p_enrollment_id: input.enrollmentId,
              p_request_id: id,
            }),
        );
      }

      return response(
        { error: 'not_found', requestId },
        404,
        requestId,
        origin,
      );
    } catch {
      console.error(
        JSON.stringify({ level: 'error', event: 'request.failure', requestId }),
      );
      return response(
        { error: 'internal_error', requestId },
        500,
        requestId,
        origin,
      );
    }
  },
} satisfies ExportedHandler<Env>;
