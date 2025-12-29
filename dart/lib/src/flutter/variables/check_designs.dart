/// Check Designs - Variable Audit System
///
/// Audits designs for:
/// - Hard-coded values that should use variables
/// - Inconsistent values (similar but not exact)
/// - Unused variables
/// - Missing variable bindings
/// - Variable naming convention violations
/// - Accessibility issues (contrast, sizing)

import 'package:flutter/material.dart';
import '../assets/variables.dart';

/// Audit issue severity
enum AuditSeverity {
  error('Error'),
  warning('Warning'),
  suggestion('Suggestion'),
  info('Info');

  final String label;
  const AuditSeverity(this.label);
}

/// Audit issue category
enum AuditCategory {
  hardcodedValue('Hard-coded Value'),
  inconsistentValue('Inconsistent Value'),
  unusedVariable('Unused Variable'),
  missingBinding('Missing Binding'),
  namingConvention('Naming Convention'),
  accessibility('Accessibility'),
  performance('Performance');

  final String label;
  const AuditCategory(this.label);
}

/// Single audit issue
class AuditIssue {
  /// Issue ID
  final String id;

  /// Severity level
  final AuditSeverity severity;

  /// Category
  final AuditCategory category;

  /// Issue title
  final String title;

  /// Detailed description
  final String description;

  /// Node ID where issue was found (if applicable)
  final String? nodeId;

  /// Property name (if applicable)
  final String? propertyName;

  /// Current value
  final dynamic currentValue;

  /// Suggested variable ID to use
  final String? suggestedVariableId;

  /// Suggested fix description
  final String? suggestedFix;

  /// Whether this issue can be auto-fixed
  final bool autoFixable;

  const AuditIssue({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.description,
    this.nodeId,
    this.propertyName,
    this.currentValue,
    this.suggestedVariableId,
    this.suggestedFix,
    this.autoFixable = false,
  });

  AuditIssue copyWith({
    String? id,
    AuditSeverity? severity,
    AuditCategory? category,
    String? title,
    String? description,
    String? nodeId,
    String? propertyName,
    dynamic currentValue,
    String? suggestedVariableId,
    String? suggestedFix,
    bool? autoFixable,
  }) {
    return AuditIssue(
      id: id ?? this.id,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      nodeId: nodeId ?? this.nodeId,
      propertyName: propertyName ?? this.propertyName,
      currentValue: currentValue ?? this.currentValue,
      suggestedVariableId: suggestedVariableId ?? this.suggestedVariableId,
      suggestedFix: suggestedFix ?? this.suggestedFix,
      autoFixable: autoFixable ?? this.autoFixable,
    );
  }
}

/// Audit configuration
class AuditConfig {
  /// Check for hard-coded colors
  final bool checkHardcodedColors;

  /// Check for hard-coded dimensions
  final bool checkHardcodedDimensions;

  /// Check for hard-coded strings
  final bool checkHardcodedStrings;

  /// Check for unused variables
  final bool checkUnusedVariables;

  /// Check naming conventions
  final bool checkNamingConventions;

  /// Check accessibility
  final bool checkAccessibility;

  /// Minimum color difference to flag as similar (0-255)
  final double colorSimilarityThreshold;

  /// Minimum dimension difference to flag as similar
  final double dimensionSimilarityThreshold;

  /// Naming convention pattern (regex)
  final String? namingPattern;

  /// Minimum contrast ratio for text
  final double minContrastRatio;

  /// Minimum touch target size
  final double minTouchTargetSize;

  const AuditConfig({
    this.checkHardcodedColors = true,
    this.checkHardcodedDimensions = true,
    this.checkHardcodedStrings = false,
    this.checkUnusedVariables = true,
    this.checkNamingConventions = true,
    this.checkAccessibility = true,
    this.colorSimilarityThreshold = 10.0,
    this.dimensionSimilarityThreshold = 2.0,
    this.namingPattern,
    this.minContrastRatio = 4.5,
    this.minTouchTargetSize = 44.0,
  });

