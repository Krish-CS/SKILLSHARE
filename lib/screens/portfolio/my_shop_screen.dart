import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/user_provider.dart';
import '../../models/product_model.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/web_image_loader.dart';
import '../shop/add_product_screen.dart';
import '../shop/product_detail_screen.dart';

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
  final FirestoreService _firestoreService = FirestoreService();
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final products = await _firestoreService.getUserProducts(userId);
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading products: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<app_auth.AuthProvider>(context);
    
    // CRITICAL: Only skilled persons can manage shop
    if (!authProvider.isSkilledPerson) {
      return _buildAccessDenied();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE91E63),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _openShopSettings(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Products', icon: Icon(Icons.inventory_2)),
            Tab(text: 'Orders', icon: Icon(Icons.list_alt)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
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
              backgroundColor: const Color(0xFFE91E63),
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
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Only skilled persons can manage their shop. Customers and companies can browse the shop instead.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products in your shop yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first product',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      color: const Color(0xFFE91E63),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) => _buildProductCard(_products[index]),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: product.images.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: WebImageLoader.loadImage(
                  imageUrl: product.images.first,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.image, color: Colors.grey[600]),
              ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('₹${product.price.toStringAsFixed(2)}'),
            const SizedBox(height: 2),
            Text(
              'Stock: ${product.stock}',
              style: TextStyle(
                color: product.stock > 0 ? Colors.green : Colors.red,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteProduct(product),
            ),
          ],
        ),
        onTap: () => _viewProduct(product),
      ),
    );
  }

  Widget _buildOrdersTab() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Please sign in'));
    }
    return StreamBuilder<List<OrderModel>>(
      stream: _firestoreService.streamSellerOrders(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E63)));
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No Orders Yet',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700])),
                const SizedBox(height: 8),
                Text('Orders from your shop will appear here',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey[500])),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColors = {
      'pending': Colors.orange,
      'confirmed': Colors.blue,
      'shipped': Colors.purple,
      'delivered': Colors.green,
      'cancelled': Colors.red,
    };
    final color = statusColors[order.status] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(order.productName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color),
                  ),
                  child: Text(order.status.toUpperCase(),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Qty: ${order.quantity}  •  \${order.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.grey)),
            if (order.buyerName != null)
              Text('Buyer: ${order.buyerName}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            if (order.status != 'delivered' && order.status != 'cancelled')
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (order.status == 'pending')
                    TextButton(
                      onPressed: () =>
                          _updateOrderStatus(order, 'confirmed'),
                      child: const Text('Confirm'),
                    ),
                  if (order.status == 'confirmed')
                    TextButton(
                      onPressed: () =>
                          _updateOrderStatus(order, 'shipped'),
                      child: const Text('Mark Shipped'),
                    ),
                  if (order.status == 'shipped')
                    TextButton(
                      onPressed: () =>
                          _updateOrderStatus(order, 'delivered'),
                      child: const Text('Mark Delivered'),
                    ),
                  TextButton(
                    onPressed: () =>
                        _updateOrderStatus(order, 'cancelled'),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(OrderModel order, String status) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      await _firestoreService.updateOrderStatus(
        orderId: order.id,
        sellerId: userId,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as $status'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildAnalyticsTab() {
    final totalProducts = _products.length;
    final totalStock = _products.fold<int>(0, (sum, product) => sum + product.stock);
    final averagePrice = _products.isEmpty
        ? 0.0
        : _products.fold<double>(0, (sum, product) => sum + product.price) / _products.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAnalyticsCard(
          'Total Products',
          '$totalProducts',
          Icons.inventory,
          const Color(0xFFE91E63),
        ),
        const SizedBox(height: 12),
        _buildAnalyticsCard(
          'Total Stock',
          '$totalStock',
          Icons.store,
          Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildAnalyticsCard(
          'Average Price',
          '₹${averagePrice.toStringAsFixed(2)}',
          Icons.currency_rupee,
          Colors.green,
        ),
        const SizedBox(height: 12),
        _buildAnalyticsCard(
          'Products Out of Stock',
          '${_products.where((p) => p.stock == 0).length}',
          Icons.warning,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  void _addProduct(BuildContext context) async {
    // SECURITY: Check if user is verified before allowing shop/product creation
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final nav = Navigator.of(context);

    // Load profile if not already loaded
    if (userProvider.currentProfile == null && authProvider.currentUser != null) {
      await userProvider.loadProfile(authProvider.currentUser!.uid);
    }

    // Check verification status
    if (userProvider.currentProfile?.isVerified != true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text('Verification Required'),
            ],
          ),
          content: const Text(
            'You must verify your Aadhaar to open a shop and sell products. This ensures buyer safety and platform integrity.\n\n'
            'Please complete your identity verification from your profile setup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to verification screen
                Navigator.pushNamed(context, '/skilled-setup');
              },
              child: const Text('Verify Now'),
            ),
          ],
        ),
      );
      return;
    }

    // Verified - proceed to add product
    final result = await nav.push(
      MaterialPageRoute(
        builder: (context) => const AddProductScreen(),
      ),
    );

    if (result == true && mounted) {
      _loadProducts(); // Refresh the list
    }
  }

  void _editProduct(ProductModel product) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
    if (result == true) {
      _loadProducts();
    }
  }

  void _viewProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestoreService.deleteProduct(product.id);
        _loadProducts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openShopSettings(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final shopNameController = TextEditingController();
    final shopDescController = TextEditingController();
    bool isLoading = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!isLoading && shopNameController.text.isEmpty) {
            isLoading = true;
            _firestoreService.getShopSettings(userId).then((settings) {
              setDialogState(() {
                shopNameController.text = settings['shopName'] as String? ?? '';
                shopDescController.text =
                    settings['shopDescription'] as String? ?? '';
                isLoading = false;
              });
            });
          }
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.store, color: Color(0xFFE91E63)),
                SizedBox(width: 8),
                Text('Shop Settings'),
              ],
            ),
            content: isLoading
                ? const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator()))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: shopNameController,
                          decoration: const InputDecoration(
                            labelText: 'Shop Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.storefront),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: shopDescController,
                          decoration: const InputDecoration(
                            labelText: 'Shop Description',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        try {
                          await _firestoreService.updateShopSettings(userId, {
                            'shopName': shopNameController.text.trim(),
                            'shopDescription': shopDescController.text.trim(),
                          });
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Shop settings saved!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')));
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63)),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Save',
                        style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
}
