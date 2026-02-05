import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LabelDetectionService {
  static const String baseUrl = "http://192.168.1.20:8000";

  static Future<List<int>?> detectLive(File imageFile) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/detect-live'),
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final response = await request.send();
    if (response.statusCode != 200) return null;

    final body = await response.stream.bytesToString();
    final data = json.decode(body);

    if (data["box"] == null) return null;
    return List<int>.from(data["box"]);
  }
}
