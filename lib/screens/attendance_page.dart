import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondly/service/attendance_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => AttendancePageState();
}

class AttendancePageState extends State<AttendancePage> {
  DateTime? clockInTime;
  DateTime? clockOutTime;
  String totalWorkingTime = "--:--:-- hours";
  bool isClockedIn = false;
  bool isLoading = false;
  
  // Location related variables
  Position? currentPosition;
  String? currentAddress;
  String? googleMapsUrl;

    // Function to get location permission and current position
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar('Location services are disabled. Please enable the services');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorSnackBar('Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  // Function to get current position
  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      setState(() {
        currentPosition = position;
        googleMapsUrl = 'https://www.google.com/maps/@${position.latitude},${position.longitude},18z';
      });
      
      await _getAddressFromLatLng(position);
    } catch (e) {
      debugPrint(e.toString());
      _showErrorSnackBar('Failed to get current location');
    }
  }

  // Function to get address from coordinates
  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];
      setState(() {
        currentAddress = 
          '${place.street}, ${place.subLocality}, '
          '${place.subAdministrativeArea}, ${place.postalCode}, '
          '${place.country}';
      });
    } catch (e) {
      debugPrint(e.toString());
      _showErrorSnackBar('Failed to get address');
    }
  }

  // Enhanced clock in/out function with API integration
  Future<void> handleClockInOut() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Get location
      await _getCurrentPosition();

      if (currentPosition == null || currentAddress == null || googleMapsUrl == null) {
        _showErrorSnackBar('Failed to get location information');
        return;
      }

      // Record attendance via API
      final success = await AttendanceService.recordAttendance(
        address: currentAddress!,
        addressLink: googleMapsUrl!,
      );

      if (success) {
        setState(() {
          if (!isClockedIn) {
            clockInTime = DateTime.now();
            isClockedIn = true;
          } else {
            clockOutTime = DateTime.now();
            isClockedIn = false;

            if (clockInTime != null && clockOutTime != null) {
              final difference = clockOutTime!.difference(clockInTime!);
              final hours = difference.inHours;
              final minutes = difference.inMinutes.remainder(60);
              final seconds = difference.inSeconds.remainder(60);
              totalWorkingTime =
                  "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} hours";
            }
          }
        });
      } else {
        _showErrorSnackBar('Failed to record attendance');
      }
    } catch (e) {
      debugPrint(e.toString());
      _showErrorSnackBar('An error occurred');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }


  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: const Color.fromRGBO(204, 0, 0, 1.0),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18.0),
            child: Image.asset(
              'assets/logoptap.png',
              width: 50,
            ),
          ),
        ],
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clock In Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClockedIn ? Colors.black : Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: handleClockInOut,
                child: Text(
                  isClockedIn ? "Clock Out" : "Clock Ins",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                  ),
                ),
              ),
            ),

            // Total Working Hour Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.work, size: 24),
                        SizedBox(width: 8),
                        Text(
                          "Total working hour",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      totalWorkingTime,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Clock in: ${clockInTime != null ? clockInTime!.toLocal().toString().split(' ')[1].split('.')[0] : '--:--:--'}",
                        ),
                        Text(
                          "Clock out: ${clockOutTime != null ? clockOutTime!.toLocal().toString().split(' ')[1].split('.')[0] : '--:--:--'}",
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Daily Report Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Daily Report',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            for (int i = 0; i < 4; i++)
              DailyReportCard(
                month: '00',
                clockIn: '00:00:00',
                clockOut: i == 2 ? 'Weekend' : '00:00:00',
                isWeekend: i == 2,
              ),

            // Summary Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SummaryCard(
                      label: 'Working Days',
                      value: '00 days',
                      color: Colors.blue),
                  SummaryCard(
                      label: 'On Leave',
                      value: '00 days',
                      color: Colors.orange),
                  SummaryCard(
                      label: 'Absent', value: '00 days', color: Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyReportCard extends StatelessWidget {
  final String month;
  final String clockIn;
  final String clockOut;
  final bool isWeekend;

  DailyReportCard({
    required this.month,
    required this.clockIn,
    required this.clockOut,
    this.isWeekend = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            color: Colors.black,
            child: Center(
              child: Text(
                month,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 16),
          if (isWeekend)
            Expanded(
              child: Center(
                child: Text(
                  clockOut,
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Clock In: $clockIn',
                      style: TextStyle(color: Colors.black, fontSize: 12)),
                  Text('Clock Out: $clockOut',
                      style: TextStyle(color: Colors.black, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: color, radius: 8),
          SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 16)),
          Spacer(),
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
