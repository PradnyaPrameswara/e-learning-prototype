begin;

create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, aud, role, email, encrypted_password)
values
  ('10000000-0000-4000-8000-000000000001', 'authenticated', 'authenticated', 'lesson-admin-a@example.test', ''),
  ('10000000-0000-4000-8000-000000000002', 'authenticated', 'authenticated', 'lesson-teacher-a@example.test', ''),
  ('10000000-0000-4000-8000-000000000003', 'authenticated', 'authenticated', 'lesson-unassigned-a@example.test', ''),
  ('10000000-0000-4000-8000-000000000004', 'authenticated', 'authenticated', 'lesson-student-a@example.test', ''),
  ('10000000-0000-4000-8000-000000000005', 'authenticated', 'authenticated', 'lesson-student-b@example.test', ''),
  ('10000000-0000-4000-8000-000000000006', 'authenticated', 'authenticated', 'lesson-admin-b@example.test', ''),
  ('10000000-0000-4000-8000-000000000007', 'authenticated', 'authenticated', 'lesson-disabled-student@example.test', ''),
  ('10000000-0000-4000-8000-000000000008', 'authenticated', 'authenticated', 'lesson-teacher-b@example.test', ''),
  ('10000000-0000-4000-8000-000000000009', 'authenticated', 'authenticated', 'lesson-unenrolled-student@example.test', '');

insert into public.schools (id, name)
values
  ('20000000-0000-4000-8000-000000000001', 'Lesson School A'),
  ('20000000-0000-4000-8000-000000000002', 'Lesson School B');

