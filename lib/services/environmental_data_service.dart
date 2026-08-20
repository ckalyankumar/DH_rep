import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

class EnvironmentalDataService {
  late String weatherApiKey;

  EnvironmentalDataService() {
    weatherApiKey = dotenv.env['WEATHER_API_KEY'] ?? '';

    if (weatherApiKey.isEmpty) {
      // #region agent log
      try {
        File('debug-7bd69c.log').writeAsStringSync(
          '${jsonEncode({
                'sessionId': '7bd69c',
                'runId': 'pre-fix',
                'hypothesisId': 'H3',
                'location':
                    'lib/services/environmental_data_service.dart:constructor',
                'message': 'missing WEATHER_API_KEY',
                'data': {},
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              })}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion
      throw Exception('WEATHER_API_KEY not found in .env file');
    }
  }

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // #region agent log
      try {
        File('debug-7bd69c.log').writeAsStringSync(
          '${jsonEncode({
                'sessionId': '7bd69c',
                'runId': 'pre-fix',
                'hypothesisId': 'H3',
                'location':
                    'lib/services/environmental_data_service.dart:getCurrentLocation',
                'message': 'location services disabled',
                'data': {},
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              })}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion
      throw Exception('Location services are disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      // #region agent log
      try {
        File('debug-7bd69c.log').writeAsStringSync(
          '${jsonEncode({
                'sessionId': '7bd69c',
                'runId': 'pre-fix',
                'hypothesisId': 'H3',
                'location':
                    'lib/services/environmental_data_service.dart:getCurrentLocation',
                'message': 'location permission permanently denied',
                'data': {'permission': permission.toString()},
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              })}\n',
          mode: FileMode.append,
          flush: true,
        );
      } catch (_) {}
      // #endregion
      throw Exception('Location permission permanently denied');
    }

    final position = await Geolocator.getCurrentPosition();
    // #region agent log
    try {
      File('debug-7bd69c.log').writeAsStringSync(
        '${jsonEncode({
              'sessionId': '7bd69c',
              'runId': 'pre-fix',
              'hypothesisId': 'H3',
              'location':
                  'lib/services/environmental_data_service.dart:getCurrentLocation',
              'message': 'location acquired',
              'data': {
                'latitude': position.latitude,
                'longitude': position.longitude,
              },
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            })}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    // #endregion
    return position;
  }

  Future<Map<String, dynamic>> getWeatherData(
      double latitude, double longitude) async {
    try {
      final String url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$weatherApiKey&units=metric';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Weather API failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAllEnvironmentalData() async {
    try {
      Position position = await getCurrentLocation();

      final weatherData =
          await getWeatherData(position.latitude, position.longitude);

      return {
        'weather': weatherData,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      rethrow;
    }
  }
}
