import 'dart:io';
import 'dart:math';

import 'package:bpe/bpe.dart';
import 'package:chunky/api/stringer.dart';

/// Extension on [Stream<Chunk>] that adds the ability to create overlapping chunks.
extension XChunkList on Stream<Chunk> {
  /// Creates a new stream where each chunk overlaps with the previous chunk's content.
  ///
  /// This is useful for maintaining context between chunks when processing
  /// text for LLM or embedding systems. The overlap helps preserve
  /// semantic meaning across chunk boundaries.
  ///
  /// @param amount The maximum number of characters to overlap between chunks
  /// @return A stream of chunks with overlapping content
  Stream<Chunk> overlap(int amount) async* {
    Chunk? previous;

    await for (Chunk i in this) {
      if (previous != null) {
        int l = 0;
        List<String> j = [];
        for (String i in previous.content.split(" ").reversed) {
          if (l + i.length > amount) {
            break;
          }

          l += i.length + 1;
          j.add(i);
        }

        String tail = j.reversed.join(" ");
        yield Chunk(
          i.id,
          i.start - tail.length,
          i.length + tail.length,
          "$tail${i.content}",
        );
      } else {
        yield i;
      }

      previous = i;
    }
  }
}

/// Represents a single chunk of text content.
///
/// A chunk is a portion of text that has been segmented from a larger document.
/// Each chunk maintains metadata about its position in the original document.
class Chunk {
  /// Unique identifier for the chunk
  final int id;

  /// Starting position of the chunk in the original document
  final int start;

  /// Length of the chunk in characters
  final int length;

  /// The actual text content of the chunk
  final String content;

  /// Creates a new chunk with the specified parameters.
  const Chunk(this.id, this.start, this.length, this.content);
}

/// Divides text streams into manageable chunks for processing.
///
/// The Chunker class is responsible for breaking down large text streams
/// into smaller, consistently sized chunks that can be processed by
/// language models or embedding systems. It ensures chunks are properly
/// sized for model context windows and can create overlapping chunks to
/// preserve context across chunk boundaries.
class Chunker {
  /// The target size for each chunk in characters
  final int chunkSize;

  /// Creates a new Chunker with the specified chunk size.
  ///
  /// @param chunkSize The target size for each chunk in characters (default: 500)
  const Chunker({this.chunkSize = 300});

  /// Transforms a raw string into non-overlapping chunks.
  ///
  /// @param input The raw text content to chunk
  /// @return A stream of non-overlapping chunks
  Stream<Chunk> transformString(String input) => transform(Stream.value(input));

  /// Transforms a file into non-overlapping chunks using Chunky's file stringers.
  ///
  /// Stringers may emit file content line by line, so this method restores
  /// line breaks between emitted pieces before chunking.
  ///
  /// @param file The file to ingest
  /// @return A stream of non-overlapping chunks
  Stream<Chunk> transformFile(File file) =>
      transform(FileStringer.streamFile(file).map((piece) => "$piece\n"));

  /// Transforms a file into overlapping chunks using Chunky's file stringers.
  ///
  /// @param file The file to ingest
  /// @param overlap The number of characters to overlap between chunks
  /// @return A stream of overlapping chunks
  Stream<Chunk> transformFileWithOverlap(File file, {int overlap = 50}) =>
      transformFile(file).overlap(overlap);

  /// Transforms a text stream into chunks with overlap between consecutive chunks.
  ///
  /// @param rawFeed The input stream of text
  /// @param overlap The number of characters to overlap between chunks (default: 125)
  /// @return A stream of chunks with overlapping content
  Stream<Chunk> transformWithOverlap(
    Stream<String> rawFeed, {
    int overlap = 50,
  }) => transform(rawFeed).overlap(overlap);

  /// Transforms a text stream into non-overlapping chunks of approximately equal size.
  ///
  /// This method breaks the input text stream into chunks that are close to the target
  /// chunk size. It uses the cleanChunks extension from the bpe package to prepare
  /// the text before chunking.
  ///
  /// @param rawFeed The input stream of text
  /// @return A stream of non-overlapping chunks
  Stream<Chunk> transform(Stream<String> rawFeed) async* {
    int start = 0;
    int lengthBuffer = 0;
    List<String> buffer = [];
    int id = 0;
    await for (String i in rawFeed.cleanChunks(
      size: max(1, chunkSize ~/ 2),
      grace: max(1, chunkSize ~/ 4),
    )) {
      buffer.add(i);
      lengthBuffer += i.length;

      if (lengthBuffer >= chunkSize && lengthBuffer - i.length <= chunkSize) {
        Chunk c = Chunk(
          id++,
          start,
          lengthBuffer - i.length,
          buffer.sublist(0, buffer.length - 1).join(),
        );
        start += c.length;
        lengthBuffer = i.length;
        buffer = [i];
        yield c;
      }
    }

    if (buffer.isNotEmpty) {
      yield Chunk(id++, start, lengthBuffer, buffer.join());
    }
  }
}