insert into public.school_memberships (id, school_id, user_id, status, disabled_at)
values
  ('30000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'active', null),
  ('30000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002', 'active', null),
  ('30000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000003', 'active', null),
  ('30000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004', 'active', null),
  ('30000000-0000-4000-8000-000000000005', '20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000005', 'active', null),
  ('30000000-0000-4000-8000-000000000006', '20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000006', 'active', null),
  ('30000000-0000-4000-8000-000000000007', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000007', 'disabled', now()),
  ('30000000-0000-4000-8000-000000000008', '20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000008', 'active', null),
  ('30000000-0000-4000-8000-000000000009', '20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000009', 'active', null);

insert into public.membership_roles (school_id, membership_id, role)
values
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', 'admin'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', 'teacher'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'teacher'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000004', 'student'),
  ('20000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000005', 'student'),
  ('20000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000006', 'admin'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000007', 'student'),
  ('20000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000008', 'teacher'),
  ('20000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000009', 'student');

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
values
  ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001'),
  ('20000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000008', '30000000-0000-4000-8000-000000000006');
insert into public.student_enrollments (school_id, academic_year_id, class_id, student_membership_id, enrolled_by)
values
  ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000004', '30000000-0000-4000-8000-000000000001'),
  ('20000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000002', '50000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000005', '30000000-0000-4000-8000-000000000006'),
  ('20000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '50000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000007', '30000000-0000-4000-8000-000000000001');

insert into public.lessons (id, school_id, course_id, title, position, status, published_at)
values
  ('80000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', 'Draft vectors', 0, 'draft', null),
  ('80000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', 'Published motion', 1, 'published', now()),
  ('80000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000002', 'School B draft', 0, 'draft', null),
  ('80000000-0000-4000-8000-000000000004', '20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', 'Empty draft', 2, 'draft', null);

insert into public.media_assets (
  id, school_id, course_id, uploader_membership_id, object_key,
  original_display_name, content_type, byte_size, purpose, status
)
values (
  '91000000-0000-4000-8000-000000000001',
  '20000000-0000-4000-8000-000000000002',
  '70000000-0000-4000-8000-000000000002',
  '30000000-0000-4000-8000-000000000008',
  'school/20000000-0000-4000-8000-000000000002/course/70000000-0000-4000-8000-000000000002/asset/91000000-0000-4000-8000-000000000001',
  'School B image.png', 'image/png', 1024, 'lesson_image', 'ready'
);

insert into public.lesson_blocks (id, school_id, course_id, lesson_id, position, block_type, payload)
values
  ('90000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 0, 'heading', '{"text":"Vectors","level":2}'),
  ('90000000-0000-4000-8000-000000000002', '20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000002', 0, 'paragraph', '{"text":"Motion describes change in position."}'),
  ('90000000-0000-4000-8000-000000000003', '20000000-0000-4000-8000-000000000002', '70000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000003', 0, 'heading', '{"text":"School B","level":2}');

select is((select count(*)::integer from pg_class as relation
  join pg_namespace as namespace on namespace.oid = relation.relnamespace
  where namespace.nspname = 'public' and relation.relname = any(array['lessons','lesson_blocks','media_assets'])
    and relation.relrowsecurity), 3, 'RLS is enabled on every Lesson and media metadata table');
select throws_ok($$insert into public.lessons (school_id, course_id, title, position) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000002', 'Wrong school', 4)$$, '23503', 'insert or update on table "lessons" violates foreign key constraint "lessons_school_id_course_id_fkey"', 'Lesson cannot reference a Course in another School');
select throws_ok($$insert into public.lesson_blocks (school_id, course_id, lesson_id, position, block_type, payload) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000002', '80000000-0000-4000-8000-000000000001', 1, 'paragraph', '{"text":"Cross-course block"}')$$, '23503', 'insert or update on table "lesson_blocks" violates foreign key constraint "lesson_blocks_school_id_course_id_lesson_id_fkey"', 'Lesson block cannot cross its Lesson Course ownership');
select throws_ok($$insert into public.lessons (school_id, course_id, title, position) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', 'Duplicate order', 0)$$, '23505', 'duplicate key value violates unique constraint "lessons_active_course_position_unique"', 'Active Lesson positions are unique within a Course');
select throws_ok($$insert into public.lesson_blocks (school_id, course_id, lesson_id, position, block_type, payload) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 0, 'paragraph', '{"text":"Duplicate order"}')$$, '23505', 'duplicate key value violates unique constraint "lesson_blocks_lesson_position_key"', 'Block positions are unique within a Lesson');
select throws_ok($$insert into public.lesson_blocks (school_id, course_id, lesson_id, position, block_type, payload) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 1, 'heading', '{"text":"No heading level"}')$$, '23514', 'new row for relation "lesson_blocks" violates check constraint "lesson_blocks_check"', 'Heading payload must include a valid level');
select throws_ok($$insert into public.lesson_blocks (school_id, course_id, lesson_id, position, block_type, payload) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 1, 'heading', '{"text":"String level","level":"2"}')$$, '23514', 'new row for relation "lesson_blocks" violates check constraint "lesson_blocks_check"', 'Heading level must be a JSON number');
select throws_ok($$insert into public.lesson_blocks (school_id, course_id, lesson_id, position, block_type, payload) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 1, 'html', '{"html":"<script>"}')$$, '23514', 'new row for relation "lesson_blocks" violates check constraint "lesson_blocks_block_type_check"', 'Arbitrary HTML is not a supported Lesson block');
select throws_ok($$insert into public.lesson_blocks (school_id, course_id, lesson_id, position, block_type, payload) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 1, 'external_video', '{"provider":"vimeo","video_id":12345}')$$, '23514', 'new row for relation "lesson_blocks" violates check constraint "lesson_blocks_check"', 'External video identifiers must be strings');
select throws_ok($$insert into public.lesson_blocks (school_id, course_id, lesson_id, position, block_type, media_asset_id, payload) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 1, 'image', '91000000-0000-4000-8000-000000000001', '{"alt_text":"Cross-school image"}')$$, '23503', 'Lesson media asset not found in this Course', 'Lesson block cannot reference media metadata from another School or Course');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons), 1, 'Enrolled Student sees only published Lessons in the enrolled Course');
select is((select count(*)::integer from public.lessons where id = '80000000-0000-4000-8000-000000000001'), 0, 'Enrolled Student cannot read draft Lesson');
select is((select count(*)::integer from public.lesson_blocks), 1, 'Enrolled Student sees blocks from published Lesson only');
select is((select count(*)::integer from public.lesson_blocks where lesson_id = '80000000-0000-4000-8000-000000000001'), 0, 'Enrolled Student cannot read draft Lesson blocks');
select is((select count(*)::integer from public.lessons where school_id = '20000000-0000-4000-8000-000000000002'), 0, 'Student cannot read another School Lesson');
select throws_ok($$select public.teacher_publish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000004')$$, '42501', 'permission denied for function teacher_publish_lesson', 'Student cannot invoke Worker-only publication RPC');
select is((select count(*)::integer from public.lessons where id = '80000000-0000-4000-8000-000000000001'), 0, 'Denied direct publication leaves draft hidden');
select throws_ok($$select count(*) from public.media_assets$$, '42501', 'permission denied for table media_assets', 'Student cannot query private media metadata');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons), 3, 'Assigned Teacher reads Course Lessons including draft state');
select is((select count(*)::integer from public.lesson_blocks), 2, 'Assigned Teacher reads Course Lesson blocks');
select lives_ok($$insert into public.lessons (school_id, course_id, title, position) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', 'Created draft', 3)$$, 'Assigned Teacher can create a draft Lesson');
select lives_ok($$update public.lessons set title = 'Updated draft' where id = '80000000-0000-4000-8000-000000000001'$$, 'Assigned Teacher can update a draft Lesson title');
select throws_ok($$update public.lessons set status = 'published', published_at = now() where id = '80000000-0000-4000-8000-000000000001'$$, '42501', 'permission denied for table lessons', 'Browser Teacher cannot publish by direct table update');
select throws_ok($$update public.lessons set title = 'Unsafe live edit' where id = '80000000-0000-4000-8000-000000000002'$$, '23514', 'Unpublish a Lesson before editing its title', 'Published Lesson title cannot be edited directly');
select lives_ok($$insert into public.lesson_blocks (school_id, course_id, lesson_id, position, block_type, payload) values ('20000000-0000-4000-8000-000000000001', '70000000-0000-4000-8000-000000000001', '80000000-0000-4000-8000-000000000001', 1, 'paragraph', '{"text":"Draft explanation"}')$$, 'Assigned Teacher can add a valid block to a draft');
update public.lesson_blocks set payload = '{"text":"Should remain unchanged"}' where id = '90000000-0000-4000-8000-000000000002';
select is((select payload ->> 'text' from public.lesson_blocks where id = '90000000-0000-4000-8000-000000000002'), 'Motion describes change in position.', 'Published blocks are not directly editable');
select is(public.reorder_lessons('70000000-0000-4000-8000-000000000001', array['80000000-0000-4000-8000-000000000002'::uuid, '80000000-0000-4000-8000-000000000001'::uuid, '80000000-0000-4000-8000-000000000004'::uuid, (select id from public.lessons where title = 'Created draft')]), 4, 'Assigned Teacher can atomically reorder every non-archived Lesson');
select is((select array_agg(lesson.id order by lesson.position) from public.lessons as lesson where lesson.course_id = '70000000-0000-4000-8000-000000000001' and lesson.status <> 'archived'), array['80000000-0000-4000-8000-000000000002'::uuid, '80000000-0000-4000-8000-000000000001'::uuid, '80000000-0000-4000-8000-000000000004'::uuid, (select id from public.lessons where title = 'Created draft')], 'Lesson reorder persists a deterministic order');
select is(public.reorder_lesson_blocks('80000000-0000-4000-8000-000000000001', array['90000000-0000-4000-8000-000000000001'::uuid, (select id from public.lesson_blocks where payload ->> 'text' = 'Draft explanation')]), 2, 'Assigned Teacher can atomically reorder every draft block');
select is((select array_agg(block.id order by block.position) from public.lesson_blocks as block where block.lesson_id = '80000000-0000-4000-8000-000000000001'), array['90000000-0000-4000-8000-000000000001'::uuid, (select id from public.lesson_blocks where payload ->> 'text' = 'Draft explanation')], 'Block order is deterministic after reorder');
select throws_ok($$select public.teacher_archive_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002')$$, '42501', 'permission denied for function teacher_archive_lesson', 'Assigned Teacher cannot bypass Worker for lifecycle changes');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000003', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons), 0, 'Teacher role without Course assignment reads no Lesson');
select is((select count(*)::integer from public.lesson_blocks), 0, 'Teacher role without assignment reads no blocks');
select throws_ok($$select public.reorder_lesson_blocks('80000000-0000-4000-8000-000000000001', array['90000000-0000-4000-8000-000000000001'::uuid])$$, '42501', 'assigned Teacher access required', 'Unassigned Teacher cannot reorder another Course blocks');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons), 0, 'Admin does not inherit Teacher Lesson visibility');
select throws_ok($$select public.teacher_publish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001')$$, '42501', 'permission denied for function teacher_publish_lesson', 'Admin cannot call Worker-only Lesson publication directly');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000008', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000008","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons), 1, 'School B Teacher reads assigned School B Lesson');
select is((select count(*)::integer from public.lessons where school_id = '20000000-0000-4000-8000-000000000001'), 0, 'School B Teacher cannot read School A Lessons');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000005', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons), 0, 'School B Student cannot read unpublished Lesson');
select is((select count(*)::integer from public.lessons where school_id = '20000000-0000-4000-8000-000000000001'), 0, 'School B Student cannot read School A Lesson');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000009', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons), 0, 'Student without enrollment cannot read Lesson');
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000007', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons), 0, 'Disabled membership cannot read published Lesson');
reset role;

