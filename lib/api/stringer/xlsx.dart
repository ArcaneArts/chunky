import 'dart:io';

import 'package:chunky/api/stringer.dart';
import 'package:excel/excel.dart';

class XLSXFileStringer extends FileStringer {
  const XLSXFileStringer({super.supportedFormats = const {"xlsx"}});

  @override
  Stream<String> stream(File file) async* {
    Excel x = Excel.decodeBytes(await file.readAsBytes());

    for (String table in x.tables.keys) {
      yield table;
      yield "\n";
      for (var row in x.tables[table]!.rows) {
        StringBuffer buffer = StringBuffer();
        for (Data? cell in row) {
          buffer.write(",");
          CellValue? value = cell?.value;
          buffer.write(switch (value) {
            TextCellValue() => value.value,
            FormulaCellValue() => value.formula,
            IntCellValue() => value.value.toString(),
            DoubleCellValue() => value.value.toString(),
            BoolCellValue() => value.value.toString(),
            DateCellValue() => value.asDateTimeUtc().toIso8601String(),
            TimeCellValue() =>
              '${value.hour}h:${value.minute}m:${value.second}s',
            DateTimeCellValue() => value.asDateTimeUtc().toIso8601String(),
            null => "",
          });
        }

        buffer.write("\n");
        yield buffer.toString().substring(1);
      }

      yield "\n\n";
    }
  }
}
