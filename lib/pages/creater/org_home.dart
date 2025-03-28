import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'org_profile.dart';
import 'org_settings.dart';
import 'org_create_event.dart';
import 'org_edit_event.dart'; // Import the new edit page

class OrgHomePage extends StatefulWidget {
  final String profileImageUrl;
  final String displayName;
  final String email;

  const OrgHomePage({
    super.key,
    required this.profileImageUrl,
    required this.displayName,
    required this.email,
  });

  @override
  _OrgHomePageState createState() => _OrgHomePageState();
}

class _OrgHomePageState extends State<OrgHomePage> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  final List<Map<String, dynamic>> events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  void _fetchEvents() async {
    try {
      setState(() => _isLoading = true);
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('organizer', isEqualTo: widget.displayName)
          .orderBy('timestamp', descending: true)
          .get();
      setState(() {
        events.clear();
        events.addAll(snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch events: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _editEvent(Map<String, dynamic> event) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrgEditEventPage(event: event),
      ),
    );
    _fetchEvents(); // Refresh the event list after editing
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully!')),
        );
        _fetchEvents();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete event: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildEventList() {
    if (events.isEmpty) {
      return const Center(
        child: Text('No events found. Create your first event!'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: ListTile(
            leading: event['image'] != null
                ? Image.network(
                    event['image'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                  )
                : const Icon(Icons.event),
            title: Text(event['title'] ?? 'Untitled Event'),
            subtitle: Text(
              event['dateTime'] != null
                  ? DateTime.parse(event['dateTime']).toLocal().toString().split('.')[0]
                  : 'No date set',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _isLoading ? null : () => _editEvent(event),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _isLoading ? null : () => _deleteEvent(event['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async => _fetchEvents(),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildEventList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      OrgProfilePage(
        profileImageUrl: widget.profileImageUrl,
        displayName: widget.displayName,
        email: widget.email,
      ),
      OrgCreateEventPage(organizerName: widget.displayName),
      OrgSettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: _selectedIndex == 0
            ? Row(
                children: [
                  CircleAvatar(
                    backgroundImage: widget.profileImageUrl.isNotEmpty
                        ? NetworkImage(widget.profileImageUrl)
                        : null,
                    child: widget.profileImageUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Welcome, ${widget.displayName.split(' ')[0]}!',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(['Home', 'Profile', 'Create Event', 'Settings'][_selectedIndex]),
        backgroundColor: Colors.redAccent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          pages[_selectedIndex],
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrgCreateEventPage(
                            organizerName: widget.displayName,
                          ),
                        ),
                      );
                      _fetchEvents();
                    },
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}