import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EventNotificationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // Send notifications to all participants when someone joins an event
  Future<void> notifyParticipants(
    BuildContext context,
    Map<String, dynamic> event, 
    String newParticipantEmail, 
    String? newParticipantPhone
  ) async {
    final eventId = event['eventId'];
    final signups = List<String>.from(event['signups'] ?? []);
    final ownerUid = event['ownerUid'] as String?;
    
    if (eventId == null || ownerUid == null || signups.isEmpty) return;
    
    try {
      // First, update the event's notification data to include the new participant
      await _addParticipantInfo(event, newParticipantEmail, newParticipantPhone);
      
      // Then create notifications for all participants
      await _createParticipantNotifications(event);
    } catch (e) {
      print('Error sending notifications: $e');
    }
  }
  
  // Add participant contact info to the event data
  Future<void> _addParticipantInfo(
    Map<String, dynamic> event,
    String email,
    String? phone
  ) async {
    final eventKey = event['key'];
    if (eventKey == null) return;
    
    // Get current participants info
    final participantsInfo = Map<String, dynamic>.from(event['participantsInfo'] ?? {});
    
    // Add the new participant's info
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final userKey = currentUser.uid;
    participantsInfo[userKey] = {
      'email': email,
      'phone': phone,
      'displayName': currentUser.displayName,
    };
    
    // Update the event with the new participant info
    await _database.ref().child('events/$eventKey/participantsInfo').set(participantsInfo);
  }
  
  // Create notifications for all participants
  Future<void> _createParticipantNotifications(Map<String, dynamic> event) async {
    final eventId = event['eventId'];
    final eventKey = event['key'];
    final eventName = event['eventName'];
    final participantsInfo = Map<String, dynamic>.from(event['participantsInfo'] ?? {});
    
    if (eventId == null || eventKey == null || participantsInfo.isEmpty) return;
    
    // Generate the participant list
    final List<Map<String, dynamic>> contactList = [];
    participantsInfo.forEach((uid, info) {
      if (info is Map) {
        contactList.add(Map<String, dynamic>.from(info as Map));
      }
    });
    
    // Create notification for each participant
    for (final uid in participantsInfo.keys) {
      final notificationData = {
        'eventId': eventId,
        'eventName': eventName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'contactShare',
        'contactList': contactList,
        'read': false,
      };
      
      await _database.ref().child('users/$uid/notifications').push().set(notificationData);
    }
  }
  
  // Get notifications for the current user
  Stream<List<Map<String, dynamic>>> getUserNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value([]);
    }
    
    return _database.ref().child('users/$uid/notifications').onValue.map((event) {
      if (!event.snapshot.exists) return [];
      
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return [];
      
      List<Map<String, dynamic>> notifications = [];
      data.forEach((key, value) {
        if (value is Map) {
          final notification = Map<String, dynamic>.from(value as Map);
          notification['key'] = key;
          notifications.add(notification);
        }
      });
      
      // Sort by timestamp (newest first)
      notifications.sort((a, b) => 
        (b['timestamp'] as int).compareTo(a['timestamp'] as int)
      );
      
      return notifications;
    });
  }
  
  // Mark a notification as read
  Future<void> markNotificationAsRead(String notificationKey) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || notificationKey.isEmpty) return;
    
    await _database.ref().child('users/$uid/notifications/$notificationKey/read').set(true);
  }
} 