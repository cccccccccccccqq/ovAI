import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_scope.dart';
import '../core/file_export.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.id});
  final String id;
  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _cardKey = GlobalKey();
  bool _busy = false;
  String? _message;

  Future<void> _export(Chronicle story, {required bool pdf}) async {
    if (_busy) return;
    final app = AppScope.of(context);
    final origin = context.findRenderObject() as RenderBox?;
    final rect = origin == null
        ? null
        : origin.localToGlobal(Offset.zero) & origin.size;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (pdf) {
        final font = pw.Font.ttf(
          await rootBundle.load('assets/fonts/Inter.ttf'),
        );
        final document = pw.Document(
          theme: pw.ThemeData.withFont(base: font, bold: font),
        );
        final template = app.templateFor(story);
        final notes = app.citationsFor(template);
        document.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(44),
            build: (_) => [
              pw.Text(
                'öv AI · PREPARED DEMO CHRONICLE',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.green800,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                story.title,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                '${app.siteById(story.siteId).name} · ${story.genre} · ${story.mood}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 24),
              for (final segment in template.segments) ...[
                pw.Text(
                  segment.kind == 'legend'
                      ? 'ORIGINAL FICTION'
                      : 'CURATED CONTEXT',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.green800,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  segment.text,
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 5),
                ),
                pw.SizedBox(height: 18),
              ],
              pw.Divider(),
              pw.Text('Reading notes', style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 10),
              for (final note in notes)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(
                    '${note.title}\n${note.author} · ${note.page}\n${note.note}${note.url == null ? '' : '\n${note.url}'}',
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
                  ),
                ),
              pw.Text(
                'Prepared for interaction testing. This is not a live AI-generated or independently verified historical account.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        );
        await Printing.sharePdf(
          bytes: await document.save(),
          filename: 'ov-${story.templateId}.pdf',
        );
      } else {
        await WidgetsBinding.instance.endOfFrame.timeout(
          const Duration(seconds: 10),
        );
        final boundary =
            _cardKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary
            .toImage(pixelRatio: 2)
            .timeout(const Duration(seconds: 10));
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final bytes = data!.buffer.asUint8List();
        if (kIsWeb) {
          await downloadBytes(bytes, 'ov-${story.templateId}.png', 'image/png');
        } else {
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  bytes,
                  mimeType: 'image/png',
                  name: 'ov-story.png',
                ),
              ],
              fileNameOverrides: ['ov-${story.templateId}.png'],
              title: story.title,
              sharePositionOrigin: rect,
            ),
          );
        }
      }
      if (mounted) {
        setState(
          () => _message = pdf
              ? 'PDF prepared. Choose where to save or share it.'
              : 'Story image prepared. Choose where to save or share it.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Export could not finish. Try again in a browser or on your device.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(Chronicle story) async {
    // Template IDs are portable across installations; local story IDs are not.
    final url = Uri.base.replace(fragment: '/demo/${story.templateId}');
    if (url.scheme != 'http' && url.scheme != 'https') {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${story.title}\n${AppScope.of(context).templateFor(story).plainText}',
        ),
      );
      if (mounted) {
        setState(
          () => _message =
              'Story text copied. Share a PDF or image to open it on another device.',
        );
      }
    } else {
      await Clipboard.setData(ClipboardData(text: url.toString()));
      if (mounted) {
        setState(
          () => _message =
              'Demo link copied. It opens this prepared story while the web preview is available.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final story = app.storyById(widget.id);
    if (story == null) {
      return const AppScaffold(
        title: 'Share',
        child: Text('This local story is no longer in your library.'),
      );
    }
    return AppScaffold(
      title: 'A story worth carrying',
      eyebrow: 'SHARE YOUR JOURNEY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            key: _cardKey,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(path: story.image),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x330C1F14), Color(0xEE0C1F14)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'öv AI',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 40,
                              height: 1,
                              fontWeight: FontWeight.w600,
                              color: OvColors.cream,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            app.siteById(story.siteId).name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 2,
                              color: OvColors.gold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            story.title,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 30,
                              height: 1.15,
                              fontWeight: FontWeight.w500,
                              color: OvColors.cream,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            app.templateFor(story).subtitle,
                            style: const TextStyle(
                              color: OvColors.cream,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Divider(color: Color(0x66F2EFE7)),
                          Text(
                            app.templateFor(story).isHistorical
                                ? 'SECRET HISTORY · ENGLISH SYNOPSIS'
                                : 'PREPARED DEMO · ORIGINAL FICTION',
                            style: const TextStyle(
                              fontSize: 9,
                              letterSpacing: 1,
                              color: OvColors.cream,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _copy(story),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy demo story'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _export(story, pdf: false),
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share image'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _export(story, pdf: false),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Export PNG'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _export(story, pdf: true),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
              ),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: LinearProgressIndicator(),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_message!),
            ),
          const SizedBox(height: 18),
          const Text(
            'Images and PDFs include the demo label. A copied web link opens the prepared story, without your profile or private local history.',
          ),
        ],
      ),
    );
  }
}
