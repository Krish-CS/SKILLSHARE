import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/order_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_helpers.dart';
import '../../utils/app_dialog.dart';
import '../shop/order_tracking_screen.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final partnerId = authProvider.currentUser?.uid;
    final partnerName = authProvider.currentUser?.name ?? 'Delivery Partner';

    if (partnerId == null) {
      return const Scaffold(
        body: Center(child: Text('Not authenticated')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Deliveries',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'My Deliveries'),
            Tab(text: 'Available'),
          ],
        ),
        elevation: 0,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MyDeliveriesTab(partnerId: partnerId, partnerName: partnerName),
          _AvailableDeliveriesTab(
              partnerId: partnerId, partnerName: partnerName),
        ],
      ),
    );
  }
}

// ─── My Deliveries tab ───────────────────────────────────────────────────────

class _MyDeliveriesTab extends StatelessWidget {
  const _MyDeliveriesTab({required this.partnerId, required this.partnerName});

  final String partnerId;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    return StreamBuilder<List<OrderModel>>(
      stream: svc.streamDeliveryPartnerOrders(partnerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const _EmptyState(
            icon: Icons.delivery_dining,
            message: 'No deliveries assigned to you yet.',
            subtitle: 'Check the "Available" tab to pick up a delivery.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (ctx, i) => _DeliveryCard(
            order: orders[i],
            partnerId: partnerId,
            partnerName: partnerName,
            isAssigned: true,
          ),
        );
      },
    );
  }
}

// ─── Available Deliveries tab ─────────────────────────────────────────────────

class _AvailableDeliveriesTab extends StatelessWidget {
  const _AvailableDeliveriesTab(
      {required this.partnerId, required this.partnerName});

  final String partnerId;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreService();
    return StreamBuilder<List<OrderModel>>(
      stream: svc.streamAvailableDeliveries(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return const _EmptyState(
            icon: Icons.check_circle_outline,
            message: 'No deliveries available right now.',
            subtitle: 'Check back soon for new pickups.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (ctx, i) => _DeliveryCard(
            order: orders[i],
            partnerId: partnerId,
            partnerName: partnerName,
            isAssigned: false,
          ),
        );
      },
    );
  }
}

// ─── Delivery Card ─────────────────────────────────────────────────────────────

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.order,
    required this.partnerId,
    required this.partnerName,
    required this.isAssigned,
  });

  final OrderModel order;
  final String partnerId;
  final String partnerName;
  final bool isAssigned;

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return const Color(0xFF1976D2);
      case 'delivered':
        return Colors.green;
      case 'out_for_delivery':
        return Colors.orange;
      case 'shipped':
        return const Color(0xFF2196F3);
      case 'failed_delivery':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'failed_delivery':
        return 'Failed Delivery';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: Color(0xFFFF6B35), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.productName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Order #${order.id.substring(0, 8).toUpperCase()}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(order.status),
                    style: TextStyle(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Details
            _InfoRow(Icons.person_outline, 'Buyer',
                order.buyerName ?? order.buyerId),
            _InfoRow(Icons.attach_money, 'Amount',
                '₹${order.totalPrice.toStringAsFixed(2)}'),
            _InfoRow(Icons.calendar_today_outlined, 'Ordered',
                AppHelpers.formatDateTime(order.createdAt)),
            if (order.estimatedDelivery != null)
              _InfoRow(
                Icons.schedule,
                'Est. Delivery',
                AppHelpers.formatDateTime(order.estimatedDelivery!),
              ),
            const SizedBox(height: 14),
            // Action buttons
            if (!isAssigned && order.status == 'confirmed')
              _AcceptButton(
                  order: order, partnerId: partnerId, partnerName: partnerName),
            if (isAssigned && order.status == 'out_for_delivery')
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Mark Delivered',
                      icon: Icons.check_circle,
                      color: Colors.green,
                      onTap: () =>
                          _updateStatus(context, order, partnerId, 'delivered'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'Failed',
                      icon: Icons.cancel,
                      color: Colors.red,
                      onTap: () => _updateStatus(
                          context, order, partnerId, 'failed_delivery'),
                    ),
                  ),
                ],
              ),
            if (isAssigned && order.status == 'out_for_delivery')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () =>
                      _updateEstimatedDelivery(context, order, partnerId),
                  icon: const Icon(Icons.schedule, size: 18),
                  label: const Text('Update ETA'),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2)),
                ),
              ),
            if (order.status == 'delivered' ||
                order.status == 'out_for_delivery')
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OrderTrackingScreen(order: order)),
                ),
                icon: const Icon(Icons.timeline, size: 18),
                label: const Text('View Timeline'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B35)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    OrderModel order,
    String partnerId,
    String status,
  ) async {
    try {
      await FirestoreService().updateDeliveryStatus(
        orderId: order.id,
        deliveryPartnerId: partnerId,
        status: status,
      );
      if (context.mounted) {
        if (status == 'delivered') {
          AppDialog.success(context, 'Marked as delivered!');
        } else {
          AppDialog.error(context, 'Marked as failed delivery.');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppDialog.error(context, 'Error updating delivery status',
            detail: e.toString());
      }
    }
  }

  Future<void> _updateEstimatedDelivery(
    BuildContext context,
    OrderModel order,
    String partnerId,
  ) async {
    final selected = await _pickEstimatedDelivery(context);
    if (selected == null) return;
    try {
      await FirestoreService().updateDeliveryEstimate(
        orderId: order.id,
        deliveryPartnerId: partnerId,
        estimatedDelivery: selected,
      );
      if (context.mounted) {
        AppDialog.success(context, 'Delivery ETA updated.');
      }
    } catch (e) {
      if (context.mounted) {
        AppDialog.error(context, 'Error updating ETA', detail: e.toString());
      }
    }
  }

  Future<DateTime?> _pickEstimatedDelivery(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (pickedDate == null || !context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 48))),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }
}

class _AcceptButton extends StatefulWidget {
  const _AcceptButton({
    required this.order,
    required this.partnerId,
    required this.partnerName,
  });

  final OrderModel order;
  final String partnerId;
  final String partnerName;

  @override
  State<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends State<_AcceptButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _accept,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.local_shipping),
        label: Text(_loading ? 'Accepting...' : 'Accept Delivery'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B35),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Future<void> _accept() async {
    final estimatedDelivery = await _pickEstimatedDelivery(context);
    if (estimatedDelivery == null) return;

    setState(() => _loading = true);
    try {
      await FirestoreService().assignDeliveryPartner(
        orderId: widget.order.id,
        deliveryPartnerId: widget.partnerId,
        deliveryPartnerName: widget.partnerName,
        estimatedDelivery: estimatedDelivery,
      );
      if (mounted) {
        AppDialog.success(context, 'Delivery accepted! You are now assigned.');
      }
    } catch (e) {
      if (mounted) {
        AppDialog.error(context, 'Error accepting delivery',
            detail: e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<DateTime?> _pickEstimatedDelivery(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );
    if (pickedDate == null || !context.mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 48))),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text('$label: ',
              style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });
  final IconData icon;
  final String message;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFFFF6B35)),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
