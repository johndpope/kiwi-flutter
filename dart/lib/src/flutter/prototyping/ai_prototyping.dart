// AI-Assisted Prototyping
// Prompt-to-prototype generation and smart suggestions

import 'package:flutter/material.dart';
import 'interactions.dart';

/// AI generation status
enum AIGenerationStatus {
  idle,
  analyzing,
  generating,
  complete,
  error,
}

/// AI suggestion type
enum AISuggestionType {
  addInteraction('Add Interaction'),
  addScreen('Add Screen'),
  addNavigation('Add Navigation'),
  addOverlay('Add Overlay'),
  fixUsability('Fix Usability'),
  addBackButton('Add Back Button'),
  improveFlow('Improve Flow');

  final String label;
  const AISuggestionType(this.label);
}

/// AI-generated suggestion
class AISuggestion {
  final String id;
  final AISuggestionType type;
  final String title;
  final String description;
  final double confidence;
  final Map<String, dynamic> actionData;

  const AISuggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.confidence = 0.8,
    this.actionData = const {},
  });

  AISuggestion copyWith({
    String? id,
    AISuggestionType? type,
    String? title,
    String? description,
    double? confidence,
    Map<String, dynamic>? actionData,
  }) {
    return AISuggestion(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
      actionData: actionData ?? this.actionData,
    );
  }
}

/// Generated prototype flow
class GeneratedFlow {
  final String id;
  final String name;
  final List<GeneratedScreen> screens;
  final List<GeneratedInteraction> interactions;

  const GeneratedFlow({
    required this.id,
    required this.name,
    this.screens = const [],
    this.interactions = const [],
  });
}

/// Generated screen
class GeneratedScreen {
  final String id;
  final String name;
  final ScreenTemplate template;
  final Map<String, dynamic> properties;

  const GeneratedScreen({
    required this.id,
    required this.name,
    required this.template,
    this.properties = const {},
  });
}

/// Screen template types
enum ScreenTemplate {
  blank('Blank'),
  login('Login'),
  signup('Sign Up'),
  home('Home'),
  profile('Profile'),
  settings('Settings'),
  list('List'),
  detail('Detail'),
  form('Form'),
  success('Success'),
  error('Error'),
  onboarding('Onboarding'),
  splash('Splash'),
  modal('Modal');

  final String label;
  const ScreenTemplate(this.label);
}

/// Generated interaction between screens
class GeneratedInteraction {
  final String fromScreenId;
  final String toScreenId;
  final String triggerElementId;
  final InteractionTrigger trigger;
  final TransitionConfig transition;

  const GeneratedInteraction({
    required this.fromScreenId,
    required this.toScreenId,
    required this.triggerElementId,
    this.trigger = InteractionTrigger.onClick,
    this.transition = const TransitionConfig(),
  });
}

/// AI Prototyping Engine (mock implementation)
class AIPrototypingEngine {
  AIGenerationStatus _status = AIGenerationStatus.idle;
  String? _lastError;

  AIGenerationStatus get status => _status;
  String? get lastError => _lastError;

  /// Generate a prototype from a natural language prompt
  Future<GeneratedFlow?> generateFromPrompt(String prompt) async {
    _status = AIGenerationStatus.analyzing;
    _lastError = null;

    // Simulate AI processing
    await Future.delayed(const Duration(milliseconds: 500));

    _status = AIGenerationStatus.generating;

    try {
      // Parse prompt and generate flow
      final flow = _parsePromptToFlow(prompt);

      await Future.delayed(const Duration(milliseconds: 800));

      _status = AIGenerationStatus.complete;
      return flow;
    } catch (e) {
      _status = AIGenerationStatus.error;
      _lastError = e.toString();
      return null;
    }
  }

