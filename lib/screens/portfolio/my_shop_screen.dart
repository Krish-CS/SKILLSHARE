import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/user_roles.dart';

/// My Shop Screen - For Skilled Persons Only
/// Skilled persons can manage their online shop here
/// They can add, edit, and manage products they want to sell
class MyShopScreen extends StatefulWidget {
  const MyShopScreen({super.key});

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    // STRICT ROLE CHECK: Only skilled persons can access this
    if (!authProvider.isSkilledPerson) {
      return _buildAccessDenied();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop'),
        backgroundColor: Colors.orange,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Products', icon: Icon(Icons.inventory)),
            Tab(text: 'Orders', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openShopSettings(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildOrdersTab(),
          _buildAnalyticsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _addProduct(context),
              backgroundColor: Colors.orange,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            )
          : null,
    );
  }

  Widget _buildAccessDenied() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store_mall_directory_outlined, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              'Shop Access Restricted',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Only skilled persons can manage their shop. Customers and companies can browse the Shop section to purchase products.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Shop Management',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Add products you want to sell\n'
                      '• Upload quality product images\n'
                      '• Set competitive prices\n'
                      '• Manage inventory and stock levels\n'
                      '• Respond to customer inquiries',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildProductCard(index),
              childCount: 5, // TODO: Replace with actual products
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _buildProductCard(int index) {
    final isAvailable = index % 2 == 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          color: Colors.grey.shade300,
          child: Icon(
            Icons.shopping_bag,
            size: 30,
            color: Colors.grey.shade500,
          ),
        ),
        title: Text('Product ${index + 1}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('₹${(index + 1) * 100}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isAvailable ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: isAvailable ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  isAvailable ? 'In Stock' : 'Out of Stock',
                  style: TextStyle(
                    fontSize: 12,
                    color: isAvailable ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'stock', child: Text('Manage Stock')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          onSelected: (value) {
            // TODO: Handle product actions
          },
        ),
      ),
    );
  }

  Widget _buildOrdersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildOrderCard('Order #1001', 'Pending', Colors.orange),
        const SizedBox(height: 12),
        _buildOrderCard('Order #1002', 'Processing', Colors.blue),
        const SizedBox(height: 12),
        _buildOrderCard('Order #1003', 'Shipped', Colors.purple),
        const SizedBox(height: 12),
        _buildOrderCard('Order #1004', 'Delivered', Colors.green),
      ],
    );
  }

  Widget _buildOrderCard(String orderId, String status, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(Icons.shopping_cart, color: color),
        ),
        title: Text(orderId),
        subtitle: Text('Customer: John Doe\nTotal: ₹599'),
        trailing: Chip(
          label: Text(status),
          backgroundColor: color.withOpacity(0.2),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAnalyticsCard('Total Products', '15', Icons.inventory, Colors.blue),
        const SizedBox(height: 12),
        _buildAnalyticsCard('Total Sales', '₹12,500', Icons.attach_money, Colors.green),
        const SizedBox(height: 12),
        _buildAnalyticsCard('Pending Orders', '3', Icons.pending, Colors.orange),
        const SizedBox(height: 12),
        _buildAnalyticsCard('Completed Orders', '24', Icons.check_circle, Colors.teal),
        const SizedBox(height: 12),
        _buildAnalyticsCard('Shop Views', '1,245', Icons.visibility, Colors.purple),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  void _addProduct(BuildContext context) {
    // TODO: Navigate to add product screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add product feature - Coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _openShopSettings(BuildContext context) {
    // TODO: Navigate to shop settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shop settings - Coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
