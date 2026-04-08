import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../providers/pdf_providers.dart';
import '../services/ocr_service.dart';

class PdfViewerWidget extends ConsumerStatefulWidget {
  const PdfViewerWidget({super.key, required this.filePath});

  final String filePath;

  @override
  ConsumerState<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends ConsumerState<PdfViewerWidget> {
  late final PdfViewerController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Stack(
        children: [
          PdfViewer.file(
            widget.filePath,
            controller: _controller,
            params: PdfViewerParams(
              backgroundColor: const Color(0xFF181825),
              margin: 8,
              onViewerReady: (document, controller) {
                ref.read(totalPagesProvider.notifier).state =
                    document.pages.length;
                ref.read(currentPageProvider.notifier).state = 1;
              },
              onPageChanged: (page) {
                if (page != null) {
                  ref.read(currentPageProvider.notifier).state = page;
                }
              },
              layoutPages: (pages, params) {
                // 단일 열 세로 레이아웃
                final width = pages.fold(0.0,
                    (max, p) => p.width > max ? p.width : max);
                double y = params.margin;
                final rects = <Rect>[];
                for (final page in pages) {
                  rects.add(Rect.fromLTWH(
                    (width - page.width) / 2 + params.margin,
                    y,
                    page.width,
                    page.height,
                  ));
                  y += page.height + params.margin;
                }
                return PdfPageLayout(
                  pageLayouts: rects,
                  documentSize: Size(
                    width + params.margin * 2,
                    y,
                  ),
                );
              },
            ),
          ),

          // Bottom toolbar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomToolbar(
              controller: _controller,
              filePath: widget.filePath,
            ),
          ),
        ],
      ),
    );
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowDown) {
      _controller.goToPage(
          pageNumber: (ref.read(currentPageProvider) + 1)
              .clamp(1, ref.read(totalPagesProvider)));
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowUp) {
      _controller.goToPage(
          pageNumber: (ref.read(currentPageProvider) - 1)
              .clamp(1, ref.read(totalPagesProvider)));
    }
  }
}

class _BottomToolbar extends ConsumerStatefulWidget {
  const _BottomToolbar({required this.controller, required this.filePath});
  final PdfViewerController controller;
  final String filePath;

  @override
  ConsumerState<_BottomToolbar> createState() => _BottomToolbarState();
}

class _BottomToolbarState extends ConsumerState<_BottomToolbar> {
  late final TextEditingController _pageInput;

  @override
  void initState() {
    super.initState();
    _pageInput = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _pageInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(currentPageProvider);
    final total = ref.watch(totalPagesProvider);

    // Sync text field with current page without triggering rebuild loop
    if (_pageInput.text != '$current') {
      _pageInput.text = '$current';
    }

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        border: Border(top: BorderSide(color: Color(0xFF313244))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Zoom out
          _ToolbarButton(
            icon: Icons.zoom_out,
            tooltip: '축소',
            onPressed: () => widget.controller.zoomDown(),
          ),

          // Zoom in
          _ToolbarButton(
            icon: Icons.zoom_in,
            tooltip: '확대',
            onPressed: () => widget.controller.zoomUp(),
          ),

          // Fit page
          _ToolbarButton(
            icon: Icons.fit_screen,
            tooltip: '화면에 맞추기',
            onPressed: () {
              final page = ref.read(currentPageProvider);
              final matrix =
                  widget.controller.calcMatrixForFit(pageNumber: page);
              if (matrix != null) widget.controller.goTo(matrix);
            },
          ),

          const SizedBox(width: 16),
          const VerticalDivider(
              color: Color(0xFF313244), width: 1, indent: 8, endIndent: 8),
          const SizedBox(width: 16),

          // Prev page
          _ToolbarButton(
            icon: Icons.chevron_left,
            tooltip: '이전 페이지',
            onPressed: current > 1
                ? () => widget.controller.goToPage(pageNumber: current - 1)
                : null,
          ),

          // Page input
          SizedBox(
            width: 48,
            child: TextField(
              controller: _pageInput,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Color(0xFFCDD6F4),
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF313244)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF313244)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF89B4FA)),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                isDense: true,
              ),
              onSubmitted: (value) {
                final page = int.tryParse(value);
                if (page != null && page >= 1 && page <= total) {
                  widget.controller.goToPage(pageNumber: page);
                } else {
                  _pageInput.text = '$current';
                }
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '/ $total',
              style: const TextStyle(
                color: Color(0xFF6C7086),
                fontSize: 13,
              ),
            ),
          ),

          // Next page
          _ToolbarButton(
            icon: Icons.chevron_right,
            tooltip: '다음 페이지',
            onPressed: current < total
                ? () => widget.controller.goToPage(pageNumber: current + 1)
                : null,
          ),

          const SizedBox(width: 16),
          const VerticalDivider(
              color: Color(0xFF313244), width: 1, indent: 8, endIndent: 8),
          const SizedBox(width: 16),

          // OCR
          _ToolbarButton(
            icon: Icons.document_scanner,
            tooltip: 'OCR 텍스트 추출',
            onPressed: total > 0
                ? () => _runOcr(context, current)
                : null,
          ),
        ],
      ),
    );
  }

  void _runOcr(BuildContext context, int pageNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OcrResultDialog(
        filePath: widget.filePath,
        pageNumber: pageNumber,
      ),
    );
  }
}

class _OcrResultDialog extends StatefulWidget {
  const _OcrResultDialog({
    required this.filePath,
    required this.pageNumber,
  });

  final String filePath;
  final int pageNumber;

  @override
  State<_OcrResultDialog> createState() => _OcrResultDialogState();
}

class _OcrResultDialogState extends State<_OcrResultDialog> {
  String? _text;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _performOcr();
  }

  Future<void> _performOcr() async {
    try {
      final text = await OcrService.recognizePage(
        widget.filePath,
        widget.pageNumber,
      );
      if (mounted) setState(() { _text = text; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: Row(
        children: [
          const Icon(Icons.document_scanner,
              color: Color(0xFF89B4FA), size: 20),
          const SizedBox(width: 8),
          Text(
            'OCR — ${widget.pageNumber}페이지',
            style: const TextStyle(
                color: Color(0xFFCDD6F4), fontSize: 16),
          ),
          const Spacer(),
          if (_text != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: '복사',
              color: const Color(0xFF89B4FA),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _text!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('클립보드에 복사되었습니다'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF89B4FA)),
                    SizedBox(height: 16),
                    Text(
                      'OCR 처리 중...',
                      style: TextStyle(color: Color(0xFF6C7086)),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFF38BA8)),
                    ),
                  )
                : _text!.isEmpty
                    ? const Center(
                        child: Text(
                          '인식된 텍스트가 없습니다',
                          style: TextStyle(color: Color(0xFF6C7086)),
                        ),
                      )
                    : SelectableText(
                        _text!,
                        style: const TextStyle(
                          color: Color(0xFFCDD6F4),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      color: onPressed != null
          ? const Color(0xFFCDD6F4)
          : const Color(0xFF45475A),
    );
  }
}
