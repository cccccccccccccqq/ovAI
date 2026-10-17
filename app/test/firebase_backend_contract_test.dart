import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/backend/firebase_backend.dart';

final _createdAt = Timestamp.fromDate(DateTime.utc(2026, 10, 16, 8, 15));
final _updatedAt = Timestamp.fromDate(DateTime.utc(2026, 10, 16, 8, 20));

Map<String, dynamic> _storyContent() => {
  'siteId': 'kharkhorin',
  'title': 'The Silver Tree',
  'subtitle': 'A prepared story',
  'genre': 'Adventure',
  'style': 'Cinematic',
  'mood': 'Wonder',
  'seed': 'A traveller arrives',
  'chapter': 1,
  'segments': [
    {
      'text': 'Historical context.',
      'kind': 'context',
      'citationId': 'source-1',
    },
    {'text': 'A fictional traveller arrives.', 'kind': 'legend'},
  ],
  'citations': [
    {
      'id': 'source-1',
      'title': 'Source title',
      'author': 'Source author',
      'page': '42',
      'note': 'Editorial context',
      'url': 'https://example.org/source',
    },
  ],
  'imagePath': 'catalog/images/silver-tree.jpg',
  'nextIds': ['silver-tree-next'],
};

Map<String, dynamic> _chronicle() => {
  ..._storyContent(),
  'id': 'chronicle-1',
  'uid': 'user-1',
  'templateId': 'silver-tree',
  'voiceId': 'samantha',
  'language': 'en',
  'contentVersion': 1,
  'contentKind': 'prepared-demo',
  'status': 'ready',
  'audioStatus': 'ready',
  'audioPath': 'catalog/audio/samantha/silver-tree.m4a',
  'createdAt': _createdAt,
  'updatedAt': _updatedAt,
};

