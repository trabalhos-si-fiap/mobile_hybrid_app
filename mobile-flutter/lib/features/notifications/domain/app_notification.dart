class AppNotification {
  const AppNotification({
    required this.id,
    required this.ticketId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        ticketId: json['ticketId'] as int?,
        title: json['title'] as String,
        body: json['body'] as String,
        read: json['read'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final int id;
  final int? ticketId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    ticketId: ticketId,
    title: title,
    body: body,
    read: read ?? this.read,
    createdAt: createdAt,
  );
}
