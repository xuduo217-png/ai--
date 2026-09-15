import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../core/media/rich_text_video_player.dart';
import '../../../../core/network/asset_url_resolver.dart';

class AidGuideRichContent extends StatelessWidget {
  const AidGuideRichContent({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) {
      return const Text('暂无指南内容', style: TextStyle(color: Color(0xFF766B6D)));
    }

    final document = HtmlParser.parseHTML(content);
    var imageIndex = 0;
    for (final image in document.querySelectorAll('img')) {
      final resolved = resolveAssetUrl(image.attributes['src']);
      if (resolved.isEmpty) {
        image.remove();
      } else {
        image.attributes['src'] = resolved;
        image.attributes['data-flutter-image-id'] = '${imageIndex++}';
        image.attributes.remove('width');
        image.attributes.remove('height');
      }
    }

    var videoIndex = 0;
    for (final wrapper in document.querySelectorAll(
      'div[data-w-e-type="video"]',
    )) {
      wrapper.attributes['data-flutter-video-id'] = '${videoIndex++}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 60;
        return Html.fromElement(
          documentElement: document,
          shrinkWrap: true,
          extensions: [
            ImageExtension(
              handleAssetImages: false,
              builder: (context) => _RichContentImage(
                imageId:
                    context.attributes['data-flutter-image-id'] ??
                    'raw-${context.node.hashCode}',
                source: context.attributes['src'] ?? '',
                width: contentWidth,
              ),
            ),
            MatcherExtension(
              matcher: _matchesRichVideo,
              builder: (context) {
                final videoId =
                    context.attributes['data-flutter-video-id'] ??
                    'raw-${context.node.hashCode}';
                final source = _extractVideoSource(context);
                if (source == null) {
                  return _UnavailableVideoBlock(videoId: videoId);
                }
                return RichTextVideoPlayer(
                  key: ValueKey('aid-guide-video-state-$videoId'),
                  source: source,
                  width: contentWidth,
                  semanticsKey: ValueKey('aid-guide-video-$videoId'),
                  semanticLabel: '富文本视频播放器',
                  controlKeyPrefix: 'aid-guide-video-$videoId',
                  accentColor: const Color(0xFFE5484D),
                  autoPlayWhenVisible: true,
                );
              },
            ),
          ],
          doNotRenderTheseTags: const {
            'script',
            'style',
            'iframe',
            'object',
            'embed',
          },
          style: {
            'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              color: const Color(0xFF393335),
              fontSize: FontSize(15),
              lineHeight: const LineHeight(1.7),
            ),
            'p': Style(margin: Margins.only(bottom: 10)),
            'h1': _headingStyle(22),
            'h2': _headingStyle(20),
            'h3': _headingStyle(18),
            'ul': Style(margin: Margins.only(bottom: 10, left: 18)),
            'ol': Style(margin: Margins.only(bottom: 10, left: 18)),
            'img': Style(
              display: Display.block,
              width: Width(100, Unit.percent),
              height: Height.auto(),
              margin: Margins.only(bottom: 10),
            ),
          },
        );
      },
    );
  }
}

class _RichContentImage extends StatelessWidget {
  const _RichContentImage({
    required this.imageId,
    required this.source,
    required this.width,
  });

  final String imageId;
  final String source;
  final double width;

  @override
  Widget build(BuildContext context) {
    final image = source.startsWith('data:')
        ? _memoryImage()
        : Image.network(
            source,
            key: ValueKey('aid-guide-image-source-$imageId'),
            width: width,
            fit: BoxFit.fitWidth,
            excludeFromSemantics: true,
            frameBuilder: _frameBuilder,
            errorBuilder: _errorBuilder,
          );
    return ClipRRect(
      key: ValueKey('aid-guide-image-$imageId'),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: width, child: image),
    );
  }

  Widget _memoryImage() {
    try {
      return Image.memory(
        UriData.parse(source).contentAsBytes(),
        key: ValueKey('aid-guide-image-source-$imageId'),
        width: width,
        fit: BoxFit.fitWidth,
        excludeFromSemantics: true,
        errorBuilder: _errorBuilder,
      );
    } on FormatException {
      return _imagePlaceholder(Icons.broken_image_outlined);
    }
  }

  Widget _frameBuilder(
    BuildContext context,
    Widget child,
    int? frame,
    bool wasSynchronouslyLoaded,
  ) {
    if (wasSynchronouslyLoaded || frame != null) return child;
    return _imagePlaceholder(Icons.image_outlined);
  }

  Widget _errorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) => _imagePlaceholder(Icons.broken_image_outlined);

  Widget _imagePlaceholder(IconData icon) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: const Color(0xFFF1F3F5),
        child: Center(child: Icon(icon, color: const Color(0xFF9CA3AF))),
      ),
    );
  }
}

bool _matchesRichVideo(ExtensionContext context) {
  if (context.elementName == 'div' &&
      context.attributes['data-w-e-type'] == 'video') {
    return true;
  }
  if (context.elementName != 'video') return false;

  var ancestor = context.element?.parent;
  while (ancestor != null) {
    if (ancestor.localName == 'div' &&
        ancestor.attributes['data-w-e-type'] == 'video') {
      return false;
    }
    ancestor = ancestor.parent;
  }
  return true;
}

RichTextVideoSource? _extractVideoSource(ExtensionContext context) {
  final element = context.element;
  if (element == null) return null;
  final video = context.elementName == 'video'
      ? element
      : element.querySelector('video');
  if (video == null) return null;

  final rawSource = video.attributes['src']?.trim().isNotEmpty == true
      ? video.attributes['src']
      : video.querySelector('source')?.attributes['src'];
  final uri = _resolveSafeNetworkUri(rawSource);
  if (uri == null) return null;

  return RichTextVideoSource(
    uri: uri,
    posterUri: _resolveSafeNetworkUri(video.attributes['poster']),
  );
}

Uri? _resolveSafeNetworkUri(String? value) {
  final resolved = resolveAssetUrl(value);
  final uri = Uri.tryParse(resolved);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}

class _UnavailableVideoBlock extends StatelessWidget {
  const _UnavailableVideoBlock({required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('aid-guide-video-unavailable-$videoId'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_outlined, color: Color(0xFF766B6D)),
          SizedBox(width: 8),
          Text(
            '视频地址无效',
            style: TextStyle(color: Color(0xFF766B6D), letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}

Style _headingStyle(double fontSize) {
  return Style(
    color: const Color(0xFF292325),
    fontSize: FontSize(fontSize),
    fontWeight: FontWeight.w700,
    margin: Margins.only(top: 10, bottom: 8),
  );
}
