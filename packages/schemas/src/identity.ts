import { z } from 'zod';

const uuid = z.uuid();
const schoolId = z.object({ schoolId: uuid }).strict();

export const schoolRoleSchema = z.enum(['student', 'teacher', 'admin']);
export const membershipRoleStatusSchema = z.enum(['active', 'revoked']);
export const membershipStatusSchema = z.enum(['active', 'disabled']);

export const createAcademicYearRequestSchema = schoolId
  .extend({
    label: z.string().trim().min(1).max(80),
    startsOn: z.iso.date(),
    endsOn: z.iso.date(),
  })
  .strict()
  .refine((value) => value.endsOn >= value.startsOn, {
    message: 'End date must be on or after the start date.',
    path: ['endsOn'],
  });

export const createClassRequestSchema = schoolId
  .extend({
    name: z.string().trim().min(1).max(100),
    gradeLevel: z.string().trim().min(1).max(40).nullable().optional(),
    section: z.string().trim().min(1).max(40).nullable().optional(),
  })
  .strict();

export const createSubjectRequestSchema = schoolId
  .extend({
    name: z.string().trim().min(1).max(100),
    code: z.string().trim().max(32).nullable().optional(),
  })
  .strict();

export const createCourseRequestSchema = schoolId
  .extend({
    academicYearId: uuid,
    classId: uuid,
    subjectId: uuid,
    title: z.string().trim().min(1).max(160),
  })
  .strict();

export const setMembershipRoleRequestSchema = schoolId
  .extend({
    userId: uuid,
    role: schoolRoleSchema,
    status: membershipRoleStatusSchema,
  })
  .strict();

export const setMembershipStatusRequestSchema = schoolId
  .extend({
    membershipId: uuid,
    status: membershipStatusSchema,
  })
  .strict();

export const assignTeacherRequestSchema = schoolId
  .extend({
    courseId: uuid,
    teacherMembershipId: uuid,
  })
  .strict();

export const revokeTeacherAssignmentRequestSchema = schoolId
  .extend({ assignmentId: uuid })
  .strict();

export const enrollStudentRequestSchema = schoolId
  .extend({
    academicYearId: uuid,
    classId: uuid,
    studentMembershipId: uuid,
  })
  .strict();

export const unenrollStudentRequestSchema = schoolId
  .extend({ enrollmentId: uuid })
  .strict();
