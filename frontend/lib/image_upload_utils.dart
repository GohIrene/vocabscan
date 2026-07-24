// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

/// Formats the app will actually process. Mirrors the backend's own check in
/// routes/vocabulary.py. Notably excludes HEIC/HEIF — the default photo
/// format on iPhone since iOS 11 — because no browser's <img> element can
/// decode it; without this check that file reaches [cropCenterSquareFromDataUrl]
/// and fails there instead, later and less clearly.
const Set<String> kAllowedImageMimeTypes = {
  'image/jpeg',
  'image/png',
  'image/webp',
};

/// A comma-separated `accept` value for a file input — narrows what the OS
/// picker offers, though (like `accept` in general) it's a hint, not
/// enforcement, so [validateImageFile] is still required.
const String kAllowedImageAccept = 'image/jpeg,image/png,image/webp';

/// Above this, a phone camera photo is more likely to freeze the tab while
/// being read and decoded than to be worth the wait. Mirrors the backend's
/// _MAX_UPLOAD_BYTES in routes/vocabulary.py.
const int kMaxImageBytes = 8 * 1024 * 1024;

/// Null if [file] is acceptable to upload; otherwise a message to show the
/// user. Checked before the file is ever read, so a bad pick fails instantly
/// instead of stalling on a decode that was never going to succeed.
String? validateImageFile(html.File file) {
  // Some browsers/OSes leave `type` empty for a file they don't recognise
  // (which HEIC often is) — treated as a rejection rather than let through,
  // since an unrecognised type is exactly the case this guards against.
  if (!kAllowedImageMimeTypes.contains(file.type)) {
    return 'Please choose a JPEG, PNG, or WEBP photo.';
  }
  if (file.size > kMaxImageBytes) {
    final mb = (kMaxImageBytes / (1024 * 1024)).toStringAsFixed(0);
    return 'That photo is too large — please choose one under ${mb}MB.';
  }
  return null;
}

/// Center-crops the image at [dataUrl] to an [outSize]×[outSize] square,
/// returning JPEG bytes ready for upload.
///
/// An `<img>` element never fires `onLoad` for image data the browser can't
/// decode — it fires `onError` instead — so code that only awaits `onLoad`
/// (as this used to) hangs forever on such a file rather than failing. This
/// races both events plus a timeout and throws, so callers' existing
/// try/catch can show an error instead of the tab silently freezing.
Future<Uint8List> cropCenterSquareFromDataUrl(
  String dataUrl, {
  int outSize = 224,
}) async {
  final img = html.ImageElement(src: dataUrl);
  final completer = Completer<void>();
  img.onLoad.first.then((_) {
    if (!completer.isCompleted) completer.complete();
  });
  img.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('Could not read that image.'));
    }
  });
  await completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () =>
        throw Exception('That photo took too long to load.'),
  );

  final iw = img.naturalWidth;
  final ih = img.naturalHeight;
  final side = math.min(iw, ih);
  final sx = (iw - side) ~/ 2;
  final sy = (ih - side) ~/ 2;

  final canvas = html.CanvasElement(width: outSize, height: outSize);
  canvas.context2D.drawImageScaledFromSource(
      img, sx, sy, side, side, 0, 0, outSize, outSize);
  final url = canvas.toDataUrl('image/jpeg', 0.92);
  return base64Decode(url.split(',')[1]);
}
