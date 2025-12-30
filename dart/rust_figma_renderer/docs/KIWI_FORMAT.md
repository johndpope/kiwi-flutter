# Kiwi Binary Format

## Overview

Kiwi is a schema-based binary serialization format created by Evan Wallace (Figma co-founder) for efficiently encoding trees of data. Figma uses Kiwi for:

- `.fig` file storage
- Multiplayer sync protocol
- Clipboard data

## File Structure

### .fig File Layout

```
┌─────────────────────────────────────────┐
│              Header (8-9 bytes)          │
│  "fig-kiwi" or "fig-kiwie" (encrypted)   │
├─────────────────────────────────────────┤
│              Chunk 0: Schema             │
│  ┌─────────────────────────────────────┐ │
│  │  Size (4 bytes, little-endian)      │ │
│  │  Data (DEFLATE compressed)          │ │
│  └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│              Chunk 1: Message            │
│  ┌─────────────────────────────────────┐ │
│  │  Size (4 bytes, little-endian)      │ │
│  │  Data (ZSTD compressed)             │ │
│  └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│        Chunk 2: Preview (optional)       │
│  ┌─────────────────────────────────────┐ │
│  │  Size (4 bytes, little-endian)      │ │
│  │  Data (PNG image)                   │ │
│  └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│           Chunk 3+ (optional)            │
│              Additional data             │
└─────────────────────────────────────────┘
```

### Header Detection

```rust
fn detect_header(data: &[u8]) -> Result<(usize, bool)> {
    match &data[0..8] {
        b"fig-kiwi" => Ok((8, false)),  // Unencrypted
        _ if &data[0..9] == b"fig-kiwie" => Ok((9, true)),  // Encrypted
        _ => Err("Invalid header"),
    }
}
```

## Primitive Types

### Variable-Length Integer (Varint)

Used for most numeric values. Small values use fewer bytes.

```
Value Range          Bytes
0-127                1 byte
128-16383            2 bytes
16384-2097151        3 bytes
...                  ...
```

**Encoding:**
```rust
fn encode_varint(mut value: u64) -> Vec<u8> {
    let mut bytes = Vec::new();
    loop {
        let mut byte = (value & 0x7F) as u8;
        value >>= 7;
        if value != 0 {
            byte |= 0x80;  // Set continuation bit
        }
        bytes.push(byte);
        if value == 0 {
            break;
        }
    }
    bytes
}
```

**Decoding:**
```rust
fn decode_varint(data: &[u8], pos: &mut usize) -> u64 {
    let mut result: u64 = 0;
    let mut shift = 0;

    loop {
        let byte = data[*pos];
        *pos += 1;
        result |= ((byte & 0x7F) as u64) << shift;
        if byte & 0x80 == 0 {
            break;
        }
        shift += 7;
    }

    result
}
```

### Signed Integer (Zigzag)

Signed integers use zigzag encoding for efficient storage of negative numbers.

```
Value    Encoded
0        0
-1       1
1        2
-2       3
2        4
...      ...
```

**Encoding:**
```rust
fn zigzag_encode(value: i64) -> u64 {
    ((value << 1) ^ (value >> 63)) as u64
}
```

**Decoding:**
```rust
fn zigzag_decode(encoded: u64) -> i64 {
    ((encoded >> 1) as i64) ^ (-((encoded & 1) as i64))
}
```

### Float

Kiwi uses a custom float encoding optimized for common values.

**Zero value:** Single byte `0x00`

**Non-zero value:** 4 bytes with bit rotation

```rust
fn encode_float(value: f32) -> Vec<u8> {
    if value == 0.0 {
        return vec![0];
    }

    let bits = value.to_bits();
    // Rotate bits: move sign+exponent to end
    let rotated = (bits >> 23) | (bits << 9);

    vec![
        (rotated >> 24) as u8,
        (rotated >> 16) as u8,
        (rotated >> 8) as u8,
        rotated as u8,
    ]
}

fn decode_float(data: &[u8], pos: &mut usize) -> f32 {
    let first = data[*pos];
    *pos += 1;

    if first == 0 {
        return 0.0;
    }

    let bits = (first as u32) << 24
        | (data[*pos] as u32) << 16
        | (data[*pos + 1] as u32) << 8
        | (data[*pos + 2] as u32);
    *pos += 3;

    // Reverse rotation
    let unrotated = (bits << 23) | (bits >> 9);
    f32::from_bits(unrotated)
}
```

### String

Null-terminated UTF-8 string.

```rust
fn decode_string(data: &[u8], pos: &mut usize) -> String {
    let start = *pos;
    while data[*pos] != 0 {
        *pos += 1;
    }
    let s = String::from_utf8_lossy(&data[start..*pos]).to_string();
    *pos += 1;  // Skip null terminator
    s
}
```

### Bytes

Length-prefixed byte array.

```rust
fn decode_bytes(data: &[u8], pos: &mut usize) -> Vec<u8> {
    let len = decode_varint(data, pos) as usize;
    let bytes = data[*pos..*pos + len].to_vec();
    *pos += len;
    bytes
}
```

## Schema Types

### Type IDs

```
ID   Type
0    bool
1    byte
2    int (signed varint)
3    uint (unsigned varint)
4    float
5    string
6    int64 (signed varint, 64-bit)
7    uint64 (unsigned varint, 64-bit)
8+   Custom types (enum, struct, message)
```

