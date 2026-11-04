import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/providers.dart';
import 'highlighted_text.dart';

class DocumentViewer extends ConsumerWidget {
  const DocumentViewer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docState = ref.watch(documentNotifierProvider);
    final searchState = ref.watch(searchNotifierProvider);

    if (docState.isLoading) {
      return const Expanded(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (docState.errorMessage != null) {
      return Expanded(
        child: Center(child: Text(docState.errorMessage!, style: const TextStyle(color: Colors.red))),
      );
    }

    final decision = docState.currentDecision;

    if (decision == null) {
      return const Expanded(
        child: Center(
          child: Text(
            'Select a decision to view details.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Expanded(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          decision.caseNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${decision.category} • ${decision.date}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        if (decision.subject.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Subject: ${decision.subject}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if (decision.result.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Result: ${decision.result}',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: decision.fullText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied case text to clipboard.')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Case Text'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ID: ${decision.id}',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                      )
                    ],
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: HighlightedText(
                  text: decision.fullText,
                  query: searchState.query,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
