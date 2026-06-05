import 'notes_streaming_transcriber_io.dart'
    if (dart.library.html) 'notes_streaming_transcriber_web.dart' as impl;

typedef GoogleStreamingTranscriber = impl.GoogleStreamingTranscriber;
