import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:record/record.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_chunked_transcriber.dart';
import 'recording_artifacts.dart';
import 'transcript_utterance.dart';

/// Streaming STT client for web that pushes raw PCM frames over WebSocket to the
/// Google Speech streaming proxy and emits interim/final text.
class GoogleStreamingTranscriber implements LiveChunkedTranscriber {
  GoogleStreamingTranscriber({
    Uri? endpoint,
    this.languageCode,
    this.enableWordTimeOffsets = false,
    this.enableAutomaticPunctuation = false,
    this.sampleRate = 16000,
  }) : _endpoint = _resolveEndpoint(endpoint);

  static const String _kWsEnv = String.fromEnvironment('STREAMING_STT_WS');
  static Uri _resolveEndpoint(Uri? override) {
    if (override != null) return override;
    if (_kWsEnv.isNotEmpty) return Uri.parse(_kWsEnv);
    // kleenops's own streaming-STT function (functions/src/modules/
    // streamingTranscriber.js). MUST be the Cloud Run (run.app) URL, not
    // the *.cloudfunctions.net alias — WebSocket upgrades through the
    // cloudfunctions.net frontend are rejected with HTTP 400; the Cloud
    // Run URL speaks WebSocket natively.
    return Uri.parse(
      'wss://googlestreamingtranscribe-dvzj6nq6aa-uc.a.run.app',
    );
  }

  final Uri _endpoint;
  Uri get endpointUri => _endpoint;
  final String? languageCode;
  final bool enableWordTimeOffsets;
  final bool enableAutomaticPunctuation;
  final int sampleRate;

  final AudioRecorder _recorder = AudioRecorder();
  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  final StreamController<TranscriptUtterance> _utteranceController =
      StreamController<TranscriptUtterance>.broadcast();
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<Uint8List>? _audioSub;
  WebSocketChannel? _channel;
  bool _reconnecting = false;
  Timer? _keepAliveTimer;
  DateTime _lastAudioSent = DateTime.now();

  bool _recording = false;
  bool _disposed = false;
  String _committed = '';
  String _interim = '';

  @override
  Stream<String> get transcriptStream => _controller.stream;

  /// Emits one event per finalized STT result — stable text with a timestamp.
  Stream<TranscriptUtterance> get utteranceStream =>
      _utteranceController.stream;

  @override
  Future<void> start({bool freshSession = false}) async {
    if (_disposed) {
      throw StateError('Transcriber has been disposed.');
    }
    if (_recording) return;

    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission denied.');
    }

    if (freshSession) {
      _committed = '';
      _interim = '';
    }

    await _openChannel();
    _sendConfig();
    await _startStreamingAudio();
    _startKeepAlive();

    _recording = true;
  }

  @override
  Future<void> pause() async {
    if (!_recording) return;
    await _stopAudioStream();
    _recording = false;
  }

  @override
  Future<void> stop() async {
    await _stopAudioStream();
    _closeChannel();
    _recording = false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _controller.close();
    await _utteranceController.close();
  }

  @override
  Future<void> clearArtifacts() async {
    // Streaming mode does not persist audio artifacts yet.
  }

  @override
  Future<RecordingArtifacts> buildRecordingArtifacts() async {
    return const RecordingArtifacts();
  }

  Future<void> _startStreamingAudio() async {
    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: sampleRate,
        numChannels: 1,
        bitRate: sampleRate * 16,
        audioInterruption: AudioInterruptionMode.pauseResume,
        streamBufferSize: 2048,
      ),
    );

    _audioSub = stream.listen(
      (chunk) {
        final socket = _channel;
        if (socket != null) {
          try {
            socket.sink.add(chunk);
            _lastAudioSent = DateTime.now();
          } catch (_) {}
        }
      },
      onError: (Object err, StackTrace st) {
        if (!_controller.isClosed) {
          _controller.addError(err, st);
        }
      },
    );
  }

  Future<void> _stopAudioStream() async {
    try {
      await _audioSub?.cancel();
    } catch (_) {}
    _audioSub = null;
    if (await _recorder.isRecording()) {
      try {
        await _recorder.stop();
      } catch (_) {}
    }
    _stopKeepAlive();
  }

  Future<void> _openChannel() async {
    try {
      _channel = WebSocketChannel.connect(_endpoint);
    } catch (err) {
      _channel = null;
      throw Exception('Unable to open streaming socket: $err');
    }
    _wsSub = _channel!.stream.listen(
      _handleServerMessage,
      onError: (Object err, StackTrace st) {
        if (!_controller.isClosed) {
          _controller.addError(err, st);
        }
        _tryReconnect();
      },
      onDone: () {
        _tryReconnect();
      },
      cancelOnError: false,
    );
  }

  void _sendConfig() {
    final cfg = <String, dynamic>{
      'languageCode': languageCode?.isNotEmpty == true ? languageCode : 'en-US',
      'sampleRateHertz': sampleRate,
      'enableWordTimeOffsets': enableWordTimeOffsets,
      'enableAutomaticPunctuation': enableAutomaticPunctuation,
    };
    _channel?.sink.add(jsonEncode(cfg));
  }

  void _handleServerMessage(dynamic message) {
    try {
      final String textMessage;
      if (message is List<int>) {
        textMessage = utf8.decode(message);
      } else if (message is String) {
        textMessage = message;
      } else {
        return;
      }
      final Map<String, dynamic> data = jsonDecode(textMessage);
      if (data['type'] != 'transcript') return;
      final text = (data['text'] as String? ?? '').trim();
      if (text.isEmpty) return;
      final isFinal = data['isFinal'] == true;
      if (isFinal) {
        _committed = '$_committed$text ';
        _interim = '';
        if (!_utteranceController.isClosed) {
          _utteranceController.add(
            TranscriptUtterance(text: text, timestamp: DateTime.now()),
          );
        }
      } else {
        _interim = text;
      }
      final combined = (_committed + _interim).trim();
      if (!_controller.isClosed) {
        _controller.add(combined.isEmpty ? '' : '$combined ');
      }
    } catch (err, st) {
      if (!_controller.isClosed) {
        _controller.addError(err, st);
      }
    }
  }

  void _closeChannel() {
    try {
      _wsSub?.cancel();
    } catch (_) {}
    _wsSub = null;
    try {
      _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
  }

  Future<void> _tryReconnect() async {
    if (_reconnecting || !_recording || _disposed) return;
    _reconnecting = true;
    try {
      _closeChannel();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await _openChannel();
      _sendConfig();
    } catch (err, st) {
      if (!_controller.isClosed) {
        _controller.addError(err, st);
      }
    } finally {
      _reconnecting = false;
    }
  }

  void _startKeepAlive() {
    _stopKeepAlive();
    const keepAliveInterval = Duration(milliseconds: 100);
    final silenceBytes = Uint8List(sampleRate ~/ 10 * 2);
    _keepAliveTimer = Timer.periodic(keepAliveInterval, (_) {
      final socket = _channel;
      if (socket == null || _disposed || !_recording) return;
      final elapsed = DateTime.now().difference(_lastAudioSent);
      if (elapsed >= keepAliveInterval) {
        try {
          socket.sink.add(silenceBytes);
          _lastAudioSent = DateTime.now();
        } catch (_) {}
      }
    });
  }

  void _stopKeepAlive() {
    try {
      _keepAliveTimer?.cancel();
    } catch (_) {}
    _keepAliveTimer = null;
  }
}
