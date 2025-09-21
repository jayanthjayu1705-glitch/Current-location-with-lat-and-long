import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'google Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Enhanced Flutter Maps'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  GoogleMapController? mapController;
  Location location = Location();
  LocationData? currentLocation;
  Set<Marker> markers = {};

  // StreamSubscription to manage memory properly
  StreamSubscription<LocationData>? locationSubscription;

  // Controllers for search functionality
  final TextEditingController latController = TextEditingController();
  final TextEditingController lngController = TextEditingController();

  // Real-time location display
  LatLng? currentLatLng;
  bool isLoading = true;
  bool showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  // Initialize location services with proper error handling
  Future<void> _initializeLocation() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _showErrorDialog('Location service is disabled. Please enable it in settings.');
          setState(() => isLoading = false);
          return;
        }
      }

      // Check and request permission
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          _showErrorDialog('Location permission denied. Please grant permission in settings.');
          setState(() => isLoading = false);
          return;
        }
      }

      // Get initial location
      await _getCurrentLocation();

      // Start location updates
      _startLocationUpdates();

    } catch (e) {
      print("Error initializing location: $e");
      _showErrorDialog('Failed to initialize location services: $e');
      setState(() => isLoading = false);
    }
  }

  // Get current location with error handling
  Future<void> _getCurrentLocation() async {
    try {
      currentLocation = await location.getLocation();
      if (currentLocation != null && mounted) {
        setState(() {
          currentLatLng = LatLng(currentLocation!.latitude!, currentLocation!.longitude!);
          isLoading = false;
          _addCurrentLocationMarker();
        });

        // Move camera to current location if map controller is ready
        _moveToCurrentLocation();
      }
    } catch (e) {
      print("Error getting current location: $e");
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorDialog('Failed to get current location: $e');
      }
    }
  }

  // Start real-time location updates with proper subscription management
  void _startLocationUpdates() {
    // Cancel existing subscription to prevent duplicates
    locationSubscription?.cancel();

    locationSubscription = location.onLocationChanged.listen(
          (LocationData locationData) {
        if (mounted) {
          setState(() {
            currentLocation = locationData;
            currentLatLng = LatLng(locationData.latitude!, locationData.longitude!);
            _addCurrentLocationMarker();
          });
        }
      },
      onError: (error) {
        print('Location update error: $error');
        _showErrorDialog('Location update failed: $error');
      },
    );
  }

  // Add current location marker with duplicate prevention
  void _addCurrentLocationMarker() {
    if (currentLatLng != null) {
      // Remove existing current location marker to prevent duplicates
      markers.removeWhere((marker) => marker.markerId.value == 'current_location');

      markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: currentLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Your Current Location',
            snippet: 'Lat: ${currentLatLng!.latitude.toStringAsFixed(6)}, Lng: ${currentLatLng!.longitude.toStringAsFixed(6)}',
          ),
        ),
      );
    }
  }

  // Search by coordinates with improved validation
  void _searchByCoordinates() {
    final String latText = latController.text.trim();
    final String lngText = lngController.text.trim();

    if (latText.isEmpty || lngText.isEmpty) {
      _showErrorDialog('Please enter both latitude and longitude values.');
      return;
    }

    double? lat = double.tryParse(latText);
    double? lng = double.tryParse(lngText);

    if (lat == null || lng == null) {
      _showErrorDialog('Please enter valid numeric coordinates!');
      return;
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      _showErrorDialog('Invalid coordinates! Latitude must be between -90 and 90, Longitude must be between -180 and 180.');
      return;
    }

    LatLng searchLocation = LatLng(lat, lng);

    // Add search marker
    setState(() {
      markers.removeWhere((marker) => marker.markerId.value == 'search_location');
      markers.add(
        Marker(
          markerId: const MarkerId('search_location'),
          position: searchLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Searched Location',
            snippet: 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}',
          ),
        ),
      );
    });

    // Move camera to searched location if map controller is available
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: searchLocation,
            zoom: 15.0,
          ),
        ),
      );
    }

    // Hide search bar and clear fields
    setState(() => showSearchBar = false);
    latController.clear();
    lngController.clear();
  }

  // Show error dialog with consistent styling
  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Move to current location with null checks
  void _moveToCurrentLocation() {
    if (currentLatLng != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLatLng!,
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("current Maps"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                showSearchBar = !showSearchBar;
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading location services...'),
          ],
        ),
      )
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: currentLatLng ?? const LatLng(37.4223, -122.0848),
              zoom: 13,
            ),
            onMapCreated: (GoogleMapController controller) {
              mapController = controller;
              // Move to current location once map is created
              if (currentLatLng != null) {
                _moveToCurrentLocation();
              }
            },
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: true,
            // Add some basic gesture settings for better UX
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
          ),

          // Real-time coordinates display
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Location:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    currentLatLng != null
                        ? 'Lat: ${currentLatLng!.latitude.toStringAsFixed(6)}\nLng: ${currentLatLng!.longitude.toStringAsFixed(6)}'
                        : 'Location not available',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Search bar
          if (showSearchBar)
            Positioned(
              top: 100,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Search by Coordinates',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            decoration: const InputDecoration(
                              labelText: 'Latitude (-90 to 90)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: lngController,
                            decoration: const InputDecoration(
                              labelText: 'Longitude (-180 to 180)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _searchByCoordinates,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moveToCurrentLocation,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  @override
  void dispose() {
    // Critical: Cancel location subscription to prevent memory leaks
    locationSubscription?.cancel();

    // Dispose controllers
    latController.dispose();
    lngController.dispose();

    // Dispose map controller
    mapController?.dispose();

    super.dispose();
  }
}