  /// Get AI suggestions for a prototype
  Future<List<AISuggestion>> getSuggestions({
    required List<String> screenIds,
    required Map<String, NodeInteractions> interactions,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final suggestions = <AISuggestion>[];

    // Check for screens without back navigation
    for (final screenId in screenIds) {
      final screenInteractions = interactions[screenId];
      final hasBack = screenInteractions?.interactions.any(
            (i) => i.action == InteractionAction.back,
          ) ??
          false;

      if (!hasBack && screenIds.indexOf(screenId) > 0) {
        suggestions.add(AISuggestion(
          id: 'suggest_back_$screenId',
          type: AISuggestionType.addBackButton,
          title: 'Add back navigation',
          description: 'Screen "$screenId" has no way to go back',
          confidence: 0.9,
          actionData: {'screenId': screenId},
        ));
      }
    }

    // Check for orphaned screens (no incoming navigation)
    final destinationScreens = <String>{};
    for (final nodeInteractions in interactions.values) {
      for (final interaction in nodeInteractions.interactions) {
        if (interaction.destinationNodeId != null) {
          destinationScreens.add(interaction.destinationNodeId!);
        }
      }
    }

    for (final screenId in screenIds.skip(1)) {
      if (!destinationScreens.contains(screenId)) {
        suggestions.add(AISuggestion(
          id: 'suggest_nav_$screenId',
          type: AISuggestionType.addNavigation,
          title: 'Connect orphaned screen',
          description: 'Screen "$screenId" is not reachable from any other screen',
          confidence: 0.85,
          actionData: {'screenId': screenId},
        ));
      }
    }

    // Suggest overlay for modal-like screens
    for (final screenId in screenIds) {
      if (screenId.contains('modal') ||
          screenId.contains('popup') ||
          screenId.contains('dialog')) {
        final usesOverlay = interactions.values.any((ni) =>
            ni.interactions.any((i) =>
                i.action == InteractionAction.openOverlay &&
                i.destinationNodeId == screenId));

        if (!usesOverlay) {
          suggestions.add(AISuggestion(
            id: 'suggest_overlay_$screenId',
            type: AISuggestionType.addOverlay,
            title: 'Use overlay for modal',
            description:
                'Screen "$screenId" looks like a modal - consider using overlay transition',
            confidence: 0.75,
            actionData: {'screenId': screenId},
          ));
        }
      }
    }

    return suggestions;
  }

  /// Parse natural language prompt into a flow structure
  GeneratedFlow _parsePromptToFlow(String prompt) {
    final promptLower = prompt.toLowerCase();
    final screens = <GeneratedScreen>[];
    final interactions = <GeneratedInteraction>[];

    // Detect common flow patterns
    if (promptLower.contains('login') || promptLower.contains('sign in')) {
      screens.addAll([
        const GeneratedScreen(
          id: 'splash',
          name: 'Splash Screen',
          template: ScreenTemplate.splash,
        ),
        const GeneratedScreen(
          id: 'login',
          name: 'Login',
          template: ScreenTemplate.login,
        ),
        const GeneratedScreen(
          id: 'home',
          name: 'Home',
          template: ScreenTemplate.home,
        ),
      ]);

      interactions.addAll([
        const GeneratedInteraction(
          fromScreenId: 'splash',
          toScreenId: 'login',
          triggerElementId: 'splash_auto',
          trigger: InteractionTrigger.afterDelay,
        ),
        const GeneratedInteraction(
          fromScreenId: 'login',
          toScreenId: 'home',
          triggerElementId: 'login_button',
        ),
      ]);

      if (promptLower.contains('signup') || promptLower.contains('sign up') ||
          promptLower.contains('register')) {
        screens.add(const GeneratedScreen(
          id: 'signup',
          name: 'Sign Up',
          template: ScreenTemplate.signup,
        ));
        interactions.add(const GeneratedInteraction(
          fromScreenId: 'login',
          toScreenId: 'signup',
          triggerElementId: 'signup_link',
        ));
        interactions.add(const GeneratedInteraction(
          fromScreenId: 'signup',
          toScreenId: 'home',
          triggerElementId: 'signup_button',
        ));
      }

      if (promptLower.contains('forgot') || promptLower.contains('password')) {
        screens.add(const GeneratedScreen(
          id: 'forgot_password',
          name: 'Forgot Password',
          template: ScreenTemplate.form,
        ));
        interactions.add(const GeneratedInteraction(
          fromScreenId: 'login',
          toScreenId: 'forgot_password',
          triggerElementId: 'forgot_link',
        ));
      }
    }

    if (promptLower.contains('onboarding') || promptLower.contains('tutorial')) {
      final onboardingScreens = <GeneratedScreen>[
        const GeneratedScreen(
          id: 'onboard_1',
          name: 'Welcome',
          template: ScreenTemplate.onboarding,
        ),
        const GeneratedScreen(
          id: 'onboard_2',
          name: 'Features',
          template: ScreenTemplate.onboarding,
        ),
        const GeneratedScreen(
          id: 'onboard_3',
          name: 'Get Started',
          template: ScreenTemplate.onboarding,
        ),
      ];

      screens.addAll(onboardingScreens);

      for (int i = 0; i < onboardingScreens.length - 1; i++) {
        interactions.add(GeneratedInteraction(
          fromScreenId: onboardingScreens[i].id,
          toScreenId: onboardingScreens[i + 1].id,
          triggerElementId: 'next_button',
          transition: const TransitionConfig(
            type: TransitionType.slideIn,
            direction: TransitionDirection.left,
          ),
        ));
      }
    }

    if (promptLower.contains('profile') || promptLower.contains('settings')) {
      if (!screens.any((s) => s.template == ScreenTemplate.home)) {
        screens.add(const GeneratedScreen(
          id: 'home',
          name: 'Home',
          template: ScreenTemplate.home,
        ));
      }

      screens.add(const GeneratedScreen(
        id: 'profile',
        name: 'Profile',
        template: ScreenTemplate.profile,
      ));
      screens.add(const GeneratedScreen(
        id: 'settings',
        name: 'Settings',
        template: ScreenTemplate.settings,
      ));

      interactions.add(const GeneratedInteraction(
        fromScreenId: 'home',
        toScreenId: 'profile',
        triggerElementId: 'profile_tab',
      ));
      interactions.add(const GeneratedInteraction(
        fromScreenId: 'profile',
        toScreenId: 'settings',
        triggerElementId: 'settings_button',
      ));
    }

    if (promptLower.contains('list') && promptLower.contains('detail')) {
      screens.addAll([
        const GeneratedScreen(
          id: 'list',
          name: 'List View',
          template: ScreenTemplate.list,
        ),
        const GeneratedScreen(
          id: 'detail',
          name: 'Detail View',
          template: ScreenTemplate.detail,
        ),
      ]);

      interactions.add(const GeneratedInteraction(
        fromScreenId: 'list',
        toScreenId: 'detail',
        triggerElementId: 'list_item',
        transition: TransitionConfig(
          type: TransitionType.push,
          direction: TransitionDirection.left,
        ),
      ));
    }

    // If no screens were generated, create a basic flow
    if (screens.isEmpty) {
      screens.addAll([
        const GeneratedScreen(
          id: 'screen_1',
          name: 'Screen 1',
          template: ScreenTemplate.blank,
        ),
        const GeneratedScreen(
          id: 'screen_2',
          name: 'Screen 2',
          template: ScreenTemplate.blank,
        ),
      ]);

      interactions.add(const GeneratedInteraction(
        fromScreenId: 'screen_1',
        toScreenId: 'screen_2',
        triggerElementId: 'button',
      ));
    }

    return GeneratedFlow(
      id: 'generated_flow_${DateTime.now().millisecondsSinceEpoch}',
      name: _generateFlowName(prompt),
      screens: screens,
      interactions: interactions,
    );
  }

  String _generateFlowName(String prompt) {
    final words = prompt.split(' ').take(3).join(' ');
    return '${words.substring(0, words.length.clamp(0, 20))} Flow';
  }
}

/// AI Prototyping Panel
class AIPrototypingPanel extends StatefulWidget {
  final void Function(GeneratedFlow) onFlowGenerated;
  final void Function(AISuggestion) onSuggestionApplied;

