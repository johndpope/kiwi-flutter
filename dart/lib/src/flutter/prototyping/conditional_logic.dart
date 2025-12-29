// Conditional Logic for Prototyping
// Supports if/else branching based on variables

import 'package:flutter/material.dart';

/// Comparison operators for conditions
enum ComparisonOperator {
  equals('='),
  notEquals('≠'),
  greaterThan('>'),
  lessThan('<'),
  greaterOrEqual('>='),
  lessOrEqual('<='),
  contains('contains'),
  startsWith('starts with'),
  endsWith('ends with'),
  isEmpty('is empty'),
  isNotEmpty('is not empty');

  final String symbol;
  const ComparisonOperator(this.symbol);

  bool evaluate(dynamic left, dynamic right) {
    switch (this) {
      case ComparisonOperator.equals:
        return left == right;
      case ComparisonOperator.notEquals:
        return left != right;
      case ComparisonOperator.greaterThan:
        if (left is num && right is num) return left > right;
        return false;
      case ComparisonOperator.lessThan:
        if (left is num && right is num) return left < right;
        return false;
      case ComparisonOperator.greaterOrEqual:
        if (left is num && right is num) return left >= right;
        return false;
      case ComparisonOperator.lessOrEqual:
        if (left is num && right is num) return left <= right;
        return false;
      case ComparisonOperator.contains:
        if (left is String && right is String) return left.contains(right);
        if (left is List) return left.contains(right);
        return false;
      case ComparisonOperator.startsWith:
        if (left is String && right is String) return left.startsWith(right);
        return false;
      case ComparisonOperator.endsWith:
        if (left is String && right is String) return left.endsWith(right);
        return false;
      case ComparisonOperator.isEmpty:
        if (left is String) return left.isEmpty;
        if (left is List) return left.isEmpty;
        if (left is Map) return left.isEmpty;
        return left == null;
      case ComparisonOperator.isNotEmpty:
        if (left is String) return left.isNotEmpty;
        if (left is List) return left.isNotEmpty;
        if (left is Map) return left.isNotEmpty;
        return left != null;
    }
  }
}

/// Logical operators for combining conditions
enum LogicalOperator {
  and('AND'),
  or('OR');

  final String label;
  const LogicalOperator(this.label);
}

/// Variable types for prototype variables
enum PrototypeVariableType {
  string('String'),
  number('Number'),
  boolean('Boolean'),
  color('Color');

  final String label;
  const PrototypeVariableType(this.label);

  dynamic parseValue(String value) {
    switch (this) {
      case PrototypeVariableType.string:
        return value;
      case PrototypeVariableType.number:
        return num.tryParse(value) ?? 0;
      case PrototypeVariableType.boolean:
        return value.toLowerCase() == 'true';
      case PrototypeVariableType.color:
        final hex = value.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
    }
  }
}

/// Prototype variable definition
class PrototypeVariable {
  final String id;
  final String name;
  final PrototypeVariableType type;
  final dynamic defaultValue;
  final String? description;
  final List<dynamic>? allowedValues;

  const PrototypeVariable({
    required this.id,
    required this.name,
    required this.type,
    required this.defaultValue,
    this.description,
    this.allowedValues,
  });

  PrototypeVariable copyWith({
    String? id,
    String? name,
    PrototypeVariableType? type,
    dynamic defaultValue,
    String? description,
    List<dynamic>? allowedValues,
  }) {
    return PrototypeVariable(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      defaultValue: defaultValue ?? this.defaultValue,
      description: description ?? this.description,
      allowedValues: allowedValues ?? this.allowedValues,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'defaultValue': defaultValue,
      'description': description,
      'allowedValues': allowedValues,
    };
  }

