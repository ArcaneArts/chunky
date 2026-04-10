# Chunky

Chunky helps with the ingestion side of long-form AI and search pipelines: it extracts text from files, splits content into manageable chunks, adds optional overlap, and can turn those chunks into embeddings.

Everything is exported from:

```dart
import 'package:chunky/chunky.dart';
```

## Features

- Chunk in-memory strings or arbitrary `Stream<String>` sources.
- Chunk files with automatic file-type detection through `FileStringer`.
- Preserve context between chunks with word-aware overlap.
- Attach chunk metadata (`id`, `start`, `length`, `content`) for indexing and traceability.
- Generate embeddings with bounded concurrency through `Embedder`.
- Ingest plain text, XLSX, DOCX, PDF, and many Pandoc-supported formats.
- Replace or reorder built-in file handlers through the global `fileStringers` list.

## Installation

Chunky currently depends on Flutter because PDF extraction uses `syncfusion_flutter_pdf`, so install it in a Flutter package or app:

```sh
flutter pub add chunky
```

Optional external tools:

- `pandoc` when you want `PandocStringer` support for formats such as Markdown, EPUB, ODT, RTF, LaTeX, Org, and more.
- `ocrmypdf` when you want PDF ingestion through `PDFStringer`.

If you only work with in-memory strings, you do not need either external binary.

## Quick Start

```dart
import 'dart:io';

import 'package:chunky/chunky.dart';

Future<void> main() async {
  final chunker = Chunker(chunkSize: 300);

  await for (final chunk in chunker.transformString(
    'Chunk long-form text directly from memory.',
  )) {
    print('${chunk.id}: ${chunk.start}..${chunk.start + chunk.length}');
    print(chunk.content);
  }

  await for (final chunk in chunker.transformFile(File('notes.txt'))) {
    print('file chunk ${chunk.id}: ${chunk.content}');
  }

  final embedder = Embedder(
    chunker: chunker,
    overlap: 50,
    embedder: (content) async => <double>[content.length.toDouble()],
  );

  await for (final embedded in embedder.transform(
    Stream.value('Embed chunked content with overlap.'),
  )) {
    print(
      '${embedded.chunk.id}: ${embedded.embedding.length} dims from ${embedded.chunk.content}',
    );
  }
}
```

## Usage

### Chunk a String

Use `transformString` when your content is already in memory:

```dart
final chunker = Chunker(chunkSize: 500);

await for (final chunk in chunker.transformString(longArticle)) {
  print('chunk #${chunk.id}');
  print('start=${chunk.start}, length=${chunk.length}');
  print(chunk.content);
}
```

Chunk sizes are approximate rather than exact. Chunky tries to split content into readable segments near the requested size instead of cutting blindly at a character boundary.

### Chunk a Stream

If your text arrives progressively, pass a `Stream<String>` directly:

```dart
final stream = Stream.fromIterable([
  'Section one...\n',
  'Section two...\n',
  'Section three...\n',
]);

await for (final chunk in Chunker(chunkSize: 250).transform(stream)) {
  print(chunk.content);
}
```

### Add Overlap Between Chunks

Overlap helps preserve context for embeddings, search, and RAG:

```dart
final chunker = Chunker(chunkSize: 300);

await for (final chunk in chunker.transformWithOverlap(
  Stream.value(longText),
  overlap: 60,
)) {
  print('${chunk.id}: ${chunk.content}');
}
```

For files there is a convenience helper:

```dart
await for (final chunk in chunker.transformFileWithOverlap(
  File('report.md'),
  overlap: 80,
)) {
  print(chunk.content);
}
```

`overlap` is measured as a maximum character budget, but the overlap logic keeps whole words from the previous chunk instead of slicing in the middle of a token.

### Chunk a File

`transformFile` delegates to `FileStringer.streamFile`, which picks the first handler that supports the file extension:

```dart
final chunker = Chunker(chunkSize: 400);
final file = File('knowledge-base.docx');

await for (final chunk in chunker.transformFile(file)) {
  print(chunk.content);
}
```

If you only want extracted text without chunking, use `FileStringer.streamFile` directly:

```dart
await for (final piece in FileStringer.streamFile(File('data.xlsx'))) {
  print(piece);
}
```

### Generate Embeddings

`Embedder` composes chunking, overlap, and your embedding callback:

```dart
final embedder = Embedder(
  chunker: Chunker(chunkSize: 350),
  overlap: 75,
  embedder: (content) async {
    return myEmbeddingClient.embed(content);
  },
);

await for (final embedded in embedder.transform(
  Stream.value(documentText),
  semaphoreBuffer: 8,
)) {
  print(embedded.chunk.id);
  print(embedded.embedding);
}
```

`semaphoreBuffer` controls how many embedding jobs run in parallel. It defaults to `4`.

### Customize File Handlers

Chunky exposes the global `fileStringers` list so you can swap built-in handlers, change priority, or add your own:

```dart
fileStringers = const [
  XLSXFileStringer(),
  DOCXFileStringer(handleNumbering: true),
  PDFStringer(),
  PandocStringer(),
  TextFileStringer(),
];
```

This is useful if you want numbered DOCX paragraphs or if you need a custom stringer to run before the defaults.

## Supported File Types

Some extensions are supported by more than one handler. Chunky uses the first matching stringer in `fileStringers`.

| Handler | Formats | Notes |
| --- | --- | --- |
| `TextFileStringer` | `txt`, `json`, `yaml`, `toml`, `xml`, `html`, `csv` | Reads line-by-line as UTF-8 text. |
| `XLSXFileStringer` | `xlsx` | Streams sheet names and comma-separated row values. |
| `DOCXFileStringer` | `docx` | Reads `word/document.xml` directly from the archive. Optional numbering support is available. |
| `PDFStringer` | `pdf` | Requires `ocrmypdf`, then falls back to direct PDF text extraction when OCR sidecar text is unnecessary. |
| `PandocStringer` | Many formats | Requires `pandoc` for formats such as `md`, `markdown`, `epub`, `odt`, `rtf`, `latex`, `org`, `tsv`, and more. |

The default priority order is:

1. `XLSXFileStringer`
2. `DOCXFileStringer`
3. `PDFStringer`
4. `PandocStringer`
5. `TextFileStringer`

## Main API Surface

- `Chunker(chunkSize: 300)`
- `Chunker.transformString(String input)`
- `Chunker.transform(Stream<String> rawFeed)`
- `Chunker.transformWithOverlap(Stream<String> rawFeed, {int overlap = 50})`
- `Chunker.transformFile(File file)`
- `Chunker.transformFileWithOverlap(File file, {int overlap = 50})`
- `FileStringer.streamFile(File file)`
- `Embedder.transform(Stream<String> rawFeed, {int semaphoreBuffer = 4})`

## When to Use Chunky

Chunky is a good fit when you need to:

- preprocess documents before embedding or vector indexing,
- normalize mixed document types into text,
- preserve chunk metadata for citations or traceability,
- add overlap to improve retrieval quality,
- build ingestion pipelines for RAG, semantic search, or summarization.
