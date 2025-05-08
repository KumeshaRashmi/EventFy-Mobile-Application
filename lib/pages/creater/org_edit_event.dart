import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'dart:io';

class OrgEditEventPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const OrgEditEventPage({super.key, required this.event});

  @override
  _OrgEditEventPageState createState() => _OrgEditEventPageState();
}

class _OrgEditEventPageState extends State<OrgEditEventPage> {
  late TextEditingController eventNameController;
  late TextEditingController eventDescriptionController;
  late TextEditingController ticketPriceController;

  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  String? selectedCategory;
  LatLng? selectedLocation;
  File? _eventImage;
  String? _existingImageUrl;
  bool _isUploading = false;

  final List<String> categories = [
    'Music',
    'Business',
    'Food',
    'Art',
    'Films',
    'Sports',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing event data
    eventNameController = TextEditingController(text: widget.event['title'] ?? '');
    eventDescriptionController = TextEditingController(text: widget.event['description'] ?? '');
    ticketPriceController = TextEditingController(text: widget.event['ticketPrice']?.toString() ?? '');

    // Initialize date and time
    if (widget.event['dateTime'] != null) {
      final eventDateTime = DateTime.parse(widget.event['dateTime']);
      selectedDate = eventDateTime;
      selectedTime = TimeOfDay(hour: eventDateTime.hour, minute: eventDateTime.minute);
    }

    // Initialize category
    selectedCategory = widget.event['category'];

    // Initialize location (handle GeoPoint)
    if (widget.event['location'] is GeoPoint) {
      final geoPoint = widget.event['location'] as GeoPoint;
      selectedLocation = LatLng(geoPoint.latitude, geoPoint.longitude);
    } else if (widget.event['location'] is String) {
      final locationData = widget.event['location'].split(',');
      selectedLocation = LatLng(double.parse(locationData[0]), double.parse(locationData[1]));
    }

    // Initialize image
    _existingImageUrl = widget.event['image'];
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _eventImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        selectedDate = pickedDate;
      });
    }
  }

  Future<void> _selectTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null && mounted) {
      setState(() {
        selectedTime = pickedTime;
      });
    }
  }

  Future<String> _uploadImageToCloudinary(File imageFile) async {
    const cloudName = 'dwuzpk4cd'; // Replace with your Cloudinary cloud name
    const uploadPreset = 'localevent'; // Replace with your Cloudinary unsigned upload preset

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', url);

    request.fields['upload_preset'] = uploadPreset;
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);
      return jsonResponse['secure_url'];
    } else {
      throw Exception('Failed to upload image to Cloudinary');
    }
  }

  Future<void> _updateEvent() async {
    if (eventNameController.text.isEmpty ||
        eventDescriptionController.text.isEmpty ||
        selectedDate == null ||
        selectedTime == null ||
        ticketPriceController.text.isEmpty ||
        selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields and select a location.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload new image if selected, otherwise use existing image URL
      String? imageUrl = _existingImageUrl;
      if (_eventImage != null) {
        imageUrl = await _uploadImageToCloudinary(_eventImage!);
      }

      // Combine date and time into a single DateTime object
      final eventDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      // Update event details in Firestore with GeoPoint
      await FirebaseFirestore.instance.collection('events').doc(widget.event['id']).update({
        'title': eventNameController.text.trim(),
        'description': eventDescriptionController.text.trim(),
        'dateTime': eventDateTime.toIso8601String(),
        'location': GeoPoint(selectedLocation!.latitude, selectedLocation!.longitude),
        'category': selectedCategory,
        'image': imageUrl,
        'ticketPrice': ticketPriceController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
      }

      // Pop back to OrgHomePage
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickLocation() async {
    final LatLng? pickedLocation = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          initialLocation: selectedLocation ?? const LatLng(6.9271, 79.8612), // Default to Colombo
        ),
      ),
    );

    if (pickedLocation != null && mounted) {
      setState(() {
        selectedLocation = pickedLocation;
      });
    }
  }

  @override
  void dispose() {
    eventNameController.dispose();
    eventDescriptionController.dispose();
    ticketPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: Colors.redAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: eventDescriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Event Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.map),
              label: Text(selectedLocation != null
                  ? 'Location Selected: ${selectedLocation!.latitude.toStringAsFixed(4)}, ${selectedLocation!.longitude.toStringAsFixed(4)}'
                  : 'Pick Location'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                backgroundColor: Colors.white,
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: _selectDate,
                    decoration: InputDecoration(
                      labelText: selectedDate != null
                          ? 'Date: ${selectedDate!.toLocal().toString().split(' ')[0]}'
                          : 'Select Date',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    onTap: _selectTime,
                    decoration: InputDecoration(
                      labelText: selectedTime != null
                          ? 'Time: ${selectedTime!.format(context)}'
                          : 'Select Time',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            TextField(
              controller: ticketPriceController,
              decoration: const InputDecoration(
                labelText: 'Ticket Price (e.g., RS.5000)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            _eventImage != null
                ? Image.file(_eventImage!, height: 200, width: double.infinity, fit: BoxFit.cover)
                : _existingImageUrl != null
                    ? Image.network(_existingImageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 50))
                    : const SizedBox.shrink(),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Change Event Image'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 15),
            _isUploading
                ? const CircularProgressIndicator(color: Colors.redAccent)
                : ElevatedButton(
                    onPressed: _updateEvent,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.redAccent,
                    ),
                    child: const Text('Update Event'),
                  ),
          ],
        ),
      ),
    );
  }
}

class LocationPickerPage extends StatelessWidget {
  final LatLng initialLocation;

  const LocationPickerPage({super.key, required this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: Colors.redAccent,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: initialLocation,
          zoom: 14.0,
        ),
        onTap: (LatLng location) {
          Navigator.pop(context, location);
        },
        markers: {
          if (initialLocation != null)
            Marker(
              markerId: const MarkerId('initialLocation'),
              position: initialLocation,
            ),
        },
      ),
    );
  }
}