  factory PrototypeVariable.fromMap(Map<String, dynamic> map) {
    return PrototypeVariable(
      id: map['id'],
      name: map['name'],
      type: PrototypeVariableType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PrototypeVariableType.string,
      ),
      defaultValue: map['defaultValue'],
      description: map['description'],
      allowedValues: map['allowedValues'] as List<dynamic>?,
    );
  }

  /// Common variable presets
  static PrototypeVariable loggedIn() => const PrototypeVariable(
        id: 'loggedIn',
        name: 'Logged In',
        type: PrototypeVariableType.boolean,
        defaultValue: false,
        description: 'Whether the user is logged in',
      );

  static PrototypeVariable darkMode() => const PrototypeVariable(
        id: 'darkMode',
        name: 'Dark Mode',
        type: PrototypeVariableType.boolean,
        defaultValue: false,
        description: 'Whether dark mode is enabled',
      );

  static PrototypeVariable userName() => const PrototypeVariable(
        id: 'userName',
        name: 'User Name',
        type: PrototypeVariableType.string,
        defaultValue: '',
        description: 'The current user name',
      );

  static PrototypeVariable itemCount() => const PrototypeVariable(
        id: 'itemCount',
        name: 'Item Count',
        type: PrototypeVariableType.number,
        defaultValue: 0,
        description: 'Number of items in cart',
      );
}

/// Single condition expression
class Condition {
  final String id;
  final String variableId;
  final ComparisonOperator operator;
  final dynamic value;

  const Condition({
    required this.id,
    required this.variableId,
    required this.operator,
    required this.value,
  });

  Condition copyWith({
    String? id,
    String? variableId,
    ComparisonOperator? operator,
    dynamic value,
  }) {
    return Condition(
      id: id ?? this.id,
      variableId: variableId ?? this.variableId,
      operator: operator ?? this.operator,
      value: value ?? this.value,
    );
  }

  bool evaluate(Map<String, dynamic> variables) {
    final variableValue = variables[variableId];
    return operator.evaluate(variableValue, value);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'variableId': variableId,
      'operator': operator.name,
      'value': value,
    };
  }

  factory Condition.fromMap(Map<String, dynamic> map) {
    return Condition(
      id: map['id'],
      variableId: map['variableId'],
      operator: ComparisonOperator.values.firstWhere(
        (e) => e.name == map['operator'],
        orElse: () => ComparisonOperator.equals,
      ),
      value: map['value'],
    );
  }
}

/// Compound condition (multiple conditions with logical operators)
class ConditionGroup {
  final String id;
  final List<Condition> conditions;
  final List<LogicalOperator> operators;

  const ConditionGroup({
    required this.id,
    this.conditions = const [],
    this.operators = const [],
  });

  ConditionGroup copyWith({
    String? id,
    List<Condition>? conditions,
    List<LogicalOperator>? operators,
  }) {
    return ConditionGroup(
      id: id ?? this.id,
      conditions: conditions ?? this.conditions,
      operators: operators ?? this.operators,
    );
  }

  ConditionGroup addCondition(Condition condition, {LogicalOperator? operator}) {
    final newConditions = [...conditions, condition];
    final newOperators = operator != null ? [...operators, operator] : operators;
    return copyWith(conditions: newConditions, operators: newOperators);
  }

  bool evaluate(Map<String, dynamic> variables) {
    if (conditions.isEmpty) return true;

    bool result = conditions.first.evaluate(variables);

    for (int i = 1; i < conditions.length; i++) {
      final condition = conditions[i];
      final operator = i - 1 < operators.length ? operators[i - 1] : LogicalOperator.and;
      final conditionResult = condition.evaluate(variables);

      switch (operator) {
        case LogicalOperator.and:
          result = result && conditionResult;
          break;
        case LogicalOperator.or:
          result = result || conditionResult;
          break;
      }
    }

    return result;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conditions': conditions.map((c) => c.toMap()).toList(),
      'operators': operators.map((o) => o.name).toList(),
    };
  }

  factory ConditionGroup.fromMap(Map<String, dynamic> map) {
    return ConditionGroup(
      id: map['id'],
      conditions: (map['conditions'] as List?)
              ?.map((c) => Condition.fromMap(c))
              .toList() ??
          [],
      operators: (map['operators'] as List?)
              ?.map((o) => LogicalOperator.values.firstWhere(
                    (e) => e.name == o,
                    orElse: () => LogicalOperator.and,
                  ))
              .toList() ??
          [],
    );
  }
}

