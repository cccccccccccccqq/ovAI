import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_scope.dart';
import '../core/audio_controller.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key});

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  bool _picking = false;
  String? _error;

  Future<void> _pickPhoto(ImageSource source) async {
    if (_picking) return;
    final app = AppScope.of(context);
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 82,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('Choose a photo smaller than 8 MB.');
      }
      final mime =
          photo.mimeType ??
          (photo.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg');
      await app.updateDraft(
        coverPath: 'data:$mime;base64,${base64Encode(bytes)}',
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code.toLowerCase().contains('denied')
            ? 'Photo access was declined. Allow access in device settings, or choose a prepared cover below.'
            : 'The camera or photo library is unavailable here. Try Photo library, or choose a prepared cover.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is FormatException
            ? error.message
            : 'This device could not open that image. Try another photo or a prepared cover.';
      });
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _chooseCover({bool illustrations = false}) async {
    final app = AppScope.of(context);
    final covers = {
      if (illustrations) 'assets/images/silver-tree.jpg',
      if (illustrations) 'assets/images/landscape.jpg',
      for (final site in app.sites) site.image,
    }.toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: OvColors.cream,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                illustrations ? 'Prepared illustrations' : 'Choose your canvas',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: OvColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bundled artwork for this prototype. Your photo is used only as the cover.',
                style: TextStyle(
                  color: OvColors.body,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: covers.length,
                  itemBuilder: (context, index) => InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      await app.updateDraft(coverPath: covers[index]);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AppImage(path: covers[index], fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final site = app.selectedSite;
    return AppScaffold(
      title: 'New chronicle',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CreationSteps(current: 0),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: _paperDecoration(context),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: _accentColor(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: site.id,
                      isExpanded: true,
                      dropdownColor: _panelColor(context),
                      style: TextStyle(
                        color: _headingColor(context),
                        fontSize: 15,
                      ),
                      items: app.sites
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (id) async {
                        if (id != null) await app.selectSite(id);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 18, left: 4),
            child: Text(
              site.era,
              style: TextStyle(color: _mutedColor(context), fontSize: 13),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                AppImage(
                  path: app.draft.coverPath ?? site.image,
                  height: 232,
                  width: double.infinity,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          OvColors.night.withValues(alpha: .85),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR CANVAS',
                        style: TextStyle(
                          color: OvColors.gold,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'A cover for the story you carry',
                        style: TextStyle(color: OvColors.cream, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _FieldLabel('START FROM'),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _CanvasOption(
                    width: width,
                    icon: Icons.camera_alt_outlined,
                    title: 'Camera',
                    description: kIsWeb
                        ? 'Use a device camera if supported'
                        : 'Capture a moment on the steppe',
                    onTap: _picking
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                  ),
                  _CanvasOption(
                    width: width,
                    icon: Icons.photo_library_outlined,
                    title: 'Photo library',
                    description: 'A photo from your journey',
                    onTap: _picking
                        ? null
                        : () => _pickPhoto(ImageSource.gallery),
                  ),
                  _CanvasOption(
                    width: width,
                    icon: Icons.landscape_outlined,
                    title: 'Landscape',
                    description: 'Prepared covers from the valley',
                    onTap: () => _chooseCover(),
                  ),
                  _CanvasOption(
                    width: width,
                    icon: Icons.draw_outlined,
                    title: 'Illustration',
                    description: 'Choose bundled artwork',
                    onTap: () => _chooseCover(illustrations: true),
                  ),
                ],
              );
            },
          ),
          if (_picking)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null) _Notice(_error!, icon: Icons.info_outline),
          const SizedBox(height: 20),
          const DemoBadge(text: 'Prepared stories · photos become covers'),
          const SizedBox(height: 24),
          PillButton(
            label: 'Next: set the tone',
            icon: Icons.arrow_forward,
            onPressed: () => context.push('/inscribe/tone'),
          ),
        ],
      ),
    );
  }
}

class ToneScreen extends StatelessWidget {
  const ToneScreen({super.key});

