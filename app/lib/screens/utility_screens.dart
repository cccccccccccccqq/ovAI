import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../auth/auth_scope.dart';

import '../core/app_scope.dart';
import '../core/app_state.dart';
import '../core/audio_controller.dart';
import '../core/download_controller.dart';
import '../core/legal.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../history/chapter_map.dart';
import '../widgets/common.dart';

Future<void> _attempt(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This action could not be saved. Please try again.'),
        ),
      );
    }
  }
}

void _message(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// A saved chapter is related to another only through its actual parentId.
Chronicle? _journeyRoot(AppState app, String? id) {
  Chronicle? current = id == null ? null : app.storyById(id);
  current ??= app.library
      .where((story) => story.siteId == 'kharkhorin')
      .firstOrNull;
  current ??= app.library.firstOrNull;
  final visited = <String>{};
  while (current != null &&
      current.parentId != null &&
      visited.add(current.id)) {
    final parent = app.storyById(current.parentId!);
    if (parent == null) break;
    current = parent;
  }
  return current;
}

List<Chronicle> _journeyChapters(AppState app, Chronicle root) {
  final chapters = <Chronicle>[];
  final visited = <String>{};
  void add(Chronicle chapter) {
    if (!visited.add(chapter.id)) return;
    chapters.add(chapter);
    final children =
        app.library.where((story) => story.parentId == chapter.id).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final child in children) {
      add(child);
    }
  }

  add(root);
  return chapters;
}

