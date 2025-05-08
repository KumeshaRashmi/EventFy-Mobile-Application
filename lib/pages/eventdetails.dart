import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lef_mob/pages/eventbooking/booking.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EventDetailsPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final Function(Map<String, dynamic>)? addFavorite;

  const EventDetailsPage({
    super.key,
    required this.event,
    this.addFavorite,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  bool isFavorited = false;
  bool isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? userId;
  late GoogleMapController _mapController;
  LatLng? _eventLocation;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    // Initialize event location from GeoPoint if available
    if (widget.event['location'] is GeoPoint) {
      final geoPoint = widget.event['location'] as GeoPoint;
      _eventLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
    } else if (widget.event['locationDisplay'] != null) {
      // Fallback to locationDisplay if it contains coordinates (e.g., "lat,lon")
      final parts = widget.event['locationDisplay'].toString().split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0]) ?? 0.0;
        final lon = double.tryParse(parts[1]) ?? 0.0;
        _eventLocation = LatLng(lat, lon);
      }
    }
  }

  Future<void> _initializeUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        await _checkIfFavorited();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _checkIfFavorited() async {
    if (userId == null) return;
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(widget.event['id'])
        .get();
    if (mounted) {
      setState(() {
        isFavorited = doc.exists;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to favorite events')),
      );
      return;
    }

    try {
      setState(() {
        isFavorited = !isFavorited;
      });

      if (isFavorited) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(widget.event['id'])
            .set(widget.event);
        widget.addFavorite?.call(widget.event);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${widget.event['title']} added to favorites!')),
          );
        }
      } else {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('favorites')
            .doc(widget.event['id'])
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${widget.event['title']} removed from favorites!')),
          );
        }
      }
    } catch (e) {
      setState(() {
        isFavorited = !isFavorited; // Revert state on error
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorite: $e')),
        );
      }
    }
  }

  Future<void> _addToCalendar() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add to calendar')),
      );
      return;
    }

    try {
      final eventDate = DateTime.parse(widget.event['dateTime']);
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('calendar_events')
          .add({
        'title': widget.event['title'],
        'location': widget.event['location'],
        'date': eventDate,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${widget.event['title']} added to calendar!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding to calendar: $e')),
        );
      }
    }
  }

  void _navigateToBookingPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BookingPage(event: widget.event)),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event['title'] ?? 'Event Details'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Image.network(
                          widget.event['image'] ?? '',
                          fit: BoxFit.cover,
                          height: 250,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 100),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.event['title'] ?? 'No Title',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Organized by ${widget.event['organizer'] ?? 'Unknown'}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _toggleFavorite,
                          icon: Icon(
                            isFavorited
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isFavorited ? Colors.red : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.event['dateTime'] ?? 'No Date'),
                        Text(widget.event['locationDisplay']?.toString() ?? 'No Location'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Program Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.event['description'] ?? 'No Description'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rs.${widget.event['ticketPrice']?.toString() ?? '0'} Per Guest',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 120,
                              child: ElevatedButton(
                                onPressed: _navigateToBookingPage,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Book Now'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 120,
                              child: ElevatedButton(
                                onPressed: _addToCalendar,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Add to Calendar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Event Location:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: _eventLocation == null
                          ? const Center(
                              child: Text(
                                'Location data is unavailable.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : GoogleMap(
                              onMapCreated: (controller) =>
                                  _mapController = controller,
                              initialCameraPosition: CameraPosition(
                                target: _eventLocation!,
                                zoom: 14.0,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('eventLocation'),
                                  position: _eventLocation!,
                                  infoWindow: InfoWindow(
                                      title: widget.event['title'] ?? 'Event'),
                                ),
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}