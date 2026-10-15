import 'package:flutter/material.dart';

class IconMapper {
  static IconData getIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'cpu':
        return Icons.memory;
      case 'radio':
        return Icons.radar;
      case 'terminal':
      case 'code-2':
      case 'code':
        return Icons.terminal;
      case 'book-open':
      case 'book':
        return Icons.menu_book;
      case 'bookmark':
        return Icons.bookmark_border;
      case 'globe':
        return Icons.language;
      case 'languages':
        return Icons.translate;
      case 'film':
        return Icons.movie;
      case 'layout':
        return Icons.dashboard_customize;
      case 'pen-tool':
      case 'pen':
        return Icons.edit_note;
      case 'activity':
      case 'heart':
      case 'fitness':
        return Icons.fitness_center;
      case 'graduation-cap':
        return Icons.school;
      case 'lock':
        return Icons.lock_outline;
      case 'droplets':
      case 'water_drop':
        return Icons.water_drop;
      default:
        return Icons.timelapse;
    }
  }
}
