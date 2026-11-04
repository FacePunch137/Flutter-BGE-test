import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/providers.dart';

class ResultsList extends ConsumerWidget {
  const ResultsList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchNotifierProvider);
    final results = searchState.results;

    if (results.isEmpty) {
      if (searchState.query.isEmpty) {
        return const Center(child: Text('Enter a query to search.'));
      }
      return const Center(child: Text('No results found.'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final doc = results[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            onTap: () {
              ref.read(documentNotifierProvider.notifier).loadDecision(doc.id, searchState.category);
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          doc.caseNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          doc.rerankScore.toStringAsFixed(3),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        doc.date.isNotEmpty ? doc.date : 'Unknown Date',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (doc.result.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        doc.result,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Text(
                    doc.chunkText,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