/// Conditional action - action to take based on condition
class ConditionalAction {
  final String id;
  final ConditionGroup condition;
  final String thenActionNodeId;
  final String? elseActionNodeId;

  const ConditionalAction({
    required this.id,
    required this.condition,
    required this.thenActionNodeId,
    this.elseActionNodeId,
  });

  ConditionalAction copyWith({
    String? id,
    ConditionGroup? condition,
    String? thenActionNodeId,
    String? elseActionNodeId,
  }) {
    return ConditionalAction(
      id: id ?? this.id,
      condition: condition ?? this.condition,
      thenActionNodeId: thenActionNodeId ?? this.thenActionNodeId,
      elseActionNodeId: elseActionNodeId ?? this.elseActionNodeId,
    );
  }

  String? evaluate(Map<String, dynamic> variables) {
    if (condition.evaluate(variables)) {
      return thenActionNodeId;
    }
    return elseActionNodeId;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'condition': condition.toMap(),
      'thenActionNodeId': thenActionNodeId,
      'elseActionNodeId': elseActionNodeId,
    };
  }

  factory ConditionalAction.fromMap(Map<String, dynamic> map) {
    return ConditionalAction(
      id: map['id'],
      condition: ConditionGroup.fromMap(map['condition']),
      thenActionNodeId: map['thenActionNodeId'],
      elseActionNodeId: map['elseActionNodeId'],
    );
  }
}

/// Variable action - set variable value
class SetVariableAction {
  final String variableId;
  final dynamic value;
  final SetVariableOperation operation;

  const SetVariableAction({
    required this.variableId,
    required this.value,
    this.operation = SetVariableOperation.set,
  });

  dynamic apply(dynamic currentValue) {
    switch (operation) {
      case SetVariableOperation.set:
        return value;
      case SetVariableOperation.increment:
        if (currentValue is num && value is num) {
          return currentValue + value;
        }
        return value;
      case SetVariableOperation.decrement:
        if (currentValue is num && value is num) {
          return currentValue - value;
        }
        return value;
      case SetVariableOperation.toggle:
        if (currentValue is bool) {
          return !currentValue;
        }
        return value;
      case SetVariableOperation.append:
        if (currentValue is String && value is String) {
          return currentValue + value;
        }
        if (currentValue is List) {
          return [...currentValue, value];
        }
        return value;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'variableId': variableId,
      'value': value,
      'operation': operation.name,
    };
  }

  factory SetVariableAction.fromMap(Map<String, dynamic> map) {
    return SetVariableAction(
      variableId: map['variableId'],
      value: map['value'],
      operation: SetVariableOperation.values.firstWhere(
        (e) => e.name == map['operation'],
        orElse: () => SetVariableOperation.set,
      ),
    );
  }
}

/// Operations for setting variables
enum SetVariableOperation {
  set('Set'),
  increment('Increment'),
  decrement('Decrement'),
  toggle('Toggle'),
  append('Append');

  final String label;
  const SetVariableOperation(this.label);
}

/// Variable store for prototype runtime
class VariableStore extends ChangeNotifier {
  final Map<String, PrototypeVariable> _definitions = {};
  final Map<String, dynamic> _values = {};

  Map<String, dynamic> get values => Map.unmodifiable(_values);

  void registerVariable(PrototypeVariable variable) {
    _definitions[variable.id] = variable;
    _values[variable.id] = variable.defaultValue;
    notifyListeners();
  }

