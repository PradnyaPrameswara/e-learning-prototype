import { describe, expect, it } from 'vitest';
import { lessonBlockSchema } from '@lms/schemas/lesson';

const ids = {
  school_id: '20000000-0000-4000-8000-000000000001',
  course_id: '70000000-0000-4000-8000-000000000001',
  lesson_id: '80000000-0000-4000-8000-000000000001',
  position: 0,
};

describe('Lesson block contracts', () => {
  it('accepts the supported text and learning-content block types', () => {
    const blocks: unknown[] = [
      {
        ...ids,
        block_type: 'heading',
        media_asset_id: null,
        payload: { text: 'Vectors', level: 2 },
      },
      {
        ...ids,
        block_type: 'paragraph',
        media_asset_id: null,
        payload: { text: 'A vector has magnitude and direction.' },
      },
      {
        ...ids,
        block_type: 'image',
        media_asset_id: '90000000-0000-4000-8000-000000000001',
        payload: { alt_text: 'Vector diagram' },
      },
      {
        ...ids,
        block_type: 'attachment',
        media_asset_id: '90000000-0000-4000-8000-000000000002',
        payload: { title: 'Worksheet PDF' },
      },
      {
        ...ids,
        block_type: 'external_video',
        media_asset_id: null,
        payload: { provider: 'youtube', video_id: 'abcdefghijk' },
      },
      {
        ...ids,
        block_type: 'formula',
        media_asset_id: null,
        payload: { latex: 'v = d/t' },
      },
      {
        ...ids,
        block_type: 'callout',
        media_asset_id: null,
        payload: { tone: 'definition', text: 'A scalar has magnitude only.' },
      },
    ];

    for (const block of blocks) {
      expect(lessonBlockSchema.safeParse(block).success).toBe(true);
    }
  });

  it('rejects arbitrary HTML and Assessment-reference blocks', () => {
    expect(
      lessonBlockSchema.safeParse({
        ...ids,
        block_type: 'html',
        media_asset_id: null,
        payload: { html: '<script>alert(1)</script>' },
      }).success,
    ).toBe(false);
    expect(
      lessonBlockSchema.safeParse({
        ...ids,
        block_type: 'assessment_reference',
        media_asset_id: null,
        payload: { assessment_id: '90000000-0000-4000-8000-000000000001' },
      }).success,
    ).toBe(false);
  });

  it('requires media-backed block types to reference a media asset', () => {
    const image = {
      ...ids,
      block_type: 'image',
      media_asset_id: null,
      payload: { alt_text: 'Diagram' },
    };

    expect(lessonBlockSchema.safeParse(image).success).toBe(false);
  });

  it('limits external video identifiers to supported provider formats', () => {
    const invalidVideo = {
      ...ids,
      block_type: 'external_video',
      media_asset_id: null,
      payload: { provider: 'youtube', video_id: 'not a safe id' },
    };

    expect(lessonBlockSchema.safeParse(invalidVideo).success).toBe(false);
  });
});
