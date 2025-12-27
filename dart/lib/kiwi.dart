/// Kiwi schema-based binary serialization format for Dart/Flutter.
///
/// Kiwi is designed for efficiently encoding trees of data with:
/// - Efficient compact encoding using variable-length encoding
/// - Support for optional fields with detectable presence
/// - Linear serialization for cache efficiency
/// - Backwards & forwards compatibility
library kiwi;

export 'src/byte_buffer.dart';
export 'src/schema.dart';
export 'src/parser.dart';
export 'src/binary.dart';
export 'src/compiler.dart';
export 'src/printer.dart';
