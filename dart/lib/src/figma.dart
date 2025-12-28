/// Figma Kiwi Schema support for Dart/Flutter
///
/// This module provides support for encoding and decoding Figma's internal
/// Kiwi binary format, which is used for .fig files and clipboard data.
///
/// Based on the Kiwi schema specification from:
/// https://github.com/gridaco/grida/tree/main/packages/grida-canvas-io-figma/fig-kiwi

library figma;

import 'dart:typed_data';
import 'compiler.dart';
import 'schema.dart';
import 'parser.dart';

/// The Figma Kiwi schema text definition
const String figmaSchemaText = r'''
// Figma Kiwi Schema - Dart/Flutter Port
// Based on Figma's internal Kiwi format specification

// ============================================================================
// ENUMS - Node Types
// ============================================================================

enum NodeType {
  NONE = 0;
  DOCUMENT = 1;
  CANVAS = 2;
  FRAME = 3;
  GROUP = 4;
  VECTOR = 5;
  BOOLEAN_OPERATION = 6;
  STAR = 7;
  LINE = 8;
  ELLIPSE = 9;
  RECTANGLE = 10;
  REGULAR_POLYGON = 11;
  ROUNDED_RECTANGLE = 12;
  TEXT = 13;
  SLICE = 14;
  SYMBOL = 15;
  INSTANCE = 16;
  STICKY = 17;
  SHAPE_WITH_TEXT = 18;
  CONNECTOR = 19;
  CODE_BLOCK = 20;
  WIDGET = 21;
  STAMP = 22;
  MEDIA = 23;
  HIGHLIGHT = 24;
  SECTION = 25;
  SECTION_OVERLAY = 26;
  WASHI_TAPE = 27;
  VARIABLE = 28;
  TABLE = 29;
  TABLE_CELL = 30;
  SLIDE = 31;
  SLIDE_ROW = 32;
  LINK_UNFURL = 33;
  LOTTIE = 34;
  AI_FILE = 35;
  DIAGRAMMING_ELEMENT = 36;
  DIAGRAMMING_CONNECTION = 37;
  COMPONENT = 38;
  COMPONENT_SET = 39;
  EMBED = 40;
}

// ============================================================================
// ENUMS - Paint & Styling
// ============================================================================

enum PaintType {
  SOLID = 0;
  GRADIENT_LINEAR = 1;
  GRADIENT_RADIAL = 2;
  GRADIENT_ANGULAR = 3;
  GRADIENT_DIAMOND = 4;
  IMAGE = 5;
  VIDEO = 6;
  EMOJI = 7;
  PATTERN = 8;
  NOISE = 9;
  EFFECT = 10;
}

enum BlendMode {
  PASS_THROUGH = 0;
  NORMAL = 1;
  DARKEN = 2;
  MULTIPLY = 3;
  COLOR_BURN = 4;
  LIGHTEN = 5;
  SCREEN = 6;
  COLOR_DODGE = 7;
  OVERLAY = 8;
  SOFT_LIGHT = 9;
  HARD_LIGHT = 10;
  DIFFERENCE = 11;
  EXCLUSION = 12;
  HUE = 13;
  SATURATION = 14;
  COLOR = 15;
  LUMINOSITY = 16;
  LINEAR_BURN = 17;
  LINEAR_DODGE = 18;
  PLUS_DARKER = 19;
  PLUS_LIGHTER = 20;
}

enum StrokeAlign {
  CENTER = 0;
  INSIDE = 1;
  OUTSIDE = 2;
}

enum StrokeCap {
  NONE = 0;
  ROUND = 1;
  SQUARE = 2;
  LINE_ARROW = 3;
  TRIANGLE_ARROW = 4;
  DIAMOND_FILLED = 5;
  CIRCLE_FILLED = 6;
  TRIANGLE_FILLED = 7;
  WASHI_TAPE_1 = 8;
  WASHI_TAPE_2 = 9;
  WASHI_TAPE_3 = 10;
  WASHI_TAPE_4 = 11;
  WASHI_TAPE_5 = 12;
  WASHI_TAPE_6 = 13;
}

enum StrokeJoin {
  MITER = 0;
  BEVEL = 1;
  ROUND = 2;
}

enum ImageScaleMode {
  STRETCH = 0;
  FIT = 1;
  FILL = 2;
  TILE = 3;
}

enum EffectType {
  DROP_SHADOW = 0;
  INNER_SHADOW = 1;
  LAYER_BLUR = 2;
  BACKGROUND_BLUR = 3;
  FOREGROUND_BLUR = 4;
}

// ============================================================================
// ENUMS - Layout & Constraints
// ============================================================================

enum StackMode {
  NONE = 0;
  HORIZONTAL = 1;
  VERTICAL = 2;
}

enum StackAlign {
  MIN = 0;
  CENTER = 1;
  MAX = 2;
  BASELINE = 3;
}

enum StackJustify {
  MIN = 0;
  CENTER = 1;
  MAX = 2;
  SPACE_EVENLY = 3;
}

enum StackSize {
  FIXED = 0;
  RESIZE_TO_FIT = 1;
  RESIZE_TO_FIT_WITH_IMPLICIT_SIZE = 2;
}

enum StackPositioning {
  AUTO = 0;
  ABSOLUTE = 1;
}

enum ConstraintType {
  MIN = 0;
  CENTER = 1;
  MAX = 2;
  STRETCH = 3;
  SCALE = 4;
  FIXED_MIN = 5;
  FIXED_MAX = 6;
}

enum LayoutGridType {
  MIN = 0;
  STRETCH = 1;
  CENTER = 2;
}

// ============================================================================
// ENUMS - Text
// ============================================================================

enum TextAlignHorizontal {
  LEFT = 0;
  CENTER = 1;
  RIGHT = 2;
  JUSTIFIED = 3;
}

enum TextAlignVertical {
  TOP = 0;
  CENTER = 1;
  BOTTOM = 2;
}

enum TextAutoResize {
  NONE = 0;
  WIDTH_AND_HEIGHT = 1;
  HEIGHT = 2;
  TRUNCATE = 3;
}

enum TextTruncation {
  DISABLED = 0;
  ENDING = 1;
}

enum TextCase {
  ORIGINAL = 0;
  UPPER = 1;
  LOWER = 2;
  TITLE = 3;
  SMALL_CAPS = 4;
  SMALL_CAPS_FORCED = 5;
}

enum TextDecoration {
  NONE = 0;
  UNDERLINE = 1;
  STRIKETHROUGH = 2;
}

enum LeadingTrim {
  NONE = 0;
  CAP_HEIGHT = 1;
}

enum FontStyle {
  NORMAL = 0;
  ITALIC = 1;
}

enum FontWeight {
  THIN = 100;
  EXTRA_LIGHT = 200;
  LIGHT = 300;
  REGULAR = 400;
  MEDIUM = 500;
  SEMI_BOLD = 600;
  BOLD = 700;
  EXTRA_BOLD = 800;
  BLACK = 900;
}

// ============================================================================
// ENUMS - Boolean Operations
// ============================================================================

enum BooleanOperation {
  UNION = 0;
  INTERSECT = 1;
  SUBTRACT = 2;
  EXCLUDE = 3;
}

// ============================================================================
// ENUMS - Masking
// ============================================================================

enum MaskType {
  NONE = 0;
  OUTLINE = 1;
  ALPHA = 2;
  LUMINANCE = 3;
}

// ============================================================================
// ENUMS - Scroll Behavior
// ============================================================================

enum ScrollBehavior {
  SCROLLS = 0;
  FIXED = 1;
  STICKY = 2;
}

// ============================================================================
// ENUMS - Prototyping
// ============================================================================

enum InteractionType {
  ON_CLICK = 0;
  ON_HOVER = 1;
  ON_PRESS = 2;
  ON_DRAG = 3;
  AFTER_TIMEOUT = 4;
  MOUSE_ENTER = 5;
  MOUSE_LEAVE = 6;
  MOUSE_UP = 7;
  MOUSE_DOWN = 8;
  ON_KEY_DOWN = 9;
}

enum NavigationType {
  NAVIGATE = 0;
  OVERLAY = 1;
  SWAP = 2;
  SCROLL_TO = 3;
  CHANGE_TO = 4;
  OPEN_URL = 5;
  CLOSE = 6;
  BACK = 7;
  SET_VARIABLE = 8;
}

enum TransitionType {
  INSTANT = 0;
  DISSOLVE = 1;
  SMART_ANIMATE = 2;
  SCROLL_ANIMATE = 3;
  MOVE_IN = 4;
  MOVE_OUT = 5;
  PUSH = 6;
  SLIDE_IN = 7;
  SLIDE_OUT = 8;
}

enum TransitionDirection {
  LEFT = 0;
  RIGHT = 1;
  TOP = 2;
  BOTTOM = 3;
}

enum EasingType {
  LINEAR = 0;
  EASE_IN = 1;
  EASE_OUT = 2;
  EASE_IN_OUT = 3;
  EASE_IN_BACK = 4;
  EASE_OUT_BACK = 5;
  EASE_IN_OUT_BACK = 6;
  CUSTOM_BEZIER = 7;
  SPRING = 8;
  GENTLE = 9;
  QUICK = 10;
  BOUNCY = 11;
  SLOW = 12;
  CUSTOM_SPRING = 13;
}

// ============================================================================
// ENUMS - Variables
// ============================================================================

enum VariableDataType {
  BOOLEAN = 0;
  FLOAT = 1;
  STRING = 2;
  COLOR = 3;
  ALIAS = 4;
}

enum VariableScope {
  ALL_SCOPES = 0;
  TEXT_CONTENT = 1;
  CORNER_RADIUS = 2;
  WIDTH_HEIGHT = 3;
  GAP = 4;
  ALL_FILLS = 5;
  FRAME_FILL = 6;
  SHAPE_FILL = 7;
  TEXT_FILL = 8;
  STROKE_COLOR = 9;
  STROKE_FLOAT = 10;
  EFFECT_FLOAT = 11;
  EFFECT_COLOR = 12;
  OPACITY = 13;
  FONT_FAMILY = 14;
  FONT_STYLE = 15;
  FONT_SIZE = 16;
  LINE_HEIGHT = 17;
  LETTER_SPACING = 18;
  PARAGRAPH_SPACING = 19;
  PARAGRAPH_INDENT = 20;
}

// ============================================================================
// ENUMS - Number Units
// ============================================================================

enum NumberUnits {
  RAW = 0;
  PIXELS = 1;
  PERCENT = 2;
}

// ============================================================================
// ENUMS - Export Settings
// ============================================================================

enum ExportFormat {
  PNG = 0;
  JPG = 1;
  SVG = 2;
  PDF = 3;
}

enum ExportConstraintType {
  SCALE = 0;
  WIDTH = 1;
  HEIGHT = 2;
}

// ============================================================================
// STRUCTS - Core Value Types
// ============================================================================

struct GUID {
  uint sessionID;
  uint localID;
}

struct Color {
  float r;
  float g;
  float b;
  float a;
}

struct Vector {
  float x;
  float y;
}

struct Rect {
  float x;
  float y;
  float w;
  float h;
}

struct Matrix {
  float m00;
  float m01;
  float m02;
  float m10;
  float m11;
  float m12;
}

struct Number {
  float value;
  NumberUnits units;
}

struct Size {
  float width;
  float height;
}

// ============================================================================
// STRUCTS - Gradient
// ============================================================================

struct ColorStop {
  float position;
  Color color;
}

struct GradientTransform {
  Vector handlePositionA;
  Vector handlePositionB;
  Vector handlePositionC;
}

// ============================================================================
// STRUCTS - Font
// ============================================================================

struct FontName {
  string family;
  string style;
  string postscript;
}

struct FontVariation {
  uint axisTag;
  float value;
}

struct Glyph {
  uint glyphID;
  int styleID;
  float emojiCodePointsOffset;
  float emojiCodePointsLength;
}

// ============================================================================
// STRUCTS - Path
// ============================================================================

struct VectorVertex {
  float x;
  float y;
  float handleInX;
  float handleInY;
  float handleOutX;
  float handleOutY;
  float cornerRadius;
  bool handleMirroring;
}

struct VectorSegment {
  uint startVertex;
  uint endVertex;
  float tangentStart;
  float tangentEnd;
}

struct VectorRegion {
  uint windingRule;
}

// ============================================================================
// STRUCTS - Layout Grid
// ============================================================================

struct LayoutGrid {
  LayoutGridType type;
  float count;
  float sectionSize;
  bool visible;
  Color color;
  float offset;
  float gutterSize;
}

// ============================================================================
// STRUCTS - Export Settings
// ============================================================================

struct ExportConstraint {
  ExportConstraintType type;
  float value;
}

struct ExportSettingsStruct {
  ExportFormat format;
  ExportConstraint constraint;
  string suffix;
}

// ============================================================================
// MESSAGES - Paint
// ============================================================================

message Paint {
  PaintType type = 1;
  Color color = 2;
  float opacity = 3;
  bool visible = 4;
  BlendMode blendMode = 5;
  ColorStop[] gradientStops = 6;
  GradientTransform gradientTransform = 7;
  ImageScaleMode imageScaleMode = 8;
  float imageSizeX = 9;
  float imageSizeY = 10;
  Matrix imageTransform = 11;
  float rotation = 12;
  float scale = 13;
}

// ============================================================================
// MESSAGES - Effect
// ============================================================================

message Effect {
  EffectType type = 1;
  bool visible = 2;
  Color color = 3;
  BlendMode blendMode = 4;
  Vector offset = 5;
  float radius = 6;
  float spread = 7;
  bool showShadowBehindNode = 8;
}

// ============================================================================
// MESSAGES - Stroke
// ============================================================================

message StrokeWeights {
  float top = 1;
  float right = 2;
  float bottom = 3;
  float left = 4;
}

// ============================================================================
// MESSAGES - Text Data
// ============================================================================

message TextStyle {
  FontName fontName = 1;
  float fontSize = 2;
  float lineHeight = 3;
  float letterSpacing = 4;
  float paragraphSpacing = 5;
  float paragraphIndent = 6;
  TextAlignHorizontal textAlignHorizontal = 7;
  TextAlignVertical textAlignVertical = 8;
  TextCase textCase = 9;
  TextDecoration textDecoration = 10;
  LeadingTrim leadingTrim = 11;
  FontStyle fontStyle = 12;
  FontVariation[] fontVariations = 13;
  Paint[] fills = 14;
  bool hyperlink = 15;
  string hyperlinkURL = 16;
}

message TextData {
  string characters = 1;
  TextStyle[] styleOverrideTable = 2;
  TextAutoResize autoResize = 3;
  TextTruncation truncation = 4;
  uint maxLines = 5;
}

// ============================================================================
// MESSAGES - Vector Data
// ============================================================================

message VectorData {
  VectorVertex[] vertices = 1;
  VectorSegment[] segments = 2;
  VectorRegion[] regions = 3;
  uint vectorNetworkBlob = 4;
}

// ============================================================================
// MESSAGES - Arc Data
// ============================================================================

message ArcData {
  float startingAngle = 1;
  float endingAngle = 2;
  float innerRadius = 3;
}

// ============================================================================
// MESSAGES - Prototype Interaction
// ============================================================================

message Transition {
  TransitionType type = 1;
  TransitionDirection direction = 2;
  float duration = 3;
  EasingType easingType = 4;
}

message Action {
  NavigationType navigationType = 1;
  GUID destinationID = 2;
  string url = 3;
  Transition transition = 4;
  bool preserveScrollPosition = 5;
  Vector scrollOffset = 6;
}

message Interaction {
  InteractionType trigger = 1;
  Action[] actions = 2;
  float delay = 3;
}

// ============================================================================
// MESSAGES - Component Properties
// ============================================================================

message ComponentProperty {
  string key = 1;
  VariableDataType type = 2;
  string defaultValue = 3;
}

message ComponentPropertyAssignment {
  string definitionID = 1;
  string value = 2;
}

// ============================================================================
// MESSAGES - Variable
// ============================================================================

message VariableValue {
  bool boolValue = 1;
  float floatValue = 2;
  string stringValue = 3;
  Color colorValue = 4;
  GUID aliasValue = 5;
}

message Variable {
  GUID id = 1;
  string name = 2;
  VariableDataType dataType = 3;
  VariableValue defaultValue = 4;
}

message VariableCollection {
  GUID id = 1;
  string name = 2;
  string defaultModeID = 3;
  Variable[] variables = 4;
}

// ============================================================================
// MESSAGES - Constraints
// ============================================================================

message Constraints {
  ConstraintType horizontal = 1;
  ConstraintType vertical = 2;
}

// ============================================================================
// MESSAGES - NodeChange (Main Node Data)
// ============================================================================

message NodeChange {
  GUID guid = 1;
  uint phase = 2;
  uint phaseIntention = 3;
  GUID parentGuid = 4;
  NodeType type = 5;
  string name = 6;
  bool visible = 7;
  bool locked = 8;
  float opacity = 9;
  BlendMode blendMode = 10;
  Size size = 11;
  Matrix transform = 12;
  Paint[] fillPaints = 13;
  Paint[] strokePaints = 14;
  float strokeWeight = 15;
  StrokeWeights strokeWeights = 16;
  StrokeAlign strokeAlign = 17;
  StrokeCap strokeCap = 18;
  StrokeJoin strokeJoin = 19;
  float miterLimit = 20;
  float cornerRadius = 21;
  float cornerSmoothing = 22;
  bool clipsContent = 23;
  Effect[] effects = 24;
  bool isMask = 25;
  MaskType maskType = 26;
  bool exportBackgroundDisabled = 27;
  Constraints constraints = 28;
  LayoutGrid[] layoutGrids = 29;
  StackMode stackMode = 30;
  StackAlign stackPrimaryAlign = 31;
  StackAlign stackCounterAlign = 32;
  float stackSpacing = 33;
  float stackPadding = 34;
  float stackPaddingTop = 35;
  float stackPaddingRight = 36;
  float stackPaddingBottom = 37;
  float stackPaddingLeft = 38;
  StackSize stackPrimarySizing = 39;
  StackSize stackCounterSizing = 40;
  StackPositioning stackPositioning = 41;
  ScrollBehavior scrollBehavior = 42;
  TextData textData = 43;
  VectorData vectorData = 44;
  BooleanOperation booleanOperation = 45;
  ArcData arcData = 46;
  uint starPointCount = 47;
  float starInnerRadius = 48;
  uint regularPolygonPointCount = 49;
  GUID componentID = 50;
  ComponentPropertyAssignment[] componentPropertyAssignments = 51;
  Interaction[] interactions = 52;
  bool isFlowStartingPoint = 53;
  string flowStartingPointName = 54;
  float transitionDuration = 55;
  Transition transitionEasing = 56;
  bool useAbsoluteScroll = 57;
  Vector scrollOrigin = 58;
}

// ============================================================================
// MESSAGES - Blob Data
// ============================================================================

message Blob {
  uint index = 1;
}

// ============================================================================
// MESSAGES - Message (Top Level Container)
// ============================================================================

message Message {
  NodeChange[] nodeChanges = 1;
  Blob[] blobs = 2;
  uint blobBaseIndex = 3;
}
''';

