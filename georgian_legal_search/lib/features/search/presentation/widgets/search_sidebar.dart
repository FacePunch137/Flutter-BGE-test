import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../controllers/providers.dart';
import 'results_list.dart';

class SearchSidebar extends ConsumerStatefulWidget {
  const SearchSidebar({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchSidebar> createState() => _SearchSidebarState();
}

class _SearchSidebarState extends ConsumerState<SearchSidebar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _executeSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(searchNotifierProvider.notifier).executeSearch(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchNotifierProvider);

    return Container(
      width: MediaQuery.of(context).size.width * 0.35,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Selector and Copy Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Civil', label: Text('Civil')),
                        ButtonSegment(value: 'Administrative', label: Text('Administrative')),
                      ],
                      selected: {searchState.category},
                      onSelectionChanged: (Set<String> newSelection) {
                        ref.read(searchNotifierProvider.notifier).setCategory(newSelection.first);
                      },
                    ),
                    if (searchState.results.isNotEmpty)
                      IconButton(
                        tooltip: 'Copy all results',
                        icon: const Icon(Icons.copy_all, color: Colors.blue),
                        onPressed: () {
                          final text = searchState.results
                              .map((r) => '${r.id} {${r.rerankScore.toStringAsFixed(3)}}')
                              .join('\n');
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied all results to clipboard.')),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Georgian legal cases...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(searchNotifierProvider.notifier).clearSearch();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => _executeSearch(),
                  onChanged: (val) => setState(() {}),
                ),
                const SizedBox(height: 8),
                if (searchState.latencyMessage.isNotEmpty)
                  Text(
                    searchState.latencyMessage,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                if (searchState.errorMessage != null)
                  Text(
                    searchState.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
              ],
            ),
          ),
          
          // Results List
          Expanded(
            child: searchState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : const ResultsList(),
          ),
        ],
      ),
    );
  }
}
