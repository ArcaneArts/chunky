import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chunky/api/stringer.dart';
import 'package:fast_log/fast_log.dart';

class PandocStringer extends FileStringer {
  const PandocStringer({
    super.supportedFormats = const {
      "biblatex",
      "bibtex",
      "bits",
      "commonmark",
      "commonmark_x",
      "creole",
      "csljson",
      "csv",
      "djot",
      "docbook",
      "docx",
      "dokuwiki",
      "endnotexml",
      "epub",
      "fb2",
      "gfm",
      "haddock",
      "html",
      "ipynb",
      "jats",
      "jira",
      "latex",
      "man",
      "md",
      "markdown",
      "markdown_github",
      "markdown_mmd",
      "markdown_phpextra",
      "markdown_strict",
      "mdoc",
      "mediawiki",
      "muse",
      "native",
      "odt",
      "opml",
      "org",
      "pod",
      "ris",
      "rst",
      "rtf",
      "t2t",
      "textile",
      "tikiwiki",
      "tsv",
      "twiki",
      "typst",
      "vimwiki",
    },
  });

  @override
  Stream<String> stream(File file) async* {
    File output = File("${file.path}.pandoc.txt");
    try {
      ProcessResult result = await Process.run("pandoc", [
        "-o",
        output.path,
        file.path,
      ]);

      if (result.stdout != null && result.stdout.isNotEmpty) {
        print("[Pandoc]: ${result.stdout}");
      }
      if (result.stderr != null && result.stderr.isNotEmpty) {
        print("[Pandoc] STDERR: ${result.stderr}");
      }
    } catch (e, es) {
      error("==> Pandoc failed to convert ${file.path}");
      throw e;
    }

    yield* output.openRead().transform(Utf8Decoder()).transform(LineSplitter());

    await output.delete();
  }
}
