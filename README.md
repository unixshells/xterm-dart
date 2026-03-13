# xterm

Fork of [TerminalStudio/xterm.dart](https://github.com/TerminalStudio/xterm.dart) with mobile fixes and rendering improvements. Maintained by [Unix Shells](https://unixshells.com).

https://github.com/unixshells/xterm-dart

Fast, fully-featured terminal emulator widget for Flutter. Works on mobile and desktop.

## Changes from upstream

- Cursor blinking
- Context menu on long press (copy/paste)
- AOSP keyboard delete handling fix
- Escape parser fixes (clearAltBuffer, restoreCursor)
- Underline and strikethrough rendering offset fixes
- Scroll position tracking fix
- Better character width measurement
- Removed MediaQuery padding (for embedded use)
- Flutter API deprecation fixes

## Features

- Works out of the box, no special configuration required
- Renders at 60fps
- Wide character support (CJK, emojis)
- IME support
- Customizable themes (changeable at runtime)
- Mobile and desktop support
- Frontend independent terminal core

## Getting started

Add to `pubspec.yaml`:

```yaml
dependencies:
  xterm:
    git:
      url: https://github.com/unixshells/xterm-dart.git
```

Create and display a terminal:

```dart
import 'package:xterm/xterm.dart';
import 'package:xterm/flutter.dart';

final terminal = Terminal();

terminal.onOutput = (output) {
  print('output: $output');
};

// In your widget tree:
child: TerminalView(terminal),
```

Write to the terminal:

```dart
terminal.write('Hello, world!');
```

## License

Copyright (c) 2020 xuty, (c) 2026 [Unix Shells](https://unixshells.com). MIT license. See [LICENSE](LICENSE).
