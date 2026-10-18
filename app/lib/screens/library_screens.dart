import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_scope.dart';
import '../core/app_scope.dart';
import '../core/audio_controller.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tab = 0;
  bool _bookmarkedOnly = false;
  String? _openingId;

  Future<void> _openTemplate(StoryTemplate template) async {
    if (_openingId != null) return;
    setState(() => _openingId = template.id);
    try {
      final state = AppScope.of(context);
      final existing = state.library
          .where((story) => story.templateId == template.id)
          .firstOrNull;
      final story =
          existing ?? await state.createChronicle(templateId: template.id);
      if (mounted) context.push('/reader/${story.id}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The story could not be opened. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  Future<void> _delete(Chronicle story) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this chronicle?'),
        content: Text(
          '“${story.title}” and its reading progress will be removed from your Scrolls. The prepared story remains in Explore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: OvColors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await AppScope.of(context).deleteChronicle(story.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chronicle removed from your Scrolls.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final stories =
        state.library
            .where((story) => !_bookmarkedOnly || story.bookmarked)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return AppScaffold(
      title: 'Scrolls',
      eyebrow: 'Stories to carry with you',
      showBack: false,
      actions: [
        IconButton.outlined(
          onPressed: () => context.push('/downloads'),
          icon: const Icon(Icons.download_outlined, size: 21),
          tooltip: 'Manage downloads',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: ['Mine', 'Journeys', 'Explore']
                  .asMap()
                  .entries
                  .map(
                    (item) => Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _tab = item.key),
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: _tab == item.key
                                ? OvColors.green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            item.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _tab == item.key ? OvColors.cream : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 22),
          if (_tab == 0) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${state.library.length} ${state.library.length == 1 ? 'chronicle' : 'chronicles'} · saved in your Scrolls',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                FilterChip(
                  label: const Text(
                    'Bookmarked',
                    style: TextStyle(fontSize: 10),
                  ),
                  selected: _bookmarkedOnly,
                  selectedColor: OvColors.gold.withValues(alpha: .25),
                  avatar: const Icon(Icons.bookmark_outline_rounded, size: 15),
                  onSelected: (value) =>
                      setState(() => _bookmarkedOnly = value),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (stories.isEmpty)
              _LibraryEmpty(
                bookmarked: _bookmarkedOnly,
                onExplore: () => setState(() {
                  _tab = 2;
                  _bookmarkedOnly = false;
                }),
              ),
            for (final story in stories) ...[
              StoryCard(story: story),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 3, 0, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_dateLabel(story.createdAt)} · ${state.voiceById(story.voiceId).name}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Chronicle actions',
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (value) {
                        if (value == 'share') {
                          context.push('/share/${story.id}');
                        }
                        if (value == 'delete') _delete(story);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'share',
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.ios_share_rounded, size: 19),
                            title: Text('Share chronicle'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.delete_outline_rounded,
                              color: OvColors.red,
                              size: 19,
                            ),
                            title: Text(
                              'Remove from Scrolls',
                              style: TextStyle(color: OvColors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
          if (_tab == 1) ...[
            const SectionHeading(
              title: 'One place. Many paths.',
              subtitle:
                  'Follow an unfolding story chapter by chapter. Your choices connect them.',
            ),
            const _JourneyOverview(),
            for (final template in state.templates.where(
              (item) => item.isHistorical && item.id == 'onon-child-en',
            )) ...[
              const SizedBox(height: 20),
              _JourneyOverview(template: template),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    color: OvColors.brown,
                    size: 24,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'At the end of each chapter, choose the next thread to follow. Completed chapters and listening positions stay in your Scrolls.',
                      style: TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_tab == 2) ...[
            const SectionHeading(
              title: 'Stories from Mongolia',
              subtitle:
                  'Prepared stories and historical synopses, with reading notes and sources.',
            ),
            for (final template in state.templates)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ExploreCard(
                  template: template,
                  busy: _openingId == template.id,
                  onOpen: () => _openTemplate(template),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty({required this.bookmarked, required this.onExplore});
  final bool bookmarked;
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 42),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: OvColors.green.withValues(alpha: .1),
          ),
          child: Icon(
            bookmarked
                ? Icons.bookmark_outline_rounded
                : Icons.auto_stories_outlined,
            color: OvColors.green,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          bookmarked ? 'Keep a story close.' : 'Your first page awaits.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(
          bookmarked
              ? 'Tap the bookmark on any chronicle to find it here.'
              : 'Create a chronicle or read a prepared story. It will be saved here for your next visit.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        PillButton(
          label: 'Explore stories',
          icon: Icons.arrow_forward_rounded,
          onPressed: onExplore,
        ),
      ],
    ),
  );
}

class _JourneyOverview extends StatelessWidget {
  const _JourneyOverview({this.template});
  final StoryTemplate? template;

  bool get _historical => template?.isHistorical ?? false;
  int get _chapterCount => _historical ? 5 : 3;

  void _open(BuildContext context) =>
      context.push(_historical ? '/demo/${template!.id}' : '/journey');

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Material(
      color: OvColors.night,
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AppImage(
                  path: template?.image ?? 'assets/images/silver-tree.jpg',
                  height: 230,
                  width: double.infinity,
                ),
                Positioned(
                  left: 17,
                  top: 16,
                  child: DemoBadge(
                    text: _historical
                        ? '5 CHAPTERS · ONON RIVER'
                        : '3 CHAPTERS · KHARKHORIN',
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _historical
                        ? 'The Secret History\nof Temujin'
                        : 'Beneath the\nSilver Tree',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 30,
                      height: 1.14,
                      color: OvColors.cream,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _historical
                        ? 'From the Onon River to the friendships that shaped a young life. Five four-minute chapters in English.'
                        : 'A traveller, a goldsmith, and a city at the meeting point of worlds.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.65,
                      color: OvColors.cream.withValues(alpha: .8),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      for (var i = 1; i <= _chapterCount; i++) ...[
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == 1 ? OvColors.gold : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == 1
                                  ? OvColors.gold
                                  : OvColors.cream.withValues(alpha: .35),
                            ),
                          ),
                          child: Text(
                            '$i',
                            style: TextStyle(
                              color: i == 1 ? OvColors.night : OvColors.cream,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (i < _chapterCount)
                          Expanded(
                            child: Container(
                              height: 1,
                              color: OvColors.cream.withValues(alpha: .25),
                            ),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _open(context),
                      icon: const Icon(Icons.route_rounded, size: 20),
                      label: const Text('Open journey'),
                      style: FilledButton.styleFrom(
                        backgroundColor: OvColors.gold,
                        foregroundColor: OvColors.night,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExploreCard extends StatelessWidget {
  const _ExploreCard({
    required this.template,
    required this.busy,
    required this.onOpen,
  });
  final StoryTemplate template;
  final bool busy;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final site = AppScope.of(context).siteById(template.siteId);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppImage(path: template.image, height: 160, width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${site.name.toUpperCase()} · ${template.readingMinutes} MIN READ',
                  style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? OvColors.gold
                        : OvColors.brown,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  template.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  template.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                PillButton(
                  label: 'Read prepared story',
                  icon: Icons.auto_stories_outlined,
                  secondary: true,
                  busy: busy,
                  onPressed: onOpen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final auth = AuthScope.maybeOf(context);
    final places = state.library.map((story) => story.siteId).toSet().length;
    final finished = state.library
        .where((story) => story.readingProgress >= 1)
        .length;
    final name = state.profileName ?? 'Guest traveller';
    return AppScaffold(
      title: 'öv AI',
      eyebrow: 'A home for your journeys',
      showBack: false,
      actions: [
        IconButton.outlined(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.tune_rounded, size: 21),
          tooltip: 'Open settings',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(21),
            decoration: BoxDecoration(
              color: OvColors.green,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: OvColors.cream.withValues(alpha: .12),
                        border: Border.all(
                          color: OvColors.cream.withValues(alpha: .25),
                        ),
                      ),
                      child: const Icon(
                        Icons.cottage_outlined,
                        color: OvColors.cream,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 21,
                              fontWeight: FontWeight.w500,
                              color: OvColors.cream,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            state.isGuest
                                ? 'A guest on the steppe'
                                : auth?.isSignedIn == true
                                ? auth!.identity!.email ??
                                      'Signed in with your account'
                                : 'Your traveller profile',
                            style: TextStyle(
                              fontSize: 12,
                              color: OvColors.cream.withValues(alpha: .8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DemoBadge(
                  text: auth?.isSignedIn == true
                      ? auth!.isEmulator
                            ? 'LOCAL TEST ACCOUNT'
                            : 'CONNECTED ACCOUNT'
                      : state.usesCloudBackend
                      ? 'EXPLORING AS A GUEST'
                      : 'ON THIS DEVICE · LOCAL PROTOTYPE',
                ),
                const SizedBox(height: 15),
                Text(
                  'Every journey leaves a story.\nMake this one yours.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.65,
                    color: OvColors.cream.withValues(alpha: .82),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _StatTile(value: '${state.library.length}', label: 'Chronicles'),
              const SizedBox(width: 9),
              _StatTile(value: '$places', label: 'Places read'),
              const SizedBox(width: 9),
              _StatTile(value: '$finished', label: 'Completed'),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeading(title: 'Make it your own'),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.person_outline_rounded,
                  title: auth != null
                      ? state.isGuest
                            ? 'Sign in'
                            : 'Account'
                      : state.isGuest
                      ? 'Create a demo profile'
                      : 'Edit traveller name',
                  subtitle: auth != null && state.isGuest
                      ? 'Continue with Google or Apple'
                      : name,
                  onTap: () => context.push('/profile-setup?next=%2Fprofile'),
                ),
                const Divider(height: 1, indent: 56),
                _ProfileRow(
                  icon: Icons.download_outlined,
                  title: 'Downloads',
                  subtitle: '${state.installedPacks.length} region packs saved',
                  onTap: () => context.push('/downloads'),
                ),
                const Divider(height: 1, indent: 56),
                _ProfileRow(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  subtitle: 'Reading, listening and appearance',
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bookmark_outline_rounded,
                      size: 20,
                      color: OvColors.brown,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${state.bookmarkedSiteIds.length} saved places',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (state.bookmarkedSiteIds.isEmpty)
                  const Text(
                    'Bookmark a place on the Steppe to keep it close.',
                    style: TextStyle(fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: state.bookmarkedSiteIds.map((id) {
                      final site = state.siteById(id);
                      return ActionChip(
                        label: Text(
                          site.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () async {
                          await state.selectSite(id);
                          if (context.mounted) context.go('/steppe');
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PillButton(
            label: 'Open my Scrolls',
            icon: Icons.auto_stories_outlined,
            onPressed: () => context.go('/scrolls'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: auth?.busy == true
                ? null
                : () async {
                    await AudioScope.of(context).stop();
                    if (auth?.isSignedIn == true) {
                      final success = await auth!.signOut();
                      if (!success) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                auth.errorMessage ??
                                    'Could not sign out. Please try again.',
                              ),
                            ),
                          );
                        }
                        return;
                      }
                    } else {
                      await state.signOut();
                    }
                    if (context.mounted) context.go('/welcome');
                  },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              auth?.isSignedIn == true ? 'Sign out' : 'Return to welcome',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.usesCloudBackend
                ? auth?.isSignedIn == true
                      ? 'öv AI · v0.1\nStories and reading progress are saved to your account. Reading settings and downloads stay on this device.'
                      : 'öv AI · v0.1\nSign in to save stories and reading progress to your account.'
                : 'öv AI · Prototype v0.1\nYour stories and preferences are stored on this device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? OvColors.gold
                  : OvColors.green,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    minVerticalPadding: 15,
    leading: Icon(
      icon,
      color: Theme.of(context).brightness == Brightness.dark
          ? OvColors.gold
          : OvColors.green,
      size: 23,
    ),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
  );
}
