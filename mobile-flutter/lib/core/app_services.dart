import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../features/auth/data/auth_api.dart';
import '../features/chatbot/data/chatbot_api.dart';
import '../features/notifications/data/notification_api.dart';
import '../features/notifications/local_notifier.dart';
import '../features/notifications/notification_center.dart';
import '../features/tickets/data/ticket_api.dart';
import 'api/api_client.dart';
import 'attachments/attachment_cache.dart';
import 'attachments/attachment_picker.dart';
import 'attachments/file_opener.dart';
import 'network/api_config.dart';
import 'network/auth_http_client.dart';
import 'network/session_store.dart';
import 'network/token_refresher.dart';
import 'network/token_store.dart';

/// Dependências do app, montadas uma vez no main (ou nos testes, com falsos).
class AppServices {
  AppServices({
    required this.navigatorKey,
    required this.tokenStore,
    required this.sessionStore,
    required this.authApi,
    required this.tickets,
    required this.chatbot,
    required this.notifications,
    required this.notificationCenter,
    required this.picker,
    required this.opener,
    required this.attachments,
    this.clock = DateTime.now,
    RouteObserver<ModalRoute<void>>? routeObserver,
  }) : routeObserver = routeObserver ?? RouteObserver<ModalRoute<void>>();

  /// [picker] e [notifier] são trocados no e2e (seletor falso, sem pedir
  /// permissão de notificação).
  factory AppServices.production({
    AttachmentPicker? picker,
    LocalNotifier? notifier,
  }) {
    final navigatorKey = GlobalKey<NavigatorState>();
    final tokenStore = TokenStore();
    final sessionStore = SessionStore();
    late final AppServices services;
    final client = AuthHttpClient(
      inner: http.Client(),
      tokenStore: tokenStore,
      refresher: TokenRefresher(tokenStore: tokenStore),
      onSessionExpired: () => services.sessionExpired(),
    );
    final api = ApiClient(client: client, baseUrl: ApiConfig.baseUrl);
    final tickets = HttpTicketRepository(api);
    final notifications = HttpNotificationRepository(api);
    services = AppServices(
      navigatorKey: navigatorKey,
      tokenStore: tokenStore,
      sessionStore: sessionStore,
      authApi: AuthApi(tokenStore: tokenStore, sessionStore: sessionStore),
      tickets: tickets,
      chatbot: HttpChatbotRepository(api),
      notifications: notifications,
      notificationCenter: NotificationCenter(
        repository: notifications,
        notifier: notifier ?? PluginLocalNotifier(),
        onOpen: (ticketId) =>
            navigatorKey.currentState?.pushNamed(notificationRoute(ticketId)),
      ),
      picker: picker ?? DeviceAttachmentPicker(),
      opener: const OpenFilexOpener(),
      attachments: AttachmentCache(tickets.download),
    );
    return services;
  }

  final GlobalKey<NavigatorState> navigatorKey;
  final TokenStore tokenStore;
  final SessionStore sessionStore;
  final AuthApi authApi;
  final TicketRepository tickets;
  final ChatbotRepository chatbot;
  final NotificationRepository notifications;
  final NotificationCenter notificationCenter;
  final AttachmentPicker picker;
  final FileOpener opener;
  final AttachmentCache attachments;
  final DateTime Function() clock;

  /// Avisa as telas (RouteAware) quando voltam a ficar visíveis.
  final RouteObserver<ModalRoute<void>> routeObserver;

  bool _sessionEnded = false;

  static String notificationRoute(int? ticketId) =>
      ticketId == null ? '/notifications' : '/tickets/$ticketId';

  /// Liga o que só a sessão USER usa.
  Future<void> startUserSession() {
    _sessionEnded = false;
    return notificationCenter.start();
  }

  Future<void> logout() async {
    _endSession();
    try {
      await tokenStore.clear();
      await sessionStore.clear();
    } finally {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (_) => false,
      );
    }
  }

  /// Chamado pelo AuthHttpClient num 401; ele já apagou os tokens.
  void sessionExpired() {
    // Um polling em voo pode receber 401 depois de um logout voluntário.
    if (_sessionEnded) return;
    _endSession();
    unawaited(sessionStore.clear());
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
      arguments: const {'sessionExpired': true},
    );
  }

  void _endSession() {
    _sessionEnded = true;
    notificationCenter.stop();
    attachments.clear();
    // Apagar os PDFs abertos na sessão não pode travar a saída.
    unawaited(opener.clear().catchError((Object _) {}));
  }
}

/// Entrega o AppServices às telas.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope ausente acima de $context');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
