/// Menu Bar State Management
///
/// Provides state management for menu bar open/close, hover, and keyboard navigation.

import 'package:flutter/foundation.dart';

/// State manager for the menu bar
class MenuBarState extends ChangeNotifier {
  String? _openMenuId;
  String? _hoveredItemId;
  int _hoveredIndex = -1;
  List<String> _currentMenuItemIds = [];

  /// Currently open menu section ID
  String? get openMenuId => _openMenuId;

  /// Currently hovered item ID (for keyboard navigation)
  String? get hoveredItemId => _hoveredItemId;

  /// Current hovered index in the menu
  int get hoveredIndex => _hoveredIndex;

  /// Whether any menu is currently open
  bool get isMenuOpen => _openMenuId != null;

  /// Opens a menu section
  void openMenu(String menuId) {
    if (_openMenuId != menuId) {
      _openMenuId = menuId;
      _hoveredItemId = null;
      _hoveredIndex = -1;
      _currentMenuItemIds = [];
      notifyListeners();
    }
  }

  /// Closes any open menu
  void closeMenu() {
    if (_openMenuId != null) {
      _openMenuId = null;
      _hoveredItemId = null;
      _hoveredIndex = -1;
      _currentMenuItemIds = [];
      notifyListeners();
    }
  }

  /// Sets the current menu item IDs for keyboard navigation
  void setMenuItems(List<String> itemIds) {
    _currentMenuItemIds = itemIds;
  }

  /// Hovers an item by ID
  void hoverItem(String? itemId) {
    if (_hoveredItemId != itemId) {
      _hoveredItemId = itemId;
      _hoveredIndex = itemId != null ? _currentMenuItemIds.indexOf(itemId) : -1;
      notifyListeners();
    }
  }

  /// Selects the next item (down arrow)
  void selectNext() {
    if (_currentMenuItemIds.isEmpty) return;

    if (_hoveredIndex < 0) {
      _hoveredIndex = 0;
    } else if (_hoveredIndex < _currentMenuItemIds.length - 1) {
      _hoveredIndex++;
    }

    _hoveredItemId = _currentMenuItemIds[_hoveredIndex];
    notifyListeners();
  }

  /// Selects the previous item (up arrow)
  void selectPrevious() {
    if (_currentMenuItemIds.isEmpty) return;

    if (_hoveredIndex < 0) {
      _hoveredIndex = _currentMenuItemIds.length - 1;
    } else if (_hoveredIndex > 0) {
      _hoveredIndex--;
    }

    _hoveredItemId = _currentMenuItemIds[_hoveredIndex];
    notifyListeners();
  }

  /// Selects first item
  void selectFirst() {
    if (_currentMenuItemIds.isEmpty) return;
    _hoveredIndex = 0;
    _hoveredItemId = _currentMenuItemIds[_hoveredIndex];
    notifyListeners();
  }

  /// Selects last item
  void selectLast() {
    if (_currentMenuItemIds.isEmpty) return;
    _hoveredIndex = _currentMenuItemIds.length - 1;
    _hoveredItemId = _currentMenuItemIds[_hoveredIndex];
    notifyListeners();
  }

  /// Toggle menu - opens if closed, closes if open
  void toggleMenu(String menuId) {
    if (_openMenuId == menuId) {
      closeMenu();
    } else {
      openMenu(menuId);
    }
  }
}
