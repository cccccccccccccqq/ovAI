import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/history/chapter_models.dart';

Map<String, dynamic> seedChapter() {
  final data =
      jsonDecode(
            File('../seed/secret-history-chapter-1.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  return Map<String, dynamic>.from((data['chapters'] as List).first as Map);
}

void main() {
  test('actual imported chapter has continuous four-minute map cues', () {
    final data = seedChapter();
    final chapter = HistoricalChapter.fromDocument('onon-child', data);
    expect(chapter.durationMs, 240000);
    expect(chapter.sourceSections, [59, 60, 61, 62, 63, 64, 65, 66]);
    expect(chapter.narration, contains('Тэмүжин'));
    expect(chapter.audioPath, startsWith('catalog/secret-history/'));
    expect(chapter.sceneAt(0), chapter.scenes.first);
    for (var i = 1; i < chapter.scenes.length; i++) {
      final boundary = chapter.scenes[i].startMs;
      expect(chapter.scenes[i - 1].endMs, boundary);
      expect(chapter.sceneAt(boundary - 1), chapter.scenes[i - 1]);
      expect(chapter.sceneAt(boundary), chapter.scenes[i]);
    }
    expect(chapter.scenes.last.endMs, chapter.durationMs);
    expect(chapter.sceneAt(chapter.durationMs), chapter.scenes.last);
  });

  test(
    'edited audio does not resume using timestamps from an older version',
    () {
      final chapter = HistoricalChapter.fromDocument(
        'onon-child',
        seedChapter(),
      );
      final old = ChapterProgress(
        contentVersion: chapter.contentVersion - 1,
        audioPositionMs: 92000,
        bookmarked: true,
        completed: true,
      ).forChapter(chapter);
      expect(old.audioPositionMs, 0);
      expect(old.completed, false);
      expect(old.bookmarked, true);
      expect(old.contentVersion, chapter.contentVersion);
      final current = ChapterProgress(
        contentVersion: chapter.contentVersion,
        audioPositionMs: 92000,
      ).forChapter(chapter);
      expect(current.audioPositionMs, 92000);
    },
  );

  test('draft chapters and cues beyond the audio cannot be loaded', () {
    expect(
      () => HistoricalChapter.fromDocument('onon-child', {
        ...seedChapter(),
        'status': 'draft',
      }),
      throwsFormatException,
    );
    final data = seedChapter();
    (data['scenes'] as List).first['endMs'] = 240001;
    expect(
      () => HistoricalChapter.fromDocument('onon-child', data),
      throwsFormatException,
    );
  });
}
