import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/service_request_model.dart';
import '../../services/firestore_service.dart';
import '../gpay_simulation_dialog.dart';

/// Widget that displays work requests inside a chat and allows asking for work.
class ChatWorkRequestSection extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final bool isCurrentUserCustomer; // Only customers can ASK for work
  final bool isCurrentUserSkilledPerson; // Only skilled person can APPROVE

  const ChatWorkRequestSection({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    required this.isCurrentUserCustomer,
    required this.isCurrentUserSkilledPerson,
  });

  @override
  State<ChatWorkRequestSection> createState() => _ChatWorkRequestSectionState();
}

class _ChatWorkRequestSectionState extends State<ChatWorkRequestSection> {
  late final FirestoreService _firestoreService;
  late final Stream<List<ServiceRequestModel>> _requestStream;

  @override
  void initState() {
    super.initState();
    // Create ONE instance and ONE stream — never recreated on rebuild
    _firestoreService = FirestoreService();
    _requestStream = _firestoreService.streamChatWorkRequests(widget.chatId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ServiceRequestModel>>(
      stream: _requestStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.work_outline,
                      size: 14, color: Colors.deepPurple),
                  const SizedBox(width: 4),
                  Text(
                    'Work Requests',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple[700],
                    ),
                  ),
                ],
              ),
            ),
            ...requests
                .take(3)
                .map((req) => _WorkRequestCard(
                      request: req,
                      currentUserId: widget.currentUserId,
                      otherUserName: widget.otherUserName,
                      isCurrentUserSkilledPerson: widget.isCurrentUserSkilledPerson,
                      isCurrentUserCustomer: widget.isCurrentUserCustomer,
                    )),
            if (requests.length > 3)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextButton(
                  onPressed: () =>
                      _showAllRequests(context, requests),
                  child: Text(
                    'View all ${requests.length} requests',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.deepPurple),
                  ),
                ),
              ),
            const Divider(),
          ],
        );
      },
    );
  }

  void _showAllRequests(BuildContext context, List<ServiceRequestModel> reqs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            const Center(
              child: Text('All Work Requests',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ...reqs.map((req) => _WorkRequestCard(
                  request: req,
                  currentUserId: widget.currentUserId,
                  otherUserName: widget.otherUserName,
                  isCurrentUserSkilledPerson: widget.isCurrentUserSkilledPerson,
                  isCurrentUserCustomer: widget.isCurrentUserCustomer,
                )),
          ],
        ),
      ),
    );
  }
}

class _WorkRequestCard extends StatefulWidget {
  final ServiceRequestModel request;
  final String currentUserId;
  final String otherUserName;
  final bool isCurrentUserSkilledPerson;
  final bool isCurrentUserCustomer;

  const _WorkRequestCard({
    required this.request,
    required this.currentUserId,
    required this.otherUserName,
    required this.isCurrentUserSkilledPerson,
    required this.isCurrentUserCustomer,
  });

  @override
  State<_WorkRequestCard> createState() => _WorkRequestCardState();
}

class _WorkRequestCardState extends State<_WorkRequestCard> {
  bool _loading = false;
  final FirestoreService _svc = FirestoreService();

  Color get _statusColor {
    switch (widget.request.status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData get _statusIcon {
    switch (widget.request.status) {
      case 'accepted':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.hourglass_empty;
    }
  }

  String get _statusLabel {
    switch (widget.request.status) {
      case 'accepted':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  Future<void> _respond(bool approve) async {
    setState(() => _loading = true);
    try {
      await _svc.respondToChatWorkRequest(
        requestId: widget.request.id,
        skilledUserId: widget.currentUserId,
        approve: approve,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve
              ? 'Work request approved! Project added to your profile.'
              : 'Work request declined.'),
          backgroundColor: approve ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _triggerPayment() async {
    // Show payment amount dialog first
    final amountResult = await showDialog<double>(
      context: context,
      builder: (ctx) => _PaymentAmountDialog(
        projectTitle: widget.request.title,
        recipientName: widget.otherUserName,
      ),
    );
    if (amountResult == null || !mounted) return;

    // Launch Google Pay simulation
    final txnId = await GPaySimulationDialog.show(
      context,
      amount: amountResult,
      recipientName: widget.otherUserName,
      description: widget.request.title,
    );

    if (txnId != null && mounted) {
      // Mark request as completed upon payment
      try {
        await _svc.updateRequestStatus(widget.request.id, 'completed');
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✅ Payment of ₹${amountResult.toStringAsFixed(2)} done! TXN: $txnId'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isPending = req.status == 'pending';
    final isAccepted = req.status == 'accepted';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.work, size: 16, color: Colors.deepPurple),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    req.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 12, color: _statusColor),
                      const SizedBox(width: 3),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            color: _statusColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (req.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                req.description,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Actions
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              )
            else if (isPending &&
                widget.isCurrentUserSkilledPerson &&
                req.skilledUserId == widget.currentUserId) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _respond(false),
                      icon: const Icon(Icons.close, size: 16,
                          color: Colors.red),
                      label: const Text('Decline',
                          style: TextStyle(color: Colors.red, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _respond(true),
                      icon:
                          const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text('Approve',
                          style:
                              TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isAccepted && widget.isCurrentUserCustomer) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _triggerPayment,
                  icon: const Icon(Icons.payment, size: 16,
                      color: Colors.white),
                  label: const Text('Pay via Google Pay',
                      style:
                          TextStyle(color: Colors.white, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dialog to enter custom payment amount
class _PaymentAmountDialog extends StatefulWidget {
  final String projectTitle;
  final String recipientName;

  const _PaymentAmountDialog({
    required this.projectTitle,
    required this.recipientName,
  });

  @override
  State<_PaymentAmountDialog> createState() => _PaymentAmountDialogState();
}

class _PaymentAmountDialogState extends State<_PaymentAmountDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    // Unfocus the amount TextField before popping to prevent
    // Flutter Web 'targetElement == domElement' assertion error.
    FocusScope.of(context).unfocus();
    final val = double.tryParse(_controller.text.trim());
    if (val == null || val <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    Navigator.pop(context, val);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Payment Amount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project: ${widget.projectTitle}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: InputDecoration(
              labelText: 'Amount (₹)',
              prefixText: '₹ ',
              errorText: _error,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _confirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
          ),
          child: const Text('Continue',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
