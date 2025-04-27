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

class _MyEventsTabState extends State<MyEventsTab> with SingleTickerProviderStateMixin {
  final _database = FirebaseDatabase.instance.ref();
  final List<Map<String, dynamic>> _activeEvents = [];
  final List<Map<String, dynamic>> _pastEvents = [];
  bool _isLoading = true;
  StreamSubscription? _userEventsSubscription;
  final Set<String> _expandedEvents = {};
  late TabController _tabController;
  
  // Color constants
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);
  static const Color backgroundColor = Color(0xFFFCFCFC);
  static const Color textColor = Color(0xFF212121);
  static const Color lightGray = Color(0xFFEEEEEE);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserEvents();
  }

  void _loadUserEvents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _activeEvents.clear();
      _pastEvents.clear();
    });

    try {
      final uid = user.uid;
      
      // Get user's created events
      final userEventsSnapshot = await _database.child('users/$uid/createdEvents').get();
      if (!userEventsSnapshot.exists || !mounted) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final createdEventsData = userEventsSnapshot.value as Map<dynamic, dynamic>?;
      if (createdEventsData == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get active events
      final activeEventsSnapshot = await _database.child('events').get();
      if (activeEventsSnapshot.exists) {
        final allActiveEvents = activeEventsSnapshot.value as Map<dynamic, dynamic>?;
        
        if (allActiveEvents != null) {
          // Filter active events that belong to the current user
          allActiveEvents.forEach((key, value) {
            if (value != null && value is Map) {
              final event = Map<String, dynamic>.from(value as Map);
              final eventId = event['eventId'];
              
              // Check if this event belongs to the current user
              if (event['ownerUid'] == uid && createdEventsData.containsKey(eventId)) {
                event['key'] = key;
                _activeEvents.add(event);
              }
            }
          });
          
          // Sort active events by time
          _activeEvents.sort((a, b) => (int.parse(a['eventTime'].toString()))
              .compareTo(int.parse(b['eventTime'].toString())));
        }
      }
      
      // Get historical events
      final historyEventsSnapshot = await _database.child('event_history').get();
      if (historyEventsSnapshot.exists) {
        final allHistoryEvents = historyEventsSnapshot.value as Map<dynamic, dynamic>?;
        
        if (allHistoryEvents != null) {
          // Filter history events that belong to the current user
          allHistoryEvents.forEach((key, value) {
            if (value != null && value is Map) {
              final event = Map<String, dynamic>.from(value as Map);
              
              // Check if this event belongs to the current user
              if (event['ownerUid'] == uid) {
                event['key'] = key;
                _pastEvents.add(event);
              }
            }
          });
          
          // Sort past events by time (most recent first)
          _pastEvents.sort((a, b) => (int.parse(b['eventTime'].toString()))
              .compareTo(int.parse(a['eventTime'].toString())));
        }
      }

      if (mounted) {
        setState(() {
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
              final index = _activeEvents.indexWhere((e) => e['key'] == key);
              if (index != -1) {
                _activeEvents[index] = updatedEvent;
              } else {
                _activeEvents.add(updatedEvent);
                _activeEvents.sort((a, b) => (a['eventTime'] as int).compareTo(b['eventTime'] as int));
              }
            });
          } else {
            // Remove expired event
            setState(() {
              _activeEvents.removeWhere((e) => e['key'] == key);
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
    _tabController.dispose();
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
          const SizedBox(height: 16),
          // Tab bar for Upcoming and Past events
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: primaryBlue,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: primaryBlue,
              ),
              tabs: const [
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('ACTIVE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('PAST', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Active events tab
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activeEvents.isEmpty
                        ? _buildEmptyState('You haven\'t created any active events')
                        : ListView.builder(
                            itemCount: _activeEvents.length,
                            itemBuilder: (context, index) {
                              return _buildEventCard(_activeEvents[index], isPast: false);
                            },
                          ),
                          
                // Past events tab
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _pastEvents.isEmpty
                        ? _buildEmptyState('No past events found')
                        : ListView.builder(
                            itemCount: _pastEvents.length,
                            itemBuilder: (context, index) {
                              return _buildEventCard(_pastEvents[index], isPast: true);
                            },
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: accentYellow.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy,
              size: 48,
              color: primaryBlue.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, {required bool isPast}) {
    final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(eventTime));
    final isStartingSoon = !isPast &&
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
            colors: isPast 
                ? [Colors.white, Colors.grey.shade200]
                : [Colors.white, lightGray],
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
                    child: Icon(
                      isPast ? Icons.history : Icons.event,
                      color: primaryBlue
                    ),
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
                          isPast ? 'Was at: $formattedTime' : 'At: $formattedTime',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  isPast
                      ? Material(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey.withOpacity(0.1),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _removeFromHistory(event),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                            ),
                          ),
                        )
                      : Material(
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
                  isPast
                      ? 'People needed: ${event['peopleCount']}'
                      : '${event['peopleCount']} people needed',
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
                  Text(
                    signups.isEmpty ? 'No signups' : 'Signups (${signups.length})',
                    style: const TextStyle(
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
                try {
                  // Remove from active events and move to history
                  await _database.child('events/$eventKey').get().then((snapshot) {
                    if (snapshot.exists) {
                      // Get data to save to history
                      final data = Map<String, dynamic>.from(snapshot.value as Map);
                      
                      // Add to history
                      _database.child('event_history').push().set(data);
                      
                      // Delete from active events
                      _database.child('events/$eventKey').remove();
                    }
                  });
                  
                  // Remove from user's created events
                  await _database.child('users/$uid/createdEvents/$eventId').remove();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event deleted and moved to history'),
                      backgroundColor: primaryBlue,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _removeFromHistory(Map<String, dynamic> event) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from History?'),
        content: const Text('This event will be permanently removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: primaryBlue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final eventKey = event['key'];

              try {
                // Delete from history
                await _database.child('event_history/$eventKey').remove();
                
                setState(() {
                  _pastEvents.removeWhere((e) => e['key'] == eventKey);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Event removed from history'),
                    backgroundColor: primaryBlue,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 