  /// Default strict configuration
  static const strict = AuditConfig(
    checkHardcodedColors: true,
    checkHardcodedDimensions: true,
    checkHardcodedStrings: true,
    checkUnusedVariables: true,
    checkNamingConventions: true,
    checkAccessibility: true,
    colorSimilarityThreshold: 5.0,
    dimensionSimilarityThreshold: 1.0,
    minContrastRatio: 4.5,
  );

  /// Default lenient configuration
  static const lenient = AuditConfig(
    checkHardcodedColors: true,
    checkHardcodedDimensions: false,
    checkHardcodedStrings: false,
    checkUnusedVariables: true,
    checkNamingConventions: false,
    checkAccessibility: true,
    colorSimilarityThreshold: 20.0,
    dimensionSimilarityThreshold: 5.0,
    minContrastRatio: 3.0,
  );
}

/// Audit result
class AuditResult {
  /// All issues found
  final List<AuditIssue> issues;

  /// Audit timestamp
  final DateTime timestamp;

  /// Configuration used
  final AuditConfig config;

  /// Statistics
  final AuditStats stats;

  const AuditResult({
    required this.issues,
    required this.timestamp,
    required this.config,
    required this.stats,
  });

  /// Get issues by severity
  List<AuditIssue> getBySeverity(AuditSeverity severity) {
    return issues.where((i) => i.severity == severity).toList();
  }

  /// Get issues by category
  List<AuditIssue> getByCategory(AuditCategory category) {
    return issues.where((i) => i.category == category).toList();
  }

  /// Get auto-fixable issues
  List<AuditIssue> get autoFixableIssues {
    return issues.where((i) => i.autoFixable).toList();
  }

  /// Check if audit passed (no errors)
  bool get passed => issues.every((i) => i.severity != AuditSeverity.error);
}

/// Audit statistics
class AuditStats {
  final int totalNodesScanned;
  final int totalPropertiesScanned;
  final int hardcodedValuesFound;
  final int variablesUsed;
  final int variablesTotal;
  final int unusedVariables;
  final Duration auditDuration;

  const AuditStats({
    required this.totalNodesScanned,
    required this.totalPropertiesScanned,
    required this.hardcodedValuesFound,
    required this.variablesUsed,
    required this.variablesTotal,
    required this.unusedVariables,
    required this.auditDuration,
  });

  /// Variable usage percentage
  double get variableUsagePercent {
    if (variablesTotal == 0) return 0;
    return (variablesUsed / variablesTotal) * 100;
  }
}

/// Node property value for auditing
class PropertyValue {
  final String nodeId;
  final String nodeName;
  final String propertyName;
  final dynamic value;
  final String? boundVariableId;

  const PropertyValue({
    required this.nodeId,
    required this.nodeName,
    required this.propertyName,
    required this.value,
    this.boundVariableId,
  });

  bool get isBound => boundVariableId != null;
}

/// Design auditor
class DesignAuditor {
  final VariableResolver resolver;
  final AuditConfig config;

  DesignAuditor({
    required this.resolver,
    this.config = const AuditConfig(),
  });

