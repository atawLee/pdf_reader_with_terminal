import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TerminalWidget extends StatefulWidget {
  const TerminalWidget({super.key});

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _outputLines = <_TermLine>[];

  Process? _process;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _startShell();
  }

  @override
  void dispose() {
    _process?.kill();
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _startShell() async {
    _process?.kill();
    _outputLines.clear();

    final shell = Platform.environment['COMSPEC'] ?? 'cmd.exe';
    _process = await Process.start(shell, [], runInShell: false);
    setState(() => _running = true);

    _process!.stdout.transform(utf8.decoder).listen(_onStdout);
    _process!.stderr.transform(utf8.decoder).listen(_onStderr);
    _process!.exitCode.then((_) {
      if (mounted) {
        setState(() => _running = false);
        _appendLine('--- 셸 종료됨 ---', _LineKind.system);
      }
    });
  }

  void _onStdout(String data) {
    if (!mounted) return;
    _appendLine(data, _LineKind.stdout);
  }

  void _onStderr(String data) {
    if (!mounted) return;
    _appendLine(data, _LineKind.stderr);
  }

  void _appendLine(String text, _LineKind kind) {
    setState(() {
      _outputLines.add(_TermLine(text, kind));
      // Keep buffer bounded.
      if (_outputLines.length > 5000) {
        _outputLines.removeRange(0, _outputLines.length - 4000);
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _sendCommand(String command) {
    if (_process == null || !_running) return;
    _process!.stdin.writeln(command);
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  void _clearOutput() {
    setState(() => _outputLines.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab bar
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
              const Text(
                '터미널',
                style: TextStyle(color: Color(0xFFCDD6F4), fontSize: 12),
              ),
              const Spacer(),
              _MiniButton(
                icon: Icons.restart_alt,
                tooltip: '재시작',
                onPressed: _startShell,
              ),
              _MiniButton(
                icon: Icons.delete_outline,
                tooltip: '지우기',
                onPressed: _clearOutput,
              ),
            ],
          ),
        ),

        // Output area
        Expanded(
          child: GestureDetector(
            onTap: () => _inputFocusNode.requestFocus(),
            child: Container(
              color: const Color(0xFF11111B),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: SelectionArea(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _outputLines.length,
                  itemBuilder: (_, i) {
                    final line = _outputLines[i];
                    return Text(
                      line.text,
                      style: TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                        height: 1.4,
                        color: switch (line.kind) {
                          _LineKind.stdout => const Color(0xFFCDD6F4),
                          _LineKind.stderr => const Color(0xFFF38BA8),
                          _LineKind.system => const Color(0xFF6C7086),
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // Input row
        Container(
          height: 34,
          color: const Color(0xFF181825),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const Text(
                '>',
                style: TextStyle(
                  fontFamily: 'Consolas',
                  fontSize: 13,
                  color: Color(0xFF89B4FA),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    // Let TextField handle Enter via onSubmitted
                  },
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                      color: Color(0xFFCDD6F4),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      hintText: '명령어를 입력하세요...',
                      hintStyle: TextStyle(
                        color: Color(0xFF45475A),
                        fontSize: 13,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) _sendCommand(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _LineKind { stdout, stderr, system }

class _TermLine {
  const _TermLine(this.text, this.kind);
  final String text;
  final _LineKind kind;
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
