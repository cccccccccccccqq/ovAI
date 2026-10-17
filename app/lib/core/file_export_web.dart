// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
  final anchor = html.AnchorElement(href: url)..download = filename;
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(seconds: 2), () => html.Url.revokeObjectUrl(url));
}
