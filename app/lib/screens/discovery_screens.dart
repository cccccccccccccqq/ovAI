import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_scope.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../maps/journey_map.dart';
import '../widgets/common.dart';

class SteppeScreen extends StatefulWidget {
  const SteppeScreen({super.key});
  @override
  State<SteppeScreen> createState() => _SteppeScreenState();
}

class _SteppeScreenState extends State<SteppeScreen> {
  final _search = TextEditingController();
  final _map = JourneyMapController();
  String _era = 'All eras';
  bool _opening = false;

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _selectSite(String id, {bool clearFilters = false}) {
    final state = AppScope.of(context);
    final site = state.siteById(id);
    unawaited(state.selectSite(id));
    _map.move(LatLng(site.lat, site.lng), site.isApproximate ? 7 : 13);
    if (clearFilters && (_era != 'All eras' || _search.text.isNotEmpty)) {
      setState(() {
        _era = 'All eras';
        _search.clear();
      });
    }
  }

  Future<void> _read(Site site) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final state = AppScope.of(context);
      await state.selectSite(site.id);
      final template = state.defaultTemplateForSite(site.id);
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
            content: Text('This story could not be opened. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final sites = state.sites
        .where(
          (site) =>
              (_era == 'All eras' || site.era == _era) &&
              (query.isEmpty ||
                  '${site.name} ${site.nameMn} ${site.era} ${site.summary}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    final selected =
        sites.where((site) => site.id == state.selectedSite.id).firstOrNull ??
        sites.firstOrNull;
    final historical =
        selected != null &&
        state.defaultTemplateForSite(selected.id).isHistorical;
    final eras = ['All eras', ...state.sites.map((site) => site.era).toSet()];
    return AppScaffold(
      eyebrow: 'Öv · Stories of Mongolia',
      title: 'Find your story.',
      showBack: false,
      actions: [
        IconButton.outlined(
          onPressed: () => context.push('/field'),
          icon: const Icon(Icons.map_outlined, size: 22),
          tooltip: 'Open field map',
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.historyCatalogError != null) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'The history collection is temporarily unavailable.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: () => state.loadHistoricalCatalog(),
                  child: const Text('Retry'),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search places, history, landscapes',
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Clear search',
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: eras
                  .map(
                    (era) => Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(
                          era,
                          style: TextStyle(
                            fontSize: 11,
                            color: _era == era
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? OvColors.green
                                      : OvColors.cream)
                                : null,
                          ),
                        ),
                        selected: _era == era,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _era = era),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          if (state.offline)
            DemoMap(
              selectedSiteId: selected?.id,
              onSiteTap: (id) => _selectSite(id, clearFilters: true),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1.08,
                child: JourneyMap(
                  controller: _map,
                  sites: state.sites,
                  selectedSiteId: selected?.id ?? '',
                  onSiteTap: (id) => _selectSite(id, clearFilters: true),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.place_outlined, size: 15, color: OvColors.brown),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${sites.length} places to discover',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const DemoBadge(text: 'PREPARED CONTENT'),
            ],
          ),
          const SizedBox(height: 12),
          if (sites.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sites
                    .map(
                      (site) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(
                            site.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected?.id == site.id
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          avatar: selected?.id == site.id
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: OvColors.green,
                                )
                              : const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                ),
                          onPressed: () => _selectSite(site.id),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          if (sites.length > 1) const SizedBox(height: 14),
          if (selected == null)
            _SearchEmpty(
              onClear: () => setState(() {
                _search.clear();
                _era = 'All eras';
              }),
            )
          else
            _PlaceCard(
              site: selected,
              opening: _opening,
              onRead: () => _read(selected),
              onWrite: () async {
                await state.selectSite(selected.id);
                if (context.mounted) context.push('/inscribe/tone');
              },
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: OvColors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  color: OvColors.gold,
                  size: 31,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        historical
                            ? 'Follow young Temujin'
                            : 'Follow the Silver Tree',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: OvColors.cream,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        historical
                            ? 'Five chapters. One unfolding journey.'
                            : 'Three chapters. One unfolding journey.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: OvColors.cream.withValues(alpha: .8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (!historical) {
                      context.push('/journey');
                      return;
                    }
                    final first = state.defaultTemplateForSite(selected.id);
                    final saved = state.library
                        .where((story) => story.templateId == first.id)
                        .firstOrNull;
                    context.push(
                      saved == null
                          ? '/demo/${first.id}'
                          : '/journey/${saved.id}',
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: OvColors.cream,
                  ),
                  tooltip: 'Open the journey',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.site,
    required this.onRead,
    required this.onWrite,
    required this.opening,
  });
  final Site site;
  final VoidCallback onRead;
  final VoidCallback onWrite;
  final bool opening;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final saved = state.bookmarkedSiteIds.contains(site.id);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AppImage(path: site.image, width: double.infinity, height: 185),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: OvColors.night.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    site.era.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      color: OvColors.cream,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 9,
                top: 7,
                child: IconButton(
                  onPressed: () => state.toggleSiteBookmark(site.id),
                  icon: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: saved ? OvColors.gold : OvColors.cream,
                  ),
                  tooltip: saved ? 'Remove saved place' : 'Save place',
                  style: IconButton.styleFrom(
                    backgroundColor: OvColors.night.withValues(alpha: .7),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  site.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  site.locationNote ??
                      '${site.nameMn}  ·  ${site.lat.toStringAsFixed(4)}°N ${site.lng.toStringAsFixed(4)}°E',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(site.summary),
                const SizedBox(height: 20),
                PillButton(
                  label: 'Inscribe this place',
                  icon: Icons.edit_outlined,
                  onPressed: onWrite,
                ),
                const SizedBox(height: 9),
                PillButton(
                  label: 'Read a prepared story',
                  icon: Icons.auto_stories_outlined,
                  secondary: true,
                  busy: opening,
                  onPressed: onRead,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty({required this.onClear});
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Column(
      children: [
        const Icon(
          Icons.travel_explore_rounded,
          color: OvColors.brown,
          size: 42,
        ),
        const SizedBox(height: 14),
        Text('No places found', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Try another name or explore all places in the collection.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Show all places'),
        ),
      ],
    ),
  );
}
