import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart'; // Add this package to pubspec.yaml
import 'package:permission_handler/permission_handler.dart'; // Add this package
import '../../constants.dart'; // adjust your path to AppColors

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> bandData = [];

  final screenshotController1 = ScreenshotController();
  final screenshotController2 = ScreenshotController();
  final screenshotController3 = ScreenshotController();

  @override
  void initState() {
    super.initState();
    fetchData();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request storage permissions
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  Future<void> fetchData() async {
    final response = await supabase.from('banddata').select('*').order('created_at');
    setState(() {
      bandData = List<Map<String, dynamic>>.from(response);
    });
  }

  List<FlSpot> getChartSpots(String key) {
    return List.generate(
      bandData.length,
          (index) => FlSpot(index.toDouble(), (bandData[index][key] ?? 0).toDouble()),
    );
  }

  Widget buildLineChart(List<FlSpot> spots, Color color, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Container(
          height: 250, // Increased height for better visibility
          width: MediaQuery.of(context).size.width * 1.5, // Make it wider than screen
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 22),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: color,
                  barWidth: 3, // Thicker line
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withOpacity(0.2),
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  String getHealthTip(String key, double value) {
    if (key == 'uv_index') {
      return value > 5 ? 'WARNING: UV Index high. Use sunscreen and avoid exposure.' : 'GOOD: UV Index is safe.';
    } else if (key == 'heart_rate') {
      return (value < 60 || value > 100) ? 'WARNING: Heart rate abnormal. Consider resting or seeking help.' : 'GOOD: Heart rate is normal.';
    } else if (key == 'spo2') {
      return value < 95 ? 'WARNING: Low SpO2. Check breathing and consider medical attention.' : 'GOOD: SpO2 level is normal.';
    }
    return '';
  }

  Future<void> generatePDFReport() async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Generating PDF..."),
            duration: Duration(seconds: 2),
          ));
      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);

      // 2. Capture chart screenshots
      final img1 = await screenshotController1.capture() ?? Uint8List(0);
      final img2 = await screenshotController2.capture() ?? Uint8List(0);
      final img3 = await screenshotController3.capture() ?? Uint8List(0);

      // 3. Build PDF content
      pdf.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Header(text: "Health Report", level: 0),
            pw.Text("Generated on: $formattedDate"),
            pw.SizedBox(height: 20),

            pw.Header(text: "UV Index", level: 1),
            pw.Image(pw.MemoryImage(img1)),
            pw.Text(getHealthTip('uv_index', bandData.last['uv_index'])),

            pw.Header(text: "Heart Rate", level: 1),
            pw.Image(pw.MemoryImage(img2)),
            pw.Text(getHealthTip('heart_rate', bandData.last['heart_rate'])),

            pw.Header(text: "SpO2", level: 1),
            pw.Image(pw.MemoryImage(img3)),
            pw.Text(getHealthTip('spo2', bandData.last['spo2'])),
          ],
        ),
      );

      // 4. Save PDF bytes
      final bytes = await pdf.save();
      final filename = "Health_Report_${now.millisecondsSinceEpoch}.pdf";

      // 5. Save to temporary directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$filename');
      await tempFile.writeAsBytes(bytes);

      // 6. Let user choose save location via share dialog
      final result = await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Save your health report',
        subject: 'Health Report PDF',
      );

      if (result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF shared successfully")),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to generate PDF: ${e.toString()}")),
      );
      debugPrint("PDF generation error: $e");
    }
  }

  void _sharePDF(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'Your Health Report');
    } catch (e) {
      print("Error sharing file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sharing file: $e"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (bandData.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Charts & Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: generatePDFReport,
            tooltip: 'Generate PDF Report',
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Your Health Metrics',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),

            // UV Index Chart - Horizontally scrollable
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('UV Index', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Screenshot(
                controller: screenshotController1,
                child: buildLineChart(getChartSpots('uv_index'), AppColors.teal, "UV Index"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                getHealthTip('uv_index', bandData.last['uv_index'].toDouble()),
                style: TextStyle(
                  fontSize: 14,
                  color: bandData.last['uv_index'] > 5 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Divider(),

            // Heart Rate Chart - Horizontally scrollable
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Heart Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Screenshot(
                controller: screenshotController2,
                child: buildLineChart(getChartSpots('heart_rate'), AppColors.lightBlue, "Heart Rate"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                getHealthTip('heart_rate', bandData.last['heart_rate'].toDouble()),
                style: TextStyle(
                  fontSize: 14,
                  color: (bandData.last['heart_rate'] < 60 || bandData.last['heart_rate'] > 100) ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Divider(),

            // SpO2 Chart - Horizontally scrollable
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('SpO2', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Screenshot(
                controller: screenshotController3,
                child: buildLineChart(getChartSpots('spo2'), Colors.redAccent, "SpO2"),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                getHealthTip('spo2', bandData.last['spo2'].toDouble()),
                style: TextStyle(
                  fontSize: 14,
                  color: bandData.last['spo2'] < 95 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: generatePDFReport,
        icon: const Icon(Icons.download),
        label: const Text('Generate Report'),
      ),
    );
  }
}