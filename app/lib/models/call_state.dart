/// Единый источник истины для состояния голосового соединения.
enum CallState {
  idle,
  connecting,
  connected,
  talking,
  reconnecting,
  failed,
}

extension CallStateX on CallState {
  bool get isMediaReady =>
      this == CallState.connected || this == CallState.talking;

  String get label {
    switch (this) {
      case CallState.idle:
        return 'Ожидание';
      case CallState.connecting:
        return 'Соединение…';
      case CallState.connected:
        return 'Готов';
      case CallState.talking:
        return 'Собеседник говорит';
      case CallState.reconnecting:
        return 'Переподключение…';
      case CallState.failed:
        return 'Ошибка';
    }
  }
}
