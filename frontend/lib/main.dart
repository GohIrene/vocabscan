import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const VocabScanApp());
}

class VocabScanApp extends StatelessWidget {
  const VocabScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VocabScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C6CF2),
        ),
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const VocabScanLandingPage(),
    );
  }
}

class VocabScanLandingPage extends StatefulWidget {
  const VocabScanLandingPage({super.key});

  @override
  State<VocabScanLandingPage> createState() => _VocabScanLandingPageState();
}

class _VocabScanLandingPageState extends State<VocabScanLandingPage> {
  static final Uri _healthUrl = Uri.parse('http://127.0.0.1:5000/health');

  bool _isCheckingBackend = false;
  String _connectionResult = 'Click the button to test your Flask backend.';
  bool? _isConnected;

  Future<void> _testBackendConnection() async {
    setState(() {
      _isCheckingBackend = true;
      _connectionResult = 'Checking backend connection...';
      _isConnected = null;
    });

    try {
      // Send a GET request to the Flask health endpoint.
      final response = await http.get(_healthUrl);

      // Decode the response with UTF-8 so multilingual text stays readable.
      final responseText = utf8.decode(response.bodyBytes);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseText);
        final serviceName = data['service'] ?? 'VocabScan Flask API';

        setState(() {
          _isConnected = true;
          _connectionResult = 'Backend connected: $serviceName';
        });
      } else {
        setState(() {
          _isConnected = false;
          _connectionResult =
              'Backend error ${response.statusCode}: $responseText';
        });
      }
    } catch (error) {
      // Show a clear message when Flask is not running or the request is blocked.
      setState(() {
        _isConnected = false;
        _connectionResult =
            'Could not connect to backend. Make sure Flask is running at '
            'http://127.0.0.1:5000. Error: $error';
      });
    } finally {
      setState(() {
        _isCheckingBackend = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultColor = switch (_isConnected) {
      true => const Color(0xFF2E7D5C),
      false => const Color(0xFFB54848),
      null => const Color(0xFF4D5573),
    };

    final resultBackground = switch (_isConnected) {
      true => const Color(0xFFDDF8E8),
      false => const Color(0xFFFFE4E4),
      null => const Color(0xFFE9E7FF),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF7F1FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 34,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_stories_rounded,
                      color: Color(0xFF7C6CF2),
                      size: 72,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'VocabScan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF17234D),
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'AI-based trilingual vocabulary learning app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF65708C),
                        fontSize: 18,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed:
                          _isCheckingBackend ? null : _testBackendConnection,
                      icon: _isCheckingBackend
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.cloud_done_rounded),
                      label: const Text('Test Backend Connection'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF80DFA7),
                        foregroundColor: const Color(0xFF17234D),
                        disabledBackgroundColor: const Color(0xFFBFEFD4),
                        disabledForegroundColor: const Color(0xFF5D6680),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: resultBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _connectionResult,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: resultColor,
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
