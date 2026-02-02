import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../utils/app_constants.dart';
import '../utils/cloudinary_config.dart';

class StorageService {
  final Uuid _uuid = const Uuid();
  late CloudinaryPublic _cloudinary;

  StorageService() {
    _cloudinary = CloudinaryPublic(
      CloudinaryConfig.cloudName,
      CloudinaryConfig.uploadPreset,
      cache: false,
    );
  }

  /// Upload profile photo to Cloudinary
  Future<String> uploadProfilePhoto(File file, String userId) async {
    final compressed = await _compressImage(file);
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        compressed.path,
        folder: CloudinaryConfig.profilePhotosFolder,
        publicId: '${userId}_${_uuid.v4()}',
      ),
    );
    return response.secureUrl;
  }

  /// Upload portfolio images to Cloudinary
  Future<String> uploadPortfolioImage(File file, String userId) async {
    final compressed = await _compressImage(file);
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        compressed.path,
        folder: '${CloudinaryConfig.portfolioFolder}/$userId',
        publicId: _uuid.v4(),
      ),
    );
    return response.secureUrl;
  }

  /// Upload product images to Cloudinary
  Future<String> uploadProductImage(File file, String userId) async {
    final compressed = await _compressImage(file);
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        compressed.path,
        folder: '${CloudinaryConfig.productsFolder}/$userId',
        publicId: _uuid.v4(),
      ),
    );
    return response.secureUrl;
  }

  /// Upload chat media to Cloudinary
  Future<String> uploadChatMedia(File file, String chatId) async {
    final compressed = await _compressImage(file);
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        compressed.path,
        folder: '${CloudinaryConfig.chatFolder}/$chatId',
        publicId: _uuid.v4(),
      ),
    );
    return response.secureUrl;
  }

  /// Upload verification documents to Cloudinary
  Future<String> uploadVerificationDocument(File file, String userId) async {
    final compressed = await _compressImage(file);
    final response = await _cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        compressed.path,
        folder: '${CloudinaryConfig.verificationFolder}/$userId',
        publicId: _uuid.v4(),
      ),
    );
    return response.secureUrl;
  }

  /// Compress image before upload (reduces size by ~70%)
  Future<File> _compressImage(File file) async {
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf('.');
    final splitted = filePath.substring(0, lastIndex);
    final outPath = '${splitted}_compressed${path.extension(filePath)}';

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      outPath,
      quality: 85,
      minWidth: 1920,
      minHeight: 1080,
    );

    return result != null ? File(result.path) : file;
  }

  /// Delete file - Cloudinary deletion requires API credentials
  /// For MVP, images remain stored (free tier allows this)
  Future<void> deleteFile(String fileUrl) async {
    // Note: Implement server-side deletion with Admin API for production
  }

  /// Delete multiple files
  Future<void> deleteFiles(List<String> fileUrls) async {
    for (final url in fileUrls) {
      await deleteFile(url);
    }
  }

  /// Validate file size
  bool validateFileSize(File file, int maxSize) {
    return file.lengthSync() <= maxSize;
  }

  /// Validate image size (10MB max for smooth upload)
  bool validateImageSize(File file) {
    return validateFileSize(file, AppConstants.maxImageSize);
  }

  /// Validate video size
  bool validateVideoSize(File file) {
    return validateFileSize(file, AppConstants.maxVideoSize);
  }
}
