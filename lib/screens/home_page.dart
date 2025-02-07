import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:secondly/models/user_data.dart';
import 'package:secondly/service/attendance_service.dart';
import 'package:secondly/service/auth_service.dart';
import 'attendance_page.dart';
import 'timesheets.dart';
import 'leave.dart';
import 'asset.dart';
import 'profile.dart';
import 'feedback.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? clockInTime;
  DateTime? clockOutTime;
  String totalWorkingTime = "--:--:--";
  bool isClockedIn = false;
  bool isLoading = false;
  String userName = "";
  String greeting = "";
  UserData? userData;
  bool isDataLoading = false;

  Position? currentPosition;
  String? currentAddress;
  String? googleMapsUrl;
  String? checkInLocation;
  String? checkOutLocation;

  Timer? _timer;
  int _elapsedSeconds = 0;

  static const int maxRetries = 3;
  static const int locationTimeout = 10; // seconds

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
    }
    super.dispose();
  }

  void initState() {
    super.initState();
    _loadUserData();
    _fetchAttendanceData();
    _updateGreeting();
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = "Good Morning";
    } else if (hour < 17) {
      greeting = "Good Afternoon";
    } else {
      greeting = "Good Evening";
    }
  }

  Future<void> _loadUserData() async {
    final data = await AuthService.getStoredUserData();
    if (data != null) {
      setState(() {
        userData = data;
        userName = data.fullName;
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorSnackBar(
          'Location services are disabled. Please enable the services');
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

  Future<void> _getCurrentPosition() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    for (int i = 0; i < maxRetries; i++) {
      try {
        Position? position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: locationTimeout),
        ).timeout(
          Duration(seconds: locationTimeout),
          onTimeout: () {
            throw TimeoutException('Location request timed out');
          },
        );

        setState(() {
          currentPosition = position;
          googleMapsUrl =
              'https://www.google.com/maps/@${position.latitude},${position.longitude},18z';
        });

        await _getAddressFromLatLng(position);
        return; // Success - exit the retry loop
      } catch (e) {
        debugPrint('Location attempt ${i + 1} failed: $e');

        if (e is TimeoutException) {
          _showErrorSnackBar('Location request timed out. Retrying...');
        } else if (e.toString().contains('LocationServiceDisabledException')) {
          _showErrorSnackBar('Location services are disabled');
          return;
        } else if (e.toString().contains('PermissionDeniedException')) {
          _showErrorSnackBar('Location permission denied');
          return;
        }

        // If this was the last retry
        if (i == maxRetries - 1) {
          _showErrorDialog(
              'Location Error',
              'Unable to get your location after several attempts. Please ensure you have:\n\n'
                  '• Good GPS signal\n'
                  '• Internet connectivity\n'
                  '• Location services enabled\n\n'
                  'Would you like to try again?');
          return;
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }

  // Address lookup with retrie
  Future<void> _getAddressFromLatLng(Position position) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(
          Duration(seconds: locationTimeout),
          onTimeout: () {
            throw TimeoutException('Address lookup timed out');
          },
        );

        if (placemarks.isEmpty) {
          throw Exception('No address found');
        }

        Placemark place = placemarks[0];
        setState(() {
          currentAddress = '${place.street ?? ''}, ${place.subLocality ?? ''}, '
                  '${place.subAdministrativeArea ?? ''}, ${place.postalCode ?? ''}, '
                  '${place.country ?? ''}'
              .replaceAll(RegExp(r', ,'), ',') // Remove empty components
              .replaceAll(RegExp(r',+'), ',') // Remove multiple commas
              .replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'),
                  '') // Remove leading/trailing commas
              .trim();
        });
        return; // Success - exit the retry loop
      } catch (e) {
        debugPrint('Address lookup attempt ${i + 1} failed: $e');

        // If this was the last retry
        if (i == maxRetries - 1) {
          setState(() {
            currentAddress = 'Location found but address lookup failed';
          });
          _showErrorSnackBar('Could not get street address');
          return;
        }

        // Wait before retrying
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      isDataLoading = true;
    });

    try {
      final userData = await AuthService.getCurrentUser();
      if (userData == null) {
        debugPrint('No user data available');
        return;
      }

      final today = DateTime.now();
      final formattedDate =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final attendanceData = await AttendanceService.getAttendanceData(
        userData.employeeId,
        formattedDate,
      );

      setState(() {
        // First, reset all states
        clockInTime = null;
        clockOutTime = null;
        isClockedIn = false;
        totalWorkingTime = "--:--:--";
        checkInLocation = null;
        checkOutLocation = null;

        if (attendanceData != null) {
          // Handle check-in and check-out times
          if (attendanceData['check_in'] != null) {
            clockInTime = DateTime.parse(attendanceData['check_in']);

            if (attendanceData['check_out'] != null) {
              clockOutTime = DateTime.parse(attendanceData['check_out']);
              isClockedIn = false; // User has completed their shift
            } else {
              isClockedIn = true; // User is currently clocked in
            }

            // Set total working time from the API data
            if (attendanceData['total_working_hours'] != null) {
              double totalHours =
                  attendanceData['total_working_hours'].toDouble();
              int hours = totalHours.floor();
              int minutes = ((totalHours - hours) * 60).floor();
              int seconds =
                  (((totalHours - hours) * 60 - minutes) * 60).round();

              totalWorkingTime =
                  "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
            }

            // Update location information
            checkInLocation = attendanceData['check_in_location'];
            checkOutLocation = attendanceData['check_out_location'];
          }
        }
      });
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
      // In case of error, reset to safe default values
      setState(() {
        clockInTime = null;
        clockOutTime = null;
        isClockedIn = false;
        totalWorkingTime = "--:--:--";
        checkInLocation = null;
        checkOutLocation = null;
      });
    } finally {
      setState(() {
        isDataLoading = false;
      });
    }
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')} hours";
  }

  Future<void> handleClockInOut() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Get location
      await _getCurrentPosition();

      if (currentPosition == null ||
          currentAddress == null ||
          googleMapsUrl == null) {
        _showErrorSnackBar('Failed to get location information');
        return;
      }

      // Record attendance via API
      final response = await AttendanceService.recordAttendance(
        address: currentAddress!,
        addressLink: googleMapsUrl!,
      );

      if (response.success) {
        if (isClockedIn) {
          // Clock Out
          clockOutTime = DateTime.now();
        } else {
          // Clock In
          clockInTime = DateTime.now();
        }

        setState(() {
          isClockedIn = !isClockedIn;
        });

        // Refresh both attendance data and daily records
        await Future.wait([
          _fetchAttendanceData(),
        ]);
      } else {
        _showErrorSnackBar(response.message);
      }
    } catch (e) {
      debugPrint('Error during clock in/out: $e');
      _showErrorSnackBar('An error occurred');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Retry'),
              onPressed: () {
                Navigator.of(context).pop();
                _getCurrentPosition();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildClockButton() {
    final bool canClockInOut = !isLoading && !isDataLoading;

    // Determine button color and text
    final Color buttonColor = isClockedIn ? Colors.black : Colors.red;
    final String buttonText = isClockedIn ? "CLOCK OUT" : "CLOCK IN";
    final String loadingText =
        isClockedIn ? "Processing Clock Out..." : "Processing Clock In...";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonSize = constraints.maxWidth * 0.4;

        return Center(
          child: ClipOval(
            child: SizedBox(
              width: buttonSize,
              height: buttonSize,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: const CircleBorder(),
                ),
                onPressed: canClockInOut ? handleClockInOut : null,
                child: isLoading
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loadingText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : FittedBox(
                        child: Text(
                          buttonText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void showComingSoonPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Coming Soon"),
        content: const Text("Fitur ini sedang dalam pengembangan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  void showMoreOptions(BuildContext context) {
    List<Map<String, dynamic>> moreOptions = [
      {'title': 'Performance ', 'icon': Icons.assessment_outlined},
      {'title': 'Dashboard', 'icon': Icons.dashboard},
      {'title': 'Assessment', 'icon': Icons.assignment},
      {'title': 'Document', 'icon': Icons.folder},
      {'title': 'Knowledge Management', 'icon': Icons.import_contacts},
      {'title': 'My Data', 'icon': Icons.perm_identity},
      {'title': 'Schedule', 'icon': Icons.calendar_today},
      {'title': 'Chat Room', 'icon': Icons.chat},
      {'title': 'Contact', 'icon': Icons.contacts},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "More Options",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 24,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: moreOptions.length,
                itemBuilder: (ctx, index) {
                  final option = moreOptions[index];
                  return GestureDetector(
                    onTap: () {
                      showComingSoonPopup(context);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 6,
                                offset: const Offset(2, 4),
                              ),
                            ],
                          ),
                          width: 56,
                          height: 56,
                          child: Icon(
                            option['icon'],
                            color: const Color.fromARGB(255, 3, 3, 3),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Adjust font size only for "Knowledge Management"
                        Text(
                          option['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: option['title'] == 'Knowledge Management'
                                ? 8
                                : 10, // 👈 Smaller font
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(BuildContext context, int index) {
    List<String> titles = [
      'Attendance',
      'Leave',
      'Time Sheet',
      'Asset',
      'SPL',
      'Claim',
      'E-Learning',
      'More'
    ];
    List<IconData> icons = [
      Icons.access_time,
      Icons.logout_outlined,
      Icons.calendar_today,
      Icons.warehouse_rounded,
      Icons.more_time_rounded,
      Icons.currency_exchange,
      Icons.school,
      Icons.grid_view,
    ];

    void navigateToPage() {
      if (index == 0) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AttendancePage()),
        );
      } else if (index == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LeavePage()),
        );
      } else if (index == 2) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TimeSheetPage()),
        );
      } else if (index == 3) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AssetScreen()),
        );
      } else if (index == 7) {
        showMoreOptions(context);
      } else {
        showComingSoonPopup(context);
      }
    }

    return GestureDetector(
      onTap: navigateToPage,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rounded Rectangle with Shadow
          Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 255, 255, 255),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 1, // Radius penyebaran shadow
                  blurRadius: 6, // Radius blur shadow
                  offset: const Offset(2, 4), // Posisi shadow (X, Y)
                ),
              ],
            ),
            width: 56,
            height: 56,
            child: Center(
              child: Icon(
                icons[index],
                size: 28,
                color: const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              titles[index],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (userData == null) {
      return const CircleAvatar(
        radius: 20,
        backgroundColor: Colors.grey,
        child: Icon(Icons.person, color: Colors.white),
      );
    }

    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey,
      child: ClipOval(
        child: Image(
          image: NetworkImage(
            'https://dev.osp.id/ptap-kpi-dev/dist/img/profilepicture/${userData!.employeeId}.png',
          ),
          fit: BoxFit.cover,
          width: 40,
          height: 40,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.person, color: Colors.white);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = _elapsedSeconds >= 28800
        ? Colors.green
        : const Color.fromARGB(255, 255, 0, 0);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo
            Image.asset(
              'assets/logolengkapptap.png',
              width: 170,
            ),
            // Profile Avatar
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              child: _buildProfileAvatar(),
            ),
          ],
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$greeting, $userName!",
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Let's get to work!",
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Clock In Section
            _buildClockButton(),

            // Total Working Hour Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16.0),
                child: isDataLoading
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.work, size: 24),
                              SizedBox(width: 8),
                              Text(
                                "Total working hour",
                                style: TextStyle(
                                    fontSize: 25, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              totalWorkingTime,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 35,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Divider(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Clock in: ${clockInTime != null ? clockInTime!.toLocal().toString().split(' ')[1].split('.')[0] : '--:--:--'}",
                                  ),
                                  Text(
                                    "Clock out: ${clockOutTime != null ? clockOutTime!.toLocal().toString().split(' ')[1].split('.')[0] : '--:--:--'}",
                                  ),
                                ],
                              ),
                              if (checkInLocation != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  "Check-in location: $checkInLocation",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                              if (checkOutLocation != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  "Check-out location: $checkOutLocation",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
              ),
            ),

            // Options Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  return _buildOption(context, index);
                },
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    vertical: 18.0, horizontal: 30.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(
                        // Add outer border
                        color: Colors.black, // Border color
                        width: 1, // Border width
                      ),
                    ),
                    elevation: 5, // Shadow for depth effect
                    shadowColor: Colors.black.withOpacity(0.5), // Shadow color
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FeedbackScreen()),
                    );
                  },
                  child: const Text(
                    'Send Feedback',
                    style: TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 20,
                      // fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Next Activity Section
            const Padding(
              padding: EdgeInsets.all(16.0),
            ),
            NextActivityWidget(),

            // More Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  showComingSoonPopup(context);
                },
                child: const Text(
                  "More",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceRecord {
  final DateTime clockIn;
  final DateTime clockOut;
  final Duration workingDuration;

  AttendanceRecord({
    required this.clockIn,
    required this.clockOut,
    required this.workingDuration,
  });
}

class NextActivityWidget extends StatefulWidget {
  const NextActivityWidget({Key? key}) : super(key: key);

  @override
  _NextActivityWidgetState createState() => _NextActivityWidgetState();
}

class _NextActivityWidgetState extends State<NextActivityWidget> {
  final List<Map<String, dynamic>> activities = [
    {
      "title": "Project Name 1",
      "subtitle": "Project leader\nPlanned squad name1, Planned squad name2",
      "isDone": false,
    },
    {
      "title": "Project Name 2",
      "subtitle": "Project leader\nPlanned squad name3, Planned squad name4",
      "isDone": false,
    },
    {
      "title": "Project Name 3",
      "subtitle": "Project leader\nPlanned squad name5, Planned squad name6",
      "isDone": false,
    },
  ];

  bool isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header dengan arrow dropdown
        GestureDetector(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Next activity",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),
          ),
        ),

        // List proyek
        if (isExpanded)
          ...activities.map((activity) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Checkbox(
                    value: activity["isDone"],
                    onChanged: (bool? value) {
                      setState(() {
                        activity["isDone"] = value!;
                      });
                    },
                  ),
                  title: Text(
                    activity["title"],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(activity["subtitle"]),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: activity["isDone"] ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      activity["isDone"] ? "Done" : "Planned",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }
}
