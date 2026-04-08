import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../providers/pdf_providers.dart';
import '../widgets/pdf_viewer_widget.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/terminal_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _pickFile(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final path = file.path!;
    final name = p.basename(path);

    ref.read(currentPdfPathProvider.notifier).state = path;
    ref.read(recentFilesProvider.notifier).add(path, name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = ref.watch(currentPdfPathProvider);
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    final terminalVisible = ref.watch(terminalVisibleProvider);

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.backquote,
            control: true): () {
          ref.read(terminalVisibleProvider.notifier).state =
              !ref.read(terminalVisibleProvider);
        },
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: Column(
        children: [
          // Top bar
          _TopBar(onOpenFile: () => _pickFile(ref)),

          // Body
          Expanded(
            child: Row(
              children: [
                // Sidebar
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: sidebarVisible
                      ? SidebarWidget(onOpenFile: () => _pickFile(ref))
                      : const SizedBox.shrink(),
                ),

                // Main content + terminal
                Expanded(
                  child: _MainContentArea(
                    currentPath: currentPath,
                    terminalVisible: terminalVisible,
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
}

class _MainContentArea extends StatefulWidget {
  const _MainContentArea({
    required this.currentPath,
    required this.terminalVisible,
  });

  final String? currentPath;
  final bool terminalVisible;

  @override
  State<_MainContentArea> createState() => _MainContentAreaState();
}

class _MainContentAreaState extends State<_MainContentArea> {
  double _terminalHeight = 220;
  static const _minTerminalHeight = 100.0;
  static const _dividerHeight = 6.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTerminalHeight = constraints.maxHeight * 0.7;
        final clampedHeight =
            _terminalHeight.clamp(_minTerminalHeight, maxTerminalHeight);

        if (!widget.terminalVisible) {
          return widget.currentPath == null
              ? const _EmptyState()
              : PdfViewerWidget(
                  key: ValueKey(widget.currentPath),
                  filePath: widget.currentPath!,
                );
        }

        return Column(
          children: [
            // PDF viewer / empty state
            Expanded(
              child: widget.currentPath == null
                  ? const _EmptyState()
                  : PdfViewerWidget(
                      key: ValueKey(widget.currentPath),
                      filePath: widget.currentPath!,
                    ),
            ),

            // Resize handle
            MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _terminalHeight = (_terminalHeight - details.delta.dy)
                        .clamp(_minTerminalHeight, maxTerminalHeight);
                  });
                },
                child: Container(
                  height: _dividerHeight,
                  color: const Color(0xFF313244),
                  child: const Center(
                    child: SizedBox(
                      width: 40,
                      height: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF45475A),
                          borderRadius: BorderRadius.all(Radius.circular(1)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Terminal panel
            SizedBox(
              height: clampedHeight,
              child: const TerminalWidget(),
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.onOpenFile});

  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarVisible = ref.watch(sidebarVisibleProvider);
    final currentPath = ref.watch(currentPdfPathProvider);
    final currentPage = ref.watch(currentPageProvider);
    final totalPages = ref.watch(totalPagesProvider);

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF181825),
        border: Border(bottom: BorderSide(color: Color(0xFF313244))),
      ),
      child: Row(
        children: [
          // Toggle sidebar
          IconButton(
            icon: Icon(
              sidebarVisible ? Icons.menu_open : Icons.menu,
              size: 18,
              color: const Color(0xFF6C7086),
            ),
            tooltip: sidebarVisible ? '사이드바 닫기' : '사이드바 열기',
            onPressed: () => ref.read(sidebarVisibleProvider.notifier).state =
                !sidebarVisible,
          ),

          // File name
          if (currentPath != null) ...[
            const Icon(Icons.picture_as_pdf,
                size: 16, color: Color(0xFFF38BA8)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p.basename(currentPath),
                style: const TextStyle(
                  color: Color(0xFFCDD6F4),
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (totalPages > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '$currentPage / $totalPages 페이지',
                  style: const TextStyle(
                    color: Color(0xFF6C7086),
                    fontSize: 12,
                  ),
                ),
              ),
          ] else
            const Spacer(),

          // Terminal toggle
          IconButton(
            icon: Icon(
              Icons.terminal,
              size: 16,
              color: ref.watch(terminalVisibleProvider)
                  ? const Color(0xFF89B4FA)
                  : const Color(0xFF6C7086),
            ),
            tooltip: '터미널 (Ctrl+`)',
            onPressed: () => ref
                .read(terminalVisibleProvider.notifier)
                .state = !ref.read(terminalVisibleProvider),
          ),

          // Open button
          TextButton.icon(
            onPressed: onOpenFile,
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('열기'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF89B4FA),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: const Color(0xFF313244),
          ),
          const SizedBox(height: 16),
          const Text(
            'PDF 파일을 열어주세요',
            style: TextStyle(
              color: Color(0xFF6C7086),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '좌측 사이드바의 "PDF 열기" 버튼 또는\n상단의 "열기" 버튼을 클릭하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF45475A),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '단축키: ← → (이전/다음 페이지)',
            style: TextStyle(
              color: Color(0xFF45475A),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