  void registerVariables(List<PrototypeVariable> variables) {
    for (final variable in variables) {
      _definitions[variable.id] = variable;
      _values[variable.id] = variable.defaultValue;
    }
    notifyListeners();
  }

  T? getValue<T>(String variableId) {
    return _values[variableId] as T?;
  }

  void setValue(String variableId, dynamic value) {
    if (_definitions.containsKey(variableId)) {
      _values[variableId] = value;
      notifyListeners();
    }
  }

  void applyAction(SetVariableAction action) {
    final currentValue = _values[action.variableId];
    final newValue = action.apply(currentValue);
    _values[action.variableId] = newValue;
    notifyListeners();
  }

  void reset() {
    for (final entry in _definitions.entries) {
      _values[entry.key] = entry.value.defaultValue;
    }
    notifyListeners();
  }

  bool evaluateCondition(ConditionGroup condition) {
    return condition.evaluate(_values);
  }

  String? evaluateConditionalAction(ConditionalAction action) {
    return action.evaluate(_values);
  }
}

/// Condition builder widget
class ConditionBuilderPanel extends StatefulWidget {
  final ConditionGroup? condition;
  final List<PrototypeVariable> availableVariables;
  final void Function(ConditionGroup) onConditionChanged;

  const ConditionBuilderPanel({
    super.key,
    this.condition,
    required this.availableVariables,
    required this.onConditionChanged,
  });

  @override
  State<ConditionBuilderPanel> createState() => _ConditionBuilderPanelState();
}

class _ConditionBuilderPanelState extends State<ConditionBuilderPanel> {
  late ConditionGroup _condition;

  @override
  void initState() {
    super.initState();
    _condition = widget.condition ??
        ConditionGroup(id: UniqueKey().toString());
  }

  void _updateCondition(ConditionGroup condition) {
    setState(() => _condition = condition);
    widget.onConditionChanged(condition);
  }

