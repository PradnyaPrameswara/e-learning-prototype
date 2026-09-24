-- Identity and academic structure. Schema ownership remains in this migration stream.
create schema if not exists private;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create type public.school_role as enum ('student', 'teacher', 'admin');
grant usage on type public.school_role to authenticated, service_role;

create table public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null check (name = btrim(name) and char_length(name) between 1 and 160),
  status text not null default 'active' check (status in ('active', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete restrict,
  display_name text check (display_name is null or (display_name = btrim(display_name) and char_length(display_name) between 1 and 120)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.school_memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  user_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'active' check (status in ('active', 'disabled')),
  joined_at timestamptz not null default now(),
  disabled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'active' and disabled_at is null) or (status = 'disabled' and disabled_at is not null)),
  unique (school_id, user_id),
  unique (school_id, id)
);

create table public.membership_roles (
  school_id uuid not null,
  membership_id uuid not null,
  role public.school_role not null,
  status text not null default 'active' check (status in ('active', 'revoked')),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'active' and revoked_at is null) or (status = 'revoked' and revoked_at is not null)),
  primary key (school_id, membership_id, role),
  foreign key (school_id, membership_id)
    references public.school_memberships(school_id, id) on delete restrict
);

create table public.academic_years (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  label text not null check (label = btrim(label) and char_length(label) between 1 and 80),
  starts_on date not null,
  ends_on date not null,
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_on >= starts_on),
  unique (school_id, label),
  unique (school_id, id)
);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  name text not null check (name = btrim(name) and char_length(name) between 1 and 100),
  grade_level text check (grade_level is null or (grade_level = btrim(grade_level) and char_length(grade_level) between 1 and 40)),
  section text check (section is null or (section = btrim(section) and char_length(section) between 1 and 40)),
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, name),
  unique (school_id, id)
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  name text not null check (name = btrim(name) and char_length(name) between 1 and 100),
  code text check (code is null or (code = btrim(code) and char_length(code) between 1 and 32)),
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (school_id, id)
);

create unique index subjects_school_name_unique on public.subjects (school_id, lower(name));
create unique index subjects_school_code_unique on public.subjects (school_id, upper(code)) where code is not null;

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  academic_year_id uuid not null,
  class_id uuid not null,
  subject_id uuid not null,
  title text not null check (title = btrim(title) and char_length(title) between 1 and 160),
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (school_id, academic_year_id)
    references public.academic_years(school_id, id) on delete restrict,
  foreign key (school_id, class_id)
    references public.classes(school_id, id) on delete restrict,
  foreign key (school_id, subject_id)
    references public.subjects(school_id, id) on delete restrict,
  unique (school_id, academic_year_id, class_id, subject_id),
  unique (school_id, id)
);

create table public.teacher_assignments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  course_id uuid not null,
  teacher_membership_id uuid not null,
  assigned_by uuid not null,
  status text not null default 'active' check (status in ('active', 'revoked')),
  assigned_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'active' and revoked_at is null) or (status = 'revoked' and revoked_at is not null)),
  foreign key (school_id, course_id)
    references public.courses(school_id, id) on delete restrict,
  foreign key (school_id, teacher_membership_id)
    references public.school_memberships(school_id, id) on delete restrict,
  foreign key (school_id, assigned_by)
    references public.school_memberships(school_id, id) on delete restrict,
  unique (school_id, id)
);

create unique index teacher_assignments_one_active_unique
  on public.teacher_assignments (course_id, teacher_membership_id)
  where status = 'active';

create table public.student_enrollments (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  academic_year_id uuid not null,
  class_id uuid not null,
  student_membership_id uuid not null,
  enrolled_by uuid not null,
  status text not null default 'active' check (status in ('active', 'unenrolled')),
  enrolled_at timestamptz not null default now(),
  unenrolled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'active' and unenrolled_at is null) or (status = 'unenrolled' and unenrolled_at is not null)),
  foreign key (school_id, academic_year_id)
    references public.academic_years(school_id, id) on delete restrict,
  foreign key (school_id, class_id)
    references public.classes(school_id, id) on delete restrict,
  foreign key (school_id, student_membership_id)
    references public.school_memberships(school_id, id) on delete restrict,
  foreign key (school_id, enrolled_by)
    references public.school_memberships(school_id, id) on delete restrict,
  unique (school_id, id)
);

create unique index student_enrollments_one_active_year_unique
  on public.student_enrollments (school_id, academic_year_id, student_membership_id)
  where status = 'active';

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  actor_role public.school_role not null,
  action text not null check (action in (
    'membership.role.grant', 'membership.role.revoke', 'user.disable', 'user.reactivate',
    'academic_year.create', 'class.create', 'subject.create', 'course.create',
    'teacher.assign', 'teacher.unassign', 'student.enroll', 'student.unenroll'
  )),
  target_type text not null,
  target_id uuid not null,
  before_summary jsonb,
  after_summary jsonb,
  reason text,
  request_id uuid,
  created_at timestamptz not null default now()
);

