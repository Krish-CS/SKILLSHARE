import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../models/chat_model.dart';
import '../../models/service_request_model.dart';
import '../../services/chat_service.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/presence_service.dart';
import '../../utils/app_helpers.dart';
import '../../utils/app_dialog.dart';
import '../../utils/web_image_loader.dart';
import '../../utils/user_roles.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../widgets/app_popup.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  String? _currentUserId;
  String? _currentUserRole;
  bool _isLoading = false;
  bool _isSending = false;

  // Work request state
  bool _workLocked = false;
  List<ServiceRequestModel> _pendingRequests = [];
  List<ServiceRequestModel> _acceptedRequests = [];
  List<ServiceRequestModel> _allWorkRequests = [];
  StreamSubscription<List<ServiceRequestModel>>? _workReqSubscription;

  // Tab controller (used when work is accepted)
  late final TabController _tabController;

  // Message stream + reactive read receipt
  late final Stream<List<MessageModel>> _messageStream;
  StreamSubscription<List<MessageModel>>? _messageReadSubscription;

  // Edit mode
  MessageModel? _editingMessage;

  // Other user online status (for WhatsApp-style ticks)
  bool _otherUserOnline = false;
  StreamSubscription<UserPresence>? _presenceSubscription;

  // AppBar bubble animation
  late final AnimationController _bubbleCtrl;

  // AppBar cycling gradient animation
  late final AnimationController _gradientCtrl;
  static const _gradientPhases = [
    [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF00B0FF)],  // purple→blue
    [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFFE91E63)],  // indigo→pink
    [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF1565C0)],  // teal→blue
    [Color(0xFF880E4F), Color(0xFFAD1457), Color(0xFFFF6F00)],  // magenta→amber
    [Color(0xFF311B92), Color(0xFF6200EA), Color(0xFF00BFA5)],  // deep purple→teal
    [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFFE040FB)],  // blue→pink
  ];
  int _gradientPhase = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _messageStream = _chatService.getMessages(widget.chatId).asBroadcastStream();
    _tabController = TabController(length: 2, vsync: this);
    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Cycling gradient for chat AppBar
    _gradientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _gradientPhase = (_gradientPhase + 1) % _gradientPhases.length);
          _gradientCtrl.forward(from: 0);
        }
      });
    _gradientCtrl.forward();

    // Track other user's online status (for WhatsApp-style ticks)
    _presenceSubscription = PresenceService.instance
        .watchUser(widget.otherUserId)
        .listen((presence) {
      if (!mounted) return;
      final online = presence.isOnline;
      if (online != _otherUserOnline) {
        setState(() => _otherUserOnline = online);
      }
    });

    // Subscribe to work requests
    _workReqSubscription = _firestoreService
        .streamChatWorkRequests(widget.chatId)
        .listen((requests) {
      if (!mounted) return;
      final pending =
          requests.where((r) => r.status == 'pending').toList();
      final accepted =
          requests.where((r) => r.status == 'accepted').toList();
      setState(() {
        _allWorkRequests = requests;
        _pendingRequests = pending;
        _acceptedRequests = accepted;
        _workLocked = accepted.isNotEmpty;
      });
    });

    // Eagerly mark existing messages as read when opening chat
    if (_currentUserId != null) {
      _chatService.markMessagesAsRead(widget.chatId, _currentUserId!);
    }

    // Reactive read receipt — also marks new incoming messages as read
    _messageReadSubscription = _messageStream.listen((messages) {
      final uid = _currentUserId;
      if (uid == null) return;
      final hasUnread =
          messages.any((m) => !m.isRead && m.senderId != uid);
      if (hasUnread) {
        _chatService.markMessagesAsRead(widget.chatId, uid);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth =
            Provider.of<app_auth.AuthProvider>(context, listen: false);
        setState(() => _currentUserRole = auth.userRole);
      }
    });
  }

  @override
  void dispose() {
    _workReqSubscription?.cancel();
    _messageReadSubscription?.cancel();
    _presenceSubscription?.cancel();
    _bubbleCtrl.dispose();
    _gradientCtrl.dispose();
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Send / Edit ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _messageController.text.trim();

    if (_editingMessage != null) {
      if (text.isEmpty) return;
      setState(() => _isSending = true);
      try {
        await _chatService.editMessage(
          chatId: widget.chatId,
          messageId: _editingMessage!.id,
          senderId: _currentUserId!,
          newText: text,
        );
        _cancelEdit();
      } catch (e) {
        if (mounted) {
          AppPopup.show(context,
              message: 'Error editing message: $e',
              type: PopupType.error);
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    if (text.isEmpty && imageUrl == null) return;
    if (_currentUserId == null) return;

    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: _currentUserId!,
        receiverId: widget.otherUserId,
        text: imageUrl != null ? 'Image' : text,
        type: imageUrl != null ? 'image' : 'text',
        mediaUrl: imageUrl,
      );
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error sending message: $e',
            type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startEdit(MessageModel msg) {
    setState(() {
      _editingMessage = msg;
      _messageController.text = msg.text;
      _messageController.selection =
          TextSelection.collapsed(offset: msg.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
      _messageController.clear();
    });
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message'),
        content:
            const Text('Delete this message? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _chatService.deleteMessage(
        chatId: widget.chatId,
        messageId: msg.id,
        senderId: _currentUserId!,
      );
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error deleting message: $e',
            type: PopupType.error);
      }
    }
  }

  void _showMessageOptions(MessageModel msg, bool isMe) {
    if (msg.isDeleted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  AppPopup.show(context,
                      message: 'Copied to clipboard',
                      type: PopupType.info);
                },
              ),
              if (isMe && msg.type == 'text' && !_workLocked)
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: Colors.deepPurple),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _startEdit(msg);
                  },
                ),
              if (isMe && !_workLocked)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: Colors.red),
                  title: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(msg);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Work button actions ──────────────────────────────────────────────────────

  void _onWorkButtonTap(BuildContext context) {
    if (_pendingRequests.isNotEmpty) {
      _showPendingRequestsSheet();
    } else if (!_workLocked && _currentUserId != null) {
      _showAskWorkDialog(context);
    }
  }

  void _showPendingRequestsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PendingRequestsSheet(
        requests: _pendingRequests,
        currentUserId: _currentUserId!,
        otherUserName: widget.otherUserName,
        firestoreService: _firestoreService,
        chatService: _chatService,
        otherUserId: widget.otherUserId,
        chatId: widget.chatId,
      ),
    );
  }

  void _showAskWorkDialog(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AskWorkSheet(
        chatId: widget.chatId,
        currentUserId: _currentUserId!,
        otherUserId: widget.otherUserId,
        firestoreService: _firestoreService,
        parentContext: context,
      ),
    );
  }

  void _showTaskMonitoringSheet(BuildContext context) {
    // Use the parent's already-active subscription data — avoids a second
    // Firestore listener that can temporarily show empty while the new
    // stream reconnects to the server.
    final allRequests = List<ServiceRequestModel>.from(_allWorkRequests);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Builder(
            builder: (context) {
              // allRequests is a snapshot — stable for this sheet session
              final pending = allRequests.where((r) => r.status == 'pending').toList();
              final accepted = allRequests.where((r) => r.status == 'accepted').toList();
              final completed = allRequests.where((r) => r.status == 'completed').toList();
              final rejected = allRequests.where((r) => r.status == 'rejected').toList();
              final cancelled = allRequests.where((r) => r.status == 'cancelled').toList();

              return Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.format_list_bulleted,
                            color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Work Requests List',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (allRequests.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${allRequests.length} request${allRequests.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (allRequests.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_outlined,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No work requests yet',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 15)),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView(
                        controller: sc,
                        padding: const EdgeInsets.all(12),
                        children: [
                          if (pending.isNotEmpty) ...[
                            _monitoringSectionLabel(
                                'Pending', Colors.orange, Icons.hourglass_top),
                            ...pending.map((r) =>
                                _monitoringTaskTile(r)),
                            const SizedBox(height: 8),
                          ],
                          if (accepted.isNotEmpty) ...[
                            _monitoringSectionLabel(
                                'In Progress', Colors.blue, Icons.work),
                            ...accepted.map((r) =>
                                _monitoringTaskTile(r)),
                            const SizedBox(height: 8),
                          ],
                          if (completed.isNotEmpty) ...[
                            _monitoringSectionLabel(
                                'Completed', Colors.blue, Icons.done_all),
                            ...completed.map((r) =>
                                _monitoringTaskTile(r)),
                            const SizedBox(height: 8),
                          ],
                          if (rejected.isNotEmpty) ...[
                            _monitoringSectionLabel(
                                'Rejected', Colors.red, Icons.close),
                            ...rejected.map((r) =>
                                _monitoringTaskTile(r)),
                            const SizedBox(height: 8),
                          ],
                          if (cancelled.isNotEmpty) ...[
                            _monitoringSectionLabel(
                                'Cancelled', Colors.grey, Icons.block),
                            ...cancelled.map((r) =>
                                _monitoringTaskTile(r)),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _monitoringSectionLabel(
      String label, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
    );
  }

  Widget _monitoringTaskTile(ServiceRequestModel r) {
    final isPending = r.status == 'pending';
    final isAccepted = r.status == 'accepted';
    final isCompleted = r.status == 'completed';
    final isRejected = r.status == 'rejected';
    final isCancelled = r.status == 'cancelled';
    
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    
    if (isPending) {
      statusColor = Colors.orange;
      statusLabel = 'Pending';
      statusIcon = Icons.hourglass_empty;
    } else if (isAccepted) {
      statusColor = Colors.blue;
      statusLabel = 'Active';
      statusIcon = Icons.work_outline;
    } else if (isCompleted) {
      statusColor = Colors.blue;
      statusLabel = 'Completed';
      statusIcon = Icons.done_all;
    } else if (isRejected) {
      statusColor = Colors.red;
      statusLabel = 'Rejected';
      statusIcon = Icons.close;
    } else if (isCancelled) {
      statusColor = Colors.grey;
      statusLabel = 'Cancelled';
      statusIcon = Icons.block;
    } else {
      statusColor = Colors.grey;
      statusLabel = r.status;
      statusIcon = Icons.info_outline;
    }
    
    final isMyRequest = r.customerId == _currentUserId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                statusIcon,
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title.isNotEmpty ? r.title : 'Work Request',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (r.description.isNotEmpty)
                      Text(
                        r.description,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // Remind & Cancel buttons for pending requests owned by customer
          if (isPending && isMyRequest) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        // Send a silent reminder notification (not a visible chat message)
                        await _firestoreService.sendReminderNotification(
                          requestId: r.id,
                          fromUserId: _currentUserId!,
                          toUserId: widget.otherUserId,
                          requestTitle: r.title,
                        );
                        if (mounted) {
                          AppPopup.show(context,
                              message: 'Reminder sent!',
                              type: PopupType.success);
                        }
                      } catch (e) {
                        if (mounted) {
                          AppPopup.show(context,
                              message: 'Error: $e',
                              type: PopupType.error);
                        }
                      }
                    },
                    icon: const Icon(Icons.notifications_active, size: 14),
                    label: const Text('Remind', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text('Cancel Work Request'),
                          content: Text(
                              'Cancel "${r.title}"? This cannot be undone.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Keep')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Cancel Request',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await _firestoreService.updateRequestStatus(
                              r.id, 'cancelled');
                          if (mounted) {
                            AppPopup.show(context,
                                message: 'Work request cancelled.',
                                type: PopupType.info);
                          }
                        } catch (e) {
                          if (mounted) {
                            AppPopup.show(context,
                                message: 'Error: $e',
                                type: PopupType.error);
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 14),
                    label: const Text('Cancel', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Image helpers ────────────────────────────────────────────────────────────

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() => _isLoading = true);
      final imageUrl = await _cloudinaryService.uploadImage(
          File(image.path),
          folder: 'chat_media');
      if (imageUrl != null) {
        await _sendMessage(imageUrl: imageUrl);
      } else {
        throw Exception('Failed to upload image');
      }
    } on Exception catch (e) {
      if (mounted &&
          e.toString().isNotEmpty &&
          !e.toString().contains('cancel')) {
        AppDialog.error(context, 'Error uploading image', detail: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() => _isLoading = true);
      final imageUrl = await _cloudinaryService.uploadImage(
          File(image.path),
          folder: 'chat_media');
      if (imageUrl != null) {
        await _sendMessage(imageUrl: imageUrl);
      } else {
        throw Exception('Failed to upload image');
      }
    } on Exception catch (e) {
      if (mounted &&
          e.toString().isNotEmpty &&
          !e.toString().contains('cancel')) {
        AppPopup.show(context,
            message: 'Error taking photo: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: Color(0xFF9C27B0)),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt,
                    color: Color(0xFF9C27B0)),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            _ImagePreviewScreen(imageUrl: imageUrl)));
  }

  // ── Report / Block ───────────────────────────────────────────────────────────

  void _showReportChatDialog() {
    final reasons = [
      'Inappropriate language',
      'Harassment or bullying',
      'Spam or scam',
      'Threatening messages',
      'Other',
    ];
    String? selectedReason = reasons.first;
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.flag, color: Colors.orange),
            SizedBox(width: 8),
            Text('Report Chat'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select reason:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...reasons.map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: selectedReason,
                    title: Text(r),
                    dense: true,
                    onChanged: (v) =>
                        setDlgState(() => selectedReason = v),
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange),
              onPressed: () async {
                Navigator.pop(ctx);
                if (_currentUserId == null) return;
                try {
                  await _chatService.reportChat(
                    chatId: widget.chatId,
                    reporterId: _currentUserId!,
                    reportedUserId: widget.otherUserId,
                    reason: selectedReason ?? 'Other',
                    details: detailsController.text.trim(),
                  );
                  if (mounted) {
                    AppPopup.show(context,
                        message:
                            'Chat reported. Our team will review it.',
                        type: PopupType.success);
                  }
                } catch (e) {
                  if (mounted) {
                    AppPopup.show(context,
                        message: 'Failed to report: $e',
                        type: PopupType.error);
                  }
                }
              },
              child: const Text('Submit',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _blockUser() async {
    if (_currentUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.block, color: Colors.red),
          SizedBox(width: 8),
          Text('Block User'),
        ]),
        content: Text(
            'Block ${widget.otherUserName}? You will no longer receive messages.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _chatService.blockUserFromChat(
        blockerId: _currentUserId!,
        blockedUserId: widget.otherUserId,
      );
      if (mounted) {
        AppPopup.show(context,
            message: '${widget.otherUserName} has been blocked.',
            type: PopupType.info);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Failed to block user: $e',
            type: PopupType.error);
      }
    }
  }

  // ── Animated chat AppBar background ────────────────────────────────────────

  Widget _buildChatAppBarBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_bubbleCtrl, _gradientCtrl]),
      builder: (context, _) {
        final t = _bubbleCtrl.value;
        // Cycling gradient lerp
        final gt = _gradientCtrl.value;
        final curr = _gradientPhases[_gradientPhase];
        final next = _gradientPhases[(_gradientPhase + 1) % _gradientPhases.length];
        final c1 = Color.lerp(curr[0], next[0], gt)!;
        final c2 = Color.lerp(curr[1], next[1], gt)!;
        final c3 = Color.lerp(curr[2], next[2], gt)!;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Gradient base — cycling colors
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c1, c2, c3],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Bubble 1 — large, drifts right
            Positioned(
              right: -10 + 28 * math.sin(t * 2 * math.pi),
              top: 4 + 12 * math.cos(t * 2 * math.pi),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
            ),
            // Bubble 2 — medium, drifts left
            Positioned(
              right: 70 + 22 * math.cos(t * 2 * math.pi + 1.2),
              top: -8 + 16 * math.sin(t * 2 * math.pi + 1.2),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            // Bubble 3 — small, bottom area
            Positioned(
              left: 60 + 18 * math.sin(t * 2 * math.pi + 2.4),
              bottom: 4 + 8 * math.cos(t * 2 * math.pi + 2.4),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Bubble 4 — tiny, floats near center-right
            Positioned(
              right: 150 + 20 * math.cos(t * 2 * math.pi + 0.8),
              top: 8 + 10 * math.sin(t * 2 * math.pi + 0.8),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c3.withValues(alpha: 0.18),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isCustomer = _currentUserRole == UserRoles.customer;
    final isCompany = _currentUserRole == UserRoles.company;
    final canAskForWork =
        (isCustomer || isCompany) && _currentUserId != null;
    final hasPending = _pendingRequests.isNotEmpty;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: StreamBuilder<UserPresence>(
            stream: PresenceService.instance.watchUser(widget.otherUserId),
            builder: (context, presSnap) {
              final presence = presSnap.data;
              final isOnline = presence?.isOnline ?? false;
              final lastSeen = presence?.lastSeen;

              String subtitle;
              if (_workLocked) {
                subtitle = 'Work in progress';
              } else if (isOnline) {
                subtitle = 'Online';
              } else if (lastSeen != null) {
                subtitle = 'Last seen ${AppHelpers.getRelativeTime(lastSeen)}';
              } else {
                subtitle = 'Offline';
              }

              return Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            WebImageLoader.getImageProvider(widget.otherUserPhoto),
                        child: widget.otherUserPhoto == null ||
                                widget.otherUserPhoto!.isEmpty
                            ? Text(
                                widget.otherUserName.isNotEmpty
                                    ? widget.otherUserName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(fontSize: 16),
                              )
                            : null,
                      ),
                      // Online dot on avatar
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.otherUserName,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: isOnline && !_workLocked
                                ? Colors.cyanAccent[100]
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            // Work Requests List icon — visible to all participants
            if (_currentUserId != null)
              GestureDetector(
                onTap: () => _showTaskMonitoringSheet(context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.format_list_bulleted,
                          color: Colors.white, size: 24),
                    ),
                    // Total requests badge
                    if (_pendingRequests.length + _acceptedRequests.length > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          height: 17,
                          constraints:
                              const BoxConstraints(minWidth: 17),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal[600],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '${_pendingRequests.length + _acceptedRequests.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            // Work-flow button — only for customers/companies
            if (canAskForWork)
              GestureDetector(
                onTap: () => _onWorkButtonTap(context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.work_outline,
                          color: Colors.white, size: 24),
                    ),
                    // Pending badge — only shown when requests are pending
                    if (hasPending)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          height: 17,
                          constraints:
                              const BoxConstraints(minWidth: 17),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange[700],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '${_pendingRequests.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'report') _showReportChatDialog();
                if (value == 'block') _blockUser();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(children: [
                    Icon(Icons.flag, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Report Chat'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Block User'),
                  ]),
                ),
              ],
            ),
          ],
          // Only show tab bar when work is accepted
          bottom: _workLocked
              ? TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Chat'),
                    Tab(icon: Icon(Icons.assignment_turned_in_outlined, size: 18), text: 'Work Project'),
                  ],
                )
              : null,
          flexibleSpace: _buildChatAppBarBackground(),
        ),
        body: _workLocked
            ? TabBarView(
                controller: _tabController,
                children: [_buildChatBody(), _buildWorkProjectTab()],
              )
            : _buildChatBody(),
      ),
    );
  }

  // ── Chat body (tab 0 / only body when unlocked) ──────────────────────────────

  Widget _buildChatBody() {
    return Column(
      children: [
        // Lock banner
        if (_workLocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFFFF8E1),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 16, color: Color(0xFFE65100)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Work in progress — messages are locked for integrity.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[900],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Messages
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: _messageStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No messages yet',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Start the conversation!',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!;
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMe = message.senderId == _currentUserId;
                  final showDate = index == messages.length - 1 ||
                      !_isSameDay(
                          message.createdAt, messages[index + 1].createdAt);
                  return Column(
                    children: [
                      if (showDate)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              AppHelpers.formatDate(message.createdAt),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[700]),
                            ),
                          ),
                        ),
                      _buildMessageBubble(message, isMe),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // Upload loader
        if (_isLoading)
          Container(
            padding: const EdgeInsets.all(8),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Uploading image...'),
              ],
            ),
          ),

        // Edit mode bar
        if (_editingMessage != null)
          Container(
            color: Colors.deepPurple.withValues(alpha: 0.07),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined,
                    size: 16, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editing: ${_editingMessage!.text}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.deepPurple),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _cancelEdit,
                  child: const Icon(Icons.close,
                      size: 18, color: Colors.deepPurple),
                ),
              ],
            ),
          ),

        // Input bar
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: _workLocked
                ? _buildLockedInputBar()
                : Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image,
                            color: Color(0xFF9C27B0)),
                        onPressed: _isLoading || _isSending
                            ? null
                            : _showImageOptions,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey[200],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          maxLines: null,
                          textCapitalization:
                              TextCapitalization.sentences,
                          enabled: !_isLoading && !_isSending,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color(0xFF9C27B0),
                            Color(0xFFE91E63),
                          ]),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : Icon(
                                  _editingMessage != null
                                      ? Icons.check
                                      : Icons.send,
                                  color: Colors.white),
                          onPressed: _isLoading || _isSending
                              ? null
                              : () => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedInputBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text(
            'Chat locked — work project in progress.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Work Project tab (tab 1) ─────────────────────────────────────────────────

  Widget _buildWorkProjectTab() {
    if (_acceptedRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active work project',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header showing count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined,
                  size: 18, color: Color(0xFF388E3C)),
              const SizedBox(width: 8),
              Text(
                '${_acceptedRequests.length} Active Project${_acceptedRequests.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // List of separate project cards with index
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _acceptedRequests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (_, i) => _WorkProjectCard(
              request: _acceptedRequests[i],
              currentUserId: _currentUserId ?? '',
              otherUserName: widget.otherUserName,
              firestoreService: _firestoreService,
              projectIndex: i + 1,
              totalProjects: _acceptedRequests.length,
            ),
          ),
        ),
      ],
    );
  }

  // ── Message Bubble ───────────────────────────────────────────────────────────

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final isDeleted = message.isDeleted;
    final isEdited = message.editedAt != null && !isDeleted;
    final isHighlighted = _editingMessage?.id == message.id;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: isHighlighted
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color:
                            Colors.deepPurple.withValues(alpha: 0.3),
                        blurRadius: 8),
                  ],
                )
              : null,
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe && !isDeleted
                      ? const LinearGradient(colors: [
                          Color(0xFF9C27B0),
                          Color(0xFFE91E63)
                        ])
                      : null,
                  color: isDeleted
                      ? Colors.grey[200]
                      : isMe
                          ? null
                          : Colors.grey[300],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
                child: isDeleted
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block,
                              size: 13, color: Colors.grey[500]),
                          const SizedBox(width: 5),
                          Text(
                            'This message was deleted',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      )
                    : message.type == 'image'
                        ? GestureDetector(
                            onTap: () =>
                                _showImagePreview(message.mediaUrl!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: WebImageLoader.loadImage(
                                imageUrl: message.mediaUrl,
                                width: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : Text(
                            message.text,
                            style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 15),
                          ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEdited)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text('edited',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[400])),
                    ),
                  Text(AppHelpers.formatTime(message.createdAt),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600])),
                  if (isMe && !isDeleted) ...[
                    const SizedBox(width: 4),
                    Icon(
                        // WhatsApp-style: double tick when read OR when other user is online
                        (message.isRead || _otherUserOnline)
                            ? Icons.done_all
                            : Icons.done,
                        size: 14,
                        // Purple only when actually read
                        color: message.isRead
                            ? const Color(0xFF7C3AED)
                            : Colors.grey[400]),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
}

