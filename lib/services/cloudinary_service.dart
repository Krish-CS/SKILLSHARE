import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
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
      print('Error uploading image to Cloudinary: $e');
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
        print('Error uploading image: $e');
      }
    }
    
    return urls;
  }
}
