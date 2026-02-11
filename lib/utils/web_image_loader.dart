import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Web-safe image loader that handles CORS issues
class WebImageLoader {
  /// Loads an image with proper CORS handling for web
  /// Falls back to standard loading for mobile platforms
  /// Returns error widget if imageUrl is null or empty
  static Widget loadImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    // Handle null or empty URLs
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
    }

    if (kIsWeb) {
      // For web, use Image.network with proper error handling
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Image load error (web): $error');
          return errorWidget ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
              );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
        },
      );
    } else {
      // For mobile, use CachedNetworkImage for better performance
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
            placeholder ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
        errorWidget: (context, url, error) =>
            errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey[300],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
      );
    }
  }

  /// Loads a circular avatar image with CORS handling
  /// Returns fallback widget for null/empty URLs
  static Widget loadAvatar({
    String? imageUrl,
    required double radius,
    String? fallbackText,
    Color? backgroundColor,
    Color? textColor,
  }) {
    // Handle null or empty URLs with fallback
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return ClipOval(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          color: backgroundColor ?? Colors.grey[400],
          child: Center(
            child: Text(
              fallbackText?.isNotEmpty == true
                  ? fallbackText![0].toUpperCase()
                  : 'U',
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: loadImage(
          imageUrl: imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: Container(
            width: radius * 2,
            height: radius * 2,
            color: backgroundColor ?? Colors.grey[300],
            child: Center(
              child: Text(
                fallbackText?.isNotEmpty == true
                    ? fallbackText![0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Creates an ImageProvider with proper CORS handling for web
  /// Returns null if imageUrl is null/empty
  static ImageProvider? getImageProvider(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return null;
    }

    if (kIsWeb) {
      return NetworkImage(imageUrl);
    } else {
      return CachedNetworkImageProvider(imageUrl);
    }
  }
}
