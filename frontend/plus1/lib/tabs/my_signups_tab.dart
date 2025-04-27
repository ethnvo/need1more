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

class _MySignupsTabState extends State<MySignupsTab> with SingleTickerProviderStateMixin {
  final _database = FirebaseDatabase.instance.ref();
  final List<Map<String, dynamic>> _activeSignupEvents = [];
  final List<Map<String, dynamic>> _pastSignupEvents = [];
  bool _isLoading = true;
  StreamSubscription? _userSignupsSubscription;
  late TabController _tabController;
  
  // Color constants
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);
  static const Color backgroundColor = Color(0xFFFCFCFC);
  static const Color textColor = Colors.black87;
  static const Color lightGray = Color(0xFFEEEEEE);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserSignups();
  }

  Future<void> _loadUserSignups() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _activeSignupEvents.clear();
      _pastSignupEvents.clear();
    });

    try {
      // Get user's signups
      final userSignupsSnapshot = await _database.child('users/${user.uid}/signups').get();
      
      if (!userSignupsSnapshot.exists || !mounted) {
        setState(() => _isLoading = false);
        return;
      }
      
      final signupsData = userSignupsSnapshot.value as Map<dynamic, dynamic>?;
      if (signupsData == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      // Create a list of event IDs to fetch
      final List<String> eventIds = signupsData.keys.cast<String>().toList();
      
      // Check active events
      final activeEvents = await _fetchEventsFromNode('events', eventIds);
      
      // Check history events
      final pastEvents = await _fetchEventsFromNode('event_history', eventIds);
      
      if (mounted) {
        setState(() {
          _activeSignupEvents.clear();
          _activeSignupEvents.addAll(activeEvents);
          _pastSignupEvents.clear();
          _pastSignupEvents.addAll(pastEvents);
          _isLoading = false;
        });
      }
      
      // Set up real-time listener for changes to signups
      _setupSignupListener(user.uid);
    } catch (e) {
      print('Error loading signups: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading signups: $e')),
        );
      }
    }
  }
  
  Future<List<Map<String, dynamic>>> _fetchEventsFromNode(String nodeName, List<String> eventIds) async {
    final List<Map<String, dynamic>> events = [];
    final now = DateTime.now().millisecondsSinceEpoch;
    
    try {
      final eventsSnapshot = await _database.child(nodeName).get();
      if (!eventsSnapshot.exists) return [];
      
      final eventsData = eventsSnapshot.value as Map<dynamic, dynamic>?;
      if (eventsData == null) return [];
      
      eventsData.forEach((key, value) {
        if (value != null && value is Map) {
          final event = Map<String, dynamic>.from(value as Map);
          final eventId = event['eventId'];
          
          // Check if this event is one the user signed up for
          if (eventId != null && eventIds.contains(eventId)) {
            event['key'] = key;
            
            if (nodeName == 'events') {
              // For active events, only include those in the future
              final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
              if (eventTime > now) {
                events.add(event);
              }
            } else {
              // For history events, include all
              events.add(event);
            }
          }
        }
      });
      
      // Sort the events
      if (nodeName == 'events') {
        // Sort active events by upcoming time
        events.sort((a, b) => (int.parse(a['eventTime'].toString()))
            .compareTo(int.parse(b['eventTime'].toString())));
      } else {
        // Sort history events with most recent first
        events.sort((a, b) => (int.parse(b['eventTime'].toString()))
            .compareTo(int.parse(a['eventTime'].toString())));
      }
      
      return events;
    } catch (e) {
      print('Error fetching events from $nodeName: $e');
      return [];
    }
  }
  
  void _setupSignupListener(String uid) {
    // Cancel previous subscription if exists
    _userSignupsSubscription?.cancel();
    
    // Set up new subscription
    _userSignupsSubscription = _database
        .child('users/$uid/signups')
        .onValue
        .listen((event) {
      // Reload all data when signups change
      _loadUserSignups();
    }, onError: (error) {
      print('Error in signup listener: $error');
    });
  }

  @override
  void dispose() {
    _userSignupsSubscription?.cancel();
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
                    child: Text('UPCOMING', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                Tab(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('HISTORY', style: TextStyle(fontWeight: FontWeight.bold)),
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
                // Upcoming events tab
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activeSignupEvents.isEmpty
                        ? _buildEmptyState('You haven\'t joined any upcoming events')
                        : RefreshIndicator(
                            onRefresh: _loadUserSignups,
                            child: ListView.builder(
                              itemCount: _activeSignupEvents.length,
                              itemBuilder: (context, index) {
                                return _buildEventCard(_activeSignupEvents[index], isHistory: false);
                              },
                            ),
                          ),
                
                // Past events tab
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _pastSignupEvents.isEmpty
                        ? _buildEmptyState('No past events found')
                        : RefreshIndicator(
                            onRefresh: _loadUserSignups,
                            child: ListView.builder(
                              itemCount: _pastSignupEvents.length,
                              itemBuilder: (context, index) {
                                return _buildEventCard(_pastSignupEvents[index], isHistory: true);
                              },
                            ),
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

  Widget _buildEventCard(Map<String, dynamic> event, {required bool isHistory}) {
    final eventTime = int.tryParse(event['eventTime'].toString()) ?? 0;
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(eventTime));
    final isStartingSoon = !isHistory &&
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
            colors: isHistory 
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
                      isHistory ? Icons.history : Icons.group,
                      color: primaryBlue,
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
                          isHistory ? 'Was at: $formattedTime' : 'At: $formattedTime',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  isHistory
                      ? ElevatedButton(
                          onPressed: () => _removeFromHistory(event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.withOpacity(0.1),
                            foregroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Remove'),
                        )
                      : ElevatedButton(
                          onPressed: () => _leaveEvent(event),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.1),
                            foregroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Leave'),
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
          return Container(
            height: 20, 
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightGray.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: primaryBlue,
                ),
              ),
            ),
          );
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

  Future<void> _leaveEvent(Map<String, dynamic> event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventId = event['eventId'];
    final eventKey = event['key'];
    final uid = user.uid;
    
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Event?'),
        content: const Text('Are you sure you want to leave this event?'),
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
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You have left the event'),
                      backgroundColor: primaryBlue,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _removeFromHistory(Map<String, dynamic> event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final eventId = event['eventId'];
    final uid = user.uid;
    
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from History?'),
        content: const Text('This event will be removed from your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: primaryBlue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                // Remove from user's signups
                await _database.child('users/$uid/signups/$eventId').remove();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Event removed from history'),
                      backgroundColor: primaryBlue,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 