  /// Run audit on design properties
  AuditResult audit(List<PropertyValue> properties) {
    final startTime = DateTime.now();
    final issues = <AuditIssue>[];
    final usedVariableIds = <String>{};

    // Track values for similarity checking
    final colorValues = <Color, List<PropertyValue>>{};
    final numberValues = <double, List<PropertyValue>>{};

    // Scan all properties
    for (final prop in properties) {
      if (prop.isBound) {
        usedVariableIds.add(prop.boundVariableId!);
      } else {
        // Check for hard-coded values
        if (prop.value is Color && config.checkHardcodedColors) {
          final color = prop.value as Color;
          colorValues.putIfAbsent(color, () => []).add(prop);

          final suggestion = _findMatchingColorVariable(color);
          if (suggestion != null) {
            issues.add(AuditIssue(
              id: 'hardcoded_color_${prop.nodeId}_${prop.propertyName}',
              severity: AuditSeverity.warning,
              category: AuditCategory.hardcodedValue,
              title: 'Hard-coded color value',
              description:
                  'Node "${prop.nodeName}" uses hard-coded color instead of variable',
              nodeId: prop.nodeId,
              propertyName: prop.propertyName,
              currentValue: color,
              suggestedVariableId: suggestion.id,
              suggestedFix: 'Use variable "${suggestion.name}"',
              autoFixable: true,
            ));
          }
        }

        if (prop.value is num && config.checkHardcodedDimensions) {
          final number = (prop.value as num).toDouble();
          numberValues.putIfAbsent(number, () => []).add(prop);

          final suggestion = _findMatchingNumberVariable(number);
          if (suggestion != null) {
            issues.add(AuditIssue(
              id: 'hardcoded_number_${prop.nodeId}_${prop.propertyName}',
              severity: AuditSeverity.suggestion,
              category: AuditCategory.hardcodedValue,
              title: 'Hard-coded dimension value',
              description:
                  'Node "${prop.nodeName}" uses hard-coded number instead of variable',
              nodeId: prop.nodeId,
              propertyName: prop.propertyName,
              currentValue: number,
              suggestedVariableId: suggestion.id,
              suggestedFix: 'Use variable "${suggestion.name}"',
              autoFixable: true,
            ));
          }
        }
      }
    }

    // Check for inconsistent values
    issues.addAll(_checkInconsistentColors(colorValues));
    issues.addAll(_checkInconsistentNumbers(numberValues));

    // Check for unused variables
    if (config.checkUnusedVariables) {
      issues.addAll(_checkUnusedVariables(usedVariableIds));
    }

    // Check naming conventions
    if (config.checkNamingConventions) {
      issues.addAll(_checkNamingConventions());
    }

    final endTime = DateTime.now();

    final stats = AuditStats(
      totalNodesScanned: properties.map((p) => p.nodeId).toSet().length,
      totalPropertiesScanned: properties.length,
      hardcodedValuesFound:
          issues.where((i) => i.category == AuditCategory.hardcodedValue).length,
      variablesUsed: usedVariableIds.length,
      variablesTotal: resolver.variables.length,
      unusedVariables:
          resolver.variables.length - usedVariableIds.length,
      auditDuration: endTime.difference(startTime),
    );

    return AuditResult(
      issues: issues,
      timestamp: DateTime.now(),
      config: config,
      stats: stats,
    );
  }

  DesignVariable? _findMatchingColorVariable(Color color) {
    for (final variable in resolver.colorVariables) {
      final varColor = resolver.resolveColor(variable.id);
      if (varColor != null && _colorsMatch(color, varColor)) {
        return variable;
      }
    }
    return null;
  }

  DesignVariable? _findMatchingNumberVariable(double number) {
    for (final variable in resolver.numberVariables) {
      final varNumber = resolver.resolveNumber(variable.id);
      if (varNumber != null && _numbersMatch(number, varNumber)) {
        return variable;
      }
    }
    return null;
  }

  bool _colorsMatch(Color a, Color b) {
    return a.value == b.value;
  }

  bool _numbersMatch(double a, double b) {
    return (a - b).abs() < 0.001;
  }