  Future<void> _select(BuildContext context, StoryTemplate template) async {
    await AppScope.of(context).updateDraft(
      genre: template.genre,
      style: template.style,
      mood: template.mood,
      seed: template.seed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final selected = app.draftTemplate;
    final presets = app
        .templatesForSite(app.draft.siteId)
        .where((item) => item.chapter == 1)
        .toList();
    Widget options(String label, String Function(StoryTemplate) value) {
      final values = presets.map(value).toSet().toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (item) => ChoiceChip(
                    label: Text(item),
                    selected: value(selected) == item,
                    selectedColor: OvColors.green,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: value(selected) == item
                          ? OvColors.cream
                          : OvColors.ink,
                      fontSize: 13,
                    ),
                    checkmarkColor: OvColors.gold,
                    side: BorderSide(
                      color: value(selected) == item
                          ? OvColors.green
                          : const Color(0xffd8d6cc),
                    ),
                    onSelected: (_) => _select(
                      context,
                      presets.firstWhere((preset) => value(preset) == item),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    return AppScaffold(
      title: app.selectedSite.name,
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CreationSteps(current: 1),
          const SizedBox(height: 24),
          const DemoBadge(text: 'Choose a prepared story preset'),
          const SizedBox(height: 12),
          Text(
            'Each preset has its own text and matching narration. Changing a choice also selects its supported style, mood and seed.',
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          options('GENRE', (item) => item.genre),
          options('LITERARY VOICE', (item) => item.style),
          options('MOOD', (item) => item.mood),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _FieldLabel('STORY SEED'),
              TextButton.icon(
                onPressed: presets.length < 2
                    ? null
                    : () {
                        final index = presets.indexWhere(
                          (item) => item.id == selected.id,
                        );
                        _select(context, presets[(index + 1) % presets.length]);
                      },
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: const Text('Try another'),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: OvColors.green,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREPARED SEED · ${presets.indexWhere((item) => item.id == selected.id) + 1} OF ${presets.length}',
                  style: const TextStyle(
                    color: OvColors.gold,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selected.seed,
                  style: const TextStyle(
                    color: OvColors.cream,
                    fontSize: 18,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  selected.title,
                  style: TextStyle(
                    color: OvColors.cream.withValues(alpha: .75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            selected.isHistorical
                ? 'An original English synopsis of The Secret History of the Mongols. Source sections and uncertain locations are noted in the chapter.'
                : 'Original demo writing inspired by the setting. Historical context is separated from imagined scenes.',
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          PillButton(
            label: 'Next: choose a voice',
            icon: Icons.arrow_forward,
            onPressed: () => context.push('/inscribe/voice'),
          ),
        ],
      ),
    );
  }
}

class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  String? _previewing;

  Future<void> _preview(String voiceId) async {
    final audio = AudioScope.of(context);
    setState(() => _previewing = voiceId);
    await audio.previewVoice(voiceId);
    if (mounted) setState(() => _previewing = null);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final draft = app.draft;
    final audio = AudioScope.of(context);
    return AppScaffold(
      title: app.selectedSite.name,
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CreationSteps(current: 2),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Who tells the story?',
            subtitle: 'A voice to carry your chronicle across the steppe.',
          ),
          const SizedBox(height: 12),
          const DemoBadge(text: 'Recorded system voices · English demo'),
          const SizedBox(height: 18),
          for (final voice in app.voices) ...[
            Container(
              decoration: _paperDecoration(
                context,
                selected: draft.voiceId == voice.id,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => app.updateDraft(voiceId: voice.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              draft.voiceId == voice.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _accentColor(context),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    voice.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _headingColor(context),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    voice.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: _mutedColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Preview ${voice.name}',
                    onPressed: _previewing == null
                        ? () => _preview(voice.id)
                        : null,
                    icon: _previewing == voice.id
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.play_circle_outline,
                            color: _accentColor(context),
                            size: 30,
                          ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (audio.error != null)
            _Notice(
              '${audio.error} Tap a preview to retry.',
              icon: Icons.volume_off_outlined,
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: OvColors.green.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryLine('Place', app.selectedSite.name),
                _SummaryLine('Genre', draft.genre),
                _SummaryLine('Style', draft.style),
                _SummaryLine('Mood', draft.mood),
                _SummaryLine('Seed', draft.seed),
                _SummaryLine('Narrator', app.voiceById(draft.voiceId).name),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PillButton(
            label: app.offline ? 'Save for later' : 'Prepare my chronicle',
            icon: Icons.draw_outlined,
            onPressed: () async {
              await audio.stop();
              if (!context.mounted) return;
              if (app.isGuest) {
                context.push('/profile-setup?next=%2Finscribe%2Fvoice');
              } else if (app.offline) {
                await app.queueDraft();
                if (context.mounted) context.push('/offline');
              } else {
                context.push('/writing');
              }
            },
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Prepared content · no credits or live AI required',
              style: TextStyle(color: _mutedColor(context), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class WritingScreen extends StatefulWidget {
  const WritingScreen({super.key});

  @override
  State<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends State<WritingScreen> {
  int _stage = 0;
  int _token = 0;
  bool _started = false;
  bool _running = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepare();
      });
    }
  }

  Future<void> _prepare() async {
    if (_running) return;
    final token = ++_token;
    final app = AppScope.of(context);
    if (app.isGuest) {
      context.go('/profile-setup?next=%2Finscribe%2Fvoice');
      return;
    }
    if (app.offline) {
      await app.queueDraft();
      if (mounted && token == _token) context.go('/offline');
      return;
    }
    final templateId = app.draftTemplate.id;
    setState(() {
      _running = true;
      _error = null;
      _stage = 0;
    });
    try {
      // The shared preparation flow opens curated content, never live AI text.
      for (var step = 0; step < 3; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 420));
        if (!mounted || token != _token) return;
        setState(() => _stage = step + 1);
      }
      if (!mounted || token != _token) return;
      final story = await app.createChronicle(templateId: templateId);
      if (!mounted || token != _token) return;
      context.go('/reader/${story.id}');
    } catch (_) {
      if (mounted && token == _token) {
        setState(() {
          _running = false;
          _error =
              'Your chronicle could not be saved. Try again, or return to your draft.';
        });
      }
    }
  }

  void _cancel() {
    _token++;
    context.go('/inscribe/voice');
  }

  @override
  void dispose() {
    _token++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _token++;
      },
      child: AppScaffold(
        title: 'Preparing your chronicle',
        dark: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 36),
            Container(
              width: 114,
              height: 114,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: OvColors.gold.withValues(alpha: .5)),
                color: OvColors.green,
              ),
              child: const Icon(
                Icons.draw_outlined,
                size: 48,
                color: OvColors.gold,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'A story is taking shape.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OvColors.cream,
                fontSize: 28,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              app.draftTemplate.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: OvColors.gold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'For ${app.profileName} · ${app.selectedSite.name}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OvColors.cream.withValues(alpha: .7),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            for (final (index, title) in [
              'Opening the prepared story',
              'Matching your selected narrator',
              'Saving to your scrolls',
            ].indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _stage > index
                          ? Icons.check_circle_outline
                          : Icons.circle_outlined,
                      color: _stage >= index
                          ? OvColors.gold
                          : OvColors.cream.withValues(alpha: .3),
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: _stage >= index
                              ? OvColors.cream
                              : OvColors.cream.withValues(alpha: .45),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              _Notice(_error!, icon: Icons.error_outline, dark: true),
              const SizedBox(height: 14),
              PillButton(
                label: 'Try again',
                icon: Icons.refresh,
                onPressed: _prepare,
              ),
            ] else
              LinearProgressIndicator(
                value: _stage / 3,
                color: OvColors.gold,
                backgroundColor: OvColors.green,
              ),
            const SizedBox(height: 24),
            Text(
              'This prototype opens a curated story with recorded narration. It does not call an AI service.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: OvColors.cream.withValues(alpha: .6),
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: OvColors.cream,
                side: BorderSide(color: OvColors.cream.withValues(alpha: .3)),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Return to my draft'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreationSteps extends StatelessWidget {
  const _CreationSteps({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final (index, label) in ['Place', 'Tone', 'Voice'].indexed) ...[
        if (index > 0)
          Expanded(
            child: Container(
              height: 1,
              color: index <= current
                  ? _accentColor(context)
                  : const Color(0xffd8d6cc),
            ),
          ),
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index <= current ? OvColors.green : Colors.transparent,
                border: Border.all(
                  color: index <= current
                      ? OvColors.green
                      : const Color(0xffa7afa7),
                ),
              ),
              child: Center(
                child: index < current
                    ? const Icon(Icons.check, size: 16, color: OvColors.cream)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: index <= current
                              ? OvColors.cream
                              : _mutedColor(context),
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: index <= current
                    ? _accentColor(context)
                    : _mutedColor(context),
                fontWeight: index == current
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
            if (index < 2) const SizedBox(width: 8),
          ],
        ),
      ],
    ],
  );
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
Color _panelColor(BuildContext context) =>
    _isDark(context) ? const Color(0xff1a3324) : Colors.white;
Color _headingColor(BuildContext context) =>
    _isDark(context) ? OvColors.cream : OvColors.ink;
Color _mutedColor(BuildContext context) =>
    _isDark(context) ? OvColors.cream.withValues(alpha: .74) : OvColors.body;
Color _accentColor(BuildContext context) =>
    _isDark(context) ? OvColors.gold : OvColors.green;

BoxDecoration _paperDecoration(BuildContext context, {bool selected = false}) =>
    BoxDecoration(
      color: _panelColor(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: selected
            ? _accentColor(context)
            : _isDark(context)
            ? const Color(0xff45644e)
            : const Color(0xffd8d6cc),
        width: selected ? 1.6 : 1,
      ),
    );

class _CanvasOption extends StatelessWidget {
  const _CanvasOption({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: _panelColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _isDark(context)
              ? const Color(0xff45644e)
              : const Color(0xffd8d6cc),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: _accentColor(context), size: 26),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _headingColor(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  color: _mutedColor(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: _isDark(context) ? OvColors.gold : OvColors.brown,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.8,
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _headingColor(context),
            ),
          ),
          TextSpan(text: value),
        ],
      ),
      style: TextStyle(fontSize: 13, height: 1.4, color: _mutedColor(context)),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {required this.icon, this.dark = false});
  final String text;
  final IconData icon;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: dark ? OvColors.green : OvColors.gold.withValues(alpha: .12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: dark || _isDark(context) ? OvColors.gold : OvColors.brown,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: dark ? OvColors.cream : _mutedColor(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}
