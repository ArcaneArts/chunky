import 'dart:async';
import 'dart:io';

import 'package:chunky/api/stringer/docx.dart';
import 'package:chunky/api/stringer/pandoc.dart';
import 'package:chunky/api/stringer/pdf.dart';
import 'package:chunky/api/stringer/text.dart';
import 'package:chunky/api/stringer/xlsx.dart';
import 'package:fast_log/fast_log.dart';

/// List of all available file stringers in priority order.
/// When a file is processed, the first stringer that supports the file format is used.
List<FileStringer> fileStringers = const [
  XLSXFileStringer(),
  DOCXFileStringer(),
  PDFStringer(),
  PandocStringer(),
  TextFileStringer(),
];

/// An abstract class that defines functionality for extracting textual content from files.
///
/// FileStringer is responsible for converting various file formats into
/// stream of string content that can be further processed for ingestion.
/// Different file formats (PDF, DOCX, XLSX, etc.) have specialized implementations
/// that extend this abstract class.
abstract class FileStringer {
  /// The set of file extensions that this stringer supports (e.g., {'pdf', 'docx'}).
  final Set<String> supportedFormats;

  /// Creates a FileStringer with the specified supported formats.
  const FileStringer({this.supportedFormats = const {}});

  /// Extracts text content from a file and returns it as a stream of strings.
  ///
  /// Implementing classes must define how to parse their specific file format.
  /// @param file The file to extract text from
  Stream<String> stream(File file);

  /// Checks if this stringer supports the given file based on its extension.
  ///
  /// @param file The file to check for compatibility
  /// @return true if this stringer can process the file, false otherwise
  bool isSupported(File file) =>
      supportedFormats.contains(file.path.split(".").last.toLowerCase());

  /// Static method to stream text content from any supported file.
  ///
  /// This method automatically selects the appropriate stringer based on the file extension.
  /// If no suitable stringer is found, it falls back to the TextFileStringer.
  ///
  /// @param file The file to extract text from
  /// @return A stream of strings containing the file's text content
  /// @throws Exception if the file doesn't exist
  static Stream<String> streamFile(File file) async* {
    if (!file.existsSync()) {
      error("File does not exist: ${file.path}");
      throw Exception("File does not exist: ${file.path}");
    }

    for (FileStringer s in fileStringers) {
      if (s.isSupported(file)) {
        yield* s.stream(file);
        return;
      }
    }

    warn(
      "No stringer found for file: ${file.path}, trying with text stringer...",
    );

    yield* const TextFileStringer().stream(file);
  }
}