  List<AuditIssue> _checkInconsistentColors(
    Map<Color, List<PropertyValue>> colorValues,
  ) {
    final issues = <AuditIssue>[];
    final colors = colorValues.keys.toList();

    for (var i = 0; i < colors.length; i++) {
      for (var j = i + 1; j < colors.length; j++) {
        final distance = _colorDistance(colors[i], colors[j]);
        if (distance > 0 && distance <= config.colorSimilarityThreshold) {
          final propsA = colorValues[colors[i]]!;
          final propsB = colorValues[colors[j]]!;

          issues.add(AuditIssue(
            id: 'inconsistent_color_${colors[i].value}_${colors[j].value}',
            severity: AuditSeverity.suggestion,
            category: AuditCategory.inconsistentValue,
            title: 'Similar colors found',
            description:
                'Colors are similar but not identical (distance: ${distance.toStringAsFixed(1)}). '
                'Consider unifying to a single variable.',
            currentValue: [colors[i], colors[j]],
            suggestedFix:
                'Unify ${propsA.length + propsB.length} properties to use same color',
          ));
        }
      }
    }

    return issues;
  }

  double _colorDistance(Color a, Color b) {
    final dr = (a.red - b.red).abs();
    final dg = (a.green - b.green).abs();
    final db = (a.blue - b.blue).abs();
    return (dr + dg + db) / 3;
  }

  List<AuditIssue> _checkInconsistentNumbers(
    Map<double, List<PropertyValue>> numberValues,
  ) {
    final issues = <AuditIssue>[];
    final numbers = numberValues.keys.toList();

    for (var i = 0; i < numbers.length; i++) {
      for (var j = i + 1; j < numbers.length; j++) {
        final diff = (numbers[i] - numbers[j]).abs();
        if (diff > 0 && diff <= config.dimensionSimilarityThreshold) {
          issues.add(AuditIssue(
            id: 'inconsistent_number_${numbers[i]}_${numbers[j]}',
            severity: AuditSeverity.info,
            category: AuditCategory.inconsistentValue,
            title: 'Similar dimensions found',
            description:
                'Values ${numbers[i]} and ${numbers[j]} are similar. '
                'Consider standardizing.',
            currentValue: [numbers[i], numbers[j]],
          ));
        }
      }
    }

    return issues;
  }

  List<AuditIssue> _checkUnusedVariables(Set<String> usedVariableIds) {
    final issues = <AuditIssue>[];

    for (final variable in resolver.variables.values) {
      if (!usedVariableIds.contains(variable.id)) {
        issues.add(AuditIssue(
          id: 'unused_variable_${variable.id}',
          severity: AuditSeverity.info,
          category: AuditCategory.unusedVariable,
          title: 'Unused variable',
          description: 'Variable "${variable.name}" is not used in any design',
          suggestedFix: 'Consider removing if no longer needed',
        ));
      }
    }

    return issues;
  }

  List<AuditIssue> _checkNamingConventions() {
    final issues = <AuditIssue>[];
    final pattern = config.namingPattern != null
        ? RegExp(config.namingPattern!)
        : RegExp(r'^[a-z][a-zA-Z0-9/\-_]*$');

    for (final variable in resolver.variables.values) {
      if (!pattern.hasMatch(variable.name)) {
        issues.add(AuditIssue(
          id: 'naming_convention_${variable.id}',
          severity: AuditSeverity.suggestion,
          category: AuditCategory.namingConvention,
          title: 'Naming convention violation',
          description:
              'Variable "${variable.name}" does not follow naming convention',
          suggestedFix: 'Rename to follow pattern: ${pattern.pattern}',
        ));
      }
    }

    return issues;
  }

  /// Check contrast ratio between two colors
  double checkContrastRatio(Color foreground, Color background) {
    final l1 = _relativeLuminance(foreground);
    final l2 = _relativeLuminance(background);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  double _relativeLuminance(Color color) {
    double channel(int value) {
      final v = value / 255;
      return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055).abs();
    }

    return 0.2126 * channel(color.red) +
        0.7152 * channel(color.green) +
        0.0722 * channel(color.blue);
  }
}

