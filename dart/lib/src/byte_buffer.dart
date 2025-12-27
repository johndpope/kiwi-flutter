import 'dart:typed_data';
import 'dart:convert';

/// A byte buffer for reading and writing binary data with variable-length encoding.
class ByteBuffer {
  Uint8List _data;
  int _index = 0;
  int length = 0;

  /// Creates a new ByteBuffer, optionally initialized with data.
  ByteBuffer([Uint8List? data])
      : _data = data ?? Uint8List(256),
        length = data?.length ?? 0;

  /// Returns the buffer contents as a Uint8List.
  Uint8List toUint8Array() {
    return Uint8List.sublistView(_data, 0, length);
  }

  /// Reads a single byte from the buffer.
  int readByte() {
    if (_index + 1 > _data.length) {
      throw Exception('Index out of bounds');
    }
    return _data[_index++];
  }

  /// Reads a byte array with length prefix.
  Uint8List readByteArray() {
    int len = readVarUint();
    int start = _index;
    int end = start + len;
    if (end > _data.length) {
      throw Exception('Read array out of bounds');
    }
    _index = end;
    // Copy into a new array
    Uint8List result = Uint8List(len);
    result.setAll(0, _data.sublist(start, end));
    return result;
  }

  /// Reads a variable-length float.
  /// Zero is encoded as a single byte, non-zero values use 4 bytes
  /// with the exponent moved to the first 8 bits for better compression.
  double readVarFloat() {
    int index = _index;
    Uint8List data = _data;
    int len = data.length;

    // Optimization: use a single byte to store zero
    if (index + 1 > len) {
      throw Exception('Index out of bounds');
    }
    int first = data[index];
    if (first == 0) {
      _index = index + 1;
      return 0.0;
    }

    // Endian-independent 32-bit read
    if (index + 4 > len) {
      throw Exception('Index out of bounds');
    }
    int bits = first |
        (data[index + 1] << 8) |
        (data[index + 2] << 16) |
        (data[index + 3] << 24);
    _index = index + 4;

    // Ensure 32-bit value before shift operations
    bits = bits & 0xFFFFFFFF;

    // Move the exponent back into place (unsigned right shift simulation)
    bits = ((bits << 23) | ((bits & 0xFFFFFFFF) >>> 9)) & 0xFFFFFFFF;

    // Convert bits to float using Uint32 to handle sign correctly
    var byteData = ByteData(4);
    byteData.setUint32(0, bits, Endian.little);
    return byteData.getFloat32(0, Endian.little);
  }

  /// Reads a variable-length unsigned integer (up to 32 bits).
  /// Uses 7 bits per byte with a continuation bit.
  int readVarUint() {
    int value = 0;
    int shift = 0;
    int byte;
    do {
      byte = readByte();
      value |= (byte & 127) << shift;
      shift += 7;
    } while ((byte & 128) != 0 && shift < 35);
    return value & 0xFFFFFFFF; // Ensure unsigned
  }

  /// Reads a variable-length signed integer using zigzag encoding.
  int readVarInt() {
    int value = readVarUint();
    // Convert from unsigned to signed using zigzag decoding
    return (value & 1) != 0 ? ~(value >> 1) : (value >> 1);
  }

  /// Reads a null-terminated UTF-8 string.
  String readString() {
    List<int> bytes = [];
    while (true) {
      int byte = readByte();
      if (byte == 0) break; // Null terminator
      bytes.add(byte);
    }
    return utf8.decode(bytes);
  }

  void _growBy(int amount) {
    if (length + amount > _data.length) {
      Uint8List newData = Uint8List((length + amount) << 1);
      newData.setAll(0, _data);
      _data = newData;
    }
    length += amount;
  }

  /// Writes a single byte to the buffer.
  void writeByte(int value) {
    int index = length;
    _growBy(1);
    _data[index] = value & 0xFF;
  }

  /// Writes a byte array with length prefix.
  void writeByteArray(Uint8List value) {
    writeVarUint(value.length);
    int index = length;
    _growBy(value.length);
    _data.setAll(index, value);
  }

  /// Writes a variable-length float.
  void writeVarFloat(double value) {
    int index = length;

    // Convert float to bits using Uint32 for correct bit representation
    var byteData = ByteData(4);
    byteData.setFloat32(0, value, Endian.little);
    int bits = byteData.getUint32(0, Endian.little);

    // Normalize NaN to positive quiet NaN (match JavaScript behavior)
    // JavaScript NaN is 0x7FC00000, Dart may produce 0xFFC00000
    if (value.isNaN) {
      bits = 0x7FC00000; // Positive quiet NaN
    }

    // Move the exponent to the first 8 bits (unsigned right shift)
    bits = (((bits & 0xFFFFFFFF) >>> 23) | (bits << 9)) & 0xFFFFFFFF;

    // Optimization: use a single byte to store zero and denormals
    if ((bits & 255) == 0) {
      writeByte(0);
      return;
    }

    // Endian-independent 32-bit write
    _growBy(4);
    _data[index] = bits & 0xFF;
    _data[index + 1] = (bits >> 8) & 0xFF;
    _data[index + 2] = (bits >> 16) & 0xFF;
    _data[index + 3] = (bits >> 24) & 0xFF;
  }

  /// Writes a variable-length unsigned integer.
  void writeVarUint(int value) {
    value = value & 0xFFFFFFFF; // Ensure unsigned
    do {
      int byte = value & 127;
      value = value >> 7;
      writeByte(value != 0 ? byte | 128 : byte);
    } while (value != 0);
  }

  /// Writes a variable-length signed integer using zigzag encoding.
  void writeVarInt(int value) {
    writeVarUint((value << 1) ^ (value >> 31));
  }

  /// Writes a null-terminated UTF-8 string.
  void writeString(String value) {
    List<int> bytes = utf8.encode(value);
    // Check for null character
    if (bytes.contains(0)) {
      throw Exception('Cannot encode a string containing the null character');
    }
    for (int byte in bytes) {
      writeByte(byte);
    }
    // Null terminator
    writeByte(0);
  }
}
