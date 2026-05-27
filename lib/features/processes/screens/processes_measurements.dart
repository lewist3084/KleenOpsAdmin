import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_widgets/tiles/standard_tile_small.dart';
import 'package:shared_widgets/lists/standardViewGroup.dart';
import 'package:kleenops_admin/features/auth/providers/auth_provider.dart';
import 'package:kleenops_admin/features/processes/forms/processes_measurement_form.dart';

class ProcessesMeasurementsContent extends ConsumerStatefulWidget {
  const ProcessesMeasurementsContent({super.key});

  @override
  ConsumerState<ProcessesMeasurementsContent> createState() =>
      _ProcessesMeasurementsContentState();
}

class _ProcessesMeasurementsContentState
    extends ConsumerState<ProcessesMeasurementsContent> {
  final ValueNotifier<bool> _fabVisibleNotifier = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _fabVisibleNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyRefAsync = ref.watch(companyIdProvider);

    return companyRefAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Error loading company: $err')),
      ),
      data: (companyRef) {
        if (companyRef == null) {
          return const Scaffold(
            body: Center(child: Text('No company linked')),
          );
        }

        final collection = companyRef.collection('processMeasurement');
        final query = collection.orderBy('name');

        final listView = Padding(
          padding: const EdgeInsets.all(16.0),
          child: NotificationListener<ScrollNotification>(
            onNotification: (scroll) {
              if (scroll is ScrollUpdateNotification &&
                  scroll.scrollDelta != null) {
                if (scroll.scrollDelta! > 0 && _fabVisibleNotifier.value) {
                  _fabVisibleNotifier.value = false;
                } else if (scroll.scrollDelta! < 0 &&
                    !_fabVisibleNotifier.value) {
                  _fabVisibleNotifier.value = true;
                }
              }
              return false;
            },
            child: StandardViewGroup.paginated(
              query: query,
              emptyBuilder: (_) =>
                  const Center(child: Text('No measurements')),
              itemBuilder: (ctx, doc, _) {
                final data = doc.data();
                final name = data['name'] as String? ?? '';
                final desc = data['description'] as String? ?? '';
                return StandardTileSmallDart.iconText(
                  leadingicon: Icons.straighten,
                  text: name,
                  secondText: desc.isEmpty ? null : desc,
                );
              },
            ),
          ),
        );

        final fab = ValueListenableBuilder<bool>(
          valueListenable: _fabVisibleNotifier,
          builder: (context, isVisible, child) => AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isVisible ? 1.0 : 0.0,
            child: child,
          ),
          child: FloatingActionButton(
            heroTag: null,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProcessesMeasurementForm(
                    companyId: companyRef,
                  ),
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
        );

        return Scaffold(
          body: listView,
          floatingActionButton: fab,
        );
      },
    );
  }
}