/// Parsed Figma schema
late final Schema _figmaSchema = parseSchema(figmaSchemaText);

/// Compiled Figma schema for encoding/decoding
late final CompiledSchema _compiledFigmaSchema = compileSchema(_figmaSchema);

/// Get the parsed Figma schema
Schema get figmaSchema => _figmaSchema;

/// Get the compiled Figma schema for encoding/decoding
CompiledSchema get compiledFigmaSchema => _compiledFigmaSchema;

/// Encode a Figma NodeChange to binary
Uint8List encodeFigmaNodeChange(Map<String, dynamic> nodeChange) {
  return _compiledFigmaSchema.encode('NodeChange', nodeChange);
}

/// Decode a Figma NodeChange from binary
Map<String, dynamic> decodeFigmaNodeChange(Uint8List data) {
  return _compiledFigmaSchema.decode('NodeChange', data);
}

/// Encode a Figma Message to binary
Uint8List encodeFigmaMessage(Map<String, dynamic> message) {
  return _compiledFigmaSchema.encode('Message', message);
}

/// Decode a Figma Message from binary
Map<String, dynamic> decodeFigmaMessage(Uint8List data) {
  return _compiledFigmaSchema.decode('Message', data);
}

/// Encode a Figma Paint to binary
Uint8List encodeFigmaPaint(Map<String, dynamic> paint) {
  return _compiledFigmaSchema.encode('Paint', paint);
}

