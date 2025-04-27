import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyEventsTab extends StatefulWidget {
  const MyEventsTab({super.key});

  @override
  _MyEventsTabState createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<MyEventsTab> {
  final _database = FirebaseDatabase.instance.ref();
  final List<Map<String, dynamic>> _myEvents = [];
  bool _isLoading = true;
  StreamSubscription? _userEventsSubscription;
  final Set<String> _expandedEvents = {};
  
  // Color constants
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color backgroundColor = Color(0xFFFCFCFC);
  static const Color textColor = Colors.black87;
  static const Color lightGray = Color(0xFFEEEEEE);

  @override
  void initState() {
    super.initState();
    _loadUserEvents();
  }

  void _loadUserEvents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _myEvents.clear();
    });

    try {
      // Get all events from database first
      final allEventsSnapshot = await _database.child('events').get();
      if (!allEventsSnapshot.exists || !mounted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final uid = user.uid;
      final allEvents = allEventsSnapshot.value as Map<dynamic, dynamic>?;
      
      if (allEvents == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Filter events that belong to the current user
      final List<Map<String, dynamic>> userEvents = [];
      
      allEvents.forEach((key, value) {
        if (value != null && value is Map) {
          final event = Map<String, dynamic>.from(value as Map);
          event['key'] = key;
          
          // Check if this event belongs to the current user
          if (event['ownerUid'] == uid) {
            // Only include future events
            final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
            final now = DateTime.now().millisecondsSinceEpoch;
            if (eventTime > now) {
              userEvents.add(event);
            }
          }
        }
      });

      // Sort by event time
      userEvents.sort((a, b) => (int.parse(a['eventTime'].toString()))
          .compareTo(int.parse(b['eventTime'].toString())));

      if (mounted) {
        setState(() {
          _myEvents.clear();
          _myEvents.addAll(userEvents);
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error loading user events: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    
    // Set up subscription for real-time updates
    _userEventsSubscription = _database
        .child('events')
        .onChildChanged
        .listen(_onEventChanged);
  }
  
  void _onEventChanged(DatabaseEvent event) {
    if (!mounted) return;
    
    try {
      final eventData = event.snapshot.value as Map<dynamic, dynamic>?;
      final key = event.snapshot.key;
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (eventData != null && key != null && currentUser != null) {
        final updatedEvent = Map<String, dynamic>.from(eventData);
        updatedEvent['key'] = key;
        
        // Check if this is the user's event
        if (updatedEvent['ownerUid'] == currentUser.uid) {
          final eventTime = int.tryParse(updatedEvent['eventTime'].toString()) ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          
          if (eventTime > now) {
            // Update the event in our list
            setState(() {
              final index = _myEvents.indexWhere((e) => e['key'] == key);
              if (index != -1) {
                _myEvents[index] = updatedEvent;
              } else {
                _myEvents.add(updatedEvent);
                _myEvents.sort((a, b) => (a['eventTime'] as int).compareTo(b['eventTime'] as int));
              }
            });
          } else {
            // Remove expired event
            setState(() {
              _myEvents.removeWhere((e) => e['key'] == key);
            });
          }
        }
      }
    } catch (error) {
      print('Error handling event change: $error');
    }
  }

  @override
  void dispose() {
    _userEventsSubscription?.cancel();
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
            'MY EVENTS',
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Events you have created',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _myEvents.isEmpty
                    ? const Center(
                        child: Text(
                          'You haven\'t created any events yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _myEvents.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(_myEvents[index]);
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
    final key = event['key'];
    final expanded = _expandedEvents.contains(key);

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
                    child: const Icon(Icons.event, color: primaryBlue),
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
                  Material(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.red.withOpacity(0.1),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _deleteEvent(event),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.delete, color: Colors.red, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${event['peopleCount']} people needed',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
              _buildSignupsSection(event),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupsSection(Map<String, dynamic> event) {
    final key = event['key'];
    final expanded = _expandedEvents.contains(key);
    final signups = List<String>.from(event['signups'] ?? []);

    return Container(
      decoration: BoxDecoration(
        color: lightGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedEvents.remove(key);
                } else {
                  _expandedEvents.add(key);
                }
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Signups',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: primaryBlue,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: signups.isEmpty
                    ? [const Text('No signups yet', style: TextStyle(fontStyle: FontStyle.italic))]
                    : signups.map((signup) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 16, color: primaryBlue),
                            const SizedBox(width: 4),
                            Text(signup),
                          ],
                        ),
                      )).toList(),
              ),
            ),
        ],
      ),
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

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: primaryBlue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final uid = FirebaseAuth.instance.currentUser?.uid;
              final eventId = event['eventId'];
              final eventKey = event['key'];

              if (uid != null && eventId != null) {
                // Remove from user's created events
                await _database.child('users/$uid/createdEvents/$eventId').remove();
                
                // Remove from database
                await _database.child('events/$eventKey').remove();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 