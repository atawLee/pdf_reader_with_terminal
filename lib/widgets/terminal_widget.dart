import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

/// Available shells the user can pick from.
enum _Shell {
  powershell('PowerShell', 'powershell.exe'),
  cmd('CMD', 'cmd.exe');

  const _Shell(this.label, this.executable);
  final String label;
  final String executable;
}

class TerminalWidget extends StatefulWidget {
  const TerminalWidget({super.key});

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  late Terminal _terminal;
  final _terminalFocusNode = FocusNode();
  Pty? _pty;
  _Shell _shell = _Shell.powershell;

  /// 한글 입력창
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  bool _showInputBar = false;

  /// 명령 히스토리 (입력창 모드용)
  final List<String> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _startPty();
  }

  @override
  void dispose() {
    _pty?.kill();
    _terminalFocusNode.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _startPty() {
    _pty?.kill();
    _terminal = Terminal(maxLines: 10000);

    final pty = Pty.start(
      _shell.executable,
      columns: _terminal.viewWidth,
      rows: _terminal.viewHeight,
      environment: Platform.environment,
    );

    pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen((data) {
      _terminal.write(data);
    });

    _terminal.onOutput = (data) {
      pty.write(const Utf8Encoder().convert(data));
    };

    _terminal.onResize = (w, h, _, __) {
      pty.resize(h, w);
    };

    setState(() => _pty = pty);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _terminalFocusNode.requestFocus();
    });

    pty.exitCode.then((_) {
      if (mounted) {
        _terminal.write('\r\n\x1b[90m--- 셸 종료됨 ---\x1b[0m\r\n');
      }
    });
  }

  void _switchShell(_Shell shell) {
    setState(() => _shell = shell);
    _startPty();
  }

  // ── 한글 입력창 ──

  void _toggleInputBar() {
    setState(() => _showInputBar = !_showInputBar);
    if (_showInputBar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocusNode.requestFocus();
      });
    } else {
      _inputController.clear();
      _historyIndex = -1;
      _terminalFocusNode.requestFocus();
    }
  }

  void _onInputSubmitted(String text) {
    final pty = _pty;
    if (pty == null) return;

    if (text.isNotEmpty) {
      _history.add(text);
    }
    _historyIndex = -1;

    final cr = Platform.isWindows ? '\r\n' : '\n';
    pty.write(const Utf8Encoder().convert(text + cr));
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  KeyEventResult _onInputKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Esc 또는 F1 → 입력창 닫기
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.f1) {
      _toggleInputBar();
      return KeyEventResult.handled;
    }

    // Ctrl+C → 인터럽트
    if (event.logicalKey == LogicalKeyboardKey.keyC &&
        HardwareKeyboard.instance.isControlPressed) {
      _pty?.write(const Utf8Encoder().convert('\x03'));
      _inputController.clear();
      return KeyEventResult.handled;
    }

    // 위 화살표 → 이전 히스토리
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_history.isNotEmpty) {
        if (_historyIndex == -1) {
          _historyIndex = _history.length - 1;
        } else if (_historyIndex > 0) {
          _historyIndex--;
        }
        _inputController.text = _history[_historyIndex];
        _inputController.selection = TextSelection.collapsed(
          offset: _inputController.text.length,
        );
      }
      return KeyEventResult.handled;
    }

    // 아래 화살표 → 다음 히스토리
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_historyIndex != -1) {
        if (_historyIndex < _history.length - 1) {
          _historyIndex++;
          _inputController.text = _history[_historyIndex];
        } else {
          _historyIndex = -1;
          _inputController.clear();
        }
        _inputController.selection = TextSelection.collapsed(
          offset: _inputController.text.length,
        );
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar ──
        Container(
          height: 32,
          decoration: const BoxDecoration(
            color: Color(0xFF181825),
            border: Border(top: BorderSide(color: Color(0xFF313244))),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.terminal, size: 14, color: Color(0xFF89B4FA)),
              const SizedBox(width: 6),
              PopupMenuButton<_Shell>(
                initialValue: _shell,
                onSelected: _switchShell,
                tooltip: '셸 변경',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minHeight: 28),
                position: PopupMenuPosition.under,
                color: const Color(0xFF1E1E2E),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _shell.label,
                      style: const TextStyle(
                        color: Color(0xFFCDD6F4),
                        fontSize: 12,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Color(0xFF6C7086),
                    ),
                  ],
                ),
                itemBuilder: (_) => _Shell.values
                    .map(
                      (s) => PopupMenuItem(
                        value: s,
                        height: 32,
                        child: Text(
                          s.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const Spacer(),
              // 한글 입력창 토글
              Tooltip(
                message: '한글 입력 (F1)',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleInputBar,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _showInputBar
                            ? const Color(0xFF89B4FA).withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: _showInputBar
                            ? Border.all(
                                color: const Color(0xFF89B4FA)
                                    .withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard,
                            size: 13,
                            color: _showInputBar
                                ? const Color(0xFF89B4FA)
                                : const Color(0xFF6C7086),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '한글',
                            style: TextStyle(
                              fontSize: 11,
                              color: _showInputBar
                                  ? const Color(0xFF89B4FA)
                                  : const Color(0xFF6C7086),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),

        // ── Terminal view ──
        Expanded(
          child: TerminalView(
            _terminal,
            focusNode: _terminalFocusNode,
            textStyle: const TerminalStyle(
              fontSize: 13,
              fontFamily: 'Consolas',
            ),
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.f1) {
                _toggleInputBar();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
          ),
        ),

        // ── 한글 입력 바 (토글) ──
        if (_showInputBar)
          Container(
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E2E),
              border: Border(top: BorderSide(color: Color(0xFF313244))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Text(
                  '\$',
                  style: TextStyle(
                    color: Color(0xFF89B4FA),
                    fontSize: 13,
                    fontFamily: 'Consolas',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Focus(
                    onKeyEvent: _onInputKeyEvent,
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      style: const TextStyle(
                        color: Color(0xFFCDD6F4),
                        fontSize: 13,
                        fontFamily: 'Consolas',
                      ),
                      decoration: const InputDecoration(
                        hintText: '한글 입력 후 Enter · F1/Esc로 닫기',
                        hintStyle: TextStyle(
                          color: Color(0xFF585B70),
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      cursorColor: const Color(0xFF89B4FA),
                      onSubmitted: _onInputSubmitted,
                    ),
                  ),
                ),
                _MiniButton(
                  icon: Icons.send,
                  tooltip: '전송 (Enter)',
                  onPressed: () => _onInputSubmitted(_inputController.text),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 14),
      tooltip: tooltip,
      onPressed: onPressed,
      color: const Color(0xFF6C7086),
      splashRadius: 14,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}
