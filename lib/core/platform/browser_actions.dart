import 'browser_actions_stub.dart'
    if (dart.library.html) 'browser_actions_web.dart' as impl;

void openUrlInNewTab(String url) => impl.openUrlInNewTab(url);

void downloadTextFile({
  required String filename,
  required String contents,
  String contentType = 'text/plain',
}) {
  impl.downloadTextFile(
    filename: filename,
    contents: contents,
    contentType: contentType,
  );
}
