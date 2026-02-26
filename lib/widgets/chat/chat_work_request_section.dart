import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/service_request_model.dart';
import '../../services/firestore_service.dart';
import '../app_popup.dart';
import '../gpay_simulation_dialog.dart';

/// Widget that displays work requests inside a chat and allows asking for work.
class ChatWorkRequestSection extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final bool isCurrentUserCustomer;
  final bool isCurrentUserSkilledPerson;
  /// Pre-fetched work requests from parent — avoids duplicate Firestore
  /// listeners and prevents data loss during widget-tree restructuring.
  final List<ServiceRequestModel>? workRequests;

  const ChatWorkRequestSection({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    required this.isCurrentUserCustomer,
    required this.isCurrentUserSkilledPerson,
    this.workRequests,
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
    _firestoreService = FirestoreService();
    _requestStream = _firestoreService.streamChatWorkRequests(widget.chatId);
  }

  @override
  Widget build(BuildContext context) {
    // If parent provides pre-fetched data, use it directly (no stream needed).
    // This avoids duplicate Firestore listeners and keeps data stable when
    // the widget tree restructures (e.g. TabBarView toggle).
    if (widget.workRequests != null) {
      return _buildContent(widget.workRequests!);
    }

    // Fallback: use own stream
    return StreamBuilder<List<ServiceRequestModel>>(
      stream: _requestStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('ChatWorkRequestSection error: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildContent(snapshot.data!);
      },
    );
  }

  Widget _buildContent(List<ServiceRequestModel> requests) {
        // Show all requests (including completed/rejected) so user can track history
        final visible = requests.toList();
        if (visible.isEmpty) return const SizedBox.shrink();

        // Show up to 5 inline, rest behind "View all"
        final inlineCount = visible.length <= 5 ? visible.length : 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
              child: Row(
                children: [
                  const Icon(Icons.work_outline,
                      size: 14, color: Colors.deepPurple),
                  const SizedBox(width: 4),
                  Text(
                    'Work Requests List',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurple[700],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${visible.length}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            ...visible
                .take(inlineCount)
                .map((req) => _WorkRequestCard(
                      request: req,
                      currentUserId: widget.currentUserId,
                      otherUserId: widget.otherUserId,
                      otherUserName: widget.otherUserName,
                      isCurrentUserSkilledPerson:
                          widget.isCurrentUserSkilledPerson,
                      isCurrentUserCustomer: widget.isCurrentUserCustomer,
                    )),
            if (visible.length > inlineCount)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextButton(
                  onPressed: () => _showAllRequests(context, visible),
                  child: Text(
                    'View all ${visible.length} requests',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.deepPurple),
                  ),
                ),
              ),
            const Divider(height: 1),
          ],
        );
  }

  void _showAllRequests(
      BuildContext context, List<ServiceRequestModel> reqs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Text('All Work Requests (${reqs.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            ...reqs.map((req) => _WorkRequestCard(
                  request: req,
                  currentUserId: widget.currentUserId,
                  otherUserId: widget.otherUserId,
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
  final String otherUserId;
  final String otherUserName;
  final bool isCurrentUserSkilledPerson;
  final bool isCurrentUserCustomer;

  const _WorkRequestCard({
    required this.request,
    required this.currentUserId,
    required this.otherUserId,
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

  // Remind cooldown: 15 min per request
  static const _remindCooldown = Duration(minutes: 15);
  static final Map<String, DateTime> _lastRemindTimes = {};

  bool get _remindedRecently {
    final last = _lastRemindTimes[widget.request.id];
    if (last == null) return false;
    return DateTime.now().difference(last) < _remindCooldown;
  }

  Color get _statusColor {
    switch (widget.request.status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.grey;
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
      case 'cancelled':
        return Icons.block_outlined;
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
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }

  Color get _cardBg {
    switch (widget.request.status) {
      case 'pending':
        return const Color(0xFFFFFDE7); // sticky-note yellow
      case 'accepted':
        return const Color(0xFFF1F8E9); // light green
      default:
        return Colors.white;
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
        AppPopup.show(context,
            message: approve
                ? 'Work request approved! Project added to your profile.'
                : 'Work request declined.',
            type: approve ? PopupType.success : PopupType.info);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context, message: 'Error: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Work Request'),
        content: Text(
            'Cancel "${widget.request.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Request',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await _svc.cancelChatWorkRequest(
        requestId: widget.request.id,
        customerId: widget.currentUserId,
      );
      if (mounted) {
        AppPopup.show(context,
            message: 'Work request cancelled.',
            type: PopupType.info);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context, message: 'Error: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remindSkilledPerson() async {
    if (_remindedRecently) {
      AppPopup.show(context,
          message: 'Reminded recently. Please wait before sending another.',
          type: PopupType.info);
      return;
    }
    setState(() => _loading = true);
    try {
      // Send a silent reminder notification instead of a visible chat message
      await _svc.sendReminderNotification(
        requestId: widget.request.id,
        fromUserId: widget.currentUserId,
        toUserId: widget.request.skilledUserId,
        requestTitle: widget.request.title,
      );
      _lastRemindTimes[widget.request.id] = DateTime.now();
      if (mounted) {
        setState(() {});
        AppPopup.show(context,
            message: 'Reminder sent!', type: PopupType.success);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context, message: 'Error: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _triggerPayment() async {
    final amountResult = await showDialog<double>(
      context: context,
      builder: (ctx) => _PaymentAmountDialog(
        projectTitle: widget.request.title,
        recipientName: widget.otherUserName,
      ),
    );
    if (amountResult == null || !mounted) return;

    final txnId = await GPaySimulationDialog.show(
      context,
      amount: amountResult,
      recipientName: widget.otherUserName,
      description: widget.request.title,
    );

    if (txnId != null && mounted) {
      try {
        await _svc.updateRequestStatus(widget.request.id, 'completed');
      } catch (_) {}
      if (mounted) {
        AppPopup.show(context,
            message:
                '✅ Payment of ₹${amountResult.toStringAsFixed(2)} done! TXN: $txnId',
            type: PopupType.success,
            duration: const Duration(seconds: 4));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isPending = req.status == 'pending';
    final isAccepted = req.status == 'accepted';

    // Customer owns this pending request → show Remind + Cancel
    final isCustomerOwned =
        isPending && widget.isCurrentUserCustomer && req.customerId == widget.currentUserId;

    // Skilled person can approve/decline pending request
    final isSkilledResponder =
        isPending && widget.isCurrentUserSkilledPerson && req.skilledUserId == widget.currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _statusColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_statusIcon, size: 16, color: _statusColor),
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
                  child: Text(
                    _statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        color: _statusColor,
                        fontWeight: FontWeight.w600),
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
            // ── Actions ──────────────────────────────────────────────
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              )
            // Skilled person: Approve / Decline
            else if (isSkilledResponder) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // Decline — soft red bg
                  Expanded(
                    child: Material(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _respond(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close_rounded, size: 17, color: Color(0xFFD32F2F)),
                              SizedBox(width: 5),
                              Text('Decline', style: TextStyle(
                                color: Color(0xFFD32F2F), fontSize: 13,
                                fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Approve — green gradient
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF43A047).withValues(alpha: 0.3),
                              blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _respond(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_rounded, size: 17, color: Colors.white),
                                SizedBox(width: 5),
                                Text('Approve', style: TextStyle(
                                  color: Colors.white, fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]
            // Customer: Remind + Cancel
            else if (isCustomerOwned) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // Remind — purple gradient (or grey when on cooldown)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _remindedRecently
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)]),
                        color: _remindedRecently ? Colors.grey[300] : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _remindedRecently
                            ? null
                            : [
                                BoxShadow(
                                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.25),
                                    blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _remindedRecently ? null : _remindSkilledPerson,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _remindedRecently
                                      ? Icons.check_circle_outline
                                      : Icons.notifications_active_outlined,
                                  size: 16,
                                  color: _remindedRecently
                                      ? Colors.grey[600]
                                      : Colors.white,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _remindedRecently ? 'Reminded' : 'Remind',
                                  style: TextStyle(
                                    color: _remindedRecently
                                        ? Colors.grey[600]
                                        : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Cancel — soft red bg
                  Expanded(
                    child: Material(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _cancelRequest,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel_outlined, size: 16,
                                  color: Color(0xFFD32F2F)),
                              SizedBox(width: 5),
                              Text('Cancel', style: TextStyle(
                                color: Color(0xFFD32F2F), fontSize: 13,
                                fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]
            // Customer: Pay when accepted
            else if (isAccepted && widget.isCurrentUserCustomer) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                        blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _triggerPayment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Pay via Google Pay', style: TextStyle(
                            color: Colors.white, fontSize: 14,
                            fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Payment Amount'),
      content: SingleChildScrollView(
        child: Column(
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