// ── Work Project Card (shown in Work tab) ─────────────────────────────────────

class _WorkProjectCard extends StatefulWidget {
  final ServiceRequestModel request;
  final String currentUserId;
  final String otherUserName;
  final FirestoreService firestoreService;
  final int projectIndex;
  final int totalProjects;

  const _WorkProjectCard({
    required this.request,
    required this.currentUserId,
    required this.otherUserName,
    required this.firestoreService,
    required this.projectIndex,
    required this.totalProjects,
  });

  @override
  State<_WorkProjectCard> createState() => _WorkProjectCardState();
}

class _WorkProjectCardState extends State<_WorkProjectCard> {
  bool _completing = false;

  Future<void> _markCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Completed'),
        content: const Text(
            'Confirm that this project has been completed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _completing = true);
    try {
      await widget.firestoreService
          .updateRequestStatus(widget.request.id, 'completed');
      if (mounted) {
        AppPopup.show(context,
            message: 'Project marked as completed!',
            type: PopupType.success);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isCustomer = req.customerId == widget.currentUserId;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5E35B1), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF5E35B1).withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF5E35B1), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                // Project number circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '#${widget.projectIndex}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    req.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                    maxLines: 2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                if (req.description.isNotEmpty) ...[
                  const Text('Description',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(req.description,
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black87)),
                  const SizedBox(height: 12),
                ],

                // Parties
                _infoRow(Icons.person_outline, 'Client',
                    isCustomer ? 'You' : widget.otherUserName),
                const SizedBox(height: 6),
                _infoRow(Icons.engineering_outlined, 'Skilled Person',
                    isCustomer ? widget.otherUserName : 'You'),
                const SizedBox(height: 6),
                _infoRow(
                  Icons.calendar_today_outlined,
                  'Started',
                  req.respondedAt != null
                      ? AppHelpers.formatDate(req.respondedAt!)
                      : AppHelpers.formatDate(req.createdAt),
                ),

                if (req.hireType != null) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.work_history_outlined, 'Hire Type',
                      req.hireType!.replaceAll('_', ' ').toUpperCase()),
                ],

                // Locked notice
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange.shade300, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 14, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chat messages are locked for integrity while work is in progress.',
                          style: TextStyle(
                              fontSize: 11, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),

                // Mark Complete (skilled person only)
                if (!isCustomer) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5E35B1), Color(0xFF9C27B0)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF5E35B1).withValues(alpha: 0.3),
                            blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _completing ? null : _markCompleted,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _completing
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_circle_outline,
                                      color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                _completing ? 'Completing...' : 'Mark as Completed',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 15,
                                  fontWeight: FontWeight.w600),
                              ),
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
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

