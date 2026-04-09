import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
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

  // OCR side panel state
  bool _ocrVisible = false;
  bool _ocrLoading = false;
  String? _ocrText;
  String? _ocrError;
  int _ocrPage = 0;

  // Note side panel state
  bool _noteVisible = false;
  late final TextEditingController _noteController;
  Timer? _saveTimer;
  bool _noteDirty = false;
  int _notePage = 1;

  String _noteFilePathForPage(int page) {
    final dir = p.dirname(widget.filePath);
    final name = p.basenameWithoutExtension(widget.filePath);
    return p.join(dir, '${name}_$page.md');
  }

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    if (_noteDirty) _saveNoteSync();
    _saveTimer?.cancel();
    _noteController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── OCR ────────────────────────────────────────────────────────────────────

  void _toggleOcr(int pageNumber) {
    if (_ocrVisible && _ocrPage == pageNumber) {
      setState(() => _ocrVisible = false);
      return;
    }
    setState(() {
      _ocrVisible = true;
      _ocrLoading = true;
      _ocrText = null;
      _ocrError = null;
      _ocrPage = pageNumber;
    });
    _performOcr(pageNumber);
  }

  Future<void> _performOcr(int pageNumber) async {
    try {
      final text = await OcrService.recognizePage(
        widget.filePath,
        pageNumber,
      );
      if (mounted && _ocrPage == pageNumber) {
        setState(() {
          _ocrText = text;
          _ocrLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _ocrPage == pageNumber) {
        setState(() {
          _ocrError = e.toString();
          _ocrLoading = false;
        });
      }
    }
  }

  // ── Note ───────────────────────────────────────────────────────────────────

  /// Save current note, then load the note for [page].
  Future<void> _switchNotePage(int page) async {
    if (page == _notePage && _noteController.text.isNotEmpty) return;
    // Save current page note first.
    if (_noteDirty) await _saveNote();
    _notePage = page;
    await _loadNote(page);
  }

  Future<void> _loadNote(int page) async {
    final file = File(_noteFilePathForPage(page));
    if (await file.exists()) {
      final content = await file.readAsString();
      _noteController.text = content;
    } else {
      _noteController.clear();
    }
    _noteDirty = false;
  }

  void _onNoteChanged() {
    _noteDirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _saveNote);
  }

  Future<void> _saveNote() async {
    if (!_noteDirty) return;
    _noteDirty = false;
    final filePath = _noteFilePathForPage(_notePage);
    if (_noteController.text.isEmpty) {
      // Remove empty note files.
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } else {
      await File(filePath).writeAsString(_noteController.text);
    }
  }

  void _saveNoteSync() {
    final filePath = _noteFilePathForPage(_notePage);
    if (_noteController.text.isEmpty) {
      final file = File(filePath);
      if (file.existsSync()) file.deleteSync();
    } else {
      File(filePath).writeAsStringSync(_noteController.text);
    }
    _noteDirty = false;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // PDF viewer area
        Expanded(
          child: KeyboardListener(
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
                        if (_noteVisible) _switchNotePage(page);
                      }
                    },
                    layoutPages: (pages, params) {
                      final width = pages.fold(
                          0.0, (max, p) => p.width > max ? p.width : max);
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
                    ocrVisible: _ocrVisible,
                    noteVisible: _noteVisible,
                    onOcrPressed: (page) => _toggleOcr(page),
                    onNotePressed: () {
                      if (_noteVisible) {
                        if (_noteDirty) _saveNote();
                        setState(() => _noteVisible = false);
                      } else {
                        final page = ref.read(currentPageProvider);
                        _notePage = page;
                        _loadNote(page);
                        setState(() => _noteVisible = true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // OCR side panel
        if (_ocrVisible) ...[
          const VerticalDivider(
              width: 1, thickness: 1, color: Color(0xFF313244)),
          SizedBox(
            width: 340,
            child: _OcrSidePanel(
              pageNumber: _ocrPage,
              loading: _ocrLoading,
              text: _ocrText,
              error: _ocrError,
              onClose: () => setState(() => _ocrVisible = false),
              onRefresh: () => _toggleOcr(ref.read(currentPageProvider)),
            ),
          ),
        ],

        // Note side panel
        if (_noteVisible) ...[
          const VerticalDivider(
              width: 1, thickness: 1, color: Color(0xFF313244)),
          SizedBox(
            width: 360,
            child: _NoteSidePanel(
              pageNumber: _notePage,
              controller: _noteController,
              onChanged: _onNoteChanged,
              onClose: () {
                if (_noteDirty) _saveNote();
                setState(() => _noteVisible = false);
              },
            ),
          ),
        ],
      ],
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

// ── OCR Side Panel ──────────────────────────────────────────────────────────

class _OcrSidePanel extends StatelessWidget {
  const _OcrSidePanel({
    required this.pageNumber,
    required this.loading,
    required this.text,
    required this.error,
    required this.onClose,
    required this.onRefresh,
  });

  final int pageNumber;
  final bool loading;
  final String? text;
  final String? error;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.document_scanner,
            title: 'OCR — $pageNumber페이지',
            actions: [
              if (text != null)
                _PanelButton(
                  icon: Icons.copy,
                  tooltip: '복사',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('클립보드에 복사되었습니다'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              _PanelButton(
                icon: Icons.refresh,
                tooltip: '현재 페이지 다시 인식',
                onPressed: loading ? null : onRefresh,
              ),
              _PanelButton(
                icon: Icons.close,
                tooltip: '닫기',
                onPressed: onClose,
              ),
            ],
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Color(0xFF89B4FA),
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'OCR 처리 중...',
                          style: TextStyle(
                              color: Color(0xFF6C7086), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            error!,
                            style: const TextStyle(
                                color: Color(0xFFF38BA8), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : text != null && text!.isEmpty
                        ? const Center(
                            child: Text(
                              '인식된 텍스트가 없습니다',
                              style: TextStyle(
                                  color: Color(0xFF6C7086), fontSize: 13),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            child: SelectableText(
                              text ?? '',
                              style: const TextStyle(
                                color: Color(0xFFCDD6F4),
                                fontSize: 13,
                                height: 1.7,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Note Side Panel ─────────────────────────────────────────────────────────

class _NoteSidePanel extends StatelessWidget {
  const _NoteSidePanel({
    required this.pageNumber,
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final int pageNumber;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.edit_note,
            title: '노트 — $pageNumber페이지',
            actions: [
              _PanelButton(
                icon: Icons.copy,
                tooltip: '복사',
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: controller.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('클립보드에 복사되었습니다'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              _PanelButton(
                icon: Icons.delete_outline,
                tooltip: '전체 지우기',
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
              _PanelButton(
                icon: Icons.close,
                tooltip: '닫기',
                onPressed: onClose,
              ),
            ],
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'Consolas',
                color: Color(0xFFCDD6F4),
                fontSize: 13,
                height: 1.7,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
                hintText: '마크다운으로 노트를 작성하세요...\n\n# 제목\n- 항목 1\n- 항목 2',
                hintStyle: TextStyle(
                  color: Color(0xFF45475A),
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Panel Widgets ────────────────────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.icon,
    required this.title,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF313244))),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF89B4FA), size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style:
                const TextStyle(color: Color(0xFFCDD6F4), fontSize: 13),
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
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
      icon: Icon(icon, size: 16),
      tooltip: tooltip,
      onPressed: onPressed,
      color: onPressed != null
          ? const Color(0xFF6C7086)
          : const Color(0xFF45475A),
      splashRadius: 14,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

// ── Bottom Toolbar ──────────────────────────────────────────────────────────

class _BottomToolbar extends ConsumerStatefulWidget {
  const _BottomToolbar({
    required this.controller,
    required this.ocrVisible,
    required this.noteVisible,
    required this.onOcrPressed,
    required this.onNotePressed,
  });

  final PdfViewerController controller;
  final bool ocrVisible;
  final bool noteVisible;
  final void Function(int pageNumber) onOcrPressed;
  final VoidCallback onNotePressed;

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
            active: widget.ocrVisible,
            onPressed: total > 0
                ? () => widget.onOcrPressed(current)
                : null,
          ),

          // Note
          _ToolbarButton(
            icon: Icons.edit_note,
            tooltip: '노트',
            active: widget.noteVisible,
            onPressed: total > 0 ? widget.onNotePressed : null,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      color: active
          ? const Color(0xFF89B4FA)
          : onPressed != null
              ? const Color(0xFFCDD6F4)
              : const Color(0xFF45475A),
    );
  }
}
