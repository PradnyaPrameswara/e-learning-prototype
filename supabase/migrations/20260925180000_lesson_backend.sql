-- Course-scoped Lessons and structured learning content.
-- R2 transfer flows remain a separate implementation boundary.

alter table public.audit_events
  drop constraint audit_events_action_check;

alter table public.audit_events
  add constraint audit_events_action_check check (action in (
    'membership.role.grant', 'membership.role.revoke', 'user.disable', 'user.reactivate',
    'academic_year.create', 'class.create', 'subject.create', 'course.create',
    'teacher.assign', 'teacher.unassign', 'student.enroll', 'student.unenroll',
    'lesson.publish', 'lesson.unpublish', 'lesson.archive'
  ));

create function private.lesson_block_payload_is_valid(p_block_type text, p_payload jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  if jsonb_typeof(p_payload) is distinct from 'object' then
    return false;
  end if;

  case p_block_type
    when 'heading' then
      return coalesce(
        jsonb_typeof(p_payload -> 'text') = 'string'
        and char_length(btrim(p_payload ->> 'text')) between 1 and 4000
        and jsonb_typeof(p_payload -> 'level') = 'number'
        and p_payload -> 'level' in ('2'::jsonb, '3'::jsonb, '4'::jsonb)
        and p_payload - array['text', 'level'] = '{}'::jsonb,
        false
      );
    when 'paragraph' then
      return coalesce(
        jsonb_typeof(p_payload -> 'text') = 'string'
        and char_length(btrim(p_payload ->> 'text')) between 1 and 12000
        and p_payload - array['text'] = '{}'::jsonb,
        false
      );
    when 'image' then
      return coalesce(
        jsonb_typeof(p_payload -> 'alt_text') = 'string'
        and char_length(btrim(p_payload ->> 'alt_text')) between 1 and 500
        and (
          not (p_payload ? 'caption')
          or (
            jsonb_typeof(p_payload -> 'caption') = 'string'
            and char_length(btrim(p_payload ->> 'caption')) between 1 and 2000
          )
        )
        and p_payload - array['alt_text', 'caption'] = '{}'::jsonb,
        false
      );
    when 'attachment' then
      return coalesce(
        jsonb_typeof(p_payload -> 'title') = 'string'
        and char_length(btrim(p_payload ->> 'title')) between 1 and 160
        and p_payload - array['title'] = '{}'::jsonb,
        false
      );
    when 'external_video' then
      return coalesce(
        jsonb_typeof(p_payload -> 'provider') = 'string'
        and jsonb_typeof(p_payload -> 'video_id') = 'string'
        and (
          (p_payload ->> 'provider' = 'youtube' and p_payload ->> 'video_id' ~ '^[A-Za-z0-9_-]{11}$')
          or (p_payload ->> 'provider' = 'vimeo' and p_payload ->> 'video_id' ~ '^[0-9]{1,20}$')
        )
        and p_payload - array['provider', 'video_id'] = '{}'::jsonb,
        false
      );
    when 'formula' then
      return coalesce(
        jsonb_typeof(p_payload -> 'latex') = 'string'
        and char_length(btrim(p_payload ->> 'latex')) between 1 and 4000
        and p_payload - array['latex'] = '{}'::jsonb,
        false
      );
    when 'callout' then
      return coalesce(
        p_payload ->> 'tone' in ('info', 'warning', 'definition')
        and jsonb_typeof(p_payload -> 'text') = 'string'
        and char_length(btrim(p_payload ->> 'text')) between 1 and 4000
        and (
          not (p_payload ? 'title')
          or (
            jsonb_typeof(p_payload -> 'title') = 'string'
            and char_length(btrim(p_payload ->> 'title')) between 1 and 160
          )
        )
        and p_payload - array['tone', 'text', 'title'] = '{}'::jsonb,
        false
      );
    else
      return false;
  end case;
end;
$$;

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  course_id uuid not null,
  uploader_membership_id uuid not null,
  object_key text not null unique,
  original_display_name text not null check (
    original_display_name = btrim(original_display_name)
    and char_length(original_display_name) between 1 and 255
  ),
  content_type text not null check (content_type in ('image/jpeg', 'image/png', 'image/webp', 'application/pdf')),
  byte_size bigint not null check (byte_size > 0),
  checksum text,
  purpose text not null check (purpose in ('lesson_image', 'lesson_attachment')),
  status text not null default 'pending' check (status in ('pending', 'ready', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (object_key = 'school/' || school_id::text || '/course/' || course_id::text || '/asset/' || id::text),
  check (
    (purpose = 'lesson_image' and content_type in ('image/jpeg', 'image/png', 'image/webp'))
    or (purpose = 'lesson_attachment' and content_type = 'application/pdf')
  ),
  foreign key (school_id, course_id)
    references public.courses(school_id, id) on delete restrict,
  foreign key (school_id, uploader_membership_id)
    references public.school_memberships(school_id, id) on delete restrict,
  unique (school_id, id),
  unique (school_id, course_id, id)
);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  course_id uuid not null,
  title text not null check (title = btrim(title) and char_length(title) between 1 and 160),
  position integer not null check (position >= 0),
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (status <> 'published' or published_at is not null),
  check (status <> 'draft' or published_at is null),
  foreign key (school_id, course_id)
    references public.courses(school_id, id) on delete restrict,
  unique (school_id, id),
  unique (school_id, course_id, id)
);

create unique index lessons_active_course_position_unique
  on public.lessons (course_id, position)
  where status <> 'archived';
create index lessons_school_course_status_position_idx
  on public.lessons (school_id, course_id, status, position);

create table public.lesson_blocks (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null,
  course_id uuid not null,
  lesson_id uuid not null,
  position integer not null check (position >= 0),
  block_type text not null check (block_type in (
    'heading', 'paragraph', 'image', 'attachment', 'external_video', 'formula', 'callout'
  )),
  media_asset_id uuid,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (private.lesson_block_payload_is_valid(block_type, payload)),
  check (
    (block_type in ('image', 'attachment') and media_asset_id is not null)
    or (block_type not in ('image', 'attachment') and media_asset_id is null)
  ),
  foreign key (school_id, course_id, lesson_id)
    references public.lessons(school_id, course_id, id) on delete restrict,
  foreign key (school_id, course_id, media_asset_id)
    references public.media_assets(school_id, course_id, id) on delete restrict,
  constraint lesson_blocks_lesson_position_key
    unique (lesson_id, position) deferrable initially immediate
);

create index lesson_blocks_school_course_lesson_idx
  on public.lesson_blocks (school_id, course_id, lesson_id, position);
create index media_assets_course_created_idx
  on public.media_assets (school_id, course_id, created_at desc);

create function private.validate_lesson_block_media()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_purpose text;
  v_content_type text;
  v_status text;
begin
  if new.media_asset_id is null then
    return new;
  end if;

  select asset.purpose, asset.content_type, asset.status
    into v_purpose, v_content_type, v_status
  from public.media_assets as asset
  where asset.school_id = new.school_id
    and asset.course_id = new.course_id
    and asset.id = new.media_asset_id;

  if not found then
    raise exception 'Lesson media asset not found in this Course' using errcode = '23503';
  end if;
  if v_status <> 'ready' then
    raise exception 'Lesson media asset is not ready' using errcode = '23514';
  end if;
  if new.block_type = 'image'
    and (v_purpose <> 'lesson_image' or v_content_type not in ('image/jpeg', 'image/png', 'image/webp')) then
    raise exception 'image block requires a ready image asset' using errcode = '23514';
  end if;
  if new.block_type = 'attachment'
    and (v_purpose <> 'lesson_attachment' or v_content_type <> 'application/pdf') then
    raise exception 'attachment block requires a ready PDF asset' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger lesson_blocks_validate_media
  before insert or update of school_id, course_id, lesson_id, block_type, media_asset_id
  on public.lesson_blocks
  for each row execute function private.validate_lesson_block_media();

create trigger lessons_touch_updated_at
  before update on public.lessons
  for each row execute function private.touch_updated_at();
create trigger lesson_blocks_touch_updated_at
  before update on public.lesson_blocks
  for each row execute function private.touch_updated_at();
create trigger media_assets_touch_updated_at
  before update on public.media_assets
  for each row execute function private.touch_updated_at();

create function private.guard_lesson_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id
    or new.school_id is distinct from old.school_id
    or new.course_id is distinct from old.course_id
    or new.created_at is distinct from old.created_at then
    raise exception 'Lesson identity and ownership are immutable' using errcode = '23514';
  end if;

  if old.status = 'archived' then
    raise exception 'Archived Lessons are immutable' using errcode = '23514';
  end if;
  if old.status = 'published' and new.title is distinct from old.title then
    raise exception 'Unpublish a Lesson before editing its title' using errcode = '23514';
  end if;

  if new.status is distinct from old.status then
    if old.status = 'draft' and new.status = 'published' and new.published_at is not null then
      return new;
    elsif old.status = 'published' and new.status = 'draft' and new.published_at is null then
      return new;
    elsif old.status in ('draft', 'published')
      and new.status = 'archived'
      and new.published_at is not distinct from old.published_at then
      return new;
    end if;
    raise exception 'Invalid Lesson lifecycle transition' using errcode = '23514';
  end if;

  if new.published_at is distinct from old.published_at then
    raise exception 'Published timestamp changes require a lifecycle transition' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger lessons_guard_update
  before update on public.lessons
  for each row execute function private.guard_lesson_update();

create function private.require_assigned_lesson_teacher(
  p_school_id uuid,
  p_course_id uuid,
  p_actor_user_id uuid
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_membership_id uuid;
begin
  select membership.id
    into v_membership_id
  from public.school_memberships as membership
  join public.membership_roles as membership_role
    on membership_role.school_id = membership.school_id
    and membership_role.membership_id = membership.id
  join public.teacher_assignments as assignment
    on assignment.school_id = membership.school_id
    and assignment.teacher_membership_id = membership.id
  join public.schools as school
    on school.id = membership.school_id
  join public.courses as course
    on course.school_id = assignment.school_id
    and course.id = assignment.course_id
  join public.academic_years as academic_year
    on academic_year.school_id = course.school_id
    and academic_year.id = course.academic_year_id
  join public.classes as class_record
    on class_record.school_id = course.school_id
    and class_record.id = course.class_id
  join public.subjects as subject
    on subject.school_id = course.school_id
    and subject.id = course.subject_id
  where membership.school_id = p_school_id
    and membership.user_id = p_actor_user_id
    and membership.status = 'active'
    and membership_role.role = 'teacher'
    and membership_role.status = 'active'
    and assignment.course_id = p_course_id
    and assignment.status = 'active'
    and school.status = 'active'
    and course.status = 'active'
    and academic_year.status = 'active'
    and class_record.status = 'active'
    and subject.status = 'active'
  limit 1
  for share of membership, membership_role, assignment, school, course, academic_year, class_record, subject;

  if v_membership_id is null then
    raise exception 'active assigned Teacher membership required' using errcode = '42501';
  end if;
  return v_membership_id;
end;
$$;

create function private.record_lesson_audit(
  p_school_id uuid,
  p_actor_user_id uuid,
  p_action text,
  p_lesson_id uuid,
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
    p_school_id, p_actor_user_id, 'teacher', p_action, 'lesson', p_lesson_id,
    p_before_summary, p_after_summary, p_request_id
  );
$$;

create function public.teacher_publish_lesson(
  p_lesson_id uuid,
  p_actor_user_id uuid,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lesson public.lessons%rowtype;
  v_membership_id uuid;
  v_published_at timestamptz;
begin
  select * into v_lesson
  from public.lessons as lesson
  where lesson.id = p_lesson_id
  for update;
  if not found then
    raise exception 'Lesson not found' using errcode = 'P0002';
  end if;

  v_membership_id := private.require_assigned_lesson_teacher(
    v_lesson.school_id, v_lesson.course_id, p_actor_user_id
  );
  if v_lesson.status = 'published' then
    return v_lesson.id;
  end if;
  if v_lesson.status <> 'draft' then
    raise exception 'Only a draft Lesson can be published' using errcode = '23514';
  end if;
  if not exists (
    select 1 from public.lesson_blocks as block
    where block.school_id = v_lesson.school_id
      and block.course_id = v_lesson.course_id
      and block.lesson_id = v_lesson.id
  ) then
    raise exception 'A Lesson needs at least one content block before publication' using errcode = '23514';
  end if;

  v_published_at := clock_timestamp();
  update public.lessons as lesson
    set status = 'published', published_at = v_published_at
  where lesson.id = v_lesson.id;
  perform private.record_lesson_audit(
    v_lesson.school_id, p_actor_user_id, 'lesson.publish', v_lesson.id,
    jsonb_build_object('status', 'draft'),
    jsonb_build_object('status', 'published', 'published_at', v_published_at),
    p_request_id
  );
  return v_lesson.id;
end;
$$;

create function public.teacher_unpublish_lesson(
  p_lesson_id uuid,
  p_actor_user_id uuid,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lesson public.lessons%rowtype;
  v_membership_id uuid;
begin
  select * into v_lesson
  from public.lessons as lesson
  where lesson.id = p_lesson_id
  for update;
  if not found then
    raise exception 'Lesson not found' using errcode = 'P0002';
  end if;

  v_membership_id := private.require_assigned_lesson_teacher(
    v_lesson.school_id, v_lesson.course_id, p_actor_user_id
  );
  if v_lesson.status = 'draft' then
    return v_lesson.id;
  end if;
  if v_lesson.status <> 'published' then
    raise exception 'Only a published Lesson can be unpublished' using errcode = '23514';
  end if;

  update public.lessons as lesson
    set status = 'draft', published_at = null
  where lesson.id = v_lesson.id;
  perform private.record_lesson_audit(
    v_lesson.school_id, p_actor_user_id, 'lesson.unpublish', v_lesson.id,
    jsonb_build_object('status', 'published', 'published_at', v_lesson.published_at),
    jsonb_build_object('status', 'draft'),
    p_request_id
  );
  return v_lesson.id;
end;
$$;

create function public.teacher_archive_lesson(
  p_lesson_id uuid,
  p_actor_user_id uuid,
  p_request_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lesson public.lessons%rowtype;
  v_membership_id uuid;
begin
  select * into v_lesson
  from public.lessons as lesson
  where lesson.id = p_lesson_id
  for update;
  if not found then
    raise exception 'Lesson not found' using errcode = 'P0002';
  end if;

  v_membership_id := private.require_assigned_lesson_teacher(
    v_lesson.school_id, v_lesson.course_id, p_actor_user_id
  );
  if v_lesson.status = 'archived' then
    return v_lesson.id;
  end if;

  update public.lessons as lesson
    set status = 'archived'
  where lesson.id = v_lesson.id;
  perform private.record_lesson_audit(
    v_lesson.school_id, p_actor_user_id, 'lesson.archive', v_lesson.id,
    jsonb_build_object('status', v_lesson.status, 'published_at', v_lesson.published_at),
    jsonb_build_object('status', 'archived', 'published_at', v_lesson.published_at),
    p_request_id
  );
  return v_lesson.id;
end;
$$;

create function public.reorder_lessons(p_course_id uuid, p_lesson_ids uuid[])
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_total integer;
  v_max_position integer;
  v_base_position bigint;
begin
  select course.school_id into v_school_id
  from public.courses as course
  where course.id = p_course_id;
  if not found or not private.is_assigned_teacher(v_school_id, p_course_id) then
    raise exception 'assigned Teacher access required' using errcode = '42501';
  end if;

  perform 1 from public.lessons as lesson
  where lesson.course_id = p_course_id and lesson.status <> 'archived'
  for update;
  select count(*)::integer, max(lesson.position)
    into v_total, v_max_position
  from public.lessons as lesson
  where lesson.course_id = p_course_id and lesson.status <> 'archived';

  if coalesce(cardinality(p_lesson_ids), 0) <> v_total
    or (
      select count(distinct supplied.lesson_id)::integer
      from unnest(coalesce(p_lesson_ids, '{}'::uuid[])) as supplied(lesson_id)
    ) <> v_total
    or exists (
      select 1
      from unnest(coalesce(p_lesson_ids, '{}'::uuid[])) as supplied(lesson_id)
      where not exists (
        select 1 from public.lessons as lesson
        where lesson.id = supplied.lesson_id
          and lesson.course_id = p_course_id
          and lesson.status <> 'archived'
      )
    ) then
    raise exception 'Lesson order must contain every active Lesson exactly once' using errcode = '22023';
  end if;

  if v_total = 0 then
    return 0;
  end if;
  v_base_position := coalesce(v_max_position, -1)::bigint + v_total::bigint + 1;
  update public.lessons as lesson
    set position = (v_base_position + ordered.ordinality - 1)::integer
  from unnest(p_lesson_ids) with ordinality as ordered(lesson_id, ordinality)
  where lesson.course_id = p_course_id
    and lesson.id = ordered.lesson_id;
  update public.lessons as lesson
    set position = (ordered.ordinality - 1)::integer
  from unnest(p_lesson_ids) with ordinality as ordered(lesson_id, ordinality)
  where lesson.course_id = p_course_id
    and lesson.id = ordered.lesson_id;
  return v_total;
end;
$$;

create function public.reorder_lesson_blocks(p_lesson_id uuid, p_block_ids uuid[])
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_school_id uuid;
  v_course_id uuid;
  v_status text;
  v_total integer;
begin
  select lesson.school_id, lesson.course_id, lesson.status
    into v_school_id, v_course_id, v_status
  from public.lessons as lesson
  where lesson.id = p_lesson_id
  for update;
  if not found or not private.is_assigned_teacher(v_school_id, v_course_id) then
    raise exception 'assigned Teacher access required' using errcode = '42501';
  end if;
  if v_status <> 'draft' then
    raise exception 'Only draft Lesson blocks can be reordered' using errcode = '23514';
  end if;

  select count(*)::integer into v_total
  from public.lesson_blocks as block
  where block.lesson_id = p_lesson_id;
  if coalesce(cardinality(p_block_ids), 0) <> v_total
    or (
      select count(distinct supplied.block_id)::integer
      from unnest(coalesce(p_block_ids, '{}'::uuid[])) as supplied(block_id)
    ) <> v_total
    or exists (
      select 1
      from unnest(coalesce(p_block_ids, '{}'::uuid[])) as supplied(block_id)
      where not exists (
        select 1 from public.lesson_blocks as block
        where block.id = supplied.block_id and block.lesson_id = p_lesson_id
      )
    ) then
    raise exception 'Block order must contain every Lesson block exactly once' using errcode = '22023';
  end if;

  if v_total = 0 then
    return 0;
  end if;
  set constraints public.lesson_blocks_lesson_position_key deferred;
  update public.lesson_blocks as block
    set position = (ordered.ordinality - 1)::integer
  from unnest(p_block_ids) with ordinality as ordered(block_id, ordinality)
  where block.lesson_id = p_lesson_id
    and block.id = ordered.block_id;
  set constraints public.lesson_blocks_lesson_position_key immediate;
  return v_total;
end;
$$;

alter table public.lessons enable row level security;
alter table public.lesson_blocks enable row level security;
alter table public.media_assets enable row level security;

create policy lessons_select_assigned_teacher_or_enrolled_student on public.lessons
  for select to authenticated using (
    private.is_assigned_teacher(school_id, course_id)
    or (status = 'published' and private.is_enrolled_student(school_id, course_id))
  );
create policy lessons_insert_assigned_teacher_draft on public.lessons
  for insert to authenticated with check (
    status = 'draft'
    and published_at is null
    and private.is_assigned_teacher(school_id, course_id)
  );
create policy lessons_update_assigned_teacher_non_archived on public.lessons
  for update to authenticated using (
    status <> 'archived'
    and private.is_assigned_teacher(school_id, course_id)
  ) with check (
    status <> 'archived'
    and private.is_assigned_teacher(school_id, course_id)
  );

create policy lesson_blocks_select_assigned_teacher_or_enrolled_student on public.lesson_blocks
  for select to authenticated using (
    private.is_assigned_teacher(school_id, course_id)
    or (
      private.is_enrolled_student(school_id, course_id)
      and exists (
        select 1 from public.lessons as lesson
        where lesson.school_id = lesson_blocks.school_id
          and lesson.course_id = lesson_blocks.course_id
          and lesson.id = lesson_blocks.lesson_id
          and lesson.status = 'published'
      )
    )
  );
create policy lesson_blocks_insert_assigned_teacher_draft on public.lesson_blocks
  for insert to authenticated with check (
    private.is_assigned_teacher(school_id, course_id)
    and exists (
      select 1 from public.lessons as lesson
      where lesson.school_id = lesson_blocks.school_id
        and lesson.course_id = lesson_blocks.course_id
        and lesson.id = lesson_blocks.lesson_id
        and lesson.status = 'draft'
    )
  );
create policy lesson_blocks_update_assigned_teacher_draft on public.lesson_blocks
  for update to authenticated using (
    private.is_assigned_teacher(school_id, course_id)
    and exists (
      select 1 from public.lessons as lesson
      where lesson.school_id = lesson_blocks.school_id
        and lesson.course_id = lesson_blocks.course_id
        and lesson.id = lesson_blocks.lesson_id
        and lesson.status = 'draft'
    )
  ) with check (
    private.is_assigned_teacher(school_id, course_id)
    and exists (
      select 1 from public.lessons as lesson
      where lesson.school_id = lesson_blocks.school_id
        and lesson.course_id = lesson_blocks.course_id
        and lesson.id = lesson_blocks.lesson_id
        and lesson.status = 'draft'
    )
  );
create policy lesson_blocks_delete_assigned_teacher_draft on public.lesson_blocks
  for delete to authenticated using (
    private.is_assigned_teacher(school_id, course_id)
    and exists (
      select 1 from public.lessons as lesson
      where lesson.school_id = lesson_blocks.school_id
        and lesson.course_id = lesson_blocks.course_id
        and lesson.id = lesson_blocks.lesson_id
        and lesson.status = 'draft'
    )
  );

revoke all on table public.lessons, public.lesson_blocks, public.media_assets from anon, authenticated;
grant select on table public.lessons, public.lesson_blocks to authenticated;
grant insert (school_id, course_id, title, position) on public.lessons to authenticated;
grant update (title, position) on public.lessons to authenticated;
grant insert (school_id, course_id, lesson_id, position, block_type, media_asset_id, payload)
  on public.lesson_blocks to authenticated;
grant update (block_type, media_asset_id, payload, position)
  on public.lesson_blocks to authenticated;
grant delete on public.lesson_blocks to authenticated;

revoke all on function private.lesson_block_payload_is_valid(text, jsonb) from public, anon;
grant execute on function private.lesson_block_payload_is_valid(text, jsonb) to authenticated;
revoke all on function private.validate_lesson_block_media() from public, anon, authenticated, service_role;
revoke all on function private.guard_lesson_update() from public, anon, authenticated, service_role;
revoke all on function private.require_assigned_lesson_teacher(uuid, uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function private.record_lesson_audit(uuid, uuid, text, uuid, jsonb, jsonb, uuid)
  from public, anon, authenticated, service_role;

revoke all on function public.teacher_publish_lesson(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.teacher_unpublish_lesson(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.teacher_archive_lesson(uuid, uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.teacher_publish_lesson(uuid, uuid, uuid) to service_role;
grant execute on function public.teacher_unpublish_lesson(uuid, uuid, uuid) to service_role;
grant execute on function public.teacher_archive_lesson(uuid, uuid, uuid) to service_role;

revoke all on function public.reorder_lessons(uuid, uuid[]) from public, anon, service_role;
revoke all on function public.reorder_lesson_blocks(uuid, uuid[]) from public, anon, service_role;
grant execute on function public.reorder_lessons(uuid, uuid[]) to authenticated;
grant execute on function public.reorder_lesson_blocks(uuid, uuid[]) to authenticated;
