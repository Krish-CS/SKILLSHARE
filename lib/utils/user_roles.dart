/// User Role Constants and Utilities
/// 
/// This file defines the three distinct user types in the application:
/// - CUSTOMER: Regular users who can browse, hire skilled persons, and purchase products
/// - COMPANY: Organizations that can post jobs and hire skilled persons
/// - SKILLED_PERSON: Service providers who showcase work, offer services, and sell products

class UserRoles {
  // Role constants
  static const String customer = 'customer';
  static const String company = 'company';
  static const String skilledPerson = 'skilled_person';
  static const String admin = 'admin';

  // All available roles
  static const List<String> allRoles = [
    customer,
    company,
    skilledPerson,
    admin,
  ];

  // Display names for roles
  static const Map<String, String> roleDisplayNames = {
    customer: 'Customer',
    company: 'Company',
    skilledPerson: 'Skilled Person',
    admin: 'Administrator',
  };

  // Get display name for a role
  static String getDisplayName(String role) {
    return roleDisplayNames[role] ?? 'Unknown';
  }

  // Check if role is valid
  static bool isValidRole(String role) {
    return allRoles.contains(role);
  }

  // Role permission checks
  static bool canPostJobs(String role) {
    return role == company || role == customer;
  }

  static bool canApplyToJobs(String role) {
    return role == skilledPerson;
  }

  static bool canSellProducts(String role) {
    return role == skilledPerson;
  }

  static bool canBuyProducts(String role) {
    return role == customer || role == company;
  }

  static bool canUploadPortfolio(String role) {
    return role == skilledPerson;
  }

  static bool canHireSkilledPersons(String role) {
    return role == customer || role == company;
  }

  static bool canBeHired(String role) {
    return role == skilledPerson;
  }

  static bool canInitiateChat(String role) {
    // All roles can chat
    return true;
  }

  static bool isCustomerOrCompany(String role) {
    return role == customer || role == company;
  }

  static bool isSkilledPerson(String role) {
    return role == skilledPerson;
  }

  static bool isAdmin(String role) {
    return role == admin;
  }
}

/// Role-based feature access
class RoleFeatures {
  // Features available to each role
  static const Map<String, List<String>> roleFeatures = {
    UserRoles.customer: [
      'browse_skilled_persons',
      'view_portfolios',
      'hire_skilled_persons',
      'buy_products',
      'post_jobs',
      'chat',
      'write_reviews',
      'search_services',
    ],
    UserRoles.company: [
      'browse_skilled_persons',
      'view_portfolios',
      'hire_skilled_persons',
      'buy_products',
      'post_jobs',
      'chat',
      'write_reviews',
      'search_services',
      'bulk_hiring',
    ],
    UserRoles.skilledPerson: [
      'upload_portfolio',
      'manage_portfolio',
      'receive_job_offers',
      'apply_to_jobs',
      'open_shop',
      'sell_products',
      'chat',
      'receive_reviews',
      'showcase_skills',
      'set_availability',
    ],
  };

  // Check if user has access to a feature
  static bool hasFeature(String role, String feature) {
    return roleFeatures[role]?.contains(feature) ?? false;
  }

  // Get all features for a role
  static List<String> getFeaturesForRole(String role) {
    return roleFeatures[role] ?? [];
  }
}

/// Navigation items for each role
class RoleNavigation {
  // Bottom navigation items visible to each role
  static const Map<String, List<NavigationItem>> roleNavigationItems = {
    UserRoles.customer: [
      NavigationItem(id: 'home', label: 'Home', icon: 'home'),
      NavigationItem(id: 'jobs', label: 'Jobs', icon: 'work'),
      NavigationItem(id: 'shop', label: 'Shop', icon: 'shopping_bag'),
      NavigationItem(id: 'chats', label: 'Chats', icon: 'chat'),
      NavigationItem(id: 'profile', label: 'Profile', icon: 'person'),
    ],
    UserRoles.company: [
      NavigationItem(id: 'home', label: 'Home', icon: 'home'),
      NavigationItem(id: 'jobs', label: 'Jobs', icon: 'work'),
      NavigationItem(id: 'shop', label: 'Shop', icon: 'shopping_bag'),
      NavigationItem(id: 'chats', label: 'Chats', icon: 'chat'),
      NavigationItem(id: 'profile', label: 'Profile', icon: 'business'),
    ],
    UserRoles.skilledPerson: [
      NavigationItem(id: 'home', label: 'Home', icon: 'home'),
      NavigationItem(id: 'portfolio', label: 'Portfolio', icon: 'photo_library'),
      NavigationItem(id: 'my_shop', label: 'My Shop', icon: 'store'),
      NavigationItem(id: 'chats', label: 'Chats', icon: 'chat'),
      NavigationItem(id: 'profile', label: 'Profile', icon: 'person'),
    ],
  };

  static List<NavigationItem> getNavigationForRole(String role) {
    return roleNavigationItems[role] ?? roleNavigationItems[UserRoles.customer]!;
  }
}

class NavigationItem {
  final String id;
  final String label;
  final String icon;

  const NavigationItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}
