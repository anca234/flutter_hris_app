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
import 'dart:async';
import 'feedback.dart';
//import 'more.dart';

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

  Timer? _timer;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchAttendanceData();
    _updateGreeting();
  }

  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startStopwatch() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = Duration(seconds: _duration.inSeconds + 1);
        final hours = _duration.inHours;
        final minutes = _duration.inMinutes.remainder(60);
        final seconds = _duration.inSeconds.remainder(60);
        totalWorkingTime =
            "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
      });
    });
  }

  void stopStopwatch() {
    _timer?.cancel();
    _timer = null;
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

  Future<void> _fetchAttendanceData() async {
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

      if (attendanceData != null) {
        setState(() {
          if (attendanceData['check_in'] != null) {
            clockInTime = DateTime.parse(attendanceData['check_in']);
            isClockedIn = attendanceData['check_out'] == null;
          }

          if (attendanceData['check_out'] != null) {
            clockOutTime = DateTime.parse(attendanceData['check_out']);
          }

          if (attendanceData['total_working_hours'] != null) {
            final hours = attendanceData['total_working_hours'].toInt();
            final minutes =
                ((attendanceData['total_working_hours'] - hours) * 60).toInt();
            final seconds =
                (((attendanceData['total_working_hours'] - hours) * 60 -
                            minutes) *
                        60)
                    .toInt();
            totalWorkingTime =
                "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching attendance data: $e');
    }
  }

  Future<void> handleClockInOut() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      if (!isClockedIn) {
        // Clock In
        clockInTime = DateTime.now();
        isClockedIn = true;
        _duration = Duration.zero; // Reset stopwatch
        totalWorkingTime = "00:00:00";
        startStopwatch();

        // Get location for Clock In
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        final address = placemarks.first;
        final addressStr =
            '${address.street}, ${address.subLocality}, ${address.postalCode}, ${address.country}';
        final mapsUrl =
            'https://www.google.com/maps/@${position.latitude},${position.longitude},18z';

        // Record Clock In attendance via API
        final success = await AttendanceService.recordAttendance(
          address: addressStr,
          addressLink: mapsUrl,
        );

        if (success) {
          await _fetchAttendanceData();
        } else {
          _showErrorSnackBar(context, 'Failed to record Clock In attendance');
        }
      } else {
        // Clock Out
        clockOutTime = DateTime.now();
        isClockedIn = false;
        stopStopwatch();

        // Get location for Clock Out
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        final address = placemarks.first;
        final addressStr =
            '${address.street}, ${address.subLocality}, ${address.postalCode}, ${address.country}';
        final mapsUrl =
            'https://www.google.com/maps/@${position.latitude},${position.longitude},18z';

        // Record Clock Out attendance via API
        final success = await AttendanceService.recordAttendance(
          address: addressStr,
          addressLink: mapsUrl,
        );

        if (success) {
          await _fetchAttendanceData();
        } else {
          _showErrorSnackBar(context, 'Failed to record Clock Out attendance');
        }
      }
    } catch (e) {
      debugPrint(e.toString());
      _showErrorSnackBar(
          context, 'An error occurred while recording attendance');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
            child: const Text(
              "Tutup",
              style:
                  TextStyle(color: Color.fromARGB(255, 0, 0, 0), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void showMoreOptions(BuildContext context) {
    List<Map<String, dynamic>> moreOptions = [
      {'title': 'Performance Evaluate', 'icon': Icons.assessment_outlined},
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
                  mainAxisSpacing: 24, // Meningkatkan jarak antar baris
                  crossAxisSpacing: 16, // Jarak antar kolom tetap
                  childAspectRatio: 0.9, // Rasio aspek tetap
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
                        // Rounded Rectangle with Shadow
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(12), // Membulatkan sudut
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withOpacity(0.2), // Warna shadow
                                spreadRadius: 1,
                                blurRadius: 6,
                                offset: const Offset(2, 4), // Posisi shadow
                              ),
                            ],
                          ),
                          width: 61,
                          height: 61,
                          child: Icon(
                            option['icon'],
                            color: const Color.fromARGB(255, 3, 3, 3),
                            size: 35,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          option['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
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
            width: 63,
            height: 63,
            child: Center(
              child: Icon(
                icons[index],
                size: 35,
                color: const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ),
          const SizedBox(height: 6),
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
    final Color stopwatchColor =
        _duration.inHours >= 9 ? Colors.green : Colors.red;
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isClockedIn
                          ? const Color.fromARGB(255, 0, 0, 0)
                          : Colors.red,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(80),
                    ),
                    onPressed: handleClockInOut,
                    child: Text(
                      isClockedIn ? "CLOCK OUT" : "CLOCK IN",
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment
                          .center, // Semua elemen berada di tengah secara horizontal
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center, // Teks berada di tengah
                          children: const [
                            Icon(Icons.work, size: 24),
                            SizedBox(width: 8),
                            Text(
                              "Total working hour",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          totalWorkingTime,
                          style: TextStyle(
                            color: stopwatchColor, // Warna stopwatch dinamis
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center, // Timer berada di tengah
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Clock in: ${clockInTime != null ? "${clockInTime!.hour.toString().padLeft(2, '0')}:${clockInTime!.minute.toString().padLeft(2, '0')}:${clockInTime!.second.toString().padLeft(2, '0')}" : '--:--:--'}",
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              "Clock out: ${clockOutTime != null ? "${clockOutTime!.hour.toString().padLeft(2, '0')}:${clockOutTime!.minute.toString().padLeft(2, '0')}:${clockOutTime!.second.toString().padLeft(2, '0')}" : '--:--:--'}",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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

// ElevatedButton yang ada di tengah layar
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Ganti dengan route yang sesuai untuk feedback screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FeedbackScreen()),
                    );
                  },
                  child: const Text(
                    'Go to Feedback screen',
                    style: TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
                onPressed: () {},
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