  const AIPrototypingPanel({
    super.key,
    required this.onFlowGenerated,
    required this.onSuggestionApplied,
  });

  @override
  State<AIPrototypingPanel> createState() => _AIPrototypingPanelState();
}

class _AIPrototypingPanelState extends State<AIPrototypingPanel> {
  final TextEditingController _promptController = TextEditingController();
  final AIPrototypingEngine _engine = AIPrototypingEngine();
  GeneratedFlow? _generatedFlow;
  List<AISuggestion> _suggestions = [];
  bool _isGenerating = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generateFlow() async {
    if (_promptController.text.trim().isEmpty) return;

    setState(() => _isGenerating = true);

    final flow = await _engine.generateFromPrompt(_promptController.text);

    setState(() {
      _isGenerating = false;
      _generatedFlow = flow;
    });

    if (flow != null) {
      widget.onFlowGenerated(flow);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[700]!, Colors.blue[700]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'AI Prototyping',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Prompt input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Describe your prototype',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _promptController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'e.g., "Create a login flow with signup and forgot password"',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateFlow,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: Text(_isGenerating ? 'Generating...' : 'Generate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick templates
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Templates',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTemplateChip('Login Flow'),
                    _buildTemplateChip('Onboarding'),
                    _buildTemplateChip('E-commerce'),
                    _buildTemplateChip('Social App'),
                    _buildTemplateChip('Settings'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.grey),

          // Generated flow preview
          if (_generatedFlow != null) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Generated: ${_generatedFlow!.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_generatedFlow!.screens.length} screens, '
                    '${_generatedFlow!.interactions.length} interactions',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  // Screen list
                  ...(_generatedFlow!.screens.map((screen) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _getTemplateIcon(screen.template),
                              color: Colors.grey[400],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              screen.name,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ))),
                ],
              ),
            ),
          ],

          // Suggestions
          if (_suggestions.isNotEmpty) ...[
            const Divider(height: 1, color: Colors.grey),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Suggestions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._suggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateChip(String label) {
    return InkWell(
      onTap: () {
        _promptController.text = label;
        _generateFlow();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.grey[300], fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(AISuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSuggestionIcon(suggestion.type),
                color: Colors.amber,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${(suggestion.confidence * 100).round()}%',
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            suggestion.description,
            style: TextStyle(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => widget.onSuggestionApplied(suggestion),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text('Apply', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTemplateIcon(ScreenTemplate template) {
    switch (template) {
      case ScreenTemplate.login:
        return Icons.login;
      case ScreenTemplate.signup:
        return Icons.person_add;
      case ScreenTemplate.home:
        return Icons.home;
      case ScreenTemplate.profile:
        return Icons.person;
      case ScreenTemplate.settings:
        return Icons.settings;
      case ScreenTemplate.list:
        return Icons.list;
      case ScreenTemplate.detail:
        return Icons.article;
      case ScreenTemplate.form:
        return Icons.edit_note;
      case ScreenTemplate.success:
        return Icons.check_circle;
      case ScreenTemplate.error:
        return Icons.error;
      case ScreenTemplate.onboarding:
        return Icons.swipe;
      case ScreenTemplate.splash:
        return Icons.flash_on;
      case ScreenTemplate.modal:
        return Icons.web_asset;
      case ScreenTemplate.blank:
        return Icons.crop_square;
    }
  }

  IconData _getSuggestionIcon(AISuggestionType type) {
    switch (type) {
      case AISuggestionType.addInteraction:
        return Icons.touch_app;
      case AISuggestionType.addScreen:
        return Icons.add_box;
      case AISuggestionType.addNavigation:
        return Icons.navigation;
      case AISuggestionType.addOverlay:
        return Icons.layers;
      case AISuggestionType.fixUsability:
        return Icons.accessibility;
      case AISuggestionType.addBackButton:
        return Icons.arrow_back;
      case AISuggestionType.improveFlow:
        return Icons.auto_fix_high;
    }
  }
}
