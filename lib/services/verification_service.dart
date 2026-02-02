import 'dart:math';

class VerificationService {
  // Dummy Aadhaar database for simulation
  // In production, this would connect to actual government API
  
  static final Map<String, Map<String, dynamic>> _dummyAadhaarDatabase = {
    '123456789012': {
      'name': 'Anita Sharma',
      'dob': '1990-05-15',
      'address': 'Mumbai, Maharashtra',
      'isValid': true,
    },
    '987654321098': {
      'name': 'Rajesh Verma',
      'dob': '1985-08-20',
      'address': 'Delhi, India',
      'isValid': true,
    },
    '111122223333': {
      'name': 'Priya Singh',
      'dob': '1992-03-10',
      'address': 'Bangalore, Karnataka',
      'isValid': true,
    },
  };

  // Verify Aadhaar number
  Future<Map<String, dynamic>?> verifyAadhaar(String aadhaarNumber) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 2));

    // Clean aadhaar number (remove spaces)
    final cleanAadhaar = aadhaarNumber.replaceAll(' ', '');

    // Check if exists in dummy database
    if (_dummyAadhaarDatabase.containsKey(cleanAadhaar)) {
      return _dummyAadhaarDatabase[cleanAadhaar];
    }

    // For testing: Generate random verification result
    final random = Random();
    if (random.nextBool()) {
      return {
        'name': 'Test User ${random.nextInt(1000)}',
        'dob': '1990-01-01',
        'address': 'Test City, Test State',
        'isValid': true,
      };
    }

    return null; // Invalid Aadhaar
  }

  // Validate Aadhaar format
  bool validateAadhaarFormat(String aadhaar) {
    final cleanAadhaar = aadhaar.replaceAll(' ', '');
    return cleanAadhaar.length == 12 && int.tryParse(cleanAadhaar) != null;
  }

  // Generate OTP (for additional verification)
  String generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Verify OTP
  Future<bool> verifyOTP(String sentOTP, String enteredOTP) async {
    // Simulate verification delay
    await Future.delayed(const Duration(milliseconds: 500));
    return sentOTP == enteredOTP;
  }

  // Add test Aadhaar (for development)
  void addTestAadhaar(String aadhaar, Map<String, dynamic> data) {
    _dummyAadhaarDatabase[aadhaar] = data;
  }
}
