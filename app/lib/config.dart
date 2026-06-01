class Config {
  // Конфигурация сервера - обновите на IP-адрес вашего ПК
  static const String serverUrl = 'http://172.20.117.231:3000';
  
  // Конфигурация WebRTC
  static const Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {
        'urls': 'turn:turn.mototalk.local:3478',
        'username': 'mototalk',
        'credential': 'mototalk123',
      },
    ],
    'iceTransportPolicy': 'all',
    'sdpSemantics': 'unified-plan',
  };
  
  // Конфигурация аудио
  static const int sampleRate = 48000;
  static const int channels = 1;
  static const int bitsPerSample = 16;
  
  // Конфигурация PTT
  static const int pttDebounceMs = 50;
  static const int voiceCommandDebounceMs = 500;
  
  // Конфигурация переподключения
  static const int maxReconnectAttempts = 10;
  static const int initialReconnectDelayMs = 1000;
  static const int maxReconnectDelayMs = 30000;
  
  // Голосовые команды (русский)
  static const List<String> voiceCommandsStart = ['приём', 'пуск'];
  static const List<String> voiceCommandsStop = ['стоп', 'отбой'];
}
