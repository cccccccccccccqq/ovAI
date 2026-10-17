import 'dart:io';
import 'package:image/image.dart' as img;

// Code-native ger symbol, matching the supplied green/cream design system.
void main() {
  final canvas = img.Image(width: 1024, height: 1024, numChannels: 4);
  final green = img.ColorRgb8(31, 77, 46);
  final cream = img.ColorRgb8(242, 239, 231);
  final gold = img.ColorRgb8(201, 162, 39);
  img.fill(canvas, color: green);
  img.drawLine(
    canvas,
    x1: 240,
    y1: 490,
    x2: 512,
    y2: 280,
    color: cream,
    thickness: 28,
  );
  img.drawLine(
    canvas,
    x1: 512,
    y1: 280,
    x2: 784,
    y2: 490,
    color: cream,
    thickness: 28,
  );
  img.drawLine(
    canvas,
    x1: 270,
    y1: 490,
    x2: 270,
    y2: 750,
    color: cream,
    thickness: 28,
  );
  img.drawLine(
    canvas,
    x1: 754,
    y1: 490,
    x2: 754,
    y2: 750,
    color: cream,
    thickness: 28,
  );
  img.drawLine(
    canvas,
    x1: 270,
    y1: 750,
    x2: 754,
    y2: 750,
    color: cream,
    thickness: 28,
  );
  img.drawLine(
    canvas,
    x1: 270,
    y1: 490,
    x2: 754,
    y2: 490,
    color: cream,
    thickness: 28,
  );
  img.drawLine(
    canvas,
    x1: 450,
    y1: 750,
    x2: 450,
    y2: 600,
    color: cream,
    thickness: 24,
  );
  img.drawLine(
    canvas,
    x1: 574,
    y1: 750,
    x2: 574,
    y2: 600,
    color: cream,
    thickness: 24,
  );
  img.drawLine(
    canvas,
    x1: 450,
    y1: 600,
    x2: 574,
    y2: 600,
    color: cream,
    thickness: 24,
  );
  img.fillCircle(canvas, x: 512, y: 205, radius: 26, color: gold);
  final ios = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  final manifest = File('${ios.path}/Contents.json').readAsStringSync();
  final entries = RegExp(
    r'"filename"\s*:\s*"([^"]+)"',
  ).allMatches(manifest).map((m) => m[1]!).toSet();
  for (final name in entries) {
    final size = RegExp(
      r'Icon-App-(\d+(?:\.\d+)?)x[^@]+@(\d)x',
    ).firstMatch(name);
    final px = size == null
        ? 1024
        : (double.parse(size[1]!) * int.parse(size[2]!)).round();
    File('${ios.path}/$name').writeAsBytesSync(
      img.encodePng(img.copyResize(canvas, width: px, height: px)),
    );
  }
  for (final size in [192, 512]) {
    final png = img.encodePng(
      img.copyResize(canvas, width: size, height: size),
    );
    File('web/icons/Icon-$size.png').writeAsBytesSync(png);
    File('web/icons/Icon-maskable-$size.png').writeAsBytesSync(png);
  }
  File('web/favicon.png').writeAsBytesSync(
    img.encodePng(img.copyResize(canvas, width: 32, height: 32)),
  );
  for (final entry in {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  }.entries) {
    File(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
    ).writeAsBytesSync(
      img.encodePng(
        img.copyResize(canvas, width: entry.value, height: entry.value),
      ),
    );
  }
}
