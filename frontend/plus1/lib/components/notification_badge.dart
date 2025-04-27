import 'package:flutter/material.dart';
import 'package:plus1/utils/event_notifications.dart';
import 'package:plus1/components/notification_view.dart';

class NotificationBadge extends StatelessWidget {
  final int count;
  final Color color;
  final Color textColor;
  final Widget child;
  
  const NotificationBadge({
    super.key,
    required this.count,
    required this.child,
    this.color = const Color(0xFFFFE260), // Default accent yellow
    this.textColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return child;
    }
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -5,
          top: -5,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Center(
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 