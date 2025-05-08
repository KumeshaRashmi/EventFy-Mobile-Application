import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EventMap extends StatefulWidget {
  const EventMap({super.key});

  @override
  State<EventMap> createState() => _EventMapState();
}

class _EventMapState extends State<EventMap> {
  static const LatLng _center =
      LatLng(6.0535, 80.2204); // Example: Southern Sri Lanka coordinates.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Map View"),
        backgroundColor: Colors.redAccent,
      ),
      body: GoogleMap(
        onMapCreated: (GoogleMapController controller) {
          // You can use the controller here if needed later
        },
        myLocationButtonEnabled: false, // Disable my location button
        zoomControlsEnabled: false, // Disable zoom controls
        initialCameraPosition: const CameraPosition(
          target: _center,
          zoom: 14.0,
        ),
        markers: {
          Marker(
            markerId: MarkerId('marker_1'),
            position: _center,
            infoWindow: InfoWindow(
              title: 'Event Location',
              snippet: 'This is an event location',
            ),
          ),
        },
      ),
    );
  }
}
