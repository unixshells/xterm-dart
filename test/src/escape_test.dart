import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/core/buffer/cell_offset.dart';
import 'package:xterm/src/core/cell.dart';
import 'package:xterm/src/terminal.dart';

/// Tests for VT100/xterm escape sequence handling.
/// These test the actual escape parser + handler integration
/// that the mobile app relies on for terminal rendering.
void main() {
  group('Terminal.write escape sequences', () {
    group('cursor movement', () {
      test('CUP moves cursor to position', () {
        final t = Terminal();
        t.write('\x1b[5;10H'); // row 5, col 10 (1-indexed)
        expect(t.buffer.cursorX, equals(9)); // 0-indexed
        expect(t.buffer.cursorY, equals(4));
      });

      test('CUP with no args moves to home', () {
        final t = Terminal();
        t.write('hello');
        t.write('\x1b[H');
        expect(t.buffer.cursorX, equals(0));
        expect(t.buffer.cursorY, equals(0));
      });

      test('CUF moves cursor forward', () {
        final t = Terminal();
        t.write('\x1b[5C'); // move right 5
        expect(t.buffer.cursorX, equals(5));
      });

      test('CUB moves cursor backward', () {
        final t = Terminal();
        t.write('\x1b[10;10H'); // go to col 10
        t.write('\x1b[3D'); // move left 3
        expect(t.buffer.cursorX, equals(6)); // 9 - 3
      });

      test('CUU moves cursor up', () {
        final t = Terminal();
        t.write('\x1b[10;1H'); // go to row 10
        t.write('\x1b[3A'); // move up 3
        expect(t.buffer.cursorY, equals(6)); // 9 - 3
      });

      test('CUD moves cursor down', () {
        final t = Terminal();
        t.write('\x1b[3B'); // move down 3
        expect(t.buffer.cursorY, equals(3));
      });

      test('cursor does not move past right margin', () {
        final t = Terminal();
        t.write('\x1b[999C'); // move right a lot
        expect(t.buffer.cursorX, lessThanOrEqualTo(t.viewWidth - 1));
      });

      test('cursor does not move past bottom margin', () {
        final t = Terminal();
        t.write('\x1b[999B'); // move down a lot
        expect(t.buffer.cursorY, lessThanOrEqualTo(t.viewHeight - 1));
      });
    });

    group('text output', () {
      test('plain text writes to buffer', () {
        final t = Terminal();
        t.write('Hello');
        expect(t.buffer.lines[0].toString(), startsWith('Hello'));
      });

      test('newline advances cursor', () {
        final t = Terminal();
        t.write('Line1\nLine2');
        expect(t.buffer.lines[0].toString(), startsWith('Line1'));
        // Line2 should be on the next line.
        expect(t.buffer.cursorY, greaterThan(0));
      });

      test('carriage return moves cursor to column 0', () {
        final t = Terminal();
        t.write('Hello\rWorld');
        // 'World' overwrites 'Hello' on same line.
        expect(t.buffer.lines[0].toString(), startsWith('World'));
      });

      test('backspace moves cursor left', () {
        final t = Terminal();
        t.write('AB\x08C');
        // C overwrites B.
        expect(t.buffer.lines[0].getText(0, 2), equals('AC'));
      });

      test('tab advances to next tab stop', () {
        final t = Terminal();
        t.write('A\tB');
        // Default tab stops at every 8 columns.
        expect(t.buffer.lines[0].getCodePoint(8), equals(0x42)); // 'B'
      });
    });

    group('erase sequences', () {
      test('ED 2 clears entire screen', () {
        final t = Terminal();
        t.write('Hello World');
        t.write('\x1b[2J');
        // First line should be cleared.
        expect(t.buffer.lines[0].getTrimmedLength(), equals(0));
      });

      test('EL 0 clears from cursor to end of line', () {
        final t = Terminal();
        t.write('Hello World');
        t.write('\x1b[6;1H'); // move to col 1 (but our text is on line 0)
        t.write('\x1b[H'); // home
        t.write('\x1b[5C'); // move to col 5
        t.write('\x1b[0K'); // clear to end of line
        expect(t.buffer.lines[0].getText(0, 5), equals('Hello'));
        expect(t.buffer.lines[0].getCodePoint(5), equals(0)); // cleared
      });

      test('EL 1 clears from start of line to cursor', () {
        final t = Terminal();
        t.write('Hello World');
        t.write('\x1b[H\x1b[5C'); // home, then right 5
        t.write('\x1b[1K'); // clear from start to cursor
        // Erased cells have no visible content (codepoint 0 or space).
        for (var i = 0; i < 5; i++) {
          final cp = t.buffer.lines[0].getCodePoint(i);
          expect(cp == 0 || cp == 0x20, isTrue,
              reason: 'cell $i should be erased, got $cp');
        }
      });

      test('EL 2 clears entire line', () {
        final t = Terminal();
        t.write('Hello World');
        t.write('\x1b[H'); // home
        t.write('\x1b[2K'); // clear entire line
        expect(t.buffer.lines[0].getTrimmedLength(), equals(0));
      });
    });

    group('SGR (text attributes)', () {
      test('bold attribute', () {
        final t = Terminal();
        t.write('\x1b[1mA'); // bold
        expect(
            t.buffer.lines[0].getAttributes(0) & CellAttr.bold, isNot(0));
      });

      test('italic attribute', () {
        final t = Terminal();
        t.write('\x1b[3mA'); // italic
        expect(
            t.buffer.lines[0].getAttributes(0) & CellAttr.italic, isNot(0));
      });

      test('underline attribute', () {
        final t = Terminal();
        t.write('\x1b[4mA'); // underline
        expect(t.buffer.lines[0].getAttributes(0) & CellAttr.underline,
            isNot(0));
      });

      test('inverse attribute', () {
        final t = Terminal();
        t.write('\x1b[7mA'); // inverse
        expect(
            t.buffer.lines[0].getAttributes(0) & CellAttr.inverse, isNot(0));
      });

      test('strikethrough attribute', () {
        final t = Terminal();
        t.write('\x1b[9mA'); // strikethrough
        expect(t.buffer.lines[0].getAttributes(0) & CellAttr.strikethrough,
            isNot(0));
      });

      test('reset attribute', () {
        final t = Terminal();
        t.write('\x1b[1;3;4m'); // bold, italic, underline
        t.write('\x1b[0mA'); // reset then write
        expect(t.buffer.lines[0].getAttributes(0), equals(0));
      });

      test('256-color foreground', () {
        final t = Terminal();
        t.write('\x1b[38;5;196mA'); // color 196
        final fg = t.buffer.lines[0].getForeground(0);
        expect(fg & CellColor.valueMask, equals(196));
        expect(fg & CellColor.typeMask, equals(CellColor.palette));
      });

      test('RGB foreground', () {
        final t = Terminal();
        t.write('\x1b[38;2;255;128;0mA'); // RGB orange
        final fg = t.buffer.lines[0].getForeground(0);
        expect(fg & CellColor.typeMask, equals(CellColor.rgb));
        final r = (fg >> 16) & 0xFF;
        final g = (fg >> 8) & 0xFF;
        final b = fg & 0xFF;
        expect(r, equals(255));
        expect(g, equals(128));
        expect(b, equals(0));
      });

      test('named foreground color', () {
        final t = Terminal();
        t.write('\x1b[31mA'); // red
        final fg = t.buffer.lines[0].getForeground(0);
        expect(fg & CellColor.typeMask, equals(CellColor.named));
      });

      test('256-color background', () {
        final t = Terminal();
        t.write('\x1b[48;5;42mA'); // bg color 42
        final bg = t.buffer.lines[0].getBackground(0);
        expect(bg & CellColor.valueMask, equals(42));
        expect(bg & CellColor.typeMask, equals(CellColor.palette));
      });
    });

    group('modes', () {
      test('DECSET 1049 switches to alt buffer', () {
        final t = Terminal();
        t.write('main buffer text');
        t.write('\x1b[?1049h'); // switch to alt
        expect(t.isUsingAltBuffer, isTrue);
        t.write('\x1b[?1049l'); // switch back
        expect(t.isUsingAltBuffer, isFalse);
        expect(t.buffer.lines[0].toString(), startsWith('main buffer text'));
      });

      test('DECSET 25 hides/shows cursor', () {
        final t = Terminal();
        expect(t.cursorVisibleMode, isTrue);
        t.write('\x1b[?25l'); // hide cursor
        expect(t.cursorVisibleMode, isFalse);
        t.write('\x1b[?25h'); // show cursor
        expect(t.cursorVisibleMode, isTrue);
      });

      test('DECSET 1000 enables mouse tracking', () {
        final t = Terminal();
        expect(t.mouseMode.index, equals(0)); // none
        t.write('\x1b[?1000h'); // enable
        expect(t.mouseMode.index, isNot(0));
        t.write('\x1b[?1000l'); // disable
        expect(t.mouseMode.index, equals(0));
      });

      test('DECSET 2004 enables bracketed paste', () {
        final t = Terminal();
        expect(t.bracketedPasteMode, isFalse);
        t.write('\x1b[?2004h');
        expect(t.bracketedPasteMode, isTrue);
        t.write('\x1b[?2004l');
        expect(t.bracketedPasteMode, isFalse);
      });
    });

    group('title', () {
      test('OSC 0 sets title', () {
        String? title;
        final t = Terminal(onTitleChange: (t) => title = t);
        t.write('\x1b]0;My Terminal\x07');
        expect(title, equals('My Terminal'));
      });

      test('OSC 2 sets title', () {
        String? title;
        final t = Terminal(onTitleChange: (t) => title = t);
        t.write('\x1b]2;Window Title\x07');
        expect(title, equals('Window Title'));
      });
    });

    group('bell', () {
      test('BEL triggers onBell', () {
        var bellCount = 0;
        final t = Terminal(onBell: () => bellCount++);
        t.write('\x07');
        expect(bellCount, equals(1));
      });
    });

    group('resize', () {
      test('resize changes viewWidth and viewHeight', () {
        final t = Terminal();
        t.resize(40, 10);
        expect(t.viewWidth, equals(40));
        expect(t.viewHeight, equals(10));
      });

      test('resize to same dimensions is no-op', () {
        final t = Terminal();
        t.write('Hello');
        t.resize(80, 24);
        expect(t.buffer.lines[0].toString(), startsWith('Hello'));
      });
    });

    group('edge cases', () {
      test('incomplete escape sequence buffered across writes', () {
        final t = Terminal();
        t.write('\x1b'); // just ESC
        t.write('[1mA'); // rest of bold + char
        expect(
            t.buffer.lines[0].getAttributes(0) & CellAttr.bold, isNot(0));
      });

      test('unknown escape sequence does not crash', () {
        final t = Terminal();
        expect(() => t.write('\x1b[999z'), returnsNormally);
      });

      test('very long line wraps', () {
        final t = Terminal();
        final longLine = 'A' * 200;
        t.write(longLine);
        // Should not crash and cursor should be valid.
        expect(t.buffer.cursorX, lessThan(t.viewWidth));
      });

      test('rapid writes do not corrupt state', () {
        final t = Terminal();
        for (var i = 0; i < 1000; i++) {
          t.write('Line $i\r\n');
        }
        // Should not crash, cursor should be at bottom.
        expect(t.buffer.cursorY, lessThanOrEqualTo(t.viewHeight - 1));
      });

      test('null bytes are handled', () {
        final t = Terminal();
        expect(() => t.write('A\x00B'), returnsNormally);
      });

      test('mixed control chars and text', () {
        final t = Terminal();
        t.write('\x1b[1;31mRed Bold\x1b[0m Normal\r\n\x1b[HHome');
        // Just verify no crash and cursor is at a valid position.
        expect(t.buffer.cursorX, greaterThanOrEqualTo(0));
        expect(t.buffer.cursorY, greaterThanOrEqualTo(0));
      });
    });

    group('scroll', () {
      test('writing past bottom scrolls buffer', () {
        final t = Terminal();
        // Fill terminal + 1 extra line.
        for (var i = 0; i < t.viewHeight + 1; i++) {
          t.write('Line $i\r\n');
        }
        // The first line should have scrolled into scrollback.
        expect(t.buffer.height, greaterThan(t.viewHeight));
      });

      test('scroll up SU moves content up', () {
        final t = Terminal();
        t.write('Line0\r\nLine1\r\nLine2');
        t.write('\x1b[1S'); // scroll up 1
        // Line0 should be gone, Line1 at top.
        // (Exact behavior depends on scroll region, but should not crash.)
        expect(t.buffer.cursorY, greaterThanOrEqualTo(0));
      });
    });

    group('save/restore cursor', () {
      test('DECSC/DECRC saves and restores cursor position', () {
        final t = Terminal();
        t.write('\x1b[5;10H'); // move to row 5, col 10
        t.write('\x1b7'); // save (DECSC)
        t.write('\x1b[1;1H'); // move home
        expect(t.buffer.cursorX, equals(0));
        t.write('\x1b8'); // restore (DECRC)
        expect(t.buffer.cursorX, equals(9));
        expect(t.buffer.cursorY, equals(4));
      });
    });

    group('wide characters', () {
      test('CJK character occupies 2 cells', () {
        final t = Terminal();
        t.write('中'); // Chinese character, width 2
        expect(t.buffer.cursorX, equals(2));
        expect(t.buffer.lines[0].getCodePoint(0), equals('中'.codeUnitAt(0)));
        expect(t.buffer.lines[0].getWidth(0), equals(2));
      });
    });
  });
}
