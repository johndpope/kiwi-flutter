// Prototyping module barrel export
// Provides prototype interactions, player, editor, and advanced features

// Core interactions and player
export 'interactions.dart';
export 'prototype_player.dart';
export 'interaction_editor.dart';

// Conditional logic and variables
export 'conditional_logic.dart';

// Device preview with status bars and scrolling
export 'device_preview.dart';

// Media support (video, GIF)
export 'media_support.dart';

// AI-assisted prototyping
export 'ai_prototyping.dart';

// Web publishing (hide FlowConnection to avoid conflict with interaction_editor)
export 'web_publishing.dart' hide FlowConnection;
