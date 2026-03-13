import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/src/core/buffer/line.dart';
import 'package:xterm/src/core/cell.dart';
import 'package:xterm/src/core/cursor.dart';

void main() {
  group('BufferLine', () {
    test('creation with length', () {
      final line = BufferLine(10);
      expect(line.length, equals(10));
      expect(line.isWrapped, isFalse);
    });

    test('creation with isWrapped', () {
      final line = BufferLine(10, isWrapped: true);
      expect(line.isWrapped, isTrue);
    });

    test('isWrapped can be toggled', () {
      final line = BufferLine(10);
      expect(line.isWrapped, isFalse);
      line.isWrapped = true;
      expect(line.isWrapped, isTrue);
      line.isWrapped = false;
      expect(line.isWrapped, isFalse);
    });

    test('setContent and getContent round-trip', () {
      final line = BufferLine(10);
      line.setContent(0, 0x41 | (1 << CellContent.widthShift));
      expect(line.getCodePoint(0), equals(0x41)); // 'A'
      expect(line.getWidth(0), equals(1));
    });

    test('setCodePoint sets width from unicode table', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x41); // 'A' - width 1
      expect(line.getCodePoint(0), equals(0x41));
      expect(line.getWidth(0), equals(1));
    });

    test('setForeground and getForeground round-trip', () {
      final line = BufferLine(10);
      line.setForeground(0, 0xFF0000 | CellColor.rgb);
      expect(line.getForeground(0), equals(0xFF0000 | CellColor.rgb));
    });

    test('setBackground and getBackground round-trip', () {
      final line = BufferLine(10);
      line.setBackground(3, 42 | CellColor.palette);
      expect(line.getBackground(3), equals(42 | CellColor.palette));
    });

    test('setAttributes and getAttributes round-trip', () {
      final line = BufferLine(10);
      line.setAttributes(0, CellAttr.bold | CellAttr.underline);
      expect(line.getAttributes(0),
          equals(CellAttr.bold | CellAttr.underline));
    });

    test('setCell sets all fields', () {
      final line = BufferLine(10);
      final style = CursorStyle(
        foreground: 1 | CellColor.named,
        background: 2 | CellColor.named,
        attrs: CellAttr.italic,
      );
      line.setCell(0, 0x42, 1, style); // 'B'
      expect(line.getCodePoint(0), equals(0x42));
      expect(line.getWidth(0), equals(1));
      expect(line.getForeground(0), equals(1 | CellColor.named));
      expect(line.getBackground(0), equals(2 | CellColor.named));
      expect(line.getAttributes(0), equals(CellAttr.italic));
    });

    test('getCellData reads all fields', () {
      final line = BufferLine(10);
      final style = CursorStyle(
        foreground: 0xFF,
        background: 0xAA,
        attrs: CellAttr.bold,
      );
      line.setCell(0, 0x43, 1, style);

      final cellData = CellData.empty();
      line.getCellData(0, cellData);
      expect(cellData.foreground, equals(0xFF));
      expect(cellData.background, equals(0xAA));
      expect(cellData.flags, equals(CellAttr.bold));
      expect(cellData.content & CellContent.codepointMask, equals(0x43));
    });

    test('eraseCell clears content but keeps style', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x41);
      final style = CursorStyle(foreground: 0xFF);
      line.eraseCell(0, style);
      expect(line.getCodePoint(0), equals(0));
      expect(line.getForeground(0), equals(0xFF));
    });

    test('resetCell clears everything', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x41);
      line.setForeground(0, 0xFF);
      line.setBackground(0, 0xAA);
      line.setAttributes(0, CellAttr.bold);
      line.resetCell(0);
      expect(line.getCodePoint(0), equals(0));
      expect(line.getForeground(0), equals(0));
      expect(line.getBackground(0), equals(0));
      expect(line.getAttributes(0), equals(0));
    });

    test('eraseRange clears multiple cells', () {
      final line = BufferLine(10);
      for (var i = 0; i < 5; i++) {
        line.setCodePoint(i, 0x41 + i); // A, B, C, D, E
      }
      line.eraseRange(1, 4, CursorStyle.empty);
      expect(line.getCodePoint(0), equals(0x41)); // A untouched
      expect(line.getCodePoint(1), equals(0)); // erased
      expect(line.getCodePoint(2), equals(0)); // erased
      expect(line.getCodePoint(3), equals(0)); // erased
      expect(line.getCodePoint(4), equals(0x45)); // E untouched
    });

    test('removeCells shifts cells left', () {
      final line = BufferLine(10);
      for (var i = 0; i < 5; i++) {
        line.setCodePoint(i, 0x41 + i); // A, B, C, D, E
      }
      line.removeCells(1, 2); // remove B, C
      expect(line.getCodePoint(0), equals(0x41)); // A
      expect(line.getCodePoint(1), equals(0x44)); // D (shifted)
      expect(line.getCodePoint(2), equals(0x45)); // E (shifted)
      expect(line.getCodePoint(3), equals(0)); // cleared
    });

    test('insertCells shifts cells right', () {
      final line = BufferLine(10);
      for (var i = 0; i < 5; i++) {
        line.setCodePoint(i, 0x41 + i); // A, B, C, D, E
      }
      line.insertCells(1, 2); // insert 2 at position 1
      expect(line.getCodePoint(0), equals(0x41)); // A
      expect(line.getCodePoint(1), equals(0)); // inserted
      expect(line.getCodePoint(2), equals(0)); // inserted
      expect(line.getCodePoint(3), equals(0x42)); // B (shifted)
      expect(line.getCodePoint(4), equals(0x43)); // C (shifted)
    });

    test('resize grows line', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x41);
      line.resize(20);
      expect(line.length, equals(20));
      expect(line.getCodePoint(0), equals(0x41)); // preserved
    });

    test('resize shrinks line', () {
      final line = BufferLine(20);
      line.setCodePoint(0, 0x41);
      line.resize(5);
      expect(line.length, equals(5));
      expect(line.getCodePoint(0), equals(0x41)); // preserved
    });

    test('resize to same length is no-op', () {
      final line = BufferLine(10);
      line.setCodePoint(5, 0x41);
      line.resize(10);
      expect(line.length, equals(10));
      expect(line.getCodePoint(5), equals(0x41));
    });

    test('getTrimmedLength with empty line', () {
      final line = BufferLine(10);
      expect(line.getTrimmedLength(), equals(0));
    });

    test('getTrimmedLength with content', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x41);
      line.setCodePoint(1, 0x42);
      line.setCodePoint(2, 0x43);
      expect(line.getTrimmedLength(), equals(3));
    });

    test('getTrimmedLength with gap', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x41);
      line.setCodePoint(5, 0x42);
      expect(line.getTrimmedLength(), equals(6));
    });

    test('getText returns string content', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x48); // H
      line.setCodePoint(1, 0x69); // i
      expect(line.getText(), equals('Hi'));
    });

    test('getText with range', () {
      final line = BufferLine(10);
      for (var i = 0; i < 5; i++) {
        line.setCodePoint(i, 0x41 + i); // A, B, C, D, E
      }
      expect(line.getText(1, 4), equals('BCD'));
    });

    test('getText with negative from clamps to 0', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x41);
      expect(line.getText(-5, 1), equals('A'));
    });

    test('getText with to beyond length clamps', () {
      final line = BufferLine(10);
      line.setCodePoint(0, 0x41);
      expect(line.getText(0, 100), equals('A'));
    });

    test('copyFrom copies cells between lines', () {
      final src = BufferLine(10);
      src.setCodePoint(0, 0x41); // A
      src.setCodePoint(1, 0x42); // B
      src.setCodePoint(2, 0x43); // C

      final dst = BufferLine(10);
      dst.copyFrom(src, 1, 3, 2); // copy B,C to dst starting at 3

      expect(dst.getCodePoint(3), equals(0x42)); // B
      expect(dst.getCodePoint(4), equals(0x43)); // C
      expect(dst.getCodePoint(0), equals(0)); // untouched
    });

    test('toString returns getText', () {
      final line = BufferLine(5);
      line.setCodePoint(0, 0x48); // H
      line.setCodePoint(1, 0x69); // i
      expect(line.toString(), equals('Hi'));
    });
  });

  group('CellAnchor', () {
    test('createAnchor tracks position', () {
      final line = BufferLine(10);
      final anchor = line.createAnchor(5);
      expect(anchor.x, equals(5));
    });

    test('removeCells repositions anchors', () {
      final line = BufferLine(10);
      final anchor = line.createAnchor(5);
      line.removeCells(2, 2); // remove 2 cells before anchor
      expect(anchor.x, equals(3)); // shifted left by 2
    });

    test('removeCells disposes anchor in removed range', () {
      final line = BufferLine(10);
      final anchor = line.createAnchor(3);
      line.removeCells(2, 3); // remove range including anchor position
      // Anchor should be disposed (removed from line's anchors list).
      expect(line.anchors, isEmpty);
    });

    test('anchor dispose removes from line', () {
      final line = BufferLine(10);
      final anchor = line.createAnchor(5);
      expect(line.anchors.length, equals(1));
      anchor.dispose();
      expect(line.anchors, isEmpty);
    });

    test('anchor reposition updates x', () {
      final line = BufferLine(10);
      final anchor = line.createAnchor(5);
      anchor.reposition(8);
      expect(anchor.x, equals(8));
    });
  });
}