  void _addCondition() {
    final newCondition = Condition(
      id: UniqueKey().toString(),
      variableId: widget.availableVariables.isNotEmpty
          ? widget.availableVariables.first.id
          : '',
      operator: ComparisonOperator.equals,
      value: '',
    );

    _updateCondition(_condition.addCondition(
      newCondition,
      operator: _condition.conditions.isNotEmpty ? LogicalOperator.and : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Conditions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.blue, size: 18),
                onPressed: _addCondition,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_condition.conditions.isEmpty)
            Text(
              'No conditions defined',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            )
          else
            ..._buildConditionRows(),
        ],
      ),
    );
  }

  List<Widget> _buildConditionRows() {
    final widgets = <Widget>[];

    for (int i = 0; i < _condition.conditions.length; i++) {
      final condition = _condition.conditions[i];

      if (i > 0) {
        // Logical operator
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildLogicalOperatorDropdown(i - 1),
          ),
        );
      }

      widgets.add(_buildConditionRow(condition, i));
    }

    return widgets;
  }

  Widget _buildLogicalOperatorDropdown(int index) {
    final operator = index < _condition.operators.length
        ? _condition.operators[index]
        : LogicalOperator.and;

    return Container(
      height: 28,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LogicalOperator>(
          value: operator,
          isExpanded: true,
          dropdownColor: Colors.grey[800],
          style: const TextStyle(color: Colors.blue, fontSize: 11),
          items: LogicalOperator.values.map((op) {
            return DropdownMenuItem(
              value: op,
              child: Text(op.label),
            );
          }).toList(),
          onChanged: (newOp) {
            if (newOp != null) {
              final newOperators = [..._condition.operators];
              if (index < newOperators.length) {
                newOperators[index] = newOp;
              } else {
                newOperators.add(newOp);
              }
              _updateCondition(_condition.copyWith(operators: newOperators));
            }
          },
        ),
      ),
    );
  }

  Widget _buildConditionRow(Condition condition, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Variable selector
          Expanded(
            flex: 2,
            child: _buildVariableDropdown(condition, index),
          ),
          const SizedBox(width: 8),
          // Operator selector
          Expanded(
            flex: 2,
            child: _buildOperatorDropdown(condition, index),
          ),
          const SizedBox(width: 8),
          // Value input
          if (!_isUnaryOperator(condition.operator))
            Expanded(
              flex: 2,
              child: _buildValueInput(condition, index),
            ),
          // Delete button
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey[400], size: 16),
            onPressed: () {
              final newConditions = [..._condition.conditions];
              newConditions.removeAt(index);
              final newOperators = [..._condition.operators];
              if (index > 0 && newOperators.isNotEmpty) {
                newOperators.removeAt(index - 1);
              } else if (newOperators.isNotEmpty) {
                newOperators.removeAt(0);
              }
              _updateCondition(_condition.copyWith(
                conditions: newConditions,
                operators: newOperators,
              ));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  bool _isUnaryOperator(ComparisonOperator op) {
    return op == ComparisonOperator.isEmpty ||
        op == ComparisonOperator.isNotEmpty;
  }

  Widget _buildVariableDropdown(Condition condition, int index) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.availableVariables.any((v) => v.id == condition.variableId)
              ? condition.variableId
              : (widget.availableVariables.isNotEmpty
                  ? widget.availableVariables.first.id
                  : null),
          isExpanded: true,
          dropdownColor: Colors.grey[700],
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: widget.availableVariables.map((variable) {
            return DropdownMenuItem(
              value: variable.id,
              child: Text(variable.name),
            );
          }).toList(),
          onChanged: (newId) {
            if (newId != null) {
              final newConditions = [..._condition.conditions];
              newConditions[index] = condition.copyWith(variableId: newId);
              _updateCondition(_condition.copyWith(conditions: newConditions));
            }
          },
        ),
      ),
    );
  }

  Widget _buildOperatorDropdown(Condition condition, int index) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ComparisonOperator>(
          value: condition.operator,
          isExpanded: true,
          dropdownColor: Colors.grey[700],
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: ComparisonOperator.values.map((op) {
            return DropdownMenuItem(
              value: op,
              child: Text(op.symbol),
            );
          }).toList(),
          onChanged: (newOp) {
            if (newOp != null) {
              final newConditions = [..._condition.conditions];
              newConditions[index] = condition.copyWith(operator: newOp);
              _updateCondition(_condition.copyWith(conditions: newConditions));
            }
          },
        ),
      ),
    );
  }

  Widget _buildValueInput(Condition condition, int index) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: TextEditingController(text: condition.value?.toString() ?? ''),
        style: const TextStyle(color: Colors.white, fontSize: 11),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 6),
          hintText: 'Value',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        onChanged: (text) {
          final variable = widget.availableVariables.firstWhere(
            (v) => v.id == condition.variableId,
            orElse: () => const PrototypeVariable(
              id: '',
              name: '',
              type: PrototypeVariableType.string,
              defaultValue: '',
            ),
          );

          dynamic value;
          switch (variable.type) {
            case PrototypeVariableType.number:
              value = num.tryParse(text) ?? 0;
              break;
            case PrototypeVariableType.boolean:
              value = text.toLowerCase() == 'true';
              break;
            default:
              value = text;
          }

          final newConditions = [..._condition.conditions];
          newConditions[index] = condition.copyWith(value: value);
          _updateCondition(_condition.copyWith(conditions: newConditions));
        },
      ),
    );
  }
}

/// Variable editor panel
class VariableEditorPanel extends StatefulWidget {
  final List<PrototypeVariable> variables;
  final void Function(List<PrototypeVariable>) onVariablesChanged;

  const VariableEditorPanel({
    super.key,
    required this.variables,
    required this.onVariablesChanged,
  });

  @override
  State<VariableEditorPanel> createState() => _VariableEditorPanelState();
}

