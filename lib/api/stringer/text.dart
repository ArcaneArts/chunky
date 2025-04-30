import 'dart:convert';
import 'dart:io';

import 'package:chunky/api/stringer.dart';

class TextFileStringer extends FileStringer {
  const TextFileStringer({
    super.supportedFormats = const {
      "txt",
      "json",
      "yaml",
      "toml",
      "xml",
      "html",
      "csv",
    },
  });

  @override
  Stream<String> stream(File file) =>
      file.openRead().transform(Utf8Decoder()).transform(LineSplitter());
}
