// User Role Constants and Utilities
//
// This file defines the three distinct user types in the application:
// - CUSTOMER: Regular users who can browse, chat, review, and purchase products
// - COMPANY: Organizations that can post jobs and create direct hire requests
// - SKILLED_PERSON: Service providers who showcase work, offer services, and sell products

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

  // Legacy aliases supported for existing Firebase users
  static const Set<String> _skilledAliases = {
    'skilled_user',
    'skilled-person',
    'skilled person',
    'service_provider',
    'service-provider',
  };

  /// Normalize role values from legacy/new data into supported constants.
  static String? normalizeRole(String? role) {
    if (role == null) return null;
    final normalized = role.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    if (normalized == customer) return customer;
    if (normalized == company) return company;
    if (normalized == admin) return admin;
    if (normalized == skilledPerson || _skilledAliases.contains(normalized)) {
      return skilledPerson;
    }

    return normalized;
  }

  // Display names for roles
  static const Map<String, String> roleDisplayNames = {
    customer: 'Customer',
    company: 'Company',
    skilledPerson: 'Skilled Person',
    admin: 'Administrator',
  };

  // Get display name for a role
  static String getDisplayName(String role) {
    final normalized = normalizeRole(role);
    return roleDisplayNames[normalized] ?? 'Unknown';
  }

  // Check if role is valid
  static bool isValidRole(String role) {
    final normalized = normalizeRole(role);
    return normalized != null && allRoles.contains(normalized);
  }

  // Role permission checks
  static bool canPostJobs(String role) {
    final normalized = normalizeRole(role);
    return normalized == company;
  }

  static bool canApplyToJobs(String role) {
    return normalizeRole(role) == skilledPerson;
  }

  static bool canSellProducts(String role) {
    return normalizeRole(role) == skilledPerson;
  }

  static bool canBuyProducts(String role) {
    final normalized = normalizeRole(role);
    return normalized == customer || normalized == company;
  }

  static bool canUploadPortfolio(String role) {
    return normalizeRole(role) == skilledPerson;
  }

  static bool canHireSkilledPersons(String role) {
    final normalized = normalizeRole(role);
    return normalized == company;
  }

  static bool canBeHired(String role) {
    return normalizeRole(role) == skilledPerson;
  }

  static bool canInitiateChat(String role) {
    // All roles can chat
    return true;
  }

  static bool isCustomerOrCompany(String role) {
    final normalized = normalizeRole(role);
    return normalized == customer || normalized == company;
  }

  static bool isSkilledPerson(String role) {
    return normalizeRole(role) == skilledPerson;
  }

  static bool isAdmin(String role) {
    return normalizeRole(role) == admin;
  }
}

/// Role-based feature access
class RoleFeatures {
  // Features available to each role
  static const Map<String, List<String>> roleFeatures = {
    UserRoles.customer: [
      'browse_skilled_persons',
      'view_portfolios',
      'buy_products',
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
    final normalized = UserRoles.normalizeRole(role);
    return roleFeatures[normalized]?.contains(feature) ?? false;
  }

  // Get all features for a role
  static List<String> getFeaturesForRole(String role) {
    final normalized = UserRoles.normalizeRole(role);
    return roleFeatures[normalized] ?? [];
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
      NavigationItem(
          id: 'portfolio', label: 'Portfolio', icon: 'photo_library'),
      NavigationItem(id: 'my_shop', label: 'My Shop', icon: 'store'),
      NavigationItem(id: 'chats', label: 'Chats', icon: 'chat'),
      NavigationItem(id: 'profile', label: 'Profile', icon: 'person'),
    ],
  };

  static List<NavigationItem> getNavigationForRole(String role) {
    final normalized = UserRoles.normalizeRole(role);
    return roleNavigationItems[normalized] ??
        roleNavigationItems[UserRoles.customer]!;
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
