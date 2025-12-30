#!/usr/bin/env python3
"""
Analyze Figma WASM capture data

Usage:
    python analyze_capture.py figma_wasm_capture.json
"""

import json
import sys
from collections import defaultdict
from pathlib import Path


def analyze_capture(filepath: str):
    with open(filepath) as f:
        data = json.load(f)

    print("=" * 80)
    print("FIGMA WASM CAPTURE ANALYSIS")
    print("=" * 80)

    # Basic stats
    print(f"\nCapture Duration: {data.get('timeline', [{}])[-1].get('timestamp', 0) / 1000:.1f} seconds")
    print(f"Total Calls: {len(data.get('timeline', []))}")

    # Import stats
    print("\n" + "=" * 80)
    print("IMPORTS (JS → WASM) - Top 20")
    print("=" * 80)
    imports = data.get('imports', {})
    sorted_imports = sorted(imports.items(), key=lambda x: len(x[1]), reverse=True)[:20]
    for name, calls in sorted_imports:
        print(f"  {name}: {len(calls)} calls")

    # Export stats
    print("\n" + "=" * 80)
    print("EXPORTS (WASM → JS) - Top 20")
    print("=" * 80)
    exports = data.get('exports', {})
    sorted_exports = sorted(exports.items(), key=lambda x: len(x[1]), reverse=True)[:20]
    for name, calls in sorted_exports:
        print(f"  {name}: {len(calls)} calls")

    # Analyze Canvas calls
    print("\n" + "=" * 80)
    print("CANVAS CONTEXT CALLS")
    print("=" * 80)
    canvas_calls = {k: v for k, v in exports.items() if k.startswith('CanvasContext_Internal_')}
    for name, calls in sorted(canvas_calls.items()):
        print(f"\n{name} ({len(calls)} calls)")
        # Show first few unique argument patterns
        patterns = set()
        for call in calls[:10]:
            args = call.get('args', [])
            pattern = tuple(
                f"{type(a.get('value')).__name__}={a.get('value')}"
                if isinstance(a.get('value'), (int, float)) and abs(a.get('value', 0)) < 10000
                else type(a.get('value')).__name__
                for a in args
            )
            patterns.add(pattern)
        for p in list(patterns)[:3]:
            print(f"    Args: {p}")

    # Analyze Kiwi serialization
    print("\n" + "=" * 80)
    print("KIWI SERIALIZATION CALLS")
    print("=" * 80)
    kiwi_calls = {k: v for k, v in imports.items() if 'KiwiSerialization' in k}
    for name, calls in sorted(kiwi_calls.items()):
        print(f"\n{name} ({len(calls)} calls)")
        # Show memory sizes if captured
        sizes = []
        for call in calls:
            args = call.get('args', [])
            for arg in args:
                if arg.get('memory'):
                    sizes.append(len(arg['memory']))
        if sizes:
            print(f"    Memory sizes: min={min(sizes)}, max={max(sizes)}, avg={sum(sizes)//len(sizes)}")

    # Analyze Node API calls
    print("\n" + "=" * 80)
    print("NODE API CALLS - Top 20")
    print("=" * 80)
    node_calls = {k: v for k, v in exports.items() if k.startswith('NodeTsApi_')}
    sorted_node = sorted(node_calls.items(), key=lambda x: len(x[1]), reverse=True)[:20]
    for name, calls in sorted_node:
        print(f"  {name}: {len(calls)} calls")

    # Timeline analysis - what happens when opening a file
    print("\n" + "=" * 80)
    print("CALL SEQUENCE (First 50 calls)")
    print("=" * 80)
    timeline = data.get('timeline', [])
    for i, call in enumerate(timeline[:50]):
        ts = call.get('timestamp', 0)
        name = call.get('name', 'unknown')
        direction = call.get('direction', '?')
        args = call.get('args', [])
        arg_summary = ', '.join(
            str(a.get('value'))[:20] if isinstance(a.get('value'), (int, float, str)) else '...'
            for a in args[:3]
        )
        result = call.get('result', '')
        result_str = f" → {result}" if result else ""
        print(f"  [{ts:6d}ms] [{direction}] {name}({arg_summary}){result_str}")

    # Extract actual data samples
    print("\n" + "=" * 80)
    print("DATA SAMPLES (Memory contents)")
    print("=" * 80)

    # Find calls with interpreted memory data
    for name, calls in list(exports.items())[:10]:
        for call in calls[:2]:
            if call.get('resultInterpreted'):
                interp = call['resultInterpreted']
                print(f"\n{name} result:")
                if interp.get('asFloat32x4'):
                    print(f"  as float32[4]: {interp['asFloat32x4']}")
                if interp.get('asString') and len(interp['asString']) > 2:
                    print(f"  as string: {interp['asString'][:50]}")


def extract_kiwi_samples(filepath: str, output_dir: str = 'kiwi_samples'):
    """Extract raw Kiwi-encoded data from captures for testing."""
    with open(filepath) as f:
        data = json.load(f)

    out_path = Path(output_dir)
    out_path.mkdir(exist_ok=True)

    imports = data.get('imports', {})

    for func_name, calls in imports.items():
        if 'KiwiSerialization' not in func_name:
            continue

        for i, call in enumerate(calls[:10]):  # First 10 samples
            args = call.get('args', [])
            for j, arg in enumerate(args):
                if arg.get('memory'):
                    # Save raw bytes
                    sample_name = f"{func_name.replace('_', '-')}_{i}_arg{j}.bin"
                    sample_path = out_path / sample_name
                    sample_path.write_bytes(bytes(arg['memory']))
                    print(f"Saved: {sample_path}")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python analyze_capture.py <capture.json> [--extract-kiwi]")
        sys.exit(1)

    filepath = sys.argv[1]

    if '--extract-kiwi' in sys.argv:
        extract_kiwi_samples(filepath)
    else:
        analyze_capture(filepath)
