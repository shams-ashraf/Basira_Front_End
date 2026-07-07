import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class CameraStreamWidget extends StatelessWidget {
  final String streamUrl;
  final bool isStreaming;

  const CameraStreamWidget({
    super.key,
    required this.streamUrl,
    required this.isStreaming,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: isStreaming
          ? SizedBox.expand(
              child: Mjpeg(
                isLive: true,
                stream: streamUrl,
                error: (context, error, stack) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'Connection Error\nCheck network & ESP32',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.redAccent, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                },
                loading: (context) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.blueAccent),
                        SizedBox(height: 12),
                        Text(
                          'Connecting to stream...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_off, color: Colors.white54, size: 64),
                  SizedBox(height: 12),
                  Text(
                    'Stream is Offline',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ),
            ),
    );
  }
}