reset role;
create function public.lesson_test_reject_publish_audit()
returns trigger
language plpgsql
as $$
begin
  if new.action = 'lesson.publish' then
    raise exception 'forced Lesson audit failure' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger lesson_test_reject_publish_audit
  before insert on public.audit_events
  for each row execute function public.lesson_test_reject_publish_audit();
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select throws_ok($$select public.teacher_publish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002')$$, 'P0001', 'forced Lesson audit failure', 'Audit failure aborts the publication transaction');
reset role;
select is((select status from public.lessons where id = '80000000-0000-4000-8000-000000000001'), 'draft', 'Failed audit leaves Lesson unpublished');
select is((select count(*)::integer from public.audit_events where action = 'lesson.publish' and target_id = '80000000-0000-4000-8000-000000000001'), 0, 'Failed publication leaves no audit row');
drop trigger lesson_test_reject_publish_audit on public.audit_events;
drop function public.lesson_test_reject_publish_audit();
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select is(public.teacher_publish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002'), '80000000-0000-4000-8000-000000000001'::uuid, 'Worker RPC publishes a draft for its verified assigned Teacher');
select is((select status from public.lessons where id = '80000000-0000-4000-8000-000000000001'), 'published', 'Publication state commits in the lifecycle transaction');
select is((select count(*)::integer from public.audit_events where action = 'lesson.publish' and target_id = '80000000-0000-4000-8000-000000000001'), 1, 'Publication and audit event commit together');
select is(public.teacher_publish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002'), '80000000-0000-4000-8000-000000000001'::uuid, 'Publication retry returns the canonical Lesson');
select is((select count(*)::integer from public.audit_events where action = 'lesson.publish' and target_id = '80000000-0000-4000-8000-000000000001'), 1, 'Publication retry does not duplicate its audit event');
select is(public.teacher_unpublish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002'), '80000000-0000-4000-8000-000000000001'::uuid, 'Worker RPC returns a published Lesson to draft');
select is((select count(*)::integer from public.audit_events where action = 'lesson.unpublish' and target_id = '80000000-0000-4000-8000-000000000001'), 1, 'Unpublish is durably audited');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons where id = '80000000-0000-4000-8000-000000000001'), 0, 'Unpublish immediately removes Student access');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000002', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
update public.lesson_blocks set payload = '{"text":"Updated after unpublish.","level":2}' where id = '90000000-0000-4000-8000-000000000001';
select is((select payload ->> 'text' from public.lesson_blocks where id = '90000000-0000-4000-8000-000000000001'), 'Updated after unpublish.', 'Teacher can edit content after explicitly unpublishing');
reset role;
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select is(public.teacher_publish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002'), '80000000-0000-4000-8000-000000000001'::uuid, 'Unpublished Lesson can be republished');
select is((select count(*)::integer from public.audit_events where action = 'lesson.publish' and target_id = '80000000-0000-4000-8000-000000000001'), 2, 'Republishing writes one new publication audit event');
select is(public.teacher_archive_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002'), '80000000-0000-4000-8000-000000000001'::uuid, 'Worker RPC archives a Lesson');
select is((select status from public.lessons where id = '80000000-0000-4000-8000-000000000001'), 'archived', 'Archived Lesson is removed from Student visibility');
select is((select count(*)::integer from public.audit_events where action = 'lesson.archive' and target_id = '80000000-0000-4000-8000-000000000001'), 1, 'Archive is durably audited');
select is(public.teacher_archive_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002'), '80000000-0000-4000-8000-000000000001'::uuid, 'Archive retry returns the canonical Lesson');
select is((select count(*)::integer from public.audit_events where action = 'lesson.archive' and target_id = '80000000-0000-4000-8000-000000000001'), 1, 'Archive retry does not duplicate its audit event');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000004', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated"}', true);
select is((select count(*)::integer from public.lessons where id = '80000000-0000-4000-8000-000000000001'), 0, 'Archived Lesson is no longer Student-visible');
reset role;
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select throws_ok($$select public.teacher_publish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000002')$$, '23514', 'Only a draft Lesson can be published', 'Archived Lesson cannot be republished');
select throws_ok($$select public.teacher_publish_lesson('80000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000002')$$, '23514', 'A Lesson needs at least one content block before publication', 'Empty Lesson publication is rejected before state change');
select is((select status from public.lessons where id = '80000000-0000-4000-8000-000000000004'), 'draft', 'Rejected empty publication leaves the Lesson in draft');
select throws_ok($$select public.teacher_publish_lesson('80000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001')$$, '42501', 'active assigned Teacher membership required', 'Worker RPC rechecks actor role and assignment');
select is((select count(*)::integer from public.audit_events where target_id = '80000000-0000-4000-8000-000000000001' and action in ('lesson.publish', 'lesson.unpublish', 'lesson.archive')), 4, 'Rejected or idempotent lifecycle calls do not create false audit events');
reset role;

select * from finish();
rollback;
