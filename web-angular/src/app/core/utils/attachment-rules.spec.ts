import { describe, expect, it } from 'vitest';

import { fakeFile } from '../../testing/test-data';
import {
  addFiles,
  fileProblem,
  formatBytes,
  isImage,
  MAX_FILE_BYTES,
  messageProblem
} from './attachment-rules';

const png = (name = 'print.png', size = 1024) => fakeFile(name, 'image/png', size);

describe('fileProblem', () => {
  it.each(['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])('accepts %s', type => {
    expect(fileProblem(fakeFile('arquivo', type, 10))).toBeNull();
  });

  it('refuses other types', () => {
    expect(fileProblem(fakeFile('anim.gif', 'image/gif', 10))).toBe(
      'anim.gif: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.'
    );
  });

  it('accepts exactly 5 MB and refuses one byte more', () => {
    expect(fileProblem(png('ok.png', MAX_FILE_BYTES))).toBeNull();
    expect(fileProblem(png('big.png', MAX_FILE_BYTES + 1))).toBe('big.png: maior que 5 MB.');
    expect(MAX_FILE_BYTES).toBe(5 * 1024 * 1024);
  });

  it('refuses an empty file, like the API', () => {
    expect(fileProblem(png('vazio.png', 0))).toBe('vazio.png: arquivo vazio.');
  });
});

describe('addFiles', () => {
  it('keeps up to 5 files', () => {
    const five = [1, 2, 3, 4, 5].map(i => png(`${i}.png`));

    expect(addFiles([], five)).toEqual({ files: five, problems: [] });
  });

  it('refuses the sixth file', () => {
    const five = [1, 2, 3, 4, 5].map(i => png(`${i}.png`));

    const result = addFiles(five, [png('6.png')]);

    expect(result.files).toHaveLength(5);
    expect(result.problems).toEqual(['Anexe no máximo 5 arquivos por mensagem.']);
  });

  it('skips invalid files and reports each one', () => {
    const result = addFiles([], [fakeFile('a.gif', 'image/gif', 10), png('b.png')]);

    expect(result.files.map(file => file.name)).toEqual(['b.png']);
    expect(result.problems).toEqual(['a.gif: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.']);
  });
});

describe('messageProblem', () => {
  it('requires some text', () => {
    expect(messageProblem('', [])).toBe('Escreva uma mensagem.');
    expect(messageProblem('   \n  ', [])).toBe('Escreva uma mensagem.');
  });

  it('accepts 2000 characters and refuses 2001, counting after the trim', () => {
    expect(messageProblem('a'.repeat(2000), [])).toBeNull();
    expect(messageProblem(`  ${'a'.repeat(2000)}  `, [])).toBeNull();
    expect(messageProblem('a'.repeat(2001), [])).toBe('A mensagem passa de 2000 caracteres.');
  });

  it('checks the files too', () => {
    const six = [1, 2, 3, 4, 5, 6].map(i => png(`${i}.png`));

    expect(messageProblem('oi', six)).toBe('Anexe no máximo 5 arquivos por mensagem.');
    expect(messageProblem('oi', [fakeFile('a.gif', 'image/gif', 1)])).toBe(
      'a.gif: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.'
    );
    expect(messageProblem('oi', [png()])).toBeNull();
  });
});

describe('isImage and formatBytes', () => {
  it('tells images apart', () => {
    expect(isImage('image/webp')).toBe(true);
    expect(isImage('application/pdf')).toBe(false);
  });

  it('formats sizes', () => {
    expect(formatBytes(512)).toBe('512 B');
    expect(formatBytes(2048)).toBe('2 KB');
    expect(formatBytes(1.5 * 1024 * 1024)).toBe('1,5 MB');
  });
});
