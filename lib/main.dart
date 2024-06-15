import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:navigations/WebViewPage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Driving Mode',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng? _currentPosition;
  LatLng _destination = LatLng(6.6745, -1.5716); // KNUST Kumasi
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  final String _apiKey = 'AIzaSyCl1lf2Q2S6QJcAy8yUwg4jc-CF5pufkvk';
  bool _showWebView = false;
  String _mapsUrl = '';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartStream();
  }

  Future<void> _checkPermissionsAndStartStream() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Location services are disabled. Please enable the services.')));
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permissions are denied')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Location permissions are permanently denied')));
      return;
    }

    _getCurrentLocationAndStartNavigation();
  }

  Future<void> _getCurrentLocationAndStartNavigation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    LatLng currentPosition = LatLng(position.latitude, position.longitude);
    setState(() {
      _currentPosition = currentPosition;
      _markers.add(Marker(
        markerId: MarkerId('current'),
        position: currentPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
      _markers.add(Marker(
        markerId: MarkerId('destination'),
        position: _destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });

    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (_currentPosition == null) return;

    try {
      PolylinePoints polylinePoints = PolylinePoints();
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        _apiKey,
        PointLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        PointLatLng(_destination.latitude, _destination.longitude),
      );

      if (result.status == 'OK' && result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = [];
        result.points.forEach((PointLatLng point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });

        setState(() {
          _polylines.add(Polyline(
            polylineId: PolylineId('route'),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));
        });

        _focusOnCurrentPosition();
        _animateCameraAlongRoute(polylineCoordinates);
      } else {
        throw Exception('Unable to get route: ${result.errorMessage}');
      }
    } catch (e) {
      print('Error fetching route: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error fetching route: $e'),
      ));
    }
  }

  void _focusOnCurrentPosition() {
    if (_currentPosition != null) {
      _controller?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentPosition!,
          zoom: 20,
          tilt: 60,
        ),
      ));
    }
  }

  void _animateCameraAlongRoute(List<LatLng> routePoints) async {
    for (int i = 0; i < routePoints.length; i++) {
      await Future.delayed(Duration(milliseconds: 100), () {
        _controller?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: routePoints[i],
            zoom: 20,
            tilt: 60,
            bearing: _calculateBearing(
                routePoints[i], routePoints[(i + 1) % routePoints.length]),
          ),
        ));
      });
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * (math.pi / 180.0);
    double lon1 = start.longitude * (math.pi / 180.0);
    double lat2 = end.latitude * (math.pi / 180.0);
    double lon2 = end.longitude * (math.pi / 180.0);

    double dLon = lon2 - lon1;
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    double bearing = math.atan2(y, x);
    return (bearing * 180.0 / math.pi + 360.0) % 360.0;
  }

  void _launchWebView() async {
    if (_currentPosition == null) return;

    final origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final destination = '${_destination.latitude},${_destination.longitude}';
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => WebViewPage(url: googleMapsUrl),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driving Mode'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(37.4219999, -122.0840575),
              zoom: 20,
              tilt: 60,
            ),
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _controller = controller;
              _focusOnCurrentPosition();
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            polylines: _polylines,
            markers: _markers,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Clement St",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "0.5 mi",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                if (_currentPosition != null) {
                  _controller?.animateCamera(CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _currentPosition!,
                      zoom: 20,
                      tilt: 60,
                      bearing:
                          _calculateBearing(_currentPosition!, _destination),
                    ),
                  ));
                }
              },
              child: Icon(Icons.directions),
            ),
          ),
          Positioned(
            bottom: 180,
            right: 20,
            child: FloatingActionButton(
              onPressed: _launchWebView,
              child: Icon(Icons.map),
            ),
          ),
          Positioned(
            bottom: 240,
            right: 20,
            child: FloatingActionButton(
              onPressed: _launchGoogleMaps,
              child: Icon(Icons.directions),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        color: Colors.white,
        height: 100,
        child: Row(
          children: [
            Icon(Icons.timer, size: 40),
            SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "8 min",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "4.8 km",
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Picking up Dylan",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(Icons.more_horiz, size: 40),
            SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  void _launchGoogleMaps() async {
    if (_currentPosition == null) return;

    final origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final destination = '${_destination.latitude},${_destination.longitude}';
    final googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';

    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }
}
