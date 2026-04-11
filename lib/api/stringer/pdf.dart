import 'dart:io';

import 'package:chunky/api/stringer.dart';
import 'package:chunky/api/stringer/text.dart';

class PDFStringer extends FileStringer {
  const PDFStringer({super.supportedFormats = const {"pdf"}});

  @override
  Stream<String> stream(File file) async* {
    File sidecar = File("${file.path}.ocrmypdf.txt");
    File outputPDF = File("${file.path}.ocrmypdf.pdf");

    ProcessResult result = await Process.run("ocrmypdf", [
      "--sidecar",
      sidecar.path,
      //"--jobs", "1",
      "--force-ocr",
      // "--invalidate-digital-signatures",
      "--output-type", "pdf",
      //"--optimize", "0",
      file.path,
      outputPDF.path,
    ]);

    if (result.stdout != null && result.stdout.isNotEmpty) {
      print("[OCRMyPDF]: ${result.stdout}");
    }
    if (result.stderr != null && result.stderr.isNotEmpty) {
      print("[OCRMyPDF] STDERR: ${result.stderr}");
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
