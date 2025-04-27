import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plus1/home_screen.dart';

// Import the individual tab pages we'll create next
import 'tabs/events_board_tab.dart';
import 'tabs/my_signups_tab.dart';
import 'tabs/my_events_tab.dart';

class EventTabsScreen extends StatefulWidget {
  const EventTabsScreen({super.key});

  @override
  _EventTabsScreenState createState() => _EventTabsScreenState();
}

class _EventTabsScreenState extends State<EventTabsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);
  final ScrollController _eventsScrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _eventsScrollController.dispose();
    super.dispose();
  }
  
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: primaryBlue)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 3,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _scrollToTop() {
    if (_eventsScrollController.hasClients) {
      _eventsScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showCreateEventModal() {
    if (_tabController.index == 0) {
      final eventsTab = _tabController.index == 0 ? 
          EventsBoardTab(scrollController: _eventsScrollController) : null;
      
      if (eventsTab != null) {
        // Using context from our widget to show modal
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Create New Event',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: eventsTab,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        // Fall back to just scrolling to top if we can't show modal
        _scrollToTop();
      }
    } else {
      // Switch to first tab and then show modal
      _tabController.animateTo(0, duration: const Duration(milliseconds: 300));
      Future.delayed(const Duration(milliseconds: 350), _showCreateEventModal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Header with gradient background
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      primaryBlue.withOpacity(0.9),
                      primaryBlue,
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Yellow decorative patterns
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: accentYellow.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -20,
                      left: -20,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: accentYellow.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Dotted pattern
                    Positioned(
                      top: 20,
                      left: 60,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accentYellow.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 50,
                      right: 80,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentYellow.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.only(left: 25, top: 50, right: 25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: accentYellow,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'PLUS ONE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black26,
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  onPressed: _confirmLogout,
                                ),
                              ),
                            ],
                          ),
                          // Reduced height before TabBar to fix overflow
                          const SizedBox(height: 15),
                          SafeArea(
                            bottom: false,
                            child: TabBar(
                              controller: _tabController,
                              indicatorColor: accentYellow,
                              indicatorWeight: 3,
                              dividerColor: Colors.transparent,
                              labelColor: accentYellow,
                              unselectedLabelColor: Colors.white70,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontSize: 13,
                              ),
                              tabs: const [
                                Tab(text: 'EVENTS'),
                                Tab(text: 'MY SIGNUPS'),
                                Tab(text: 'MY EVENTS'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Main content area with tab views
            Positioned(
              top: 160,
              left: 0,
              right: 0,
              bottom: 0,
              child: TabBarView(
                controller: _tabController,
                children: [
                  EventsBoardTab(scrollController: _eventsScrollController),
                  const MySignupsTab(),
                  const MyEventsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 