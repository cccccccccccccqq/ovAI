import 'package:flutter_test/flutter_test.dart';
import 'package:ov_chronicles/core/startup_location.dart';

void main() {
  test('chapter hash and query survive startup', () {
    expect(
      webStartupLocation(
        Uri.parse('http://127.0.0.1:8766/#/history/onon-child'),
      ),
      '/history/onon-child',
    );
    expect(
      webStartupLocation(
        Uri.parse('http://127.0.0.1:8766/#/playback?story=one'),
      ),
      '/playback?story=one',
    );
  });
  test('empty and external fragments do not become app routes', () {
    expect(webStartupLocation(Uri.parse('http://127.0.0.1:8766/')), isNull);
    expect(
      webStartupLocation(
        Uri.parse('http://127.0.0.1:8766/#https://example.com'),
      ),
      isNull,
    );
    expect(
      webStartupLocation(
        Uri.parse('http://127.0.0.1:8766/#//example.com/route'),
      ),
      isNull,
    );
  });
}