create index school_memberships_user_status_idx
  on public.school_memberships (user_id, status, school_id);
create index membership_roles_active_lookup_idx
  on public.membership_roles (school_id, role, status, membership_id);
create index academic_years_school_status_idx
  on public.academic_years (school_id, status);
create index classes_school_status_idx
  on public.classes (school_id, status);
create index courses_school_year_class_idx
  on public.courses (school_id, academic_year_id, class_id, status);
create index courses_school_subject_idx
  on public.courses (school_id, subject_id, status);
create index teacher_assignments_teacher_status_idx
  on public.teacher_assignments (school_id, teacher_membership_id, status, course_id);
create index student_enrollments_student_status_idx
  on public.student_enrollments (school_id, student_membership_id, status, academic_year_id);
create index student_enrollments_class_status_idx
  on public.student_enrollments (school_id, class_id, academic_year_id, status);
create index audit_events_school_created_idx
  on public.audit_events (school_id, created_at desc);
create index audit_events_target_created_idx
  on public.audit_events (target_type, target_id, created_at desc);

create function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create function private.ensure_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

insert into public.profiles (id)
select users.id from auth.users as users
on conflict (id) do nothing;

create trigger auth_user_profile_after_insert
  after insert on auth.users
  for each row execute function private.ensure_profile_for_auth_user();

create trigger schools_touch_updated_at before update on public.schools
  for each row execute function private.touch_updated_at();
create trigger profiles_touch_updated_at before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger memberships_touch_updated_at before update on public.school_memberships
  for each row execute function private.touch_updated_at();
create trigger membership_roles_touch_updated_at before update on public.membership_roles
  for each row execute function private.touch_updated_at();
create trigger academic_years_touch_updated_at before update on public.academic_years
  for each row execute function private.touch_updated_at();
create trigger classes_touch_updated_at before update on public.classes
  for each row execute function private.touch_updated_at();
create trigger subjects_touch_updated_at before update on public.subjects
  for each row execute function private.touch_updated_at();
create trigger courses_touch_updated_at before update on public.courses
  for each row execute function private.touch_updated_at();
create trigger teacher_assignments_touch_updated_at before update on public.teacher_assignments
  for each row execute function private.touch_updated_at();
create trigger student_enrollments_touch_updated_at before update on public.student_enrollments
  for each row execute function private.touch_updated_at();

create function private.has_active_school_role(p_school_id uuid, p_role public.school_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.school_memberships as membership
    join public.membership_roles as role
      on role.school_id = membership.school_id and role.membership_id = membership.id
    where membership.school_id = p_school_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and exists (select 1 from public.schools as school where school.id = membership.school_id and school.status = 'active')
      and role.role = p_role
      and role.status = 'active'
      and exists (select 1 from public.schools as school where school.id = membership.school_id and school.status = 'active')
  );
$$;

create function private.has_active_school_membership(p_school_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.school_memberships as membership
    join public.membership_roles as role
      on role.school_id = membership.school_id and role.membership_id = membership.id
    where membership.school_id = p_school_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and role.status = 'active'
      and exists (select 1 from public.schools as school where school.id = membership.school_id and school.status = 'active')
  );
$$;

create function private.membership_has_active_role(
  p_school_id uuid,
  p_membership_id uuid,
  p_role public.school_role
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.school_memberships as membership
    join public.membership_roles as role
      on role.school_id = membership.school_id and role.membership_id = membership.id
    where membership.school_id = p_school_id
      and membership.id = p_membership_id
      and membership.status = 'active'
      and role.role = p_role
      and role.status = 'active'
      and exists (select 1 from public.schools as school where school.id = membership.school_id and school.status = 'active')
  );
$$;

create function private.current_user_has_membership_role(
  p_school_id uuid,
  p_membership_id uuid,
  p_role public.school_role
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.school_memberships as membership
    join public.membership_roles as role
      on role.school_id = membership.school_id and role.membership_id = membership.id
    where membership.school_id = p_school_id
      and membership.id = p_membership_id
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and exists (select 1 from public.schools as school where school.id = membership.school_id and school.status = 'active')
      and role.role = p_role
      and role.status = 'active'
  );
$$;