/// A playlist follows the selected branch. Other saved journeys are separate.
List<Chronicle> _playbackPath(AppState app, String? selectedId) {
  final root = _journeyRoot(app, selectedId);
  if (root == null) return [];
  final selected = selectedId == null
      ? root
      : app.storyById(selectedId) ?? root;
  final reversed = <Chronicle>[];
  var current = selected;
  final visited = <String>{};
  while (visited.add(current.id)) {
    reversed.add(current);
    final parent = current.parentId == null
        ? null
        : app.storyById(current.parentId!);
    if (parent == null) break;
    current = parent;
  }
  final path = reversed.reversed.toList();
  current = selected;
  while (true) {
    final children =
        app.library.where((story) => story.parentId == current.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (children.isEmpty || !visited.add(children.first.id)) break;
    current = children.first;
    path.add(current);
  }
  return path;
}

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key, this.id});
  final String? id;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final root = _journeyRoot(app, id);
    if (root == null) {
      return AppScaffold(
        title: 'Your first journey',
        eyebrow: 'Chapter by chapter',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: const AppImage(
                path: 'assets/images/silver-tree.jpg',
                height: 250,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 24),
            const DemoBadge(text: 'A PREPARED THREE-CHAPTER JOURNEY'),
            const SizedBox(height: 18),
            Text(
              'The Silver Tree of Karakorum',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Begin in Kharkhorin with William of Rubruck in 1254. Meet the goldsmith or walk the city, then carry the Khan\'s letter west. Your saved chapters and chosen branch will appear here.',
            ),
            const SizedBox(height: 24),
            PillButton(
              label: 'Begin the Kharkhorin journey',
              icon: Icons.route_outlined,
              onPressed: () => _attempt(context, () async {
                await app.selectSite('kharkhorin');
                await app.updateDraft(genre: 'Legend · domog');
                if (context.mounted) context.go('/inscribe/tone');
              }),
            ),
          ],
        ),
      );
    }
    final chapters = _journeyChapters(app, root);
    final rootTemplate = app.templateFor(root);
    final historicalPlaceIds = chapters
        .expand((story) => app.templateFor(story).historicalScenes)
        .map((scene) => scene.placeId)
        .toSet();
    final historicalPlaces = {
      for (final entry in app.historicalPlaces.entries)
        if (historicalPlaceIds.contains(entry.key)) entry.key: entry.value,
    };
    final completed = chapters
        .where((story) => story.readingProgress >= .95)
        .length;
    final branches = chapters
        .where((story) => app.templateFor(story).chapter == 2)
        .length;
    return AppScaffold(
      title: 'A journey through the steppe',
      eyebrow: app.siteById(root.siteId).name,
      actions: [
        IconButton(
          onPressed: () => context.push('/share/${root.id}'),
          icon: const Icon(Icons.ios_share_rounded),
          tooltip: 'Export journey card',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: AppImage(
              path: root.image,
              height: 215,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 20),
          const DemoBadge(text: 'YOUR SAVED CHAPTERS'),
          const SizedBox(height: 14),
          Text(root.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '$completed of ${chapters.length} saved chapters read${branches > 1 ? ' · $branches saved branches' : ''}',
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: chapters.isEmpty ? 0 : completed / chapters.length,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 24),
          PillButton(
            label: 'Listen to this journey',
            icon: Icons.headphones_rounded,
            onPressed: () => context.push('/playback?story=${id ?? root.id}'),
          ),
          const SizedBox(height: 28),
          const SectionHeading(
            title: 'The chapters you chose',
            subtitle: 'Each continuation stays linked to its previous chapter.',
          ),
          for (var index = 0; index < chapters.length; index++) ...[
            _ChapterTile(
              story: chapters[index],
              number: app.templateFor(chapters[index]).chapter,
              subtitle:
                  chapters[index].parentId == null ||
                      app.storyById(chapters[index].parentId!) == null
                  ? 'Journey begins here'
                  : 'After ${app.storyById(chapters[index].parentId!)!.title}',
              onTap: () => context.push('/reader/${chapters[index].id}'),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          if (rootTemplate.isHistorical && historicalPlaces.isNotEmpty)
            SizedBox(
              height: 240,
              child: ChapterMap(
                places: historicalPlaces,
                selectedPlaceId:
                    rootTemplate.historicalScenes.firstOrNull?.placeId,
                follow: false,
                onUserPan: () {},
              ),
            )
          else
            const DemoMap(compact: true),
          const SizedBox(height: 12),
          Text(
            rootTemplate.isHistorical
                ? 'Research regions for your saved chapters. These areas are not a reconstructed travel route.'
                : 'Illustrated Orkhon overview. Story chapters use their saved place; this is not a recorded travel route.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({
    required this.story,
    required this.number,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });
  final Chronicle story;
  final int number;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      leading: CircleAvatar(
        backgroundColor: selected ? OvColors.gold : OvColors.green,
        foregroundColor: selected ? OvColors.night : OvColors.cream,
        child: story.readingProgress >= .95
            ? const Icon(Icons.check_rounded)
            : Text('$number'),
      ),
      title: Text(story.title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(subtitle, style: const TextStyle(fontSize: 11)),
      ),
      trailing: Icon(
        selected ? Icons.equalizer_rounded : Icons.chevron_right_rounded,
        color: selected ? OvColors.gold : null,
      ),
      onTap: onTap,
    ),
  );
}

class PlaybackScreen extends StatefulWidget {
  const PlaybackScreen({super.key, this.id});
  final String? id;
  @override
  State<PlaybackScreen> createState() => _PlaybackScreenState();
}

class _PlaybackScreenState extends State<PlaybackScreen> {
  bool _initialized = false;
  String? _selectedId;
  String? _branchId;
  double? _scrubMs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = AppScope.of(context);
    final audio = AudioScope.of(context);
    _branchId = widget.id ?? audio.currentStoryId;
    final playlist = _playbackPath(app, _branchId);
    if (playlist.isEmpty) return;
    _selectedId = playlist.any((item) => item.id == _branchId)
        ? _branchId
        : playlist.first.id;
    final story = app.storyById(_selectedId!);
    if (story != null && audio.currentStoryId != story.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _attempt(context, () => audio.playStory(story, autoplay: false));
        }
      });
    }
  }

  Future<void> _select(Chronicle story) async {
    setState(() {
      _selectedId = story.id;
      _scrubMs = null;
    });
    await _attempt(context, () => AudioScope.of(context).playStory(story));
  }

  String _time(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final audio = AudioScope.of(context);
    final playlist = _playbackPath(app, _branchId);
    final story = app.storyById(_selectedId ?? '') ?? playlist.firstOrNull;
    if (story == null) {
      return AppScaffold(
        title: 'Journey playback',
        child: Column(
          children: [
            const SizedBox(height: 45),
            const Icon(
              Icons.headphones_outlined,
              size: 58,
              color: OvColors.gold,
            ),
            const SizedBox(height: 20),
            const Text(
              'Save your first prepared chapter to build a listening journey.',
            ),
            const SizedBox(height: 25),
            PillButton(
              label: 'Explore the journey',
              onPressed: () => context.go('/journey'),
            ),
          ],
        ),
      );
    }
    final index = playlist.indexWhere((item) => item.id == story.id);
    final isCurrent = audio.currentStoryId == story.id;
    return AppScaffold(
      title: 'Listen along the way',
      eyebrow: 'Journey playback',
      dark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DemoBadge(text: 'PREPARED NARRATION · MANUAL CHAPTER ADVANCE'),
          const SizedBox(height: 22),
          DemoMap(
            selectedSiteId: story.siteId,
            compact: true,
            showRoute: false,
          ),
          const SizedBox(height: 10),
          Text(
            'Chapter location · ${app.siteById(story.siteId).name}',
            style: const TextStyle(color: OvColors.gold, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Text(story.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '${app.voiceById(story.voiceId).name} · Chapter ${app.templateFor(story).chapter}',
            style: TextStyle(color: OvColors.cream.withValues(alpha: .75)),
          ),
          const SizedBox(height: 16),
          StreamBuilder<Duration?>(
            stream: audio.player.durationStream,
            initialData: audio.player.duration,
            builder: (context, durationSnapshot) => StreamBuilder<Duration>(
              stream: audio.player.positionStream,
              initialData: audio.player.position,
              builder: (context, positionSnapshot) {
                final duration = isCurrent
                    ? durationSnapshot.data ?? Duration.zero
                    : Duration.zero;
                final position = isCurrent
                    ? positionSnapshot.data ?? Duration.zero
                    : Duration(milliseconds: story.audioPositionMs);
                final maxMs = duration.inMilliseconds.toDouble();
                final value = (_scrubMs ?? position.inMilliseconds.toDouble())
                    .clamp(0.0, maxMs > 0 ? maxMs : 1.0);
                return Column(
                  children: [
                    Slider(
                      value: value,
                      min: 0,
                      max: maxMs > 0 ? maxMs : 1,
                      onChanged: !isCurrent || audio.loading || maxMs <= 0
                          ? null
                          : (value) => setState(() => _scrubMs = value),
                      onChangeEnd: !isCurrent || maxMs <= 0
                          ? null
                          : (value) async {
                              await _attempt(
                                context,
                                () => audio.seek(
                                  Duration(milliseconds: value.round()),
                                ),
                              );
                              if (mounted) setState(() => _scrubMs = null);
                            },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _time(position),
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          _time(duration),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          StreamBuilder<PlayerState>(
            stream: audio.player.playerStateStream,
            initialData: audio.player.playerState,
            builder: (context, snapshot) {
              final completed =
                  isCurrent &&
                  snapshot.data?.processingState == ProcessingState.completed;
              final playing =
                  isCurrent && (snapshot.data?.playing ?? false) && !completed;
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: index <= 0
                            ? null
                            : () => _select(playlist[index - 1]),
                        icon: const Icon(Icons.skip_previous_rounded, size: 32),
                        tooltip: 'Previous saved chapter',
                      ),
                      const SizedBox(width: 22),
                      FilledButton(
                        onPressed: audio.loading
                            ? null
                            : () => _attempt(context, () async {
                                if (!isCurrent || audio.error != null) {
                                  await audio.playStory(story);
                                } else {
                                  await audio.toggle();
                                }
                              }),
                        style: FilledButton.styleFrom(
                          backgroundColor: OvColors.gold,
                          foregroundColor: OvColors.night,
                          shape: const CircleBorder(),
                          minimumSize: const Size(78, 78),
                        ),
                        child: audio.loading
                            ? const SizedBox(
                                width: 25,
                                height: 25,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : completed
                                    ? Icons.replay_rounded
                                    : Icons.play_arrow_rounded,
                                size: 38,
                              ),
                      ),
                      const SizedBox(width: 22),
                      IconButton(
                        onPressed: index < 0 || index >= playlist.length - 1
                            ? null
                            : () => _select(playlist[index + 1]),
                        icon: const Icon(Icons.skip_next_rounded, size: 32),
                        tooltip: 'Next saved chapter',
                      ),
                    ],
                  ),
                  if (completed)
                    const Padding(
                      padding: EdgeInsets.only(top: 15),
                      child: Text(
                        'Chapter complete. Choose the next chapter when you are ready.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: OvColors.gold, fontSize: 12),
                      ),
                    ),
                ],
              );
            },
          ),
          if (audio.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                audio.error!,
                style: const TextStyle(color: Color(0xffe9a28e)),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Playback speed  ', style: TextStyle(fontSize: 12)),
              DropdownButton<double>(
                value: [0.75, 1.0, 1.25, 1.5, 2.0].contains(app.playbackSpeed)
                    ? app.playbackSpeed
                    : null,
                hint: Text('${app.playbackSpeed}×'),
                items: [0.75, 1.0, 1.25, 1.5, 2.0]
                    .map(
                      (speed) => DropdownMenuItem(
                        value: speed,
                        child: Text('$speed×'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    _attempt(context, () => audio.setSpeed(value));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Saved branch playlist',
            subtitle:
                'Only the selected journey is included. No chapter starts automatically.',
          ),
          for (final chapter in playlist) ...[
            _ChapterTile(
              story: chapter,
              number: app.templateFor(chapter).chapter,
              subtitle: app.siteById(chapter.siteId).name,
              selected: chapter.id == story.id,
              onTap: () => _select(chapter),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          PillButton(
            label: 'Open this chapter',
            icon: Icons.auto_stories_outlined,
            secondary: true,
            onPressed: () => context.push('/reader/${story.id}'),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double? _scale;
  bool _resetting = false;

  Future<void> _reset() async {
    final cloud = AppScope.of(context).usesCloudBackend;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cloud ? 'Reset this device?' : 'Reset this device?'),
        content: Text(
          cloud
              ? 'Clear downloaded packs, drafts, saved places and reading settings from this device. Stories and progress saved to your account will remain.'
              : 'This removes saved stories, profile, queued drafts, downloaded pack files and settings from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cloud ? 'Keep my settings' : 'Keep my data'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(cloud ? 'Reset device' : 'Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final downloads = DownloadScope.of(context);
    final audio = AudioScope.of(context);
    final app = AppScope.of(context);
    setState(() => _resetting = true);
    try {
      for (final id in downloads.busy.toList()) {
        downloads.cancel(id);
      }
      // Active copies finish their cancellation cleanup before reset removes files.
      final cancelDeadline = DateTime.now().add(const Duration(seconds: 10));
      while (downloads.busy.isNotEmpty) {
        if (DateTime.now().isAfter(cancelDeadline)) {
          throw StateError('Pack cancellation timed out.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
        if (!mounted) return;
      }
      for (final site in app.sites) {
        await downloads.remove(site.id);
      }
      await audio.stop();
      await app.resetDemo();
      if (mounted) context.go('/');
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'Some local files could not be removed. Please retry the reset.',
        );
      }
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final audio = AudioScope.of(context);
    final scale = _scale ?? app.textScale;
    final auth = AuthScope.maybeOf(context);
    return AppScaffold(
      title: 'Make it yours',
      eyebrow: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DemoBadge(
            text: app.usesCloudBackend
                ? 'READING SETTINGS · ON THIS DEVICE'
                : 'SAVED ON THIS DEVICE',
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: OvColors.green,
                    foregroundColor: OvColors.gold,
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.profileName ??
                              (app.isGuest
                                  ? 'Guest traveller'
                                  : 'Your local profile'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          auth?.isSignedIn == true
                              ? app.usesCloudBackend
                                    ? 'Stories saved to your account'
                                    : 'Account library · device storage'
                              : 'Guest profile · device storage',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeading(title: 'Reading'),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Night reading'),
            subtitle: const Text('A deep green canvas for your stories'),
            value: app.darkMode,
            onChanged: _resetting
                ? null
                : (value) => _attempt(context, () => app.setDarkMode(value)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Text size'),
              Text(
                '${(scale * 100).round()}%',
                style: const TextStyle(color: OvColors.gold),
              ),
            ],
          ),
          Slider(
            value: scale,
            min: .85,
            max: 1.5,
            divisions: 13,
            label: '${(scale * 100).round()}%',
            onChanged: _resetting
                ? null
                : (value) => setState(() => _scale = value),
            onChangeEnd: _resetting
                ? null
                : (value) async {
                    await _attempt(context, () => app.setTextScale(value));
                    if (mounted) setState(() => _scale = null);
                  },
          ),
          Card(
            margin: EdgeInsets.zero,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Every road carries a story. Take a moment to listen.',
                style: TextStyle(fontSize: 18, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeading(title: 'Listening'),
          DropdownButtonFormField<double>(
            initialValue:
                [0.75, 1.0, 1.25, 1.5, 2.0].contains(app.playbackSpeed)
                ? app.playbackSpeed
                : 1,
            decoration: const InputDecoration(labelText: 'Narration speed'),
            items: [0.75, 1.0, 1.25, 1.5, 2.0]
                .map(
                  (speed) =>
                      DropdownMenuItem(value: speed, child: Text('$speed×')),
                )
                .toList(),
            onChanged: _resetting
                ? null
                : (value) {
                    if (value != null) {
                      _attempt(context, () => audio.setSpeed(value));
                    }
                  },
          ),
          const SizedBox(height: 28),
          const SectionHeading(title: 'Out on the steppe'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Location & nearby stories'),
            subtitle: const Text(
              'Foreground permission is requested on the map',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/field'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('Downloaded packs'),
            subtitle: Text('${app.installedPacks.length} on this device'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/downloads'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('Offline mode'),
            subtitle: Text(
              app.usesCloudBackend
                  ? 'Read saved stories and keep new drafts on this device until you are online.'
                  : 'Try the queue and explicit resume flow. Prepared stories remain readable.',
            ),
            value: app.offline,
            onChanged: _resetting
                ? null
                : (value) => _attempt(context, () => app.setOffline(value)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.outbox_outlined),
            title: const Text('Queued drafts'),
            subtitle: Text('${app.queuedDrafts.length} waiting for you'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/offline'),
          ),
          const SizedBox(height: 28),
          const SectionHeading(title: 'About öv AI'),
          Text(
            app.usesCloudBackend
                ? 'öv AI · v0.1\nPrepared stories and recorded narration. Stories and reading progress are saved to your account. Reading settings, drafts, saved places and downloads stay on this device.'
                : 'öv AI · v0.1\nPrepared editorial stories and system narration. Profiles, stories and progress are stored locally. AI generation and account sync are planned for a later version.',
            style: TextStyle(fontSize: 12),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new_rounded, size: 18),
            onTap: () => openPrivacyPolicy(context),
          ),
          const SizedBox(height: 18),
          PillButton(
            label: app.usesCloudBackend
                ? 'Reset device settings'
                : 'Reset this device',
            icon: Icons.restart_alt_rounded,
            secondary: true,
            busy: _resetting,
            onPressed: _reset,
          ),
        ],
      ),
    );
  }
}

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  bool _inspected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inspected) return;
    _inspected = true;
    final downloads = DownloadScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _attempt(context, downloads.inspect);
    });
  }

  String _bytes(int bytes) => bytes >= 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(0)} KB';

  Future<void> _read(String siteId) async {
    final app = AppScope.of(context);
    final template = app.defaultTemplateForSite(siteId);
    await _attempt(context, () async {
      final existing = app.library
          .where((story) => story.templateId == template.id)
          .firstOrNull;
      final story =
          existing ?? await app.createChronicle(templateId: template.id);
      if (mounted) context.push('/reader/${story.id}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final downloads = DownloadScope.of(context);
    final total = downloads.byteCounts.values.fold<int>(
      0,
      (sum, bytes) => sum + bytes,
    );
    return AppScaffold(
      title: 'Carry a little history',
      eyebrow: 'Downloads',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DemoBadge(text: 'BUNDLED STORY PACKS'),
          const SizedBox(height: 18),
          const Text(
            'Install a cover, prepared story and Samantha narration into local storage. These packs are bundled with the app; they do not include map tiles.',
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: OvColors.gold,
                    size: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${app.installedPacks.length} of ${app.sites.length} packs installed',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${_bytes(total)} of local pack files',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          for (final site in app.sites) ...[
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppImage(
                    path: site.image,
                    height: 135,
                    width: double.infinity,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          site.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          app.defaultTemplateForSite(site.id).title,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        if (downloads.busy.contains(site.id)) ...[
                          LinearProgressIndicator(
                            value: downloads.progress[site.id] ?? 0,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Installing bundled files · ${((downloads.progress[site.id] ?? 0) * 100).round()}%',
                            style: const TextStyle(fontSize: 12),
                          ),
                          TextButton.icon(
                            onPressed: () => downloads.cancel(site.id),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Cancel install'),
                          ),
                        ] else if (app.installedPacks.contains(site.id)) ...[
                          Text(
                            'Installed · ${_bytes(downloads.byteCounts[site.id] ?? 0)}',
                            style: const TextStyle(
                              color: OvColors.gold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _read(site.id),
                                  icon: const Icon(
                                    Icons.auto_stories_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Read story'),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _attempt(
                                  context,
                                  () => downloads.remove(site.id),
                                ),
                                icon: const Icon(Icons.delete_outline_rounded),
                                tooltip: 'Remove ${site.name} pack',
                              ),
                            ],
                          ),
                        ] else ...[
                          // Stories are bundled, so reading never waits for
                          // an install; the pack only adds offline storage.
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _read(site.id),
                              icon: const Icon(
                                Icons.auto_stories_outlined,
                                size: 18,
                              ),
                              label: const Text('Read story'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          PillButton(
                            label: 'Save for offline',
                            icon: Icons.download_rounded,
                            secondary: true,
                            onPressed: () => _attempt(
                              context,
                              () => downloads.install(site.id),
                            ),
                          ),
                        ],
                        if (downloads.errors[site.id] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              downloads.errors[site.id]!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          const Text(
            'Saved library stories stay available when a pack is removed. Device storage or browser data clearing removes local pack files.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});
  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  String? _resumingId;

  Future<void> _resume(ChronicleDraft draft) async {
    final app = AppScope.of(context);
    if (app.isGuest) {
      context.push('/profile-setup?next=%2Foffline');
      return;
    }
    setState(() => _resumingId = draft.id);
    try {
      await app.setOffline(false);
      await app.restoreQueuedDraft(draft.id);
      final story = await app.createChronicle();
      try {
        await app.removeQueuedDraft(draft.id);
      } catch (_) {
        if (mounted) {
          _message(
            context,
            'Story saved. Its queue entry could not be removed; you can cancel it from the queue.',
          );
        }
      }
      if (mounted) context.go('/reader/${story.id}');
    } catch (_) {
      if (mounted) {
        _message(
          context,
          'The draft could not be resumed. It remains in your queue.',
        );
      }
    } finally {
      if (mounted) setState(() => _resumingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AppScaffold(
      title: 'Keep the story with you',
      eyebrow: 'Offline & drafts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DemoBadge(
            text: app.usesCloudBackend
                ? 'DRAFTS ON THIS DEVICE'
                : 'QUEUED ON THIS DEVICE',
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile.adaptive(
              secondary: Icon(
                app.offline
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                color: OvColors.gold,
              ),
              title: Text(
                app.usesCloudBackend
                    ? app.offline
                          ? 'Offline mode is on'
                          : 'Offline mode is off'
                    : app.offline
                    ? 'Offline mode is on'
                    : 'Offline mode is off',
              ),
              subtitle: Text(
                app.usesCloudBackend
                    ? 'Read saved stories offline. Turn this off before saving a new chronicle to your account.'
                    : 'This switch simulates connection state. Stories are prepared on this device.',
              ),
              value: app.offline,
              onChanged: _resumingId != null
                  ? null
                  : (value) => _attempt(context, () => app.setOffline(value)),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Queue your selection now, then explicitly resume it when you are ready. öv AI does not create stories in the background or send notifications.',
          ),
          const SizedBox(height: 18),
          PillButton(
            label: 'Queue my current draft',
            icon: Icons.add_rounded,
            secondary: true,
            onPressed: _resumingId != null
                ? null
                : () => _attempt(context, () async {
                    await app.queueDraft();
                    if (context.mounted) {
                      _message(context, 'Your draft is in the local queue.');
                    }
                  }),
          ),
          const SizedBox(height: 28),
          SectionHeading(
            title: 'Waiting for your next step',
            subtitle:
                '${app.queuedDrafts.length} queued ${app.queuedDrafts.length == 1 ? 'draft' : 'drafts'}',
          ),
          if (app.queuedDrafts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'Your queue is empty. Your current draft stays saved as you explore.',
                ),
              ),
            ),
          for (final draft in app.queuedDrafts) ...[
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.siteById(draft.siteId).name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${draft.genre}\n${draft.style} · ${draft.mood}\n${app.voiceById(draft.voiceId).name}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      draft.seed,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PillButton(
                      label: 'Resume prepared story',
                      icon: Icons.play_arrow_rounded,
                      busy: _resumingId == draft.id,
                      onPressed: _resumingId != null
                          ? null
                          : () => _resume(draft),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        TextButton.icon(
                          onPressed: _resumingId != null
                              ? null
                              : () => _attempt(context, () async {
                                  await app.restoreQueuedDraft(draft.id);
                                  if (context.mounted) {
                                    context.go('/inscribe/tone');
                                  }
                                }),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit selection'),
                        ),
                        TextButton.icon(
                          onPressed: _resumingId != null
                              ? null
                              : () => _attempt(
                                  context,
                                  () => app.removeQueuedDraft(draft.id),
                                ),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Cancel draft'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 20),
          const SectionHeading(
            title: 'Read while you wait',
            subtitle:
                'Prepared library stories and downloaded packs work without a connection.',
          ),
          PillButton(
            label: 'Open my saved scrolls',
            icon: Icons.auto_stories_outlined,
            secondary: true,
            onPressed: () => context.push('/scrolls'),
          ),
          const SizedBox(height: 10),
          PillButton(
            label: 'Manage downloads',
            icon: Icons.download_outlined,
            secondary: true,
            onPressed: () => context.push('/downloads'),
          ),
        ],
      ),
    );
  }
}
