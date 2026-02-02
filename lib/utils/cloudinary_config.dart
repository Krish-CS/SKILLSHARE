/// Cloudinary Configuration
/// 
/// Sign up at: https://cloudinary.com/users/register/free
/// Get credentials from: Dashboard → API Keys
class CloudinaryConfig {
  // Your Cloudinary credentials
  static const String cloudName = 'dlmpcyi79'; // Your cloud name from dashboard
  static const String uploadPreset = 'skillshare_preset'; // You need to create this (see below)
  
  // Upload URLs
  static const String imageUploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  static const String videoUploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/video/upload';
  
  // Folder structure
  static const String profilePhotosFolder = 'skillshare/profiles';
  static const String portfolioFolder = 'skillshare/portfolios';
  static const String productsFolder = 'skillshare/products';
  static const String verificationFolder = 'skillshare/verification';
  static const String chatFolder = 'skillshare/chat';
}
