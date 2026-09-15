import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

const int maxChatMediaSelectionCount = 9;

enum LocalChatMediaKind { image, video }

LocalChatMediaKind localChatMediaKindFor(XFile file) {
  final mimeType = file.mimeType?.trim().toLowerCase() ?? '';
  if (mimeType.startsWith('video/')) return LocalChatMediaKind.video;
  if (mimeType.startsWith('image/')) return LocalChatMediaKind.image;

  final fileName = file.name.trim().isEmpty ? file.path : file.name;
  final extension = path.extension(fileName).toLowerCase();
  return _videoExtensions.contains(extension)
      ? LocalChatMediaKind.video
      : LocalChatMediaKind.image;
}

List<XFile> limitChatMediaSelection(Iterable<XFile> files) {
  return files.take(maxChatMediaSelectionCount).toList(growable: false);
}

const Set<String> _videoExtensions = {
  '.3gp',
  '.avi',
  '.m4v',
  '.mkv',
  '.mov',
  '.mp4',
  '.mpeg',
  '.mpg',
  '.webm',
  '.wmv',
};
