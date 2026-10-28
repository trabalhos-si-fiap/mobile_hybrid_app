import { describe, expect, it } from 'vitest';

describe('ci red path', () => {
  it('fails on purpose', () => {
    expect(1).toBe(2);
  });
});
