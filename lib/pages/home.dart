import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'eventdetails.dart';
import 'favourites.dart';
import 'profile.dart';
import 'setting.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Home extends StatefulWidget {
  final String profileImageUrl;
  final String displayName;
  final String email;

  const Home({
    super.key,
    required this.profileImageUrl,
    required this.displayName,
    required this.email,
  });

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  String? userId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
    _pages = [
      HomePageContent(
        onFavorite: _addFavorite,
        displayName: widget.displayName,
        profileImageUrl: widget.profileImageUrl,
      ),
      ProfilePage(
        profileImageUrl: widget.profileImageUrl,
        displayName: widget.displayName,
        email: widget.email,
      ),
      const AccountSettingsPage(),
      const FavoritesScreen(),
    ];
  }

  Future<void> _initializeUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      setState(() {
        userId = user.uid;
      });
    }
  }

  Future<void> _addFavorite(Map<String, dynamic> event) async {
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to add favorites')),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(event['id'])
          .set(event);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${event['title'] ?? 'Event'} added to favorites!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add favorite: $e')),
        );
      }
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index && mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
            tooltip: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
            tooltip: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
            tooltip: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favorites',
            tooltip: 'Favorites',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color.fromARGB(255, 250, 67, 67),
        unselectedItemColor: const Color.fromARGB(255, 130, 128, 128),
        backgroundColor: Colors.white,
        elevation: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomePageContent extends StatefulWidget {
  final Function(Map<String, dynamic>) onFavorite;
  final String displayName;
  final String profileImageUrl;

  const HomePageContent({
    super.key,
    required this.onFavorite,
    required this.displayName,
    required this.profileImageUrl,
  });

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> with SingleTickerProviderStateMixin {
  String selectedLocation = 'All';
  String selectedCategory = 'All';
  String searchQuery = '';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> events = [];

  List<String> carouselImages = [
    'lib/assets/event1.jpg',
    'lib/assets/event2.jpg',
    'lib/assets/event3.jpg',
  ];

  final List<String> sriLankanLocations = [
    'All',
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

  final List<String> eventCategories = [
    'All',
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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _fetchEvents();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchEvents() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection('events').get();
      if (mounted) {
        setState(() {
          events.clear();
          events.addAll(snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            // Handle GeoPoint for location
            if (data['location'] is GeoPoint) {
              final geoPoint = data['location'] as GeoPoint;
              data['locationDisplay'] = '${geoPoint.latitude.toStringAsFixed(4)}, ${geoPoint.longitude.toStringAsFixed(4)}';
              // Map to Sri Lankan location if possible
              data['location'] = _getLocationFromGeoPoint(geoPoint);
            } else {
              data['locationDisplay'] = data['location']?.toString() ?? 'Unknown';
              data['location'] = data['location']?.toString() ?? 'Unknown';
            }
            // Handle dateTime
            if (data['dateTime'] is Timestamp) {
              data['dateTime'] = (data['dateTime'] as Timestamp).toDate().toString();
            } else if (data['dateTime'] is String) {
              data['dateTime'] = DateTime.tryParse(data['dateTime'])?.toString() ?? 'No Date';
            } else {
              data['dateTime'] = 'No Date';
            }
            return data;
          }).toList());
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch events: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getLocationFromGeoPoint(GeoPoint geoPoint) {
    // Simplified mapping; in a real app, use a reverse geocoding API
    final double lat = geoPoint.latitude;
    final double lon = geoPoint.longitude;

    if (lat >= 6.8 && lat <= 7.0 && lon >= 79.8 && lon <= 80.0) {
      return 'Colombo';
    } else if (lat >= 7.2 && lat <= 7.4 && lon >= 80.6 && lon <= 80.8) {
      return 'Kandy';
    } else if (lat >= 6.0 && lat <= 6.2 && lon >= 80.2 && lon <= 80.4) {
      return 'Galle';
    }
    // If no match, return the coordinates as a fallback
    return sriLankanLocations.contains('$lat,$lon') ? '$lat,$lon' : 'Unknown';
  }

  List<Map<String, dynamic>> getFilteredEvents() {
    return events.where((event) {
      final matchesLocation = selectedLocation == 'All' || event['location'] == selectedLocation;
      final matchesCategory = selectedCategory == 'All' || event['category']?.toString() == selectedCategory;
      final matchesSearchQuery = event['title']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false;
      return matchesLocation && matchesCategory && matchesSearchQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = getFilteredEvents();

    return RefreshIndicator(
      onRefresh: _fetchEvents,
      color: const Color.fromARGB(255, 250, 67, 67),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Welcome, ${widget.displayName.split(' ')[0]} to EventFy",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: widget.profileImageUrl.isNotEmpty
                        ? NetworkImage(widget.profileImageUrl)
                        : null,
                    child: widget.profileImageUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 20)
                        : null,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'Ef',
                    style: TextStyle(
                      color: Color.fromARGB(255, 250, 67, 67),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            searchQuery = value;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        hintText: 'Search events...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color.fromARGB(255, 250, 67, 67)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _fadeAnimation,
                child: CarouselSlider(
                  options: CarouselOptions(
                    height: 200.0,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 3),
                    enlargeCenterPage: true,
                    viewportFraction: 0.9,
                  ),
                  items: carouselImages.map((image) {
                    return Container(
                      width: MediaQuery.of(context).size.width,
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: AssetImage(image),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedLocation,
                      decoration: InputDecoration(
                        labelText: 'Select Location',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color.fromARGB(255, 250, 67, 67)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      items: sriLankanLocations.map((location) {
                        return DropdownMenuItem(
                          value: location,
                          child: Text(location, style: const TextStyle(color: Colors.black)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            selectedLocation = value!;
                          });
                        }
                      },
                      dropdownColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Select Category',
                        labelStyle: const TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color.fromARGB(255, 250, 67, 67)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      items: eventCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category, style: const TextStyle(color: Colors.black)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (mounted) {
                          setState(() {
                            selectedCategory = value!;
                          });
                        }
                      },
                      dropdownColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Discover Events',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 250, 67, 67)))
                  : filteredEvents.isEmpty
                      ? const Center(
                          child: Column(
                            children: [
                              Icon(Icons.event_busy, size: 60, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No events found.',
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredEvents.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final event = filteredEvents[index];
                            return FadeTransition(
                              opacity: _fadeAnimation,
                              child: buildEventCard(event, context, widget.onFavorite),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEventCard(Map<String, dynamic> event, BuildContext context, Function(Map<String, dynamic>) onFavorite) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 5,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailsPage(event: event, addFavorite: widget.onFavorite),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white, // Set background color to white
            border: Border.all(
              color: Colors.black, // Set border color to black
              width: 1.0, // Set border width
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  event['image']?.toString() ?? '',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    size: 100,
                    color: Colors.grey,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title']?.toString() ?? 'Untitled Event',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          event['dateTime']?.toString() ?? 'No Date',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          event['locationDisplay']?.toString() ?? 'No Location',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event['description']?.toString() ?? 'No Description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rs. ${event['ticketPrice']?.toString() ?? '0'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 250, 67, 67),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}