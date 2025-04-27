import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final Function() onJoin;
  final Function() onLeave;
  
  const EventCard({
    super.key,
    required this.event,
    required this.onJoin,
    required this.onLeave,
  });

  bool get isCreator {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && event['createdBy'] == currentUser.uid;
  }

  bool get isParticipant {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;
    
    List<dynamic>? participants = event['participants'];
    return participants != null && participants.contains(currentUser.uid);
  }

  bool get isFull {
    final int peopleNeeded = event['peopleNeeded'] ?? 0;
    final List<dynamic>? participants = event['participants'];
    return participants != null && participants.length >= peopleNeeded;
  }

  int get spotsLeft {
    final int peopleNeeded = event['peopleNeeded'] ?? 0;
    final List<dynamic>? participants = event['participants'];
    if (participants == null) return peopleNeeded;
    return peopleNeeded - participants.length;
  }

  String get timeUntil {
    final Timestamp timestamp = event['datetime'];
    final DateTime eventTime = timestamp.toDate();
    final Duration difference = eventTime.difference(DateTime.now());
    
    if (difference.isNegative) {
      return 'Ended';
    }
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return '${difference.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime eventTime = (event['datetime'] as Timestamp).toDate();
    final String formattedDate = DateFormat('MMM d, y').format(eventTime);
    final String formattedTime = DateFormat('h:mm a').format(eventTime);
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with event name and creator info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4E96CC),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        event['name'] ?? 'Unnamed Event',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timeUntil,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Created by ${event['creatorName'] ?? 'Anonymous'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          // Event details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date and time info
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Participants info
                Row(
                  children: [
                    const Icon(Icons.people, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: '${(event['participants'] as List<dynamic>?)?.length ?? 0}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: ' of ${event['peopleNeeded'] ?? 0} participants'),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Progress bar
                const SizedBox(height: 8),
                _buildProgressBar(),
                
                // Join or leave button
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _buildActionButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressBar() {
    final int peopleNeeded = event['peopleNeeded'] ?? 0;
    final List<dynamic>? participants = event['participants'];
    final int currentParticipants = participants?.length ?? 0;
    final double progress = peopleNeeded > 0 ? currentParticipants / peopleNeeded : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            color: progress >= 1.0 
                ? Colors.green
                : progress >= 0.5 
                    ? const Color(0xFFFFE260) 
                    : const Color(0xFF4E96CC),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isFull 
              ? 'All spots filled!'
              : '$spotsLeft ${spotsLeft == 1 ? 'spot' : 'spots'} left',
          style: TextStyle(
            fontSize: 12,
            color: isFull ? Colors.green : Colors.grey.shade600,
            fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton() {
    if (isCreator) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.edit),
        label: const Text('YOU CREATED THIS'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey.shade700,
          side: BorderSide(color: Colors.grey.shade400),
        ),
        onPressed: null,
      );
    } else if (isParticipant) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('LEAVE EVENT'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade100,
          foregroundColor: Colors.red.shade700,
        ),
        onPressed: onLeave,
      );
    } else if (isFull) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.people),
        label: const Text('EVENT FULL'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          foregroundColor: Colors.grey.shade700,
        ),
        onPressed: null,
      );
    } else {
      return ElevatedButton.icon(
        icon: const Icon(Icons.add_circle),
        label: const Text('JOIN EVENT'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFE260),
          foregroundColor: Colors.black87,
        ),
        onPressed: onJoin,
      );
    }
  }
} 