### Enum

```kiwi
enum BlendMode {
  PASS_THROUGH = 0;
  NORMAL = 1;
  MULTIPLY = 2;
  // ...
}
```

Encoded as varint.

### Struct

Fixed set of fields, all present in order.

```kiwi
struct Vector {
  float x;
  float y;
}
```

Encoded as: `<x float> <y float>` (no field tags)

### Message

Variable fields with tags, supports optional fields.

```kiwi
message Node {
  uint id = 1;
  string name = 2;
  float x = 3;
  float y = 4;
  repeated Node children = 5;
}
```

Encoded as:
```
<field_index varint> <value>
<field_index varint> <value>
...
<0> (end marker)
```

For arrays:
```
<field_index varint> <length varint> <value> <value> ...
```

## Figma-Specific Structures

### GUID

Node identifier: two uint32 values (session ID + local ID).

```rust
fn decode_guid(data: &[u8], pos: &mut usize) -> String {
    let session = decode_varint(data, pos) as u32;
    let local = decode_varint(data, pos) as u32;
    format!("{}:{}", session, local)
}
```

### ParentIndex

Reference to parent node with position hint.

```rust
struct ParentIndex {
    guid: String,
    position: String,  // e.g., "a", "ab", position key
}
```

### Transform

2D affine transform matrix.

```kiwi
struct Matrix {
  float m00;  // scale x
  float m01;  // skew y
  float m10;  // skew x
  float m11;  // scale y
  float m02;  // translate x
  float m12;  // translate y
}
```

### Size

```kiwi
struct Size {
  float x;  // width
  float y;  // height
}
```

### Color

RGBA color (0-1 range in Figma, stored as floats or bytes).

```kiwi
struct Color {
  float r;
  float g;
  float b;
  float a;
}
```

## Paint Encoding

Fill and stroke paints are stored as binary blobs with their own format.

### Paint Data Structure

```
<count varint>
for each paint:
  <type varint>
  <type-specific data>
  <opacity float>
  <blend_mode varint>
```

### Paint Types

```
0 = Solid
1 = Gradient Linear
2 = Gradient Radial
3 = Gradient Angular
4 = Gradient Diamond
5 = Image
```

### Solid Paint

```
<type=0> <r u8> <g u8> <b u8> <a u8> <opacity float> <blend_mode>
```

### Gradient Paint

```
<type=1-4>
<stop_count varint>
for each stop:
  <position float>
  <r u8> <g u8> <b u8> <a u8>
<opacity float>
<blend_mode varint>
```

### Image Paint

```
<type=5>
<image_ref string>
<scale_mode varint>
<opacity float>
<blend_mode varint>
```

## Effect Encoding

### Effect Data Structure

```
<count varint>
for each effect:
  <type varint>
  <visible bool>
  <radius float>
  <type-specific data>
```

### Effect Types

```
0 = Drop Shadow
1 = Inner Shadow
2 = Layer Blur
3 = Background Blur
```

### Shadow Effect

```
<type=0|1>
<visible bool>
<radius float>
<r u8> <g u8> <b u8> <a u8>
<offset_x float>
<offset_y float>
<spread float>
```

### Blur Effect

```
<type=2|3>
<visible bool>
<radius float>
```

## Vector Path Encoding

### Path Data Structure

```
<fill_rule u8>  // 0=nonzero, 1=evenodd
<commands...>
<0> (end marker)
```

### Command Types

```
0 = End
1 = MoveTo
2 = LineTo
3 = CubicTo
4 = QuadTo
5 = Close
```

### Command Encoding

```
MoveTo:   <1> <x float> <y float>
LineTo:   <2> <x float> <y float>
CubicTo:  <3> <x1 float> <y1 float> <x2 float> <y2 float> <x float> <y float>
QuadTo:   <4> <x1 float> <y1 float> <x float> <y float>
Close:    <5>
End:      <0>
```

## Node Message Structure

The main document is a message containing `nodeChanges`:

```kiwi
message Document {
  repeated NodeChange nodeChanges = 1;
  // ... other fields
}

message NodeChange {
  GUID guid = 1;
  ParentIndex parentIndex = 2;
  NodeType type = 3;
  string name = 4;
  bool visible = 5;
  float opacity = 6;
  Matrix transform = 7;
  Size size = 8;
  bytes fillPaints = 9;
  bytes strokePaints = 10;
  bytes effects = 11;
  float strokeWeight = 12;
  // ... many more fields
}
```

## Compression

### Schema Chunk (DEFLATE)

Raw DEFLATE without zlib header/footer.

```rust
use flate2::read::DeflateDecoder;

fn decompress_schema(data: &[u8]) -> Vec<u8> {
    let mut decoder = DeflateDecoder::new(data);
    let mut output = Vec::new();
    decoder.read_to_end(&mut output).unwrap();
    output
}
```

### Data Chunk (ZSTD)

Standard ZSTD compression.

```rust
fn decompress_data(data: &[u8]) -> Vec<u8> {
    zstd::decode_all(data).unwrap()
}
```

## References

- [Original Kiwi repository](https://github.com/evanw/kiwi)
- [Kiwi format demo](https://evanw.github.io/kiwi/)
- [brine-kiwi (Rust)](https://github.com/zfedoran/brine-kiwi)
- [Figma Plugin API](https://www.figma.com/plugin-docs/)