class _VariableEditorPanelState extends State<VariableEditorPanel> {
  late List<PrototypeVariable> _variables;

  @override
  void initState() {
    super.initState();
    _variables = List.from(widget.variables);
  }

  void _addVariable() {
    final newVariable = PrototypeVariable(
      id: UniqueKey().toString(),
      name: 'newVariable',
      type: PrototypeVariableType.string,
      defaultValue: '',
    );
    setState(() {
      _variables = [..._variables, newVariable];
    });
    widget.onVariablesChanged(_variables);
  }

  void _updateVariable(int index, PrototypeVariable variable) {
    setState(() {
      _variables = [..._variables];
      _variables[index] = variable;
    });
    widget.onVariablesChanged(_variables);
  }

  void _removeVariable(int index) {
    setState(() {
      _variables = [..._variables];
      _variables.removeAt(index);
    });
    widget.onVariablesChanged(_variables);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Variables',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.blue, size: 20),
                  onPressed: _addVariable,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          Expanded(
            child: _variables.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _variables.length,
                    itemBuilder: (context, index) {
                      return _VariableItem(
                        variable: _variables[index],
                        onUpdate: (v) => _updateVariable(index, v),
                        onDelete: () => _removeVariable(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.data_object, color: Colors.grey[600], size: 48),
          const SizedBox(height: 16),
          Text(
            'No variables',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addVariable,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add variable'),
          ),
        ],
      ),
    );
  }
}

class _VariableItem extends StatelessWidget {
  final PrototypeVariable variable;
  final void Function(PrototypeVariable) onUpdate;
  final VoidCallback onDelete;

  const _VariableItem({
    required this.variable,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getTypeIcon(), color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: variable.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (name) {
                    onUpdate(variable.copyWith(name: name));
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey[400], size: 18),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Type dropdown
              Expanded(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<PrototypeVariableType>(
                      value: variable.type,
                      isExpanded: true,
                      dropdownColor: Colors.grey[800],
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      items: PrototypeVariableType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        );
                      }).toList(),
                      onChanged: (type) {
                        if (type != null) {
                          onUpdate(variable.copyWith(type: type));
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Default value
              Expanded(
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildDefaultValueInput(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (variable.type) {
      case PrototypeVariableType.string:
        return Icons.text_fields;
      case PrototypeVariableType.number:
        return Icons.numbers;
      case PrototypeVariableType.boolean:
        return Icons.toggle_on;
      case PrototypeVariableType.color:
        return Icons.palette;
    }
  }

  Widget _buildDefaultValueInput() {
    if (variable.type == PrototypeVariableType.boolean) {
      return DropdownButtonHideUnderline(
        child: DropdownButton<bool>(
          value: variable.defaultValue as bool? ?? false,
          isExpanded: true,
          dropdownColor: Colors.grey[800],
          style: const TextStyle(color: Colors.white, fontSize: 11),
          items: const [
            DropdownMenuItem(value: true, child: Text('true')),
            DropdownMenuItem(value: false, child: Text('false')),
          ],
          onChanged: (value) {
            if (value != null) {
              onUpdate(variable.copyWith(defaultValue: value));
            }
          },
        ),
      );
    }

    return TextField(
      controller: TextEditingController(text: variable.defaultValue?.toString() ?? ''),
      style: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
        hintText: 'Default',
        hintStyle: TextStyle(color: Colors.grey[600]),
      ),
      keyboardType: variable.type == PrototypeVariableType.number
          ? TextInputType.number
          : TextInputType.text,
      onChanged: (text) {
        dynamic value;
        switch (variable.type) {
          case PrototypeVariableType.number:
            value = num.tryParse(text) ?? 0;
            break;
          case PrototypeVariableType.color:
            value = text;
            break;
          default:
            value = text;
        }
        onUpdate(variable.copyWith(defaultValue: value));
      },
    );
  }
}
