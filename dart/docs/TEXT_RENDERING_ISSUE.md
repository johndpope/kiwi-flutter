# Text Rendering Issue - Component Instance Overrides

## Problem Summary

Text inside component instances shows placeholder text (e.g., "X", "xx") instead of the overridden values (e.g., "B", "10", "11").

## Root Cause

The `symbolOverrides` in Figma instances use `guidPath` with the **original component definition's GUIDs**, not the GUIDs from the current document's `nodeMap`.

### Example from Debug Logs

```
DEBUG OVERRIDE: key=9:5584 has textData.characters="B"
DEBUG OVERRIDE MAP for ".Letter": 1 entries, keys=[9:5584]
DEBUG CHILD MATCHING for ".Letter":
  childKeys: [524:44863]
  overrideKeys: [9:5584]
  child "524:44863" guid={sessionID: 524, localID: 44863}
```

- Override targets guid `9:5584`
- Actual child node has guid `524:44863`
- These don't match, so override is not applied

## Technical Details

### Data Flow

1. INSTANCE node has `symbolData.symbolID` pointing to source COMPONENT
2. INSTANCE has `symbolData.symbolOverrides` with overrides
3. Each override has `guidPath` identifying target node within component
4. `guidPath` uses guids from when component was DEFINED, not current nodeMap

### Override Structure

```dart
// symbolOverrides entry with textData
{
  'guidPath': {
    'guids': [{'sessionID': 9, 'localID': 5584}]
  },
  'textData': {
    'characters': 'B',
    'lines': [...]
  }
}
```

### Component Property Assignments (Modern Style)

```dart
// symbolOverrides entry with componentPropAssignments
{
  'guidPath': {...},
  'componentPropAssignments': [
    {
      'defID': {'sessionID': 10, 'localID': 5},
      'value': {
        'textValue': {
          'characters': 'B',
          'lines': [...]
        }
      }
    }
  ]
}
```

## Current Code Location

**File:** `lib/src/flutter/node_renderer.dart`

### Override Map Building (lines ~1054-1190)

```dart
// Build override map from symbolOverrides
final overrideMap = <String, Map<String, dynamic>>{};
if (symbolOverrides != null) {
  for (final override in symbolOverrides) {
    if (override is Map) {
      final guidPath = override['guidPath'];
      // Extract key from guidPath...
      if (overrideKey != null) {
        overrideMap[overrideKey] = overrideProps;
      }
    }
  }
}
```

### Override Lookup (lines ~1236-1266)

```dart
// Check if there's an override for this child
Map<String, dynamic>? childOverride = overrideMap[childKey];

// Try by node's original guid
if (childOverride == null && overrideMap.isNotEmpty) {
  final childGuid = childNode['guid'];
  if (childGuid is Map) {
    final guidKey = '${childGuid['sessionID']}:${childGuid['localID']}';
    childOverride = overrideMap[guidKey];
  }
}

// Fallback for single text child/override
if (childOverride == null && singleTextOverride != null && childProps.type == 'TEXT') {
  childOverride = singleTextOverride;
}
```

## Attempted Solutions

### 1. Match by Node's GUID (Doesn't Work)
The node's stored guid in nodeMap doesn't match override guidPath because guids change when components are copied/exported.

### 2. Single Text Fallback (Partial)
If component has exactly 1 TEXT child and 1 text override, assume they match. Works for simple cases but not complex components.

## Potential Solutions to Investigate

### Option A: Build GUID Mapping Table
When loading component definitions, build a mapping from original guids to nodeMap keys based on:
- Node position in hierarchy
- Node name
- Node type

### Option B: Use Component Property References
For modern Figma files using `componentPropAssignments`:
1. Parse component property definitions from source component
2. Map `defID` to which nodes reference that property
3. Apply values to referencing nodes

### Option C: Name-Based Matching
Match overrides to nodes by comparing node names when guid matching fails.

### Option D: Index-Based Matching
For simple components, match by child index position.

## Files to Examine

- `lib/src/flutter/node_renderer.dart` - Main rendering logic
- `lib/src/flutter/figma_canvas.dart` - Document/nodeMap creation
- `lib/src/figma.dart` / `lib/src/figma_schema.kiwi` - Schema definitions

## Debug Flag

Enable verbose logging:
```dart
// lib/src/flutter/node_renderer.dart:174
bool figmaRendererDebug = true; // Enable for debugging
```

## Related Figma Concepts

- **Component**: Reusable design element (type: COMPONENT or SYMBOL)
- **Instance**: Usage of a component (type: INSTANCE)
- **symbolOverrides**: Array of property overrides for instance
- **guidPath**: Path to target node within component hierarchy
- **componentPropAssignments**: Modern property override system with defID references
