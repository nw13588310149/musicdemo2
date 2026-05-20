import 'dart:typed_data';

import 'ai_chat_attachment_picker_stub.dart'
    if (dart.library.html) 'ai_chat_attachment_picker_web.dart'
    if (dart.library.io) 'ai_chat_attachment_picker_io.dart';

Future<({Uint8List bytes, String filename, int size})?>
pickAiChatAttachmentFile() => pickAiChatAttachmentFileImpl();
