import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'detection_result.dart';
import 'camera_service.dart';
import 'detection_api_service.dart';
import 'control_button.dart';

class CameraTestPage extends StatefulWidget {
  final String? initialMode;
  const CameraTestPage({super.key, this.initialMode});

  @override
  State<CameraTestPage> createState() => _CameraTestPageState();
}

class _CameraTestPageState extends State<CameraTestPage> {
  late final WebViewController _controller;
  bool _isStreaming = false;
  bool _isLoading = false;
  bool _hasError = false;

  // Real-time Monitoring & Mode state
  String _aiMode = 'object'; // 'object', 'scene_vit', 'scene_blip', 'scene_florence'
  late String _runningMode;
  bool _modeInitialized = false;
  Timer? _monitoringTimer;
  bool _isDetecting = false; // prevents overlapping requests
  int _captureIntervalSeconds = 3;
  bool _debugMode = false;
  bool _isBackendHealthy = false;
  
  // Results
  List<DetectionItem> _latestDetections = [];
  String _latestSceneSummary = '';
  String _lastDetectionTime = '';
  double _lastProcessingTimeMs = 0;
  String _detectionErrorMessage = '';
  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _runningMode = widget.initialMode == 'scene' ? 'scene' : 'object';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() {
          _isLoading = true;
          _hasError = false;
        }),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (_) => setState(() {
          _isLoading = false;
          _hasError = true;
        }),
      ));

    // Apply initial mode from constructor
    if (widget.initialMode != null) {
      _runningMode = widget.initialMode == 'scene' ? 'scene' : 'object';
      _applyInitialMode(widget.initialMode!);
      _modeInitialized = true;
    }

    _ipController = TextEditingController();
    _initIp();
    _checkBackendHealth();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_modeInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments as Map?;
      final mode = args?['mode'] as String?;
      if (mode != null) {
        _runningMode = mode == 'scene' ? 'scene' : 'object';
        _applyInitialMode(mode);
      } else {
        _runningMode = widget.initialMode == 'scene' ? 'scene' : 'object';
        _applyInitialMode(_runningMode);
      }
      _modeInitialized = true;
    }
  }

  void _applyInitialMode(String mode) {
    if (mode == 'object') {
      _aiMode = 'object';
      _captureIntervalSeconds = 3;
    } else if (mode == 'scene' || mode == 'scene_vit') {
      _aiMode = 'scene_vit';
      _captureIntervalSeconds = 5;
    } else if (mode == 'scene_blip') {
      _aiMode = 'scene_blip';
      _captureIntervalSeconds = 5;
    } else if (mode == 'scene_florence') {
      _aiMode = 'scene_florence';
      _captureIntervalSeconds = 5;
    }
  }

  Future<void> _initIp() async {
    await CameraService.loadIp();
    if (mounted) {
      setState(() {
        _ipController.text = CameraService.espIp;
      });
    }
  }

  @override
  void dispose() {
    _stopMonitoringTimer();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _checkBackendHealth() async {
    final healthy = await DetectionApiService.checkHealth();
    if (mounted) {
      setState(() {
        _isBackendHealthy = healthy;
      });
    }
  }

  void _startStream() {
    setState(() {
      _isStreaming = true;
      _hasError = false;
      _detectionErrorMessage = '';
      _latestDetections = [];
      _latestSceneSummary = '';
    });
    _controller.loadRequest(Uri.parse(CameraService.streamUrl));
    _startMonitoringTimer();
  }

  void _stopStream() {
    _stopMonitoringTimer();
    setState(() {
      _isStreaming = false;
      _isLoading = false;
      _hasError = false;
      _isDetecting = false;
      _latestDetections = [];
      _latestSceneSummary = '';
    });
    _controller.loadRequest(Uri.parse('about:blank'));
  }

  void _setAiMode(String mode) {
    if (_aiMode == mode) return;
    
    _stopMonitoringTimer();
    setState(() {
      _aiMode = mode;
      _isDetecting = false;
      _latestDetections = [];
      _latestSceneSummary = '';
      _detectionErrorMessage = '';
      _captureIntervalSeconds = (mode.startsWith('scene')) ? 5 : 3;
    });
    
    if (_isStreaming) {
      _startMonitoringTimer();
    }
  }

  void _startMonitoringTimer() {
    _stopMonitoringTimer();
    _monitoringTimer = Timer.periodic(
      Duration(seconds: _captureIntervalSeconds),
      (_) => _processNextFrame(),
    );
  }

  void _stopMonitoringTimer() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  void _updateInterval(int seconds) {
    setState(() {
      _captureIntervalSeconds = seconds;
    });
    if (_isStreaming) {
      _startMonitoringTimer();
    }
  }

  Future<void> _processNextFrame() async {
    if (!_isStreaming || _isDetecting) return;

    setState(() {
      _isDetecting = true;
    });

    final Uint8List? imageBytes = await DetectionApiService.captureFrame();

    if (imageBytes != null && _isStreaming) {
      if (_runningMode == 'object') {
        final response = await DetectionApiService.detectObject(
          imageBytes,
          debug: _debugMode,
        );

        if (mounted && _isStreaming && _runningMode == 'object') {
          setState(() {
            if (response.success) {
              _latestDetections = response.detections;
              _lastDetectionTime = response.timestamp;
              _lastProcessingTimeMs = response.processingTimeMs;
              _detectionErrorMessage = '';
            } else {
              _detectionErrorMessage = response.error ?? 'Detection failure';
            }
          });
        }
      } else if (_runningMode == 'scene') {
        String modelType = 'vit';
        if (_aiMode == 'scene_blip') modelType = 'blip';
        else if (_aiMode == 'scene_florence') modelType = 'florence';

        final response = await DetectionApiService.generateSceneSummary(
          imageBytes, 
          modelType: modelType
        );

        if (mounted && _isStreaming && _runningMode == 'scene') {
          setState(() {
            if (response.success) {
              _latestSceneSummary = response.summary;
              _lastDetectionTime = response.timestamp;
              _lastProcessingTimeMs = response.processingTimeMs;
              _detectionErrorMessage = '';
            } else {
              _detectionErrorMessage = response.error ?? 'Scene summary failure';
            }
          });
        }
      }
    } else if (imageBytes == null && mounted && _isStreaming) {
      setState(() {
        _detectionErrorMessage = 'Failed to capture frame from ESP32';
      });
    }

    if (mounted && _isStreaming) {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  String _formatTimestamp(String timestamp) {
    if (timestamp.isEmpty) return '--';
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _runningMode == 'object' ? 'Object Detection Mode' : 'Scene Description Mode',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.dns_rounded,
                  size: 16,
                  color: _isBackendHealthy ? Colors.greenAccent : Colors.redAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  _isBackendHealthy ? 'API OK' : 'API ERR',
                  style: TextStyle(
                    color: _isBackendHealthy ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white70),
                  onPressed: _checkBackendHealth,
                  tooltip: 'Check Backend Health',
                )
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top Status Bar: Streaming Indicator & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: _isStreaming ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isStreaming ? 'Live Monitoring' : 'Stream Offline',
                        style: TextStyle(
                          color: _isStreaming ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (_isDetecting)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blueAccent,
                            ),
                          ),
                        )
                    ],
                  ),
                  // Mode Indicator & Interval
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _aiMode == 'object' ? 'YOLO (3s)' : (_aiMode == 'scene_vit' ? 'ViT Scene (5s)' : (_aiMode == 'scene_blip' ? 'BLIP Scene (5s)' : 'Florence (5s)')),
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: _captureIntervalSeconds,
                        dropdownColor: const Color(0xFF2D2D2D),
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1s')),
                          DropdownMenuItem(value: 3, child: Text('3s')),
                          DropdownMenuItem(value: 5, child: Text('5s')),
                          DropdownMenuItem(value: 10, child: Text('10s')),
                        ],
                        onChanged: (val) {
                          if (val != null) _updateInterval(val);
                        },
                      ),
                      const SizedBox(width: 4),
                      if (_aiMode == 'object')
                        Tooltip(
                          message: 'Debug Mode (Save annotated images on backend)',
                          child: FilterChip(
                            label: const Text('Debug', style: TextStyle(fontSize: 11)),
                            selected: _debugMode,
                            selectedColor: Colors.blueAccent.withOpacity(0.3),
                            checkmarkColor: Colors.blueAccent,
                            onSelected: (val) => setState(() => _debugMode = val),
                            backgroundColor: Colors.white12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Inline IP editing UI
              Card(
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.router, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: "Camera IP",
                            labelStyle: TextStyle(color: Colors.white54),
                            hintText: "e.g. 192.168.1.10",
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (value) async {
                            final newIp = _ipController.text.trim();
                            if (newIp.isNotEmpty) {
                              await CameraService.saveIp(newIp);
                              if (_isStreaming) {
                                _stopStream();
                                _startStream();
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final newIp = _ipController.text.trim();
                          if (newIp.isNotEmpty) {
                            await CameraService.saveIp(newIp);
                            if (_isStreaming) {
                              _stopStream();
                              _startStream();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IP Saved!")));
                            }
                          }
                        },
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text("Save"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Stream preview card
              Expanded(
                flex: 5,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isStreaming
                          ? Colors.blueAccent.withOpacity(0.6)
                          : Colors.white12,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      if (_isStreaming)
                        WebViewWidget(controller: _controller),

                      if (!_isStreaming)
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off, color: Colors.white24, size: 72),
                              SizedBox(height: 12),
                              Text('Stream is Off', style: TextStyle(color: Colors.white38, fontSize: 18)),
                              SizedBox(height: 6),
                              Text('Press ON to start real-time monitoring', style: TextStyle(color: Colors.white24, fontSize: 13)),
                            ],
                          ),
                        ),

                      if (_isLoading && _isStreaming)
                        Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.blueAccent),
                                SizedBox(height: 14),
                                Text('Connecting to ESP32-CAM Stream...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),

                      if (_hasError && _isStreaming)
                        Container(
                          color: Colors.black87,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
                                const SizedBox(height: 12),
                                const Text(
                                  'Cannot reach ESP32-CAM\nCheck WiFi connection',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.redAccent, fontSize: 15),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _startStream,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reconnect'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // AI Mode Selector Bar
              if (_runningMode == 'scene')
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _setAiMode('scene_vit'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _aiMode == 'scene_vit' ? Colors.blueAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 16,
                                  color: _aiMode == 'scene_vit' ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ViT',
                                  style: TextStyle(
                                    color: _aiMode == 'scene_vit' ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _setAiMode('scene_blip'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _aiMode == 'scene_blip' ? Colors.blueAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_search_rounded,
                                  size: 16,
                                  color: _aiMode == 'scene_blip' ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'BLIP',
                                  style: TextStyle(
                                    color: _aiMode == 'scene_blip' ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _setAiMode('scene_florence'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _aiMode == 'scene_florence' ? Colors.blueAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.document_scanner_rounded,
                                  size: 16,
                                  color: _aiMode == 'scene_florence' ? Colors.white : Colors.white70,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Florence',
                                  style: TextStyle(
                                    color: _aiMode == 'scene_florence' ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // AI Results UI Card
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _aiMode == 'object' ? Icons.insights_rounded : Icons.auto_awesome_rounded,
                                color: Colors.blueAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _aiMode == 'object' ? 'YOLO Detections (${_latestDetections.length})' : (_aiMode == 'scene_vit' ? 'ViT Scene Summary' : (_aiMode == 'scene_blip' ? 'BLIP Scene Summary' : 'Florence Scene Summary')),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          if (_lastDetectionTime.isNotEmpty)
                            Text(
                              'Updated: ${_formatTimestamp(_lastDetectionTime)} (${_lastProcessingTimeMs}ms)',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_detectionErrorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _detectionErrorMessage,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Mode Specific Results
                      if (_runningMode == 'object')
                        Expanded(
                          child: !_isStreaming
                              ? const Center(
                                  child: Text('Start monitoring to see object detections', style: TextStyle(color: Colors.white38, fontSize: 14)),
                                )
                              : _latestDetections.isEmpty
                                  ? Center(
                                      child: Text(_isDetecting ? 'Analyzing frame...' : 'No objects detected in view', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                                    )
                                  : ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _latestDetections.length,
                                      itemBuilder: (context, index) {
                                        final item = _latestDetections[index];
                                        final isHighConf = item.confidence >= 0.70;
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: isHighConf ? Colors.greenAccent.withOpacity(0.4) : Colors.white12),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.center_focus_strong_rounded,
                                                    color: isHighConf ? Colors.greenAccent : Colors.blueAccent,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    item.label.toUpperCase(),
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 60,
                                                    child: LinearProgressIndicator(
                                                      value: item.confidence,
                                                      backgroundColor: Colors.white12,
                                                      color: isHighConf ? Colors.greenAccent : Colors.blueAccent,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    '${(item.confidence * 100).toInt()}%',
                                                    style: TextStyle(color: isHighConf ? Colors.greenAccent : Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                ],
                                              )
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),

                      if (_runningMode == 'scene')
                        Expanded(
                          child: !_isStreaming
                              ? const Center(
                                  child: Text('Start monitoring to see scene summary', style: TextStyle(color: Colors.white38, fontSize: 14)),
                                )
                              : _latestSceneSummary.isEmpty
                                  ? Center(
                                      child: Text(_isDetecting ? 'Generating scene summary...' : 'No summary generated yet', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                                    )
                                  : Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 1.5),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent, size: 36),
                                          const SizedBox(height: 16),
                                          Text(
                                            _latestSceneSummary,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
                                          ),
                                        ],
                                      ),
                                    ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ON / OFF controls
              Row(
                children: [
                  Expanded(
                    child: ControlButton(
                      label: 'ON',
                      icon: Icons.play_arrow_rounded,
                      color: const Color(0xFF2E7D32),
                      onPressed: _isStreaming ? null : _startStream,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ControlButton(
                      label: 'OFF',
                      icon: Icons.stop_rounded,
                      color: const Color(0xFFC62828),
                      onPressed: _isStreaming ? _stopStream : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                'Stream: ${CameraService.streamUrl} | Backend: ${CameraService.backendUrl}',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
