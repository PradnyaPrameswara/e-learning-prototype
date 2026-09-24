import { z } from 'zod';

const uuid = z.uuid();
const plainText = (maximum: number) => z.string().trim().min(1).max(maximum);

export const lessonStatusSchema = z.enum(['draft', 'published', 'archived']);

export const lessonBlockTypeSchema = z.enum([
  'heading',
  'paragraph',
  'image',
  'attachment',
  'external_video',
  'formula',
  'callout',
]);

const lessonBlockIdentity = {
  school_id: uuid,
  course_id: uuid,
  lesson_id: uuid,
  position: z.number().int().min(0),
};

const headingPayloadSchema = z
  .object({
    text: plainText(4000),
    level: z.union([z.literal(2), z.literal(3), z.literal(4)]),
  })
  .strict();

const paragraphPayloadSchema = z.object({ text: plainText(12000) }).strict();

const imagePayloadSchema = z
  .object({
    alt_text: plainText(500),
    caption: plainText(2000).optional(),
  })
  .strict();

const attachmentPayloadSchema = z.object({ title: plainText(160) }).strict();

const externalVideoPayloadSchema = z.discriminatedUnion('provider', [
  z
    .object({
      provider: z.literal('youtube'),
      video_id: z.string().regex(/^[A-Za-z0-9_-]{11}$/),
    })
    .strict(),
  z
    .object({
      provider: z.literal('vimeo'),
      video_id: z.string().regex(/^[0-9]{1,20}$/),
    })
    .strict(),
]);

const formulaPayloadSchema = z.object({ latex: plainText(4000) }).strict();

const calloutPayloadSchema = z
  .object({
    tone: z.enum(['info', 'warning', 'definition']),
    text: plainText(4000),
    title: plainText(160).optional(),
  })
  .strict();

export const lessonBlockSchema = z.discriminatedUnion('block_type', [
  z
    .object({
      ...lessonBlockIdentity,
      block_type: z.literal('heading'),
      media_asset_id: z.null(),
      payload: headingPayloadSchema,
    })
    .strict(),
  z
    .object({
      ...lessonBlockIdentity,
      block_type: z.literal('paragraph'),
      media_asset_id: z.null(),
      payload: paragraphPayloadSchema,
    })
    .strict(),
  z
    .object({
      ...lessonBlockIdentity,
      block_type: z.literal('image'),
      media_asset_id: uuid,
      payload: imagePayloadSchema,
    })
    .strict(),
  z
    .object({
      ...lessonBlockIdentity,
      block_type: z.literal('attachment'),
      media_asset_id: uuid,
      payload: attachmentPayloadSchema,
    })
    .strict(),
  z
    .object({
      ...lessonBlockIdentity,
      block_type: z.literal('external_video'),
      media_asset_id: z.null(),
      payload: externalVideoPayloadSchema,
    })
    .strict(),
  z
    .object({
      ...lessonBlockIdentity,
      block_type: z.literal('formula'),
      media_asset_id: z.null(),
      payload: formulaPayloadSchema,
    })
    .strict(),
  z
    .object({
      ...lessonBlockIdentity,
      block_type: z.literal('callout'),
      media_asset_id: z.null(),
      payload: calloutPayloadSchema,
    })
    .strict(),
]);

export const createLessonRequestSchema = z
  .object({
    school_id: uuid,
    course_id: uuid,
    title: plainText(160),
    position: z.number().int().min(0),
  })
  .strict();

export const reorderLessonsRequestSchema = z
  .object({
    course_id: uuid,
    lesson_ids: z.array(uuid),
  })
  .strict()
  .refine(
    (value) => new Set(value.lesson_ids).size === value.lesson_ids.length,
    {
      message: 'Lesson IDs must be unique.',
      path: ['lesson_ids'],
    },
  );

export const reorderLessonBlocksRequestSchema = z
  .object({
    lesson_id: uuid,
    block_ids: z.array(uuid),
  })
  .strict()
  .refine((value) => new Set(value.block_ids).size === value.block_ids.length, {
    message: 'Block IDs must be unique.',
    path: ['block_ids'],
  });

export type LessonBlock = z.infer<typeof lessonBlockSchema>;