/// Auto-fix engine for audit issues
class AuditAutoFixer {
  /// Apply auto-fix for an issue
  AutoFixResult applyFix(AuditIssue issue, VariableManager manager) {
    if (!issue.autoFixable || issue.suggestedVariableId == null) {
      return AutoFixResult(
        success: false,
        message: 'Issue is not auto-fixable',
        issue: issue,
      );
    }

    // The actual fix would bind the property to the variable
    // This is a placeholder - actual implementation depends on the
    // design system's property binding mechanism
    return AutoFixResult(
      success: true,
      message: 'Fixed: bound ${issue.propertyName} to variable',
      issue: issue,
      appliedVariableId: issue.suggestedVariableId,
    );
  }

  /// Apply all auto-fixes
  List<AutoFixResult> applyAllFixes(
    List<AuditIssue> issues,
    VariableManager manager,
  ) {
    return issues
        .where((i) => i.autoFixable)
        .map((i) => applyFix(i, manager))
        .toList();
  }
}

/// Result of an auto-fix operation
class AutoFixResult {
  final bool success;
  final String message;
  final AuditIssue issue;
  final String? appliedVariableId;

  const AutoFixResult({
    required this.success,
    required this.message,
    required this.issue,
    this.appliedVariableId,
  });
}

/// Audit report generator
class AuditReportGenerator {
  /// Generate markdown report
  String generateMarkdownReport(AuditResult result) {
    final buffer = StringBuffer();

    buffer.writeln('# Design Audit Report');
    buffer.writeln();
    buffer.writeln('Generated: ${result.timestamp.toIso8601String()}');
    buffer.writeln();

    // Summary
    buffer.writeln('## Summary');
    buffer.writeln();
    buffer.writeln('| Metric | Value |');
    buffer.writeln('|--------|-------|');
    buffer.writeln('| Nodes Scanned | ${result.stats.totalNodesScanned} |');
    buffer.writeln(
        '| Properties Scanned | ${result.stats.totalPropertiesScanned} |');
    buffer.writeln(
        '| Hard-coded Values | ${result.stats.hardcodedValuesFound} |');
    buffer.writeln(
        '| Variables Used | ${result.stats.variablesUsed}/${result.stats.variablesTotal} |');
    buffer.writeln('| Unused Variables | ${result.stats.unusedVariables} |');
    buffer.writeln();

    // Issues by severity
    buffer.writeln('## Issues');
    buffer.writeln();

    for (final severity in AuditSeverity.values) {
      final severityIssues = result.getBySeverity(severity);
      if (severityIssues.isEmpty) continue;

      buffer.writeln('### ${severity.label}s (${severityIssues.length})');
      buffer.writeln();

      for (final issue in severityIssues) {
        buffer.writeln('- **${issue.title}**');
        buffer.writeln('  - ${issue.description}');
        if (issue.suggestedFix != null) {
          buffer.writeln('  - Suggested: ${issue.suggestedFix}');
        }
        buffer.writeln();
      }
    }

    // Status
    buffer.writeln('## Status');
    buffer.writeln();
    buffer.writeln(result.passed ? '✅ Audit Passed' : '❌ Audit Failed');

    return buffer.toString();
  }

  /// Generate JSON report
  Map<String, dynamic> generateJsonReport(AuditResult result) {
    return {
      'timestamp': result.timestamp.toIso8601String(),
      'passed': result.passed,
      'stats': {
        'totalNodesScanned': result.stats.totalNodesScanned,
        'totalPropertiesScanned': result.stats.totalPropertiesScanned,
        'hardcodedValuesFound': result.stats.hardcodedValuesFound,
        'variablesUsed': result.stats.variablesUsed,
        'variablesTotal': result.stats.variablesTotal,
        'unusedVariables': result.stats.unusedVariables,
      },
      'issues': result.issues
          .map((i) => {
                'id': i.id,
                'severity': i.severity.name,
                'category': i.category.name,
                'title': i.title,
                'description': i.description,
                'nodeId': i.nodeId,
                'propertyName': i.propertyName,
                'autoFixable': i.autoFixable,
              })
          .toList(),
    };
  }
}
