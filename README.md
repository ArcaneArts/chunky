Chunk stuff

```dart
  Embedder e = Embedder(
    chunker: Chunker(chunkSize: 300),
    embedder: (k) async {
      return [];
    },
    overlap: 50,
  );

  await for (EmbeddedChunk i in e.transform(Stream.fromIterable([s]))) {
    print(
      "${i.chunk.id}: ${i.chunk.start}++${i.chunk.length}: ${i.chunk.content.trim().replaceAll("\n", "")}",
    );
  }
```