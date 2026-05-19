import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'collections_provider.dart';
import 'create_collection_sheet.dart';

class CreateCollectionScreen extends ConsumerStatefulWidget {
  const CreateCollectionScreen({super.key});

  @override
  ConsumerState<CreateCollectionScreen> createState() =>
      _CreateCollectionScreenState();
}

class _CreateCollectionScreenState extends ConsumerState<CreateCollectionScreen> {
  bool _opened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final collection = await showCreateCollectionSheet(context);
      if (!mounted) return;
      ref.invalidate(collectionsListProvider);
      ref.invalidate(collectionsSummaryProvider);
      if (collection != null) {
        context.go('/collections/${collection.id}');
      } else {
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
