import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MySignupsTab extends StatefulWidget {
  const MySignupsTab({super.key});

  @override
  _MySignupsTabState createState() => _MySignupsTabState();
}

class _MySignupsTabState extends State<MySignupsTab> {
  final _database = FirebaseDatabase.instance.ref();
  final List<Map<String, dynamic>> _signupEvents = [];
  bool _isLoading = true;
  StreamSubscription? _userSignupsSubscription;
  
  // Color constants
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color backgroundColor = Color(0xFFFCFCFC);
  static const Color textColor = Colors.black87;
  static const Color lightGray = Color(0xFFEEEEEE);

  @override
  void initState() {
    super.initState();
    _loadUserSignups();
  }

  void _loadUserSignups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _signupEvents.clear();
    });

    // Get all events the user signed up for
    _userSignupsSubscription = _database
        .child('users/${user.uid}/signups')
        .onValue
        .listen((event) async {
      final signupsData = event.snapshot.value as Map<dynamic, dynamic>?;
      
      if (signupsData == null || !mounted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch the actual event data for each signup
      List<Map<String, dynamic>> events = [];
      
      final allEventsSnapshot = await _database.child('events').get();
      if (!allEventsSnapshot.exists || !mounted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final allEvents = allEventsSnapshot.value as Map<dynamic, dynamic>?;
      if (allEvents != null) {
        allEvents.forEach((key, value) {
          final event = Map<String, dynamic>.from(value as Map);
          final eventId = event['eventId'];
          
          // Check if this event is one that the user signed up for
          if (eventId != null && signupsData.containsKey(eventId)) {
            event['key'] = key;
            
            // Only include future events
            final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
            final now = DateTime.now().millisecondsSinceEpoch;
            if (eventTime > now) {
              events.add(event);
            }
          }
        });

        // Sort by event time
        events.sort((a, b) => (int.parse(a['eventTime'].toString()))
            .compareTo(int.parse(b['eventTime'].toString())));
      }

      if (mounted) {
        setState(() {
          _signupEvents.addAll(events);
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _userSignupsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MY SIGNUPS',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Events you have joined',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _signupEvents.isEmpty
                    ? const Center(
                        child: Text(
                          'You haven\'t joined any events yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _signupEvents.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(_signupEvents[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(eventTime));
    final isStartingSoon =
        eventTime - DateTime.now().millisecondsSinceEpoch <= 10 * 60 * 1000;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, lightGray],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.group, color: primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['eventName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'At: $formattedTime',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _cancelSignup(event),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
              if (isStartingSoon)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        _buildCountdownText(eventTime),
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _buildOwnerInfoSection(event),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerInfoSection(Map<String, dynamic> event) {
    final ownerUid = event['ownerUid'];
    
    return FutureBuilder<DataSnapshot>(
      future: _database.child('users/$ownerUid').get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 20, child: Center(child: LinearProgressIndicator()));
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Owner information not available');
        }
        
        final userData = snapshot.data!.value as Map;
        final email = userData['email'] ?? 'No email';
        final phone = userData['phone'] ?? 'No phone';
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: lightGray.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Event Owner:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.email, size: 16, color: primaryBlue),
                  const SizedBox(width: 8),
                  Text(email.toString()),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: primaryBlue),
                  const SizedBox(width: 8),
                  Text(phone.toString()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildCountdownText(int eventTime) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = eventTime - now;

    if (diffMs <= 0) {
      return "Starting Now!";
    } else {
      final minutes = (diffMs ~/ 60000).toString().padLeft(2, '0');
      final seconds = ((diffMs % 60000) ~/ 1000).toString().padLeft(2, '0');
      return "Starting Soon: $minutes:$seconds";
    }
  }

  Future<void> _cancelSignup(Map<String, dynamic> event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventId = event['eventId'];
    final eventKey = event['key'];
    final uid = user.uid;
    
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Signup?'),
        content: const Text('Are you sure you want to cancel your signup for this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No', style: TextStyle(color: primaryBlue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                // Get current event data
                final eventRef = _database.child('events/$eventKey');
                final eventSnap = await eventRef.get();
                
                if (eventSnap.exists) {
                  final eventData = Map<String, dynamic>.from(eventSnap.value as Map);
                  final currentPeople = eventData['peopleCount'] ?? 0;
                  final signups = List<String>.from(eventData['signups'] ?? []);
                  
                  // Get user's display name
                  final displayName = user.displayName ?? user.email ?? 'Anonymous';
                  
                  // Remove from signups
                  signups.remove(displayName);
                  
                  // Update event
                  await eventRef.update({
                    'peopleCount': currentPeople + 1, // Increment people needed
                    'signups': signups,
                  });
                }
                
                // Remove from user's signups
                await _database.child('users/$uid/signups/$eventId').remove();
                
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 