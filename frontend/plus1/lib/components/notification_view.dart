import 'package:flutter/material.dart';
import 'package:plus1/utils/event_notifications.dart';
import 'package:intl/intl.dart';

class NotificationView extends StatefulWidget {
  const NotificationView({Key? key}) : super(key: key);

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView> {
  final _notificationService = EventNotificationService();
  
  static const Color primaryBlue = Color(0xFF4E96CC);
  static const Color accentYellow = Color(0xFFFFE260);
  static const Color backgroundColor = Color(0xFFFCFCFC);
  static const Color lightGray = Color(0xFFEEEEEE);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationService.getUserNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }
        
        final notifications = snapshot.data!;
        
        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }
  
  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['read'] == true;
    final eventName = notification['eventName'] ?? 'Event';
    final timestamp = notification['timestamp'] as int? ?? 0;
    final formattedDate = DateFormat('MMM d, yyyy - h:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: isRead ? 2 : 4,
      color: isRead ? Colors.white : Colors.white,
      child: InkWell(
        onTap: () {
          _showContactDetails(notification);
          _markAsRead(notification);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isRead 
                ? null 
                : Border.all(color: primaryBlue.withOpacity(0.5), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isRead 
                            ? primaryBlue.withOpacity(0.1)
                            : primaryBlue.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_alt,
                        color: primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Info for "$eventName"',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isRead ? Colors.black87 : primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'View contact information for all participants',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Tap to view',
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showContactDetails(Map<String, dynamic> notification) {
    final contacts = List<Map<String, dynamic>>.from(notification['contactList'] ?? []);
    final eventName = notification['eventName'] ?? 'Event';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contact Info for "$eventName"'),
        content: SizedBox(
          width: double.maxFinite,
          child: contacts.isEmpty
              ? const Text('No contact information available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final name = contact['displayName'] ?? 'User';
                    final email = contact['email'] ?? 'No email';
                    final phone = contact['phone'] ?? 'No phone';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: lightGray.withOpacity(0.3),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.email, size: 16, color: primaryBlue),
                                const SizedBox(width: 8),
                                Expanded(child: Text(email)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 16, color: primaryBlue),
                                const SizedBox(width: 8),
                                Text(phone),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _markAsRead(Map<String, dynamic> notification) {
    if (notification['read'] != true) {
      final notificationKey = notification['key'] as String?;
      if (notificationKey != null) {
        _notificationService.markNotificationAsRead(notificationKey);
      }
    }
  }
} 