/// Decode a Figma Paint from binary
Map<String, dynamic> decodeFigmaPaint(Uint8List data) {
  return _compiledFigmaSchema.decode('Paint', data);
}

/// Encode a Figma Effect to binary
Uint8List encodeFigmaEffect(Map<String, dynamic> effect) {
  return _compiledFigmaSchema.encode('Effect', effect);
}

/// Decode a Figma Effect from binary
Map<String, dynamic> decodeFigmaEffect(Uint8List data) {
  return _compiledFigmaSchema.decode('Effect', data);
}

/// Get the Figma NodeType enum values
Map<String, int> get figmaNodeTypeValues =>
    _compiledFigmaSchema.getEnumValues('NodeType')!;

/// Get the Figma NodeType enum names
Map<int, String> get figmaNodeTypeNames =>
    _compiledFigmaSchema.getEnumNames('NodeType')!;

/// Get the Figma BlendMode enum values
Map<String, int> get figmaBlendModeValues =>
    _compiledFigmaSchema.getEnumValues('BlendMode')!;

/// Get the Figma BlendMode enum names
Map<int, String> get figmaBlendModeNames =>
    _compiledFigmaSchema.getEnumNames('BlendMode')!;

/// Get the Figma PaintType enum values
Map<String, int> get figmaPaintTypeValues =>
    _compiledFigmaSchema.getEnumValues('PaintType')!;

/// Get the Figma PaintType enum names
Map<int, String> get figmaPaintTypeNames =>
    _compiledFigmaSchema.getEnumNames('PaintType')!;

/// Get the Figma EffectType enum values
Map<String, int> get figmaEffectTypeValues =>
    _compiledFigmaSchema.getEnumValues('EffectType')!;

/// Get the Figma EffectType enum names
Map<int, String> get figmaEffectTypeNames =>
    _compiledFigmaSchema.getEnumNames('EffectType')!;
