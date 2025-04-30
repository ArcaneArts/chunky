import 'dart:io';

import 'package:chunky/api/stringer.dart';
import 'package:chunky/api/stringer/text.dart';
import 'package:fast_log/fast_log.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PDFStringer extends FileStringer {
  const PDFStringer({super.supportedFormats = const {"pdf"}});

  @override
  Stream<String> stream(File file) async* {
    File sidecar = File("${file.path}.ocrmypdf.txt");
    File outputPDF = File("${file.path}.ocrmypdf.pdf");

    ProcessResult result = await Process.run("ocrmypdf", [
      "--sidecar",
      sidecar.path,
      "--jobs",
      "1",
      //"--force-ocr",
      "--invalidate-digital-signatures",
      "--output-type", "pdf",
      "--optimize", "0",
      file.path,
      outputPDF.path,
    ]);

    if (result.stdout != null && result.stdout.isNotEmpty) {
      print("[OCRMyPDF]: ${result.stdout}");
    }
    if (result.stderr != null && result.stderr.isNotEmpty) {
      print("[OCRMyPDF] STDERR: ${result.stderr}");
    }

    if (!await sidecar.exists()) {
      info(
        "OCR Unnecessary for ${file.path}. Text already exists. Reading out sidecar...",
      );

      File of = outputPDF;
      if (!await outputPDF.exists()) {
        of = file;
      }

      PdfDocument document = PdfDocument(inputBytes: await of.readAsBytes());
      int pageCount = document.pages.count;
      IOSink sink = sidecar.openWrite();
      for (int i = 0; i < pageCount; i++) {
        sink.writeln(
          PdfTextExtractor(
            document,
          ).extractText(startPageIndex: i, layoutText: true),
        );
      }

      document.dispose();
      await sink.flush();
      await sink.close();
    } else {
      info(
        "OCR complete for ${file.path}. Text saved to ${sidecar.path} and PDF saved to ${outputPDF.path}. Feeding text into pandoc",
      );
    }

    yield* const TextFileStringer().stream(sidecar);

    try {
      await outputPDF.delete();
    } catch (e) {}
    try {
      await sidecar.delete();
    } catch (e) {}
  }
}
