import 'package:flutter/material.dart';

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

  void handleClockInOut() {
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
                  isClockedIn ? "Clock Out" : "Clock In",
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