// ── Pending Requests Detail Sheet ─────────────────────────────────────────────

class _PendingRequestsSheet extends StatefulWidget {
  final List<ServiceRequestModel> requests;
  final String currentUserId;
  final String otherUserName;
  final String otherUserId;
  final String chatId;
  final FirestoreService firestoreService;
  final ChatService chatService;

  const _PendingRequestsSheet({
    required this.requests,
    required this.currentUserId,
    required this.otherUserName,
    required this.otherUserId,
    required this.chatId,
    required this.firestoreService,
    required this.chatService,
  });

  @override
  State<_PendingRequestsSheet> createState() =>
      _PendingRequestsSheetState();
}

class _PendingRequestsSheetState extends State<_PendingRequestsSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.pending_actions,
                      color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pending Work Requests',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                        'Sent to ${widget.otherUserName} · awaiting response',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List of pending request cards
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: widget.requests.length,
              itemBuilder: (_, i) => _PendingDetailCard(
                request: widget.requests[i],
                currentUserId: widget.currentUserId,
                otherUserName: widget.otherUserName,
                chatId: widget.chatId,
                otherUserId: widget.otherUserId,
                firestoreService: widget.firestoreService,
                chatService: widget.chatService,
                onActionDone: () {
                  if (widget.requests.length == 1) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() {});
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PendingDetailCard extends StatefulWidget {
  final ServiceRequestModel request;
  final String currentUserId;
  final String otherUserName;
  final String chatId;
  final String otherUserId;
  final FirestoreService firestoreService;
  final ChatService chatService;
  final VoidCallback onActionDone;

  const _PendingDetailCard({
    required this.request,
    required this.currentUserId,
    required this.otherUserName,
    required this.chatId,
    required this.otherUserId,
    required this.firestoreService,
    required this.chatService,
    required this.onActionDone,
  });

  @override
  State<_PendingDetailCard> createState() => _PendingDetailCardState();
}

class _PendingDetailCardState extends State<_PendingDetailCard> {
  bool _loading = false;

  // Remind cooldown: 15 min per request
  static const _remindCooldown = Duration(minutes: 15);
  static final Map<String, DateTime> _lastRemindTimes = {};

  bool get _remindedRecently {
    final last = _lastRemindTimes[widget.request.id];
    if (last == null) return false;
    return DateTime.now().difference(last) < _remindCooldown;
  }

  bool get _isMine =>
      widget.request.customerId == widget.currentUserId;

  Future<void> _remind() async {
    if (_remindedRecently) {
      AppPopup.show(context,
          message: 'Reminded recently. Please wait before sending another.',
          type: PopupType.info);
      return;
    }
    setState(() => _loading = true);
    try {
      // Send a silent reminder notification instead of a visible chat message
      await FirestoreService().sendReminderNotification(
        requestId: widget.request.id,
        fromUserId: widget.currentUserId,
        toUserId: widget.otherUserId,
        requestTitle: widget.request.title,
      );
      _lastRemindTimes[widget.request.id] = DateTime.now();
      if (mounted) {
        setState(() {});
        AppPopup.show(context,
            message: 'Reminder sent!', type: PopupType.success);
        widget.onActionDone();
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
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
      await widget.firestoreService.cancelChatWorkRequest(
        requestId: widget.request.id,
        customerId: widget.currentUserId,
      );
      if (mounted) {
        AppPopup.show(context,
            message: 'Work request cancelled.',
            type: PopupType.info);
        widget.onActionDone();
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(14),
        border: Border(
            left: BorderSide(color: Colors.orange[700]!, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                const Icon(Icons.hourglass_empty,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(req.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Pending',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            // Description
            if (req.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(req.description,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black54)),
            ],
            // Metadata
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Sent ${AppHelpers.formatDate(req.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                const Spacer(),
                const Icon(Icons.person_outline,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text('To ${widget.otherUserName}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ],
            ),
            // Actions (only if this customer owns it)
            if (_isMine) ...[
              const SizedBox(height: 12),
              if (_loading)
                const LinearProgressIndicator()
              else
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
                            onTap: _remindedRecently ? null : _remind,
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
                          onTap: _cancel,
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
            ],
          ],
        ),
      ),
    );
  }
}

// ── Ask Work Sheet ────────────────────────────────────────────────────────────

class _AskWorkSheet extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;
  final FirestoreService firestoreService;
  final BuildContext parentContext;

  const _AskWorkSheet({
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
    required this.firestoreService,
    required this.parentContext,
  });

  @override
  State<_AskWorkSheet> createState() => _AskWorkSheetState();
}

class _AskWorkSheetState extends State<_AskWorkSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parentCtx = widget.parentContext;
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await widget.firestoreService.createChatWorkRequest(
        chatId: widget.chatId,
        customerId: widget.currentUserId,
        skilledUserId: widget.otherUserId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
      );
      if (mounted) Navigator.pop(context);
      if (mounted && parentCtx.mounted) {
        AppPopup.show(parentCtx,
            message: 'Work request sent. Waiting for approval.',
            type: PopupType.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        if (parentCtx.mounted) {
          AppPopup.show(parentCtx,
              message: 'Error: $e', type: PopupType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF9C27B0), Color(0xFFE91E63)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask for Work / Project',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Send a work request to this skilled person',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Project / Work Title *',
                hintText: 'e.g. Build a mobile app, Design a logo...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a title'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe what needs to be done...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.description_outlined),
                ),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Please enter a description'
                  : null,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF9C27B0), Color(0xFFE91E63)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send, color: Colors.white),
                label: Text(
                  _submitting ? 'Sending...' : 'Send Request',
                  style:
                      const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image Preview Screen ──────────────────────────────────────────────────────

class _ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  const _ImagePreviewScreen({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: WebImageLoader.loadImage(
              imageUrl: imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
