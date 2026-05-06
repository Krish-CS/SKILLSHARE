import 'package:flutter/material.dart';

import '../screens/profile/profile_tab_screen.dart';
import '../screens/profile/skilled_user_setup_screen.dart';

Widget buildOwnProfileScreen({
  required String role,
  required String userId,
}) {
  return const ProfileTabScreen();
}

Widget buildSkilledEditScreen({required String userId}) {
  return SkilledUserSetupScreen(userId: userId, isEditing: true);
}