void main() {
  group('Firebase callable inputs', () {
    test('profile trims names and follows server length limit', () {
      expect(EnsureProfileRequest(displayName: '  Өв traveller  ').toJson(), {
        'displayName': 'Өв traveller',
      });
      expect(
        () => EnsureProfileRequest(displayName: '  '),
        throwsArgumentError,
      );
      expect(
        () => EnsureProfileRequest(displayName: 'x' * 61),
        throwsArgumentError,
      );
      expect(
        () => EnsureProfileRequest(displayName: 'name\nnext line'),
        throwsArgumentError,
      );
    });

    test('creation preserves retry identity and rejects unsafe IDs', () {
      final request = CreatePreparedChronicleRequest(
        requestId: 'attempt-1_saved',
        templateId: 'silver-tree',
        voiceId: 'samantha',
      );
      expect(request.toJson(), {
        'requestId': 'attempt-1_saved',
        'templateId': 'silver-tree',
        'voiceId': 'samantha',
      });
      for (final badId in ['', '../other', 'has space', '_start', 'x' * 129]) {
        expect(
          () => CreatePreparedChronicleRequest(
            requestId: badId,
            templateId: 'silver-tree',
            voiceId: 'samantha',
          ),
          throwsArgumentError,
        );
      }
      expect(
        () => CreatePreparedChronicleRequest(
          requestId: 'attempt-1',
          templateId: 'x' * 97,
          voiceId: 'samantha',
        ),
        throwsArgumentError,
      );
    });

    test(
      'library patch keeps explicit false and zero, omits absent fields',
      () {
        expect(
          PatchLibraryItemRequest(
            chronicleId: 'chronicle-1',
            bookmarked: false,
            readingProgress: 0,
            audioPositionMs: 0,
          ).toJson(),
          {
            'chronicleId': 'chronicle-1',
            'bookmarked': false,
            'readingProgress': 0.0,
            'audioPositionMs': 0,
          },
        );
        expect(
          PatchLibraryItemRequest(
            chronicleId: 'chronicle-1',
            bookmarked: true,
          ).toJson(),
          {'chronicleId': 'chronicle-1', 'bookmarked': true},
        );
        expect(
          () => PatchLibraryItemRequest(chronicleId: 'chronicle-1'),
          throwsArgumentError,
        );
        for (final progress in [-0.01, 1.01, double.nan, double.infinity]) {
          expect(
            () => PatchLibraryItemRequest(
              chronicleId: 'chronicle-1',
              readingProgress: progress,
            ),
            throwsArgumentError,
          );
        }
        for (final position in [-1, 86400001]) {
          expect(
            () => PatchLibraryItemRequest(
              chronicleId: 'chronicle-1',
              audioPositionMs: position,
            ),
            throwsArgumentError,
          );
        }
      },
    );
  });

  group('Firebase response and document contracts', () {
    test(
      'deleted creation replay is preserved rather than treated as ready',
      () {
        final result = CreatePreparedChronicleResult.fromJson({
          'chronicleId': 'chronicle-1',
          'status': 'deleted',
          'replayed': true,
        });
        expect(result.status, BackendChronicleStatus.deleted);
        expect(result.replayed, isTrue);
        expect(
          () => CreatePreparedChronicleResult.fromJson({
            'chronicleId': 'chronicle-1',
            'status': 'pending',
            'replayed': true,
          }),
          throwsFormatException,
        );
        expect(
          () => CreatePreparedChronicleResult.fromJson({
            'chronicleId': 'chronicle-1',
            'status': 'ready',
            'replayed': 'true',
          }),
          throwsFormatException,
        );
      },
    );

    test(
      'saved story owns its text, citations, version and Firestore timestamps',
      () {
        final data = _chronicle();
        final chronicle = BackendChronicle.fromDocument('chronicle-1', data);
        (data['segments'] as List).clear();
        expect(
          chronicle.content.plainText,
          'Historical context.\n\nA fictional traveller arrives.',
        );
        expect(chronicle.content.citations.single.page, '42');
        expect(chronicle.contentVersion, 1);
        expect(chronicle.createdAt, DateTime.utc(2026, 10, 16, 8, 15));
        expect(chronicle.createdAt.isUtc, isTrue);
        expect(chronicle.updatedAt, DateTime.utc(2026, 10, 16, 8, 20));
        expect(chronicle.audioStatus, BackendAudioStatus.ready);
        expect(chronicle.audioPath, 'catalog/audio/samantha/silver-tree.m4a');
        expect(
          () => chronicle.content.segments.clear(),
          throwsUnsupportedError,
        );
        expect(
          () => chronicle.content.citations.clear(),
          throwsUnsupportedError,
        );
      },
    );

    test('malformed timestamps and fractional versions fail explicitly', () {
      expect(
        () => BackendChronicle.fromDocument('chronicle-1', {
          ..._chronicle(),
          'createdAt': '2026-10-16',
        }),
        throwsFormatException,
      );
      expect(
        () => BackendChronicle.fromDocument('chronicle-1', {
          ..._chronicle(),
          'contentVersion': 1.5,
        }),
        throwsFormatException,
      );
    });

    test(
      'published template supports both unseeded and ready audio catalog',
      () {
        final data = {
          ..._storyContent(),
          'status': 'published',
          'contentVersion': 1,
          'language': 'en',
          'contentKind': 'prepared-demo',
          'voiceIds': ['samantha'],
          'audioByVoice': <String, dynamic>{},
        };
        expect(
          BackendStoryTemplate.fromDocument('silver-tree', data).audioByVoice,
          isEmpty,
        );
        data['audioByVoice'] = {
          'samantha': {
            'storagePath': 'catalog/audio/samantha/silver-tree.m4a',
            'status': 'ready',
          },
        };
        final template = BackendStoryTemplate.fromDocument('silver-tree', data);
        expect(
          template.audioByVoice['samantha']!.storagePath,
          contains('silver-tree.m4a'),
        );
        expect(() => template.audioByVoice.clear(), throwsUnsupportedError);
      },
    );

    test('library progress is separate from immutable story snapshot', () {
      final item = BackendLibraryItem.fromDocument('chronicle-1', {
        'uid': 'user-1',
        'chronicleId': 'chronicle-1',
        'title': 'The Silver Tree',
        'siteId': 'kharkhorin',
        'voiceId': 'samantha',
        'contentKind': 'prepared-demo',
        'bookmarked': true,
        'readingProgress': 0.45,
        'audioPositionMs': 12000,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt,
      });
      expect(item.bookmarked, isTrue);
      expect(item.readingProgress, 0.45);
      expect(item.audioPositionMs, 12000);
      expect(item.imagePath, isNull);
    });
  });
}
