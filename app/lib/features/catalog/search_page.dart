import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../l10n/strings.dart';
import '../../providers/providers.dart';
import '../../models/catalog.dart';
import '../../widgets/common.dart';
import '../../widgets/layout.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    // Wait for a pause in typing so each keystroke is not a request.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final results = _query.length < 2
        ? null
        : ref.watch(productsProvider(ProductQuery(search: _query)));

    final searchField = TextField(
      controller: _controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: strings.searchHint,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _controller.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );

    if (Breakpoints.isWide(context)) {
      return AppPage(
        title: strings.search,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(children: [
                  const Icon(Icons.search_rounded),
                  const SizedBox(width: 10),
                  Expanded(child: searchField)
                ]),
              ),
            ),
            Expanded(child: _results(context, strings, results)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: searchField),
      body: _results(context, strings, results),
    );
  }

  Widget _results(BuildContext context, Strings strings,
      AsyncValue<List<ProductSummary>>? results) {
    return MaxWidthBody(
      child: results == null
          ? EmptyView(
              icon: Icons.search_rounded,
              title: strings.search,
              message: strings.searchHint,
            )
          : results.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const ShimmerBox(height: 72),
              ),
              error: (error, _) => ErrorView(error: error),
              data: (list) {
                if (list.isEmpty) {
                  return EmptyView(
                    icon: Icons.search_off_rounded,
                    title: strings.noProducts,
                    message: strings.noProductsBody,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = list[index];
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(10),
                        leading: AppImage(
                          url: product.imageUrl,
                          width: 54,
                          height: 54,
                          fallbackIcon: Icons.sports_esports_rounded,
                        ),
                        title: Text(product.localisedName(strings.isBurmese)),
                        subtitle: product.startingPrice == null
                            ? null
                            : Text(
                                '${strings.priceFrom} ${Format.money(product.startingPrice!)}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/product/${product.slug}'),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
