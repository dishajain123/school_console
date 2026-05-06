// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}

void downloadTextFile({
  required String filename,
  required String contents,
  String contentType = 'text/plain',
}) {
  final bytes = utf8.encode(contents);
  final blob = html.Blob([bytes], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
