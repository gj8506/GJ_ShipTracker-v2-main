import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';

abstract class ImageStorageService {
  Future<String> uploadImage(File file, {String? folder});
  Future<List<String>> uploadMultipleImages(List<File> files, {String? folder});
}

class CloudinaryImageStorageService implements ImageStorageService {
  final String cloudName;
  final String uploadPreset;

  CloudinaryImageStorageService({
    String? cloudName,
    String? uploadPreset,
  })  : cloudName = cloudName ?? AppConstants.cloudinaryCloudName,
        uploadPreset = uploadPreset ?? AppConstants.cloudinaryUploadPreset;

  @override
  Future<String> uploadImage(File file, {String? folder}) async {
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset;

    if (folder != null && folder.isNotEmpty) {
      request.fields['folder'] = folder;
    }

    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['secure_url'] as String;
    } else {
      throw Exception(
          'Image upload failed (${response.statusCode}): ${response.body}');
    }
  }

  @override
  Future<List<String>> uploadMultipleImages(List<File> files,
      {String? folder}) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadImage(file, folder: folder);
      urls.add(url);
    }
    return urls;
  }
}

// Riverpod Provider for Image Storage
final imageStorageServiceProvider = Provider<ImageStorageService>((ref) {
  return CloudinaryImageStorageService();
});
