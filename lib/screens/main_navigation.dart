import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'jobs/jobs_screen.dart';
import 'shop/shop_screen.dart';
import 'chat/chats_screen.dart';
import 'profile/profile_tab_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Define screens based on user role
    final screens = [
      const HomeScreen(),
      const JobsScreen(),
      const ShopScreen(),
      const ChatsScreen(),
      const ProfileTabScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _getGradientColor(_currentIndex, 0),
              _getGradientColor(_currentIndex, 1),
              _getGradientColor(_currentIndex, 2),
              _getGradientColor(_currentIndex, 3),
            ],
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.work),
              label: 'Jobs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag),
              label: 'Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradientColor(int currentIndex, int position) {
    switch (currentIndex) {
      case 0: // Home - Purple gradient
        return position < 2 ? const Color(0xFF9C27B0) : const Color(0xFFE91E63);
      case 1: // Jobs - Blue gradient
        return position < 2 ? const Color(0xFF2196F3) : const Color(0xFF00BCD4);
      case 2: // Shop - Orange/Pink gradient
        return position < 2 ? const Color(0xFFE91E63) : const Color(0xFFFF9800);
      case 3: // Chats - Purple/Pink gradient
        return position < 2 ? const Color(0xFF9C27B0) : const Color(0xFFE91E63);
      case 4: // Profile - Purple gradient
        return position < 2 ? const Color(0xFF9C27B0) : const Color(0xFFE91E63);
      default:
        return const Color(0xFF9C27B0);
    }
  }
}
