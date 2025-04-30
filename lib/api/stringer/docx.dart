import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chunky/api/stringer.dart';
import 'package:xml/xml.dart' as xml;

ZipDecoder? _zipDecoder;

class DOCXFileStringer extends FileStringer {
  final bool handleNumbering;

  const DOCXFileStringer({
    super.supportedFormats = const {"docx"},
    this.handleNumbering = false,
  });

  @override
  Stream<String> stream(File file) async* {
    Uint8List bytes = await file.readAsBytes();
    _zipDecoder ??= ZipDecoder();
    Archive archive = _zipDecoder!.decodeBytes(bytes);

    for (final file in archive) {
      if (file.isFile && file.name == 'word/document.xml') {
        String fileContent = utf8.decode(file.content);
        xml.XmlDocument document = xml.XmlDocument.parse(fileContent);
        Iterable<xml.XmlElement> paragraphNodes = document.findAllElements(
          'w:p',
        );
        int number = 0;
        String lastNumId = '0';

        for (final paragraph in paragraphNodes) {
          final textNodes = paragraph.findAllElements('w:t');
          var text = textNodes.map((node) => node.innerText).join();

          if (handleNumbering) {
            var numbering = paragraph
                .getElement('w:pPr')
                ?.getElement('w:numPr');
            if (numbering != null) {
              final numId =
                  numbering.getElement('w:numId')!.getAttribute('w:val')!;

              if (numId != lastNumId) {
                number = 0;
                lastNumId = numId;
              }
              number++;
              text = '$number. $text';
            }
          }

          yield text;
          yield "\n";
        }
      }
    }
  }
}
