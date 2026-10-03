const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

const relativeFormat = new Intl.RelativeTimeFormat('pt-BR', { numeric: 'always' });

function parse(iso: string | null | undefined): number | null {
  if (!iso) {
    return null;
  }
  const time = new Date(iso).getTime();
  return Number.isNaN(time) ? null : time;
}

/** 29/09/2026 14:05, no fuso do navegador (ou no fuso informado, nos testes). */
export function formatDateTime(iso: string | null | undefined, timeZone?: string): string {
  const time = parse(iso);
  if (time === null) {
    return '—';
  }

  const parts = new Intl.DateTimeFormat('pt-BR', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(time);
  const part = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((item) => item.type === type)?.value ?? '';

  return `${part('day')}/${part('month')}/${part('year')} ${part('hour')}:${part('minute')}`;
}

/** 29/09/2026, para saber quando uma conversa muda de dia. */
export function formatDate(iso: string | null | undefined, timeZone?: string): string {
  const time = parse(iso);
  if (time === null) {
    return '';
  }

  return new Intl.DateTimeFormat('pt-BR', {
    timeZone,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(time);
}

/** 14:05, para o horário das mensagens e da presença. */
export function formatTime(iso: string | null | undefined, timeZone?: string): string {
  const time = parse(iso);
  if (time === null) {
    return '';
  }

  return new Intl.DateTimeFormat('pt-BR', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(time);
}

/** "há 10 minutos", "em 2 horas", "agora". */
export function relativeTime(iso: string | null | undefined, now: number): string {
  const time = parse(iso);
  if (time === null) {
    return '';
  }

  const diff = time - now;
  return Math.abs(diff) < MINUTE ? 'agora' : formatDiff(diff);
}

/** "vence em 2 horas", "venceu há 10 minutos". */
export function slaDueLabel(iso: string | null | undefined, now: number): string {
  const time = parse(iso);
  if (time === null) {
    return 'sem prazo';
  }

  const diff = time - now;
  if (Math.abs(diff) < MINUTE) {
    return diff >= 0 ? 'vence agora' : 'venceu agora';
  }
  return `${diff >= 0 ? 'vence' : 'venceu'} ${formatDiff(diff)}`;
}

function formatDiff(diff: number): string {
  const abs = Math.abs(diff);
  const sign = diff < 0 ? -1 : 1;

  if (abs < HOUR) {
    return relativeFormat.format(sign * Math.floor(abs / MINUTE), 'minute');
  }
  if (abs < DAY) {
    return relativeFormat.format(sign * Math.floor(abs / HOUR), 'hour');
  }
  return relativeFormat.format(sign * Math.floor(abs / DAY), 'day');
}
