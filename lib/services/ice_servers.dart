import 'package:cloud_functions/cloud_functions.dart';

const List<Map<String, dynamic>> _googleIceServers = [
  {
    'urls': [
      'stun:stun.l.google.com:19302',
      'stun:stun1.l.google.com:19302',
      'stun:stun2.l.google.com:19302',
      'stun:stun3.l.google.com:19302',
      'stun:stun4.l.google.com:19302',
    ],
  },
];

List<Map<String, dynamic>> fallbackIceServers() {
  return _googleIceServers
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList();
}

Future<List<Map<String, dynamic>>> fetchIceServers() async {
  final callable = FirebaseFunctions.instance.httpsCallable('getIceServers');
  final result = await callable.call();
  final data = result.data;
  final raw = data is Map<String, dynamic> ? data['iceServers'] : data;
  if (raw is! List) {
    throw StateError('ICE server response missing "iceServers" list.');
  }
  return raw
      .whereType<Map>()
      .map((entry) => Map<String, dynamic>.from(entry))
      .toList();
}
