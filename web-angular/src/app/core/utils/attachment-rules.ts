/** Espelha a API (AttachmentValidator e TicketTexts); ela continua sendo a autoridade. */
export const MAX_FILES = 5;
export const MAX_FILE_BYTES = 5 * 1024 * 1024;
export const MAX_BODY_LENGTH = 2000;
export const ACCEPTED_TYPES: readonly string[] = [
  'image/png',
  'image/jpeg',
  'image/webp',
  'application/pdf',
];
export const ACCEPT_ATTRIBUTE = ACCEPTED_TYPES.join(',');

const TOO_MANY_FILES = `Anexe no máximo ${MAX_FILES} arquivos por mensagem.`;

export function fileProblem(file: File): string | null {
  if (!ACCEPTED_TYPES.includes(file.type)) {
    return `${file.name}: tipo não aceito. Use PNG, JPEG, WEBP ou PDF.`;
  }
  if (file.size === 0) {
    return `${file.name}: arquivo vazio.`;
  }
  if (file.size > MAX_FILE_BYTES) {
    return `${file.name}: maior que 5 MB.`;
  }
  return null;
}

/** Junta os arquivos escolhidos aos que já estão na mensagem, recusando os inválidos e o excesso. */
export function addFiles(current: File[], picked: File[]): { files: File[]; problems: string[] } {
  const files = [...current];
  const problems: string[] = [];

  for (const file of picked) {
    const problem = fileProblem(file);
    if (problem) {
      problems.push(problem);
      continue;
    }
    if (files.length >= MAX_FILES) {
      problems.push(TOO_MANY_FILES);
      break;
    }
    files.push(file);
  }
  return { files, problems };
}

export function messageProblem(body: string, files: File[]): string | null {
  const text = body.trim();
  if (!text) {
    return 'Escreva uma mensagem.';
  }
  if (text.length > MAX_BODY_LENGTH) {
    return `A mensagem passa de ${MAX_BODY_LENGTH} caracteres.`;
  }
  if (files.length > MAX_FILES) {
    return TOO_MANY_FILES;
  }
  return files.map(fileProblem).find((problem) => problem !== null) ?? null;
}

export function isImage(contentType: string): boolean {
  return contentType.startsWith('image/');
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes} B`;
  }
  if (bytes < 1024 * 1024) {
    return `${Math.round(bytes / 1024)} KB`;
  }
  return `${(bytes / (1024 * 1024)).toFixed(1).replace('.', ',')} MB`;
}
