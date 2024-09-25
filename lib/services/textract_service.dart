import 'dart:typed_data';
import 'package:http/http.dart' as http;

class TextractService {
  final String tokenServiceUrl;

  TextractService(this.tokenServiceUrl);
  
  Future<String> extractText(Uint8List imageBytes) async {
    try {
      var response = await http.post(
        Uri.parse('$tokenServiceUrl/textract/extract-text'),
        headers: {
          'Content-Type': 'application/octet-stream', // Specify content type for binary data
        },
        body: imageBytes,
      );

      if (response.statusCode == 200) {
        return response.body; // The extracted text in JSON format
      } else {
        throw Exception('Failed to extract text. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }
}
