import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:http/http.dart' as http;
import '../utils/cloudinary_config.dart';

class CloudinaryService {
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    CloudinaryConfig.cloudName,
    CloudinaryConfig.uploadPreset,
    cache: false,
  );

  /// Upload an image to Cloudinary
  /// [imageFile] - The image file to upload
  /// [folder] - Optional folder name in Cloudinary (e.g., 'profiles', 'portfolios', 'products', 'chat_media')
  /// Returns the URL of the uploaded image or null if upload fails
  Future<String?> uploadImage(
    File imageFile, {
    String folder = 'uploads',
  }) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading image to Cloudinary: $e');
      return null;
    }
  }

  /// Upload raw bytes to Cloudinary (web-friendly)
  /// [bytes] - The image bytes to upload
  /// [folder] - Optional folder name in Cloudinary
  /// [filename] - Optional filename for the upload
  Future<String?> uploadImageBytes(
    Uint8List bytes, {
    String folder = 'uploads',
    String? filename,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.imageUploadUrl),
      );
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.fields['folder'] = folder;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename:
              filename ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      }

      debugPrint(
          'Cloudinary upload failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error uploading image bytes to Cloudinary: $e');
      return null;
    }
  }

  /// Upload video to Cloudinary
  /// Returns the secure URL of the uploaded video or null if failed
  Future<String?> uploadVideo(File videoFile,
      {String folder = 'uploads'}) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          videoFile.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Video,
        ),
      );

      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading video to Cloudinary: $e');
      return null;
    }
  }

  /// Upload multiple images to Cloudinary
  /// [imageFiles] - List of image files to upload
  /// [folder] - Optional folder name in Cloudinary
  /// Returns a list of URLs of the uploaded images
  Future<List<String>> uploadMultipleImages(
    List<File> imageFiles, {
    String folder = 'uploads',
  }) async {
    List<String> urls = [];

    for (var imageFile in imageFiles) {
      try {
        final url = await uploadImage(imageFile, folder: folder);
        if (url != null) {
          urls.add(url);
        }
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }

    return urls;
  }
}