create function private.is_assigned_teacher(p_school_id uuid, p_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.teacher_assignments as assignment
    join public.school_memberships as membership
      on membership.school_id = assignment.school_id and membership.id = assignment.teacher_membership_id
    join public.membership_roles as role
      on role.school_id = membership.school_id and role.membership_id = membership.id
    join public.courses as course
      on course.school_id = assignment.school_id and course.id = assignment.course_id
    join public.academic_years as year
      on year.school_id = course.school_id and year.id = course.academic_year_id
    join public.classes as class_record
      on class_record.school_id = course.school_id and class_record.id = course.class_id
    join public.subjects as subject
      on subject.school_id = course.school_id and subject.id = course.subject_id
    where assignment.school_id = p_school_id
      and assignment.course_id = p_course_id
      and assignment.status = 'active'
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and exists (select 1 from public.schools as school where school.id = membership.school_id and school.status = 'active')
      and role.role = 'teacher'
      and role.status = 'active'
      and course.status = 'active'
      and year.status = 'active'
      and class_record.status = 'active'
      and subject.status = 'active'
  );
$$;

create function private.is_enrolled_student(p_school_id uuid, p_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.student_enrollments as enrollment
    join public.school_memberships as membership
      on membership.school_id = enrollment.school_id and membership.id = enrollment.student_membership_id
    join public.membership_roles as role
      on role.school_id = membership.school_id and role.membership_id = membership.id
    join public.courses as course
      on course.school_id = enrollment.school_id
      and course.academic_year_id = enrollment.academic_year_id
      and course.class_id = enrollment.class_id
      and course.id = p_course_id
    join public.academic_years as year
      on year.school_id = course.school_id and year.id = course.academic_year_id
    join public.classes as class_record
      on class_record.school_id = course.school_id and class_record.id = course.class_id
    join public.subjects as subject
      on subject.school_id = course.school_id and subject.id = course.subject_id
    where enrollment.school_id = p_school_id
      and course.school_id = p_school_id
      and enrollment.status = 'active'
      and membership.user_id = (select auth.uid())
      and membership.status = 'active'
      and role.role = 'student'
      and role.status = 'active'
      and exists (select 1 from public.schools as school where school.id = membership.school_id and school.status = 'active')
      and course.status = 'active'
      and year.status = 'active'
      and class_record.status = 'active'
      and subject.status = 'active'
  );
$$;

