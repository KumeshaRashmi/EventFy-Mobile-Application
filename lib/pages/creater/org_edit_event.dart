import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
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
  String? selectedLocation;
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

  final List<String> sriLankanLocations = [
    'Colombo',
    'Gampaha',
    'Kalutara',
    'Kandy',
    'Matale',
    'Nuwara Eliya',
    'Galle',
    'Matara',
    'Hambantota',
    'Jaffna',
    'Kilinochchi',
    'Mannar',
    'Mullaitivu',
    'Vavuniya',
    'Batticaloa',
    'Ampara',
    'Trincomalee',
    'Kurunegala',
    'Puttalam',
    'Anuradhapura',
    'Polonnaruwa',
    'Badulla',
    'Monaragala',
    'Ratnapura',
    'Kegalle',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing event data
    eventNameController = TextEditingController(text: widget.event['title']);
    eventDescriptionController = TextEditingController(text: widget.event['description']);
    ticketPriceController = TextEditingController(text: widget.event['ticketPrice']);
    
    // Initialize date and time
    if (widget.event['dateTime'] != null) {
      final eventDateTime = DateTime.parse(widget.event['dateTime']);
      selectedDate = eventDateTime;
      selectedTime = TimeOfDay(hour: eventDateTime.hour, minute: eventDateTime.minute);
    }

    // Initialize category and location
    selectedCategory = widget.event['category'];
    selectedLocation = widget.event['location'];

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

    if (pickedDate != null) {
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

    if (pickedTime != null) {
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
    if (_eventImage == null && _existingImageUrl == null ||
        eventNameController.text.isEmpty ||
        eventDescriptionController.text.isEmpty ||
        selectedDate == null ||
        selectedTime == null ||
        ticketPriceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields and select an image.')),
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

      // Update event details in Firestore
      await FirebaseFirestore.instance.collection('events').doc(widget.event['id']).update({
        'title': eventNameController.text.trim(),
        'description': eventDescriptionController.text.trim(),
        'dateTime': eventDateTime.toIso8601String(),
        'location': selectedLocation,
        'category': selectedCategory,
        'image': imageUrl,
        'ticketPrice': ticketPriceController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated successfully!')),
      );

      // Pop back to OrgHomePage
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update event: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
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
                setState(() {
                  selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedLocation,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              items: sriLankanLocations.map((location) {
                return DropdownMenuItem(value: location, child: Text(location));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedLocation = value;
                });
              },
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
            ),
            const SizedBox(height: 15),
            _eventImage != null
                ? Image.file(_eventImage!, height: 200, width: double.infinity, fit: BoxFit.cover)
                : _existingImageUrl != null
                    ? Image.network(_existingImageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover)
                    : const SizedBox.shrink(),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Change Event Image'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
            const SizedBox(height: 15),
            _isUploading
                ? const CircularProgressIndicator()
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