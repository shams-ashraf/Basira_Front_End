import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  late TextEditingController _serverIpController;
  late TextEditingController _aiServerIpController;
  late TextEditingController _esp32IpController;
  double _captureInterval = 3;
  double _serverTimeout = 8;
  int _captureMaxWidth = 1280;

  double _obstacleThreshold = 100;
  double _faceThreshold = 0.5;
  double _yoloThreshold = 0.3;
  String _generationMode = 'greedy';

  final List<int> _maxWidthOptions = [640, 1280, 1920];

  @override
  void initState() {
    super.initState();
    _serverIpController = TextEditingController(text: AppConfig.serverIp);
    _aiServerIpController =
        TextEditingController(text: AppConfig.aiLabServerIp);
    _esp32IpController = TextEditingController(text: AppConfig.esp32Ip);
    _captureInterval = AppConfig.captureIntervalSeconds.toDouble();
    _serverTimeout = AppConfig.serverTimeoutSeconds.toDouble();
    _captureMaxWidth = AppConfig.captureMaxWidth;
    _loadSavedSettings();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _captureInterval =
            (prefs.getInt('esp32_capture_interval') ?? 3).toDouble();
        _serverTimeout =
            (prefs.getInt('server_timeout_seconds') ?? 8).toDouble();
        _captureMaxWidth = prefs.getInt('esp32_capture_max_width') ?? 1280;
        if (!_maxWidthOptions.contains(_captureMaxWidth)) {
          _captureMaxWidth = 1280;
        }
        _obstacleThreshold = (prefs.getInt('esp32_obstacle_threshold_cm') ?? 100).toDouble();
        _faceThreshold = prefs.getDouble('face_recognition_threshold') ?? 0.5;
        _yoloThreshold = prefs.getDouble('yolo_confidence_threshold') ?? 0.3;
        _generationMode = prefs.getString('ai_generation_mode') ?? 'greedy';
      });
    }
  }

  @override
  void dispose() {
    _serverIpController.dispose();
    _aiServerIpController.dispose();
    _esp32IpController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final ip = _serverIpController.text.trim();
    final aiIp = _aiServerIpController.text.trim();
    final espIp = _esp32IpController.text.trim();

    await AppConfig.saveSettings(
      server: ip.isNotEmpty ? ip : AppConfig.serverIp,
      esp: espIp.isNotEmpty ? espIp : AppConfig.esp32Ip,
      aiServer: aiIp.isNotEmpty ? aiIp : AppConfig.aiLabServerIp,
      interval: _captureInterval.round(),
      maxWidth: _captureMaxWidth,
      timeout: _serverTimeout.round(),
      obstacleThresholdCm: _obstacleThreshold.round(),
      faceRecognitionThreshold: _faceThreshold,
      yoloConfidenceThreshold: _yoloThreshold,
      generationMode: _generationMode,
    );
    await AppConfig.load();

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/language-select');
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white54),
      prefixIcon: Icon(icon, color: Colors.white54),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF17B890), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text("System Setup / إعداد النظام",
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.settings_ethernet_rounded,
                size: 64,
                color: Color(0xFF17B890),
              ),
              const SizedBox(height: 24),
              const Text(
                "Configure System / اضبط النظام",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter the server addresses and configure camera settings.\nأدخل عناوين السيرفرات واضبط إعدادات الكاميرا.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // ── Server Section ──
              _sectionHeader("Servers / السيرفرات", Icons.dns_rounded),
              const SizedBox(height: 12),

              TextField(
                controller: _serverIpController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  labelText:
                      "Backend Server URL / عنوان السيرفر الأساسي",
                  icon: Icons.computer,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aiServerIpController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  labelText: "AI Server URL / عنوان سيرفر الذكاء",
                  icon: Icons.memory,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _generationMode,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: _inputDecoration(
                  labelText: "Generation Mode / نمط التوليد",
                  icon: Icons.speed,
                ),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'greedy', child: Text('Greedy (Fast)')),
                  DropdownMenuItem(value: 'beam', child: Text('Beam (Accurate)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _generationMode = val);
                },
              ),

              const SizedBox(height: 28),

              // ── Camera Section ──
              _sectionHeader("Camera / الكاميرا", Icons.videocam_rounded),
              const SizedBox(height: 12),

              TextField(
                controller: _esp32IpController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  labelText: "ESP32-CAM IP / عنوان الكاميرا",
                  icon: Icons.camera_alt,
                ),
              ),

              const SizedBox(height: 20),

              // Capture Interval Slider
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Capture Interval / فترة الالتقاط",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17B890).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${_captureInterval.round()}s",
                            style: const TextStyle(
                              color: Color(0xFF17B890),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF17B890),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFF17B890),
                        overlayColor: const Color(0xFF17B890).withOpacity(0.2),
                      ),
                      child: Slider(
                        min: 1,
                        max: 10,
                        divisions: 9,
                        value: _captureInterval,
                        onChanged: (val) =>
                            setState(() => _captureInterval = val),
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("1s", style: TextStyle(color: Colors.white30, fontSize: 11)),
                        Text("10s", style: TextStyle(color: Colors.white30, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Max Width Dropdown
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Max Width / أقصى عرض",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17B890).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<int>(
                        value: _captureMaxWidth,
                        dropdownColor: const Color(0xFF1E1E1E),
                        underline: const SizedBox(),
                        style: const TextStyle(
                          color: Color(0xFF17B890),
                          fontWeight: FontWeight.bold,
                        ),
                        items: _maxWidthOptions
                            .map((w) => DropdownMenuItem(
                                  value: w,
                                  child: Text("${w}px"),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _captureMaxWidth = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Server Timeout Slider
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Server Timeout / مهلة السيرفر",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17B890).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${_serverTimeout.round()}s",
                            style: const TextStyle(
                              color: Color(0xFF17B890),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF17B890),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFF17B890),
                        overlayColor: const Color(0xFF17B890).withOpacity(0.2),
                      ),
                      child: Slider(
                        min: 1,
                        max: 20,
                        divisions: 19,
                        value: _serverTimeout,
                        onChanged: (val) =>
                            setState(() => _serverTimeout = val),
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("1s", style: TextStyle(color: Colors.white30, fontSize: 11)),
                        Text("20s", style: TextStyle(color: Colors.white30, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── AI Thresholds Section ──
              _sectionHeader("AI Thresholds / حدود الذكاء", Icons.tune_rounded),
              const SizedBox(height: 12),

              // Obstacle Threshold Slider
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Obstacle Alert Distance / مسافة تنبيه العائق",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17B890).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${_obstacleThreshold.round()}cm",
                            style: const TextStyle(
                              color: Color(0xFF17B890),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF17B890),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFF17B890),
                        overlayColor: const Color(0xFF17B890).withOpacity(0.2),
                      ),
                      child: Slider(
                        min: 50,
                        max: 300,
                        divisions: 25,
                        value: _obstacleThreshold,
                        onChanged: (val) => setState(() => _obstacleThreshold = val),
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("50cm", style: TextStyle(color: Colors.white30, fontSize: 11)),
                        Text("300cm", style: TextStyle(color: Colors.white30, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Face Confidence Slider
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Face Confidence / دقة الوجوه",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17B890).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${(_faceThreshold * 100).round()}%",
                            style: const TextStyle(
                              color: Color(0xFF17B890),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF17B890),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFF17B890),
                        overlayColor: const Color(0xFF17B890).withOpacity(0.2),
                      ),
                      child: Slider(
                        min: 0.1,
                        max: 0.9,
                        divisions: 8,
                        value: _faceThreshold,
                        onChanged: (val) => setState(() => _faceThreshold = val),
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("10%", style: TextStyle(color: Colors.white30, fontSize: 11)),
                        Text("90%", style: TextStyle(color: Colors.white30, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // YOLO Confidence Slider
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Object Confidence / دقة الأشياء",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17B890).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${(_yoloThreshold * 100).round()}%",
                            style: const TextStyle(
                              color: Color(0xFF17B890),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFF17B890),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFF17B890),
                        overlayColor: const Color(0xFF17B890).withOpacity(0.2),
                      ),
                      child: Slider(
                        min: 0.1,
                        max: 0.9,
                        divisions: 8,
                        value: _yoloThreshold,
                        onChanged: (val) => setState(() => _yoloThreshold = val),
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("10%", style: TextStyle(color: Colors.white30, fontSize: 11)),
                        Text("90%", style: TextStyle(color: Colors.white30, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF17B890),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Save & Continue / حفظ ومتابعة",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF17B890), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF17B890),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Divider(color: Colors.white12, thickness: 1),
        ),
      ],
    );
  }
}