create function private.can_read_academic_year(p_school_id uuid, p_academic_year_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_school_role(p_school_id, 'admin')
    or exists (
      select 1
      from public.courses as course
      where course.school_id = p_school_id
        and course.academic_year_id = p_academic_year_id
        and (private.is_assigned_teacher(p_school_id, course.id)
          or private.is_enrolled_student(p_school_id, course.id))
    )
    or exists (
      select 1
      from public.student_enrollments as enrollment
      join public.school_memberships as membership
        on membership.school_id = enrollment.school_id and membership.id = enrollment.student_membership_id
      where enrollment.school_id = p_school_id
        and enrollment.academic_year_id = p_academic_year_id
        and enrollment.status = 'active'
        and membership.user_id = (select auth.uid())
        and membership.status = 'active'
        and private.membership_has_active_role(p_school_id, membership.id, 'student')
    );
$$;

create function private.can_read_class(p_school_id uuid, p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_school_role(p_school_id, 'admin')
    or exists (
      select 1
      from public.student_enrollments as enrollment
      join public.school_memberships as membership
        on membership.school_id = enrollment.school_id and membership.id = enrollment.student_membership_id
      where enrollment.school_id = p_school_id
        and enrollment.class_id = p_class_id
        and enrollment.status = 'active'
        and membership.user_id = (select auth.uid())
        and membership.status = 'active'
        and private.membership_has_active_role(p_school_id, membership.id, 'student')
    )
    or exists (
      select 1
      from public.courses as course
      where course.school_id = p_school_id
        and course.class_id = p_class_id
        and private.is_assigned_teacher(p_school_id, course.id)
    );
$$;

create function private.can_read_subject(p_school_id uuid, p_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.has_active_school_role(p_school_id, 'admin')
    or exists (
      select 1
      from public.courses as course
      where course.school_id = p_school_id
        and course.subject_id = p_subject_id
        and (private.is_assigned_teacher(p_school_id, course.id)
          or private.is_enrolled_student(p_school_id, course.id))
    );
$$;

create function private.require_school_admin(p_school_id uuid, p_actor_user_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_membership_id uuid;
begin
  select membership.id
    into v_membership_id
  from public.school_memberships as membership
  join public.membership_roles as role
    on role.school_id = membership.school_id and role.membership_id = membership.id
  where membership.school_id = p_school_id
    and membership.user_id = p_actor_user_id
    and membership.status = 'active'
    and exists (select 1 from public.schools as school where school.id = membership.school_id and school.status = 'active')
    and role.role = 'admin'
    and role.status = 'active'
  limit 1;

  if v_membership_id is null then
    raise exception 'active school administrator membership required' using errcode = '42501';
  end if;

  return v_membership_id;
end;
$$;

create function private.record_admin_audit(
  p_school_id uuid,
  p_actor_user_id uuid,
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_before_summary jsonb,
  p_after_summary jsonb,
  p_request_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_events (
    school_id, actor_user_id, actor_role, action, target_type, target_id,
    before_summary, after_summary, request_id
  ) values (
    p_school_id, p_actor_user_id, 'admin', p_action, p_target_type, p_target_id,
    p_before_summary, p_after_summary, p_request_id
  );
$$;

create function public.admin_create_academic_year(
  p_school_id uuid, p_actor_user_id uuid, p_label text, p_starts_on date, p_ends_on date,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_id uuid;
begin
  perform private.require_school_admin(p_school_id, v_actor);
  if p_label is null or p_label <> btrim(p_label) or char_length(p_label) not between 1 and 80
     or p_starts_on is null or p_ends_on is null or p_ends_on < p_starts_on then
    raise exception 'invalid academic year values' using errcode = '22023';
  end if;

  insert into public.academic_years (school_id, label, starts_on, ends_on)
  values (p_school_id, p_label, p_starts_on, p_ends_on)
  returning id into v_id;

  perform private.record_admin_audit(p_school_id, v_actor, 'academic_year.create', 'academic_year', v_id,
    null, jsonb_build_object('label', p_label, 'starts_on', p_starts_on, 'ends_on', p_ends_on), p_request_id);
  return v_id;
end;
$$;

create function public.admin_create_class(
  p_school_id uuid, p_actor_user_id uuid, p_name text, p_grade_level text default null,
  p_section text default null, p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_id uuid;
begin
  perform private.require_school_admin(p_school_id, v_actor);
  if p_name is null or p_name <> btrim(p_name) or char_length(p_name) not between 1 and 100 then
    raise exception 'invalid class name' using errcode = '22023';
  end if;
  if p_grade_level is not null and (p_grade_level <> btrim(p_grade_level) or char_length(p_grade_level) not between 1 and 40) then
    raise exception 'invalid grade level' using errcode = '22023';
  end if;
  if p_section is not null and (p_section <> btrim(p_section) or char_length(p_section) not between 1 and 40) then
    raise exception 'invalid class section' using errcode = '22023';
  end if;

  insert into public.classes (school_id, name, grade_level, section)
  values (p_school_id, p_name, p_grade_level, p_section)
  returning id into v_id;

  perform private.record_admin_audit(p_school_id, v_actor, 'class.create', 'class', v_id,
    null, jsonb_build_object('name', p_name, 'grade_level', p_grade_level, 'section', p_section), p_request_id);
  return v_id;
end;
$$;

create function public.admin_create_subject(
  p_school_id uuid, p_actor_user_id uuid, p_name text, p_code text default null,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_id uuid;
  v_code text := nullif(upper(btrim(p_code)), '');
begin
  perform private.require_school_admin(p_school_id, v_actor);
  if p_name is null or p_name <> btrim(p_name) or char_length(p_name) not between 1 and 100 then
    raise exception 'invalid subject name' using errcode = '22023';
  end if;
  if v_code is not null and char_length(v_code) > 32 then
    raise exception 'invalid subject code' using errcode = '22023';
  end if;

  insert into public.subjects (school_id, name, code)
  values (p_school_id, p_name, v_code)
  returning id into v_id;

  perform private.record_admin_audit(p_school_id, v_actor, 'subject.create', 'subject', v_id,
    null, jsonb_build_object('name', p_name, 'code', v_code), p_request_id);
  return v_id;
end;
$$;

create function public.admin_create_course(
  p_school_id uuid,
  p_actor_user_id uuid,
  p_academic_year_id uuid,
  p_class_id uuid,
  p_subject_id uuid,
  p_title text,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_id uuid;
begin
  perform private.require_school_admin(p_school_id, v_actor);
  if p_title is null or p_title <> btrim(p_title) or char_length(p_title) not between 1 and 160 then
    raise exception 'invalid course title' using errcode = '22023';
  end if;
  if not exists (select 1 from public.academic_years as year
      where year.school_id = p_school_id and year.id = p_academic_year_id and year.status = 'active')
     or not exists (select 1 from public.classes as class_record
      where class_record.school_id = p_school_id and class_record.id = p_class_id and class_record.status = 'active')
     or not exists (select 1 from public.subjects as subject
      where subject.school_id = p_school_id and subject.id = p_subject_id and subject.status = 'active') then
    raise exception 'active school academic year, class, and subject required' using errcode = '23514';
  end if;

  insert into public.courses (school_id, academic_year_id, class_id, subject_id, title)
  values (p_school_id, p_academic_year_id, p_class_id, p_subject_id, p_title)
  returning id into v_id;

  perform private.record_admin_audit(p_school_id, v_actor, 'course.create', 'course', v_id,
    null, jsonb_build_object('academic_year_id', p_academic_year_id, 'class_id', p_class_id,
      'subject_id', p_subject_id, 'title', p_title), p_request_id);
  return v_id;
end;
$$;

create function public.admin_set_membership_role(
  p_school_id uuid,
  p_actor_user_id uuid,
  p_user_id uuid,
  p_role public.school_role,
  p_status text default 'active',
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_membership_id uuid;
  v_membership_status text;
  v_old_status text;
  v_rows integer;
begin
  perform private.require_school_admin(p_school_id, v_actor);
  -- Serialize administrator removal so concurrent changes cannot remove the final Admin.
  perform 1 from public.schools as school where school.id = p_school_id for update;
  perform private.require_school_admin(p_school_id, v_actor);
  if p_status not in ('active', 'revoked') then
    raise exception 'invalid membership role status' using errcode = '22023';
  end if;

  if p_status = 'active' then
    insert into public.school_memberships (school_id, user_id)
    values (p_school_id, p_user_id)
    on conflict (school_id, user_id) do nothing;
  end if;

  select membership.id, membership.status
    into v_membership_id, v_membership_status
  from public.school_memberships as membership
  where membership.school_id = p_school_id and membership.user_id = p_user_id
  for update;

  if v_membership_id is null then
    raise exception 'membership target not found' using errcode = 'P0002';
  end if;
  if v_membership_status <> 'active' and p_status = 'active' then
    raise exception 'disabled membership must be explicitly reactivated first' using errcode = '42501';
  end if;

  if p_role = 'admin' and p_status = 'revoked'
     and exists (select 1 from public.membership_roles as role
       where role.school_id = p_school_id and role.membership_id = v_membership_id
         and role.role = 'admin' and role.status = 'active')
     and (select count(*) from public.school_memberships as membership
       join public.membership_roles as role
         on role.school_id = membership.school_id and role.membership_id = membership.id
       where membership.school_id = p_school_id and membership.status = 'active'
         and role.role = 'admin' and role.status = 'active') <= 1 then
    raise exception 'the final active school administrator cannot be removed' using errcode = '23514';
  end if;

  select role.status into v_old_status
  from public.membership_roles as role
  where role.school_id = p_school_id and role.membership_id = v_membership_id and role.role = p_role;

  insert into public.membership_roles (school_id, membership_id, role, status)
  values (p_school_id, v_membership_id, p_role, p_status)
  on conflict (school_id, membership_id, role) do update
    set status = excluded.status,
        granted_at = case when excluded.status = 'active' then now() else public.membership_roles.granted_at end,
        revoked_at = case when excluded.status = 'revoked' then now() else null end
    where public.membership_roles.status is distinct from excluded.status;

  get diagnostics v_rows = row_count;
  if v_rows > 0 then
    perform private.record_admin_audit(p_school_id, v_actor,
      case when p_status = 'active' then 'membership.role.grant' else 'membership.role.revoke' end,
      'school_membership', v_membership_id,
      case when v_old_status is null then null else jsonb_build_object('role', p_role, 'status', v_old_status) end,
      jsonb_build_object('role', p_role, 'status', p_status), p_request_id);
  end if;
  return v_membership_id;
end;
$$;

create function public.admin_set_membership_status(
  p_school_id uuid,
  p_actor_user_id uuid,
  p_membership_id uuid,
  p_status text,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_old_status text;
begin
  perform private.require_school_admin(p_school_id, v_actor);
  -- Share the same school-row lock as role changes to protect the final Admin invariant.
  perform 1 from public.schools as school where school.id = p_school_id for update;
  perform private.require_school_admin(p_school_id, v_actor);
  if p_status not in ('active', 'disabled') then
    raise exception 'invalid membership status' using errcode = '22023';
  end if;

  select membership.status into v_old_status
  from public.school_memberships as membership
  where membership.school_id = p_school_id and membership.id = p_membership_id
  for update;
  if v_old_status is null then
    raise exception 'membership target not found' using errcode = 'P0002';
  end if;

  if p_status = 'disabled'
     and exists (select 1 from public.membership_roles as role
       where role.school_id = p_school_id and role.membership_id = p_membership_id
         and role.role = 'admin' and role.status = 'active')
     and (select count(*) from public.school_memberships as membership
       join public.membership_roles as role
         on role.school_id = membership.school_id and role.membership_id = membership.id
       where membership.school_id = p_school_id and membership.status = 'active'
         and role.role = 'admin' and role.status = 'active') <= 1 then
    raise exception 'the final active school administrator cannot be disabled' using errcode = '23514';
  end if;

  if v_old_status is distinct from p_status then
    update public.school_memberships as membership
      set status = p_status,
          disabled_at = case when p_status = 'disabled' then now() else null end
    where membership.school_id = p_school_id and membership.id = p_membership_id;

    perform private.record_admin_audit(p_school_id, v_actor,
      case when p_status = 'disabled' then 'user.disable' else 'user.reactivate' end,
      'school_membership', p_membership_id,
      jsonb_build_object('status', v_old_status), jsonb_build_object('status', p_status), p_request_id);
  end if;
  return p_membership_id;
end;
$$;

create function public.admin_assign_teacher(
  p_school_id uuid,
  p_actor_user_id uuid,
  p_course_id uuid,
  p_teacher_membership_id uuid,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_actor_membership uuid;
  v_assignment_id uuid;
begin
  v_actor_membership := private.require_school_admin(p_school_id, v_actor);
  if not private.membership_has_active_role(p_school_id, p_teacher_membership_id, 'teacher') then
    raise exception 'active Teacher membership in this school required' using errcode = '23514';
  end if;

  select assignment.id into v_assignment_id
  from public.teacher_assignments as assignment
  where assignment.school_id = p_school_id and assignment.course_id = p_course_id
    and assignment.teacher_membership_id = p_teacher_membership_id and assignment.status = 'active';
  if v_assignment_id is not null then
    return v_assignment_id;
  end if;

  insert into public.teacher_assignments (school_id, course_id, teacher_membership_id, assigned_by)
  values (p_school_id, p_course_id, p_teacher_membership_id, v_actor_membership)
  returning id into v_assignment_id;

  perform private.record_admin_audit(p_school_id, v_actor, 'teacher.assign', 'teacher_assignment', v_assignment_id,
    null, jsonb_build_object('course_id', p_course_id, 'teacher_membership_id', p_teacher_membership_id), p_request_id);
  return v_assignment_id;
exception
  when unique_violation then
    select assignment.id into v_assignment_id
    from public.teacher_assignments as assignment
    where assignment.school_id = p_school_id and assignment.course_id = p_course_id
      and assignment.teacher_membership_id = p_teacher_membership_id and assignment.status = 'active';
    if v_assignment_id is not null then return v_assignment_id; end if;
    raise;
end;
$$;

create function public.admin_revoke_teacher_assignment(
  p_school_id uuid, p_actor_user_id uuid, p_assignment_id uuid, p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_course_id uuid;
  v_teacher_membership_id uuid;
  v_status text;
begin
  perform private.require_school_admin(p_school_id, v_actor);
  select assignment.course_id, assignment.teacher_membership_id, assignment.status
    into v_course_id, v_teacher_membership_id, v_status
  from public.teacher_assignments as assignment
  where assignment.school_id = p_school_id and assignment.id = p_assignment_id
  for update;
  if v_status is null then raise exception 'assignment not found' using errcode = 'P0002'; end if;
  if v_status = 'active' then
    update public.teacher_assignments as assignment
      set status = 'revoked', revoked_at = now()
    where assignment.school_id = p_school_id and assignment.id = p_assignment_id;
    perform private.record_admin_audit(p_school_id, v_actor, 'teacher.unassign', 'teacher_assignment', p_assignment_id,
      jsonb_build_object('course_id', v_course_id, 'teacher_membership_id', v_teacher_membership_id, 'status', 'active'),
      jsonb_build_object('status', 'revoked'), p_request_id);
  end if;
  return p_assignment_id;
end;
$$;

create function public.admin_enroll_student(
  p_school_id uuid,
  p_actor_user_id uuid,
  p_academic_year_id uuid,
  p_class_id uuid,
  p_student_membership_id uuid,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_actor_membership uuid;
  v_enrollment_id uuid;
  v_class_id uuid;
begin
  v_actor_membership := private.require_school_admin(p_school_id, v_actor);
  if not private.membership_has_active_role(p_school_id, p_student_membership_id, 'student') then
    raise exception 'active Student membership in this school required' using errcode = '23514';
  end if;
  if not exists (select 1 from public.academic_years as year
    where year.school_id = p_school_id and year.id = p_academic_year_id and year.status = 'active')
    or not exists (select 1 from public.classes as class
    where class.school_id = p_school_id and class.id = p_class_id and class.status = 'active') then
    raise exception 'active school academic year and class required' using errcode = '23514';
  end if;

  select enrollment.id, enrollment.class_id into v_enrollment_id, v_class_id
  from public.student_enrollments as enrollment
  where enrollment.school_id = p_school_id and enrollment.academic_year_id = p_academic_year_id
    and enrollment.student_membership_id = p_student_membership_id and enrollment.status = 'active';
  if v_enrollment_id is not null then
    if v_class_id = p_class_id then return v_enrollment_id; end if;
    raise exception 'Student already has an active class enrollment for this academic year' using errcode = '23514';
  end if;

  insert into public.student_enrollments (
    school_id, academic_year_id, class_id, student_membership_id, enrolled_by
  ) values (
    p_school_id, p_academic_year_id, p_class_id, p_student_membership_id, v_actor_membership
  ) returning id into v_enrollment_id;

  perform private.record_admin_audit(p_school_id, v_actor, 'student.enroll', 'student_enrollment', v_enrollment_id,
    null, jsonb_build_object('academic_year_id', p_academic_year_id, 'class_id', p_class_id,
      'student_membership_id', p_student_membership_id), p_request_id);
  return v_enrollment_id;
exception
  when unique_violation then
    select enrollment.id, enrollment.class_id into v_enrollment_id, v_class_id
    from public.student_enrollments as enrollment
    where enrollment.school_id = p_school_id and enrollment.academic_year_id = p_academic_year_id
      and enrollment.student_membership_id = p_student_membership_id and enrollment.status = 'active';
    if v_class_id = p_class_id then return v_enrollment_id; end if;
    raise exception 'Student already has an active class enrollment for this academic year' using errcode = '23514';
end;
$$;

create function public.admin_unenroll_student(
  p_school_id uuid, p_actor_user_id uuid, p_enrollment_id uuid, p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := p_actor_user_id;
  v_student_membership_id uuid;
  v_status text;
begin
  perform private.require_school_admin(p_school_id, v_actor);
  select enrollment.student_membership_id, enrollment.status
    into v_student_membership_id, v_status
  from public.student_enrollments as enrollment
  where enrollment.school_id = p_school_id and enrollment.id = p_enrollment_id
  for update;
  if v_status is null then raise exception 'enrollment not found' using errcode = 'P0002'; end if;
  if v_status = 'active' then
    update public.student_enrollments as enrollment
      set status = 'unenrolled', unenrolled_at = now()
    where enrollment.school_id = p_school_id and enrollment.id = p_enrollment_id;
    perform private.record_admin_audit(p_school_id, v_actor, 'student.unenroll', 'student_enrollment', p_enrollment_id,
      jsonb_build_object('student_membership_id', v_student_membership_id, 'status', 'active'),
      jsonb_build_object('status', 'unenrolled'), p_request_id);
  end if;
  return p_enrollment_id;
end;
$$;

alter table public.schools enable row level security;
alter table public.profiles enable row level security;
alter table public.school_memberships enable row level security;
alter table public.membership_roles enable row level security;
alter table public.academic_years enable row level security;
alter table public.classes enable row level security;
alter table public.subjects enable row level security;
alter table public.courses enable row level security;
alter table public.teacher_assignments enable row level security;
alter table public.student_enrollments enable row level security;
alter table public.audit_events enable row level security;

create policy schools_select_member on public.schools
  for select to authenticated using (private.has_active_school_membership(id));
create policy profiles_select_self_or_school_admin on public.profiles
  for select to authenticated using (
    id = (select auth.uid())
    or exists (
      select 1 from public.school_memberships as target
      where target.user_id = profiles.id and private.has_active_school_role(target.school_id, 'admin')
    )
  );
create policy profiles_update_self on public.profiles
  for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy memberships_select_self_or_admin on public.school_memberships
  for select to authenticated using (
    (user_id = (select auth.uid()) and status = 'active' and private.has_active_school_membership(school_id))
    or private.has_active_school_role(school_id, 'admin')
  );
create policy membership_roles_select_self_or_admin on public.membership_roles
  for select to authenticated using (
    private.has_active_school_role(school_id, 'admin')
    or (status = 'active' and exists (
      select 1 from public.school_memberships as membership
      where membership.school_id = membership_roles.school_id
        and membership.id = membership_roles.membership_id
        and membership.user_id = (select auth.uid()) and membership.status = 'active'
    ) and private.has_active_school_membership(school_id))
  );
create policy academic_years_select_scope on public.academic_years
  for select to authenticated using (private.can_read_academic_year(school_id, id));
create policy classes_select_scope on public.classes
  for select to authenticated using (private.can_read_class(school_id, id));
create policy subjects_select_scope on public.subjects
  for select to authenticated using (private.can_read_subject(school_id, id));
create policy courses_select_scope on public.courses
  for select to authenticated using (
    private.has_active_school_role(school_id, 'admin')
    or private.is_assigned_teacher(school_id, id)
    or private.is_enrolled_student(school_id, id)
  );
create policy teacher_assignments_select_scope on public.teacher_assignments
  for select to authenticated using (
    private.has_active_school_role(school_id, 'admin')
    or (status = 'active' and private.current_user_has_membership_role(school_id, teacher_membership_id, 'teacher')
      and exists (
        select 1 from public.school_memberships as membership
        where membership.school_id = teacher_assignments.school_id
          and membership.id = teacher_assignments.teacher_membership_id
          and membership.user_id = (select auth.uid())
      ))
  );
create policy student_enrollments_select_scope on public.student_enrollments
  for select to authenticated using (
    private.has_active_school_role(school_id, 'admin')
    or (status = 'active' and exists (
      select 1 from public.school_memberships as membership
      where membership.school_id = student_enrollments.school_id
        and membership.id = student_enrollments.student_membership_id
        and membership.user_id = (select auth.uid()) and membership.status = 'active'
    ) and private.current_user_has_membership_role(school_id, student_membership_id, 'student'))
    or exists (
      select 1 from public.courses as course
      where course.school_id = student_enrollments.school_id
        and course.academic_year_id = student_enrollments.academic_year_id
        and course.class_id = student_enrollments.class_id
        and private.is_assigned_teacher(course.school_id, course.id)
    )
  );
create policy audit_events_select_admin on public.audit_events
  for select to authenticated using (private.has_active_school_role(school_id, 'admin'));

revoke all on table public.schools, public.profiles, public.school_memberships, public.membership_roles,
  public.academic_years, public.classes, public.subjects, public.courses, public.teacher_assignments,
  public.student_enrollments, public.audit_events from anon, authenticated;

grant select on table public.schools, public.profiles, public.school_memberships, public.membership_roles,
  public.academic_years, public.classes, public.subjects, public.courses, public.teacher_assignments,
  public.student_enrollments, public.audit_events to authenticated;
grant update (display_name) on public.profiles to authenticated;

revoke all on function private.touch_updated_at() from public, anon, authenticated;
revoke all on function private.ensure_profile_for_auth_user() from public, anon, authenticated;
revoke all on function private.has_active_school_role(uuid, public.school_role) from public, anon, authenticated;
revoke all on function private.has_active_school_membership(uuid) from public, anon, authenticated;
revoke all on function private.membership_has_active_role(uuid, uuid, public.school_role) from public, anon, authenticated;
revoke all on function private.current_user_has_membership_role(uuid, uuid, public.school_role) from public, anon, authenticated;
revoke all on function private.is_assigned_teacher(uuid, uuid) from public, anon, authenticated;
revoke all on function private.is_enrolled_student(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_read_academic_year(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_read_class(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_read_subject(uuid, uuid) from public, anon, authenticated;
revoke all on function private.require_school_admin(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.record_admin_audit(uuid, uuid, text, text, uuid, jsonb, jsonb, uuid) from public, anon, authenticated;

grant execute on function private.has_active_school_role(uuid, public.school_role) to authenticated;
grant execute on function private.has_active_school_membership(uuid) to authenticated;
grant execute on function private.current_user_has_membership_role(uuid, uuid, public.school_role) to authenticated;
grant execute on function private.is_assigned_teacher(uuid, uuid) to authenticated;
grant execute on function private.is_enrolled_student(uuid, uuid) to authenticated;
grant execute on function private.can_read_academic_year(uuid, uuid) to authenticated;
grant execute on function private.can_read_class(uuid, uuid) to authenticated;
grant execute on function private.can_read_subject(uuid, uuid) to authenticated;

revoke all on function public.admin_create_academic_year(uuid, uuid, text, date, date, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_create_class(uuid, uuid, text, text, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_create_subject(uuid, uuid, text, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_create_course(uuid, uuid, uuid, uuid, uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_set_membership_role(uuid, uuid, uuid, public.school_role, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_set_membership_status(uuid, uuid, uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_assign_teacher(uuid, uuid, uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_revoke_teacher_assignment(uuid, uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_enroll_student(uuid, uuid, uuid, uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.admin_unenroll_student(uuid, uuid, uuid, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.admin_create_academic_year(uuid, uuid, text, date, date, uuid) to service_role;
grant execute on function public.admin_create_class(uuid, uuid, text, text, text, uuid) to service_role;
grant execute on function public.admin_create_subject(uuid, uuid, text, text, uuid) to service_role;
grant execute on function public.admin_create_course(uuid, uuid, uuid, uuid, uuid, text, uuid) to service_role;
grant execute on function public.admin_set_membership_role(uuid, uuid, uuid, public.school_role, text, uuid) to service_role;
grant execute on function public.admin_set_membership_status(uuid, uuid, uuid, text, uuid) to service_role;
grant execute on function public.admin_assign_teacher(uuid, uuid, uuid, uuid, uuid) to service_role;
grant execute on function public.admin_revoke_teacher_assignment(uuid, uuid, uuid, uuid) to service_role;
grant execute on function public.admin_enroll_student(uuid, uuid, uuid, uuid, uuid, uuid) to service_role;
grant execute on function public.admin_unenroll_student(uuid, uuid, uuid, uuid) to service_role;
