import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/search/presentation/widgets/search_sidebar.dart';
import 'features/search/presentation/widgets/document_viewer.dart';
import 'features/search/presentation/controllers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // We initialize the container
  final container = ProviderContainer();
  
  // Init database and ONNX
  try {
    await container.read(searchRepositoryProvider).init();
  } catch (e) {
    debugPrint('Initialization error: $e');
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: const GeorgianLegalSearchApp(),
  ));
}

class GeorgianLegalSearchApp extends StatelessWidget {
  const GeorgianLegalSearchApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Georgian Legal Search',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const WorkspaceScreen(),
    );
  }
}

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Georgian Legal Search Workstation'),
      ),
      body: Row(
        children: const [
          SearchSidebar(),
          DocumentViewer(),
        ],
      ),
    );
  }
}
