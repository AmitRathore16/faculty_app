import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> shareLink({
    required String url,
    String? title,
  }) async {
    await Share.share(
      url,
      subject: title,
    );
  }

  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
