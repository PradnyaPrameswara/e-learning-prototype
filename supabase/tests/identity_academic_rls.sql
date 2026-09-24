begin;

create extension if not exists pgtap with schema extensions;
select plan(44);

insert into auth.users (id, aud, role, email, encrypted_password)
values
  ('10000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'admin-a@example.test', ''),
  ('10000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'student-a@example.test', ''),
  ('10000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'teacher-a@example.test', ''),
  ('10000000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', 'unassigned-teacher@example.test', ''),
  ('10000000-0000-4000-8000-000000000005', 'authenticated', 'authenticated', 'student-b@example.test', ''),
  ('10000000-0000-4000-8000-000000000006', 'authenticated', 'authenticated', 'admin-b@example.test', ''),
  ('10000000-0000-4000-8000-000000000007', 'authenticated', 'authenticated', 'disabled-student@example.test', '');

insert into public.schools (id, name)
values
  ('20000000-0000-4000-8000-000000000001', 'School A'),
  ('20000000-0000-4000-8000-000000000002', 'School B');

insert into public.school_memberships (id, school_id, user_id, status, disabled_at)
values
  ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'active', null),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'active', null),
  ('30000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'active', null),
  ('30000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', 'active', null),
  ('30000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000005', 'active', null),
  ('30000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000006', 'active', null),
  ('30000000-0000-4000-8000-000000000007', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000007', 'disabled', now());

insert into public.membership_roles (school_id, membership_id, role)
values
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'admin'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'student'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'teacher'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000004', 'teacher'),
  ('20000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000005', 'student'),
  ('20000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000006', 'admin'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000007', 'student');

insert into public.academic_years (id, school_id, label, starts_on, ends_on)
values
  ('40000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '2026', '2026-01-01', '2026-12-31'),
  ('40000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', '2026', '2026-01-01', '2026-12-31');
insert into public.classes (id, school_id, name)
values
  ('50000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Class A'),
  ('50000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 'Class B');
insert into public.subjects (id, school_id, name, code)
values
  ('60000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Physics', 'PHY'),
  ('60000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', 'Physics', 'PHY');
insert into public.courses (id, school_id, academic_year_id, class_id, subject_id, title)
values
  ('70000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '60000000-0000-4000-8000-000000000001', 'Physics A'),
  ('70000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000002', 'Physics B');
insert into public.teacher_assignments (school_id, course_id, teacher_membership_id, assigned_by)
values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000001');
insert into public.student_enrollments (school_id, academic_year_id, class_id, student_membership_id, enrolled_by)
values
  ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001'),
  ('20000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000005', '30000000-0000-4000-8000-000000000006'),
  ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000007', '30000000-0000-4000-8000-000000000001');

select is((select count(*)::integer from pg_class as relation
  join pg_namespace as namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public' and relation.relkind = 'r'
    and relation.relname = any(array['schools','profiles','school_memberships','membership_roles','academic_years','classes','subjects','courses','teacher_assignments','student_enrollments','audit_events'])
    and relation.relrowsecurity), 11, 'RLS is enabled on every identity and academic table');
select throws_ok($$insert into public.courses (school_id, academic_year_id, class_id, subject_id, title) values ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000002', '60000000-0000-4000-8000-000000000001', 'Cross-school class')$$, '23503', 'insert or update on table "courses" violates foreign key constraint "courses_school_id_class_id_fkey"', 'Course cannot reference a class from another school');
select throws_ok($$insert into public.teacher_assignments (school_id, course_id, teacher_membership_id, assigned_by) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000005', '30000000-0000-4000-8000-000000000001')$$, '23503', 'insert or update on table "teacher_assignments" violates foreign key constraint "teacher_assignments_school_id_teacher_membership_id_fkey"', 'Teacher assignment cannot cross schools');
select throws_ok($$insert into public.student_enrollments (school_id, academic_year_id, class_id, student_membership_id, enrolled_by) values ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001')$$, '23503', 'insert or update on table "student_enrollments" violates foreign key constraint "student_enrollments_school_id_academic_year_id_fkey"', 'Student enrollment cannot reference another school year');
select throws_ok($$insert into public.student_enrollments (school_id, academic_year_id, class_id, student_membership_id, enrolled_by) values ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001')$$, '23505', 'duplicate key value violates unique constraint "student_enrollments_one_active_year_unique"', 'Student has at most one active class enrollment per school year');
select is((select count(*)::integer from public.profiles), 7, 'Auth users receive one linked application profile');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((select count(*)::integer from public.schools), 1, 'Student reads only the school where membership is active');
select is((select count(*)::integer from public.courses), 1, 'Student reads an enrolled Course');
select is((select count(*)::integer from public.courses where id = '70000000-0000-4000-8000-000000000002'), 0, 'Student cannot read a cross-school Course');
select is((select count(*)::integer from public.student_enrollments), 1, 'Student reads only their own active enrollment');
select is((select count(*)::integer from public.student_enrollments where student_membership_id = '30000000-0000-4000-8000-000000000005'), 0, 'Student cannot read another Student enrollment');
select is((select count(*)::integer from public.membership_roles), 1, 'Student reads only their own active role');
select throws_ok($$insert into public.membership_roles (school_id, membership_id, role) values ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'admin')$$, '42501', 'permission denied for table membership_roles', 'Student cannot self-assign an Admin role');
select throws_ok($$update public.school_memberships set status = 'active' where id = '30000000-0000-4000-8000-000000000007'$$, '42501', 'permission denied for table school_memberships', 'Student cannot reactivate a disabled membership');
select throws_ok($$select public.admin_set_membership_role('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'admin', 'active')$$, '42501', 'permission denied for function admin_set_membership_role', 'Student cannot invoke the Worker-only role operation');
select throws_ok($$select public.admin_set_membership_role('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', 'teacher', 'active')$$, '42501', 'permission denied for function admin_set_membership_role', 'Student cannot self-assign a Teacher role');
select throws_ok($$insert into public.teacher_assignments (school_id, course_id, teacher_membership_id, assigned_by) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002')$$, '42501', 'permission denied for table teacher_assignments', 'Student cannot self-create a Teacher assignment');
select throws_ok($$insert into public.student_enrollments (school_id, academic_year_id, class_id, student_membership_id, enrolled_by) values ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002')$$, '42501', 'permission denied for table student_enrollments', 'Student cannot self-enroll through direct table writes');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select count(*)::integer from public.courses), 1, 'Assigned Teacher reads the assigned Course');
select is((select count(*)::integer from public.courses where id = '70000000-0000-4000-8000-000000000002'), 0, 'Assigned Teacher cannot read another school Course');
select is((select count(*)::integer from public.teacher_assignments), 1, 'Teacher reads only their own active assignment');
select throws_ok($$select public.admin_set_membership_role('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003', 'admin', 'active')$$, '42501', 'permission denied for function admin_set_membership_role', 'Teacher cannot invoke the Worker-only role operation');
select throws_ok($$select public.admin_create_academic_year('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', '2027', '2027-01-01', '2027-12-31')$$, '42501', 'permission denied for function admin_create_academic_year', 'Teacher cannot invoke an Admin academic mutation directly');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select is((select count(*)::integer from public.courses), 0, 'Teacher role alone grants no Course access');
select ok(not private.is_assigned_teacher('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001'), 'Unassigned Teacher is not authorized for a Course');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select count(*)::integer from public.schools), 1, 'Admin reads only its own school');
select is((select count(*)::integer from public.courses where id = '70000000-0000-4000-8000-000000000002'), 0, 'Admin cannot read another school Course');
select ok(not private.is_assigned_teacher('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001'), 'Admin does not inherit Teacher assignment permission');
select throws_ok($$select public.admin_create_class('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Class A2', 'Grade 10', 'B')$$, '42501', 'permission denied for function admin_create_class', 'Admin browser cannot invoke the Worker-only RPC directly');
reset role;

set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select ok(public.admin_create_class('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Class A2', 'Grade 10', 'B') is not null, 'Worker credential can create a class for its verified Admin actor');
select is((select count(*)::integer from public.audit_events where action = 'class.create'), 1, 'Class creation and audit record commit together');
select throws_ok($$select public.admin_create_class('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'Forged actor', null, null)$$, '42501', 'active school administrator membership required', 'Worker-only RPC rechecks the supplied actor against current Admin membership');
select throws_ok($$select public.admin_assign_teacher('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002')$$, '23514', 'active Teacher membership in this school required', 'Admin cannot assign a Student as a Teacher');
select is(public.admin_enroll_student('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002'), (select id from public.student_enrollments where student_membership_id = '30000000-0000-4000-8000-000000000002' and status = 'active'), 'Repeated enrollment returns the canonical active enrollment');
select throws_ok($$select public.admin_create_class('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'Wrong school', null, null)$$, '42501', 'active school administrator membership required', 'School A Admin cannot mutate School B');
select throws_ok($$select public.admin_set_membership_status('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'disabled')$$, '23514', 'the final active school administrator cannot be disabled', 'The final active Admin cannot disable their own school access');
select throws_ok($$select public.admin_set_membership_role('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'admin', 'revoked')$$, '23514', 'the final active school administrator cannot be removed', 'The final active Admin role cannot be revoked');
select is(public.admin_set_membership_status('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'disabled'), '30000000-0000-4000-8000-000000000002'::uuid, 'Admin can disable membership through the trusted operation');
select is((select count(*)::integer from public.audit_events where action = 'user.disable'), 1, 'Membership disable writes a durable audit event');
select is(public.admin_set_membership_status('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'active'), '30000000-0000-4000-8000-000000000002'::uuid, 'Admin can explicitly reactivate membership');
select is((select count(*)::integer from public.audit_events where action = 'user.reactivate'), 1, 'Membership reactivation writes a durable audit event');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
select is((select count(*)::integer from public.schools), 0, 'Disabled membership grants no school access');
select is((select count(*)::integer from public.courses), 0, 'Disabled membership grants no Course access');
select is((select count(*)::integer from public.school_memberships), 0, 'Disabled user cannot retain application membership access');

select * from finish();
rollback;
