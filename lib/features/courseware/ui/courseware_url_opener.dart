import 'courseware_url_opener_io.dart'
    if (dart.library.html) 'courseware_url_opener_web.dart';

/// Opens an external resource URL in a new browser tab/window on web,
/// no-op on other platforms.
void openCoursewareUrl(String url) {
  if (url.trim().isEmpty) {
    return;
  }
  openCoursewareUrlImpl(url);
}
