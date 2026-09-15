import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/config/api_config.dart';
import '../../../core/media/rich_text_video_player.dart';
import '../../../core/network/asset_url_resolver.dart';
import 'mall_json.dart';

class MallRichText extends StatelessWidget {
  const MallRichText({
    super.key,
    required this.content,
    this.baseUrl = ApiConfig.baseUrl,
  });

  final String content;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    final html = content.trim();
    if (html.isEmpty) {
      return const Text(
        '暂无商品描述',
        style: TextStyle(color: Color(0xFF5F6673), height: 1.6),
      );
    }

    final document = HtmlParser.parseHTML(html);
    for (final image in document.querySelectorAll('img')) {
      final source = image.attributes['src']?.trim() ?? '';
      if (source.isEmpty || source.startsWith('data:')) continue;
      image.attributes['src'] = source.startsWith('//')
          ? 'https:$source'
          : resolveMallImage(baseUrl, source);
      image.attributes.remove('width');
      image.attributes.remove('height');
    }

    var videoIndex = 0;
    for (final wrapper in document.querySelectorAll(
      'div[data-w-e-type="video"]',
    )) {
      wrapper.attributes['data-flutter-video-id'] = '${videoIndex++}';
    }
    for (final video in document.querySelectorAll('video')) {
      var ancestor = video.parent;
      var wrappedByWangEditor = false;
      while (ancestor != null) {
        if (ancestor.localName == 'div' &&
            ancestor.attributes['data-w-e-type'] == 'video') {
          wrappedByWangEditor = true;
          break;
        }
        ancestor = ancestor.parent;
      }
      if (wrappedByWangEditor) continue;
      video.attributes['data-flutter-video-id'] = '${videoIndex++}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        return Html.fromElement(
          documentElement: document,
          shrinkWrap: true,
          extensions: [
            ImageExtension(
              handleAssetImages: false,
              handleDataImages: false,
              builder: (context) => _MallRichImage(
                url: context.attributes['src'] ?? '',
                width: contentWidth,
              ),
            ),
            MatcherExtension(
              matcher: _matchesMallRichVideo,
              builder: (context) {
                final videoId =
                    context.attributes['data-flutter-video-id'] ??
                    'raw-${context.node.hashCode}';
                final source = _extractMallVideoSource(context, baseUrl);
                if (source == null) {
                  return UnavailableRichTextVideo(
                    key: ValueKey('mall-rich-video-unavailable-$videoId'),
                    foregroundColor: const Color(0xFF5F6673),
                  );
                }
                return RichTextVideoPlayer(
                  key: ValueKey('mall-rich-video-state-$videoId'),
                  source: source,
                  width: contentWidth,
                  semanticsKey: ValueKey('mall-rich-video-$videoId'),
                  semanticLabel: '商品详情视频播放器',
                  controlKeyPrefix: 'mall-rich-video',
                  accentColor: const Color(0xFF5875E8),
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
              color: const Color(0xFF333333),
              fontSize: FontSize(15),
              lineHeight: const LineHeight(1.6),
            ),
            'p': Style(margin: Margins.only(bottom: 10)),
            'h1': _headingStyle(22),
            'h2': _headingStyle(20),
            'h3': _headingStyle(18),
            'h4': _headingStyle(16),
            'ul': Style(margin: Margins.only(bottom: 10, left: 18)),
            'ol': Style(margin: Margins.only(bottom: 10, left: 18)),
            'li': Style(lineHeight: const LineHeight(1.6)),
            'a': Style(
              color: const Color(0xFF5875E8),
              textDecoration: TextDecoration.underline,
            ),
            'blockquote': Style(
              color: const Color(0xFF5F6673),
              margin: Margins.only(top: 8, bottom: 8),
              padding: HtmlPaddings.only(left: 12),
              border: const Border(
                left: BorderSide(color: Color(0xFFDDE1E8), width: 4),
              ),
            ),
            'img': Style(
              display: Display.block,
              width: Width(contentWidth),
              height: Height.auto(),
              margin: Margins.only(bottom: 8),
            ),
          },
        );
      },
    );
  }

  static Style _headingStyle(double fontSize) {
    return Style(
      color: const Color(0xFF1F2329),
      fontSize: FontSize(fontSize),
      fontWeight: FontWeight.w600,
      margin: Margins.only(top: 10, bottom: 8),
    );
  }
}

bool _mallVideoHasWangEditorAncestor(ExtensionContext context) {
  var ancestor = context.element?.parent;
  while (ancestor != null) {
    if (ancestor.localName == 'div' &&
        ancestor.attributes['data-w-e-type'] == 'video') {
      return true;
    }
    ancestor = ancestor.parent;
  }
  return false;
}

bool _matchesMallRichVideo(ExtensionContext context) {
  if (context.elementName == 'div' &&
      context.attributes['data-w-e-type'] == 'video') {
    return true;
  }
  return context.elementName == 'video' &&
      !_mallVideoHasWangEditorAncestor(context);
}

RichTextVideoSource? _extractMallVideoSource(
  ExtensionContext context,
  String baseUrl,
) {
  final element = context.element;
  if (element == null) return null;
  final video = context.elementName == 'video'
      ? element
      : element.querySelector('video');
  if (video == null) return null;

  final directSource = video.attributes['src']?.trim();
  final rawSource = directSource?.isNotEmpty == true
      ? directSource
      : video.querySelector('source')?.attributes['src'];
  final uri = _resolveMallVideoUri(rawSource, baseUrl);
  if (uri == null) return null;

  return RichTextVideoSource(
    uri: uri,
    posterUri: _resolveMallVideoUri(video.attributes['poster'], baseUrl),
  );
}

Uri? _resolveMallVideoUri(String? value, String baseUrl) {
  final source = value?.trim() ?? '';
  if (source.isEmpty) return null;
  final resolved = source.startsWith('//')
      ? 'https:$source'
      : resolveAssetUrl(source, assetBaseUrl: baseUrl);
  final uri = Uri.tryParse(resolved);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  return uri;
}

class _MallRichImage extends StatelessWidget {
  const _MallRichImage({required this.url, required this.width});

  final String url;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Image.network(
        url,
        width: width,
        fit: BoxFit.fitWidth,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _placeholder(icon: Icons.image_outlined);
        },
        errorBuilder: (context, error, stackTrace) {
          return _placeholder(icon: Icons.broken_image_outlined);
        },
      ),
    );
  }

  Widget _placeholder({required IconData icon}) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ColoredBox(
        color: const Color(0xFFF0F2F5),
        child: Center(
          child: Icon(icon, color: const Color(0xFFB8BEC9), size: 40),
        ),
      ),
    );
  }
}
