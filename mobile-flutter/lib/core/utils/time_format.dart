String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// "30/09 14:05", no fuso do aparelho.
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)} '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

/// "agora", "há 5 min", "há 2 h", "há 1 dia", "há 3 dias".
String relativeTime(DateTime value, DateTime now) {
  final elapsed = now.difference(value);
  if (elapsed.inMinutes < 1) return 'agora';
  if (elapsed.inHours < 1) return 'há ${elapsed.inMinutes} min';
  if (elapsed.inDays < 1) return 'há ${elapsed.inHours} h';
  return elapsed.inDays == 1 ? 'há 1 dia' : 'há ${elapsed.inDays} dias';
}
