import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/recent_file.dart';
import '../providers/pdf_providers.dart';

class SidebarWidget extends ConsumerWidget {
  const SidebarWidget({
    super.key,
    required this.onOpenFile,
  });

  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentFiles = ref.watch(recentFilesProvider);
    final currentPath = ref.watch(currentPdfPathProvider);

    return Container(
      width: 260,
      color: const Color(0xFF1E1E2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF181825),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: Color(0xFF89B4FA), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'BookApp',
                    style: TextStyle(
                      color: Color(0xFFCDD6F4),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Open button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: onOpenFile,
              icon: const Icon(Icons.folder_open, size: 18),
              label: const Text('PDF 열기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF89B4FA),
                foregroundColor: const Color(0xFF1E1E2E),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          const Divider(color: Color(0xFF313244), height: 1),

          // Recent files header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(
              children: [
                const Text(
                  '최근 파일',
                  style: TextStyle(
                    color: Color(0xFF6C7086),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                if (recentFiles.isNotEmpty)
                  IconButton(
                    onPressed: () =>
                        ref.read(recentFilesProvider.notifier).clear(),
                    icon: const Icon(Icons.delete_sweep_outlined,
                        size: 16, color: Color(0xFF6C7086)),
                    tooltip: '최근 목록 지우기',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Recent files list
          Expanded(
            child: recentFiles.isEmpty
                ? const Center(
                    child: Text(
                      '최근 파일 없음',
                      style: TextStyle(color: Color(0xFF6C7086), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: recentFiles.length,
                    itemBuilder: (context, index) {
                      final file = recentFiles[index];
                      final isActive = file.path == currentPath;
                      return _RecentFileItem(
                        file: file,
                        isActive: isActive,
                        onTap: () {
                          ref
                              .read(currentPdfPathProvider.notifier)
                              .state = file.path;
                          ref
                              .read(recentFilesProvider.notifier)
                              .add(file.path, file.name);
                        },
                        onRemove: () => ref
                            .read(recentFilesProvider.notifier)
                            .remove(file.path),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecentFileItem extends StatelessWidget {
  const _RecentFileItem({
    required this.file,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
  });

  final RecentFile file;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? const Color(0xFF313244) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.picture_as_pdf,
                size: 18,
                color: isActive
                    ? const Color(0xFFF38BA8)
                    : const Color(0xFF6C7086),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.basenameWithoutExtension(file.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFFCDD6F4)
                            : const Color(0xFFA6ADC8),
                        fontSize: 13,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    Text(
                      _formatDate(file.openedAt),
                      style: const TextStyle(
                        color: Color(0xFF6C7086),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 14),
                color: const Color(0xFF6C7086),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '목록에서 제거',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}
