import 'dart:convert';
import 'dart:io';

import 'package:ov_chronicles/core/demo_data.dart';

/// Export the reviewed prototype fixtures without importing Flutter widgets.
/// These records remain explicitly prepared demo writing, not approved facts.
void main() {
  final catalog = {
    'schemaVersion': 1,
    'contentKind': 'prepared-demo',
    'sites': [
      for (final site in demoSites)
        {
          'id': site.id,
          'name': site.name,
          'nameMn': site.nameMn,
          'summary': site.summary,
          'lat': site.lat,
          'lng': site.lng,
          'era': site.era,
          'imagePath': site.image.replaceFirst('assets/', 'catalog/'),
          'status': 'published',
          'contentKind': 'prepared-demo',
        },
    ],
    'templates': [
      for (final story in demoTemplates)
        {
          'id': story.id,
          'siteId': story.siteId,
          'title': story.title,
          'subtitle': story.subtitle,
          'imagePath': story.image.replaceFirst('assets/', 'catalog/'),
          'chapter': story.chapter,
          'genre': story.genre,
          'style': story.style,
          'mood': story.mood,
          'seed': story.seed,
          'nextIds': story.nextIds,
          'segments': [
            for (final segment in story.segments)
              {
                'text': segment.text,
                'kind': segment.kind,
                if (segment.citationId != null)
                  'citationId': segment.citationId,
              },
          ],
          'citations': [
            for (final citation in demoCitations.where(
              (citation) => story.segments.any(
                (segment) => segment.citationId == citation.id,
              ),
            ))
              {
                'id': citation.id,
                'title': citation.title,
                'author': citation.author,
                'page': citation.page,
                'note': citation.note,
                if (citation.url != null) 'url': citation.url,
              },
          ],
          'voiceIds': demoVoices.map((voice) => voice.id).toList(),
          'audioByVoice': <String, Object>{},
          'language': 'en',
          'contentVersion': 1,
          'contentKind': 'prepared-demo',
          'status': 'published',
        },
    ],
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(catalog));
}
