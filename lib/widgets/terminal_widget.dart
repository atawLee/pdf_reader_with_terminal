import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

    // Give focus to the terminal after build.
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
              // Shell selector
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
                          color: Color(0xFFCDD6F4), fontSize: 12),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        size: 16, color: Color(0xFF6C7086)),
                  ],
                ),
                itemBuilder: (_) => _Shell.values
                    .map((s) => PopupMenuItem(
                          value: s,
                          height: 32,
                          child: Text(s.label,
                              style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
              ),
              const Spacer(),
              _MiniButton(
                icon: Icons.restart_alt,
                tooltip: '재시작',
                onPressed: _startPty,
              ),
            ],
          ),
        ),

        // Terminal view
        Expanded(
          child: TerminalView(
            _terminal,
            focusNode: _terminalFocusNode,
            autofocus: true,
            hardwareKeyboardOnly: true,
            textStyle: const TerminalStyle(
              fontFamily: 'Consolas',
              fontSize: 13,
            ),
            theme: const TerminalTheme(
              cursor: Color(0xFF89B4FA),
              selection: Color(0x4089B4FA),
              foreground: Color(0xFFCDD6F4),
              background: Color(0xFF11111B),
              black: Color(0xFF45475A),
              red: Color(0xFFF38BA8),
              green: Color(0xFFA6E3A1),
              yellow: Color(0xFFF9E2AF),
              blue: Color(0xFF89B4FA),
              magenta: Color(0xFFF5C2E7),
              cyan: Color(0xFF94E2D5),
              white: Color(0xFFBAC2DE),
              brightBlack: Color(0xFF585B70),
              brightRed: Color(0xFFF38BA8),
              brightGreen: Color(0xFFA6E3A1),
              brightYellow: Color(0xFFF9E2AF),
              brightBlue: Color(0xFF89B4FA),
              brightMagenta: Color(0xFFF5C2E7),
              brightCyan: Color(0xFF94E2D5),
              brightWhite: Color(0xFFA6ADC8),
              searchHitBackground: Color(0xFFF9E2AF),
              searchHitBackgroundCurrent: Color(0xFFFAB387),
              searchHitForeground: Color(0xFF1E1E2E),
            ),
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
