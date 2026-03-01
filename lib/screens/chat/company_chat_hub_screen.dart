import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../services/presence_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_helpers.dart';
import '../../utils/app_dialog.dart';
import '../../utils/user_roles.dart';
import '../../utils/web_image_loader.dart';
import '../../widgets/universal_avatar.dart';
import '../../widgets/app_popup.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../profile/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data class for one tab entry in the hub
// ─────────────────────────────────────────────────────────────────────────────
class _ChatTabEntry {
  final String chatId;
  final String label;
  final IconData icon;
  final bool isHiring;
  final bool isJob;
  final String? jobTitle;
  final int unreadCount;

  const _ChatTabEntry({
    required this.chatId,
    required this.label,
    required this.icon,
    this.isHiring = false,
    this.isJob = false,
    this.jobTitle,
    this.unreadCount = 0,
  });

  _ChatTabEntry withUnread(int count) => _ChatTabEntry(
        chatId: chatId,
        label: label,
        icon: icon,
        isHiring: isHiring,
        isJob: isJob,
        jobTitle: jobTitle,
        unreadCount: count,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CompanyChatHubScreen
// ─────────────────────────────────────────────────────────────────────────────

/// A multi-tab chat hub that groups all conversations (normal, hiring, job
/// chats) between the current user and [otherUserId] into a single screen,
/// similar to how the CustomerChat shows "Chat" + "Work Project" tabs.
class CompanyChatHubScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  /// If provided, the hub will start on the tab whose chatId matches this.
  final String? initialChatId;

  const CompanyChatHubScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    this.initialChatId,
  });

  @override
  State<CompanyChatHubScreen> createState() => _CompanyChatHubScreenState();
}

class _CompanyChatHubScreenState extends State<CompanyChatHubScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();

  String? _currentUserId;
  String? _currentUserRole;
  String? _otherUserRole;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _otherRoleSub;

  // All chats with this person – updated live
  StreamSubscription<List<ChatModel>>? _chatsSub;

  // Derived tabs from _allChats
  List<_ChatTabEntry> _tabs = [];
  TabController? _tabController;
  int _activeTabIndex = 0;

  // Animated AppBar
  late final AnimationController _bubbleCtrl;
  late final AnimationController _gradientCtrl;
  int _gradientPhase = 0;

  static const _gradientPhases = [
    [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFF00B0FF)],
    [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFFE91E63)],
    [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF1565C0)],
    [Color(0xFF880E4F), Color(0xFFAD1457), Color(0xFFFF6F00)],
    [Color(0xFF311B92), Color(0xFF6200EA), Color(0xFF00BFA5)],
    [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFFE040FB)],
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    _bubbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _gradientCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          if (!mounted) return;
          setState(() =>
              _gradientPhase = (_gradientPhase + 1) % _gradientPhases.length);
          _gradientCtrl.forward(from: 0);
        }
      });
    _gradientCtrl.forward();

    // Stream other user's role
    _otherRoleSub = FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(widget.otherUserId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      final role = UserRoles.normalizeRole(
          (doc.data()?['role'] as String?)?.trim() ?? '');
      if (role != _otherUserRole) setState(() => _otherUserRole = role);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentRole());

    if (_currentUserId != null) {
      _subscribeToChats();
    }
  }

  void _loadCurrentRole() {
    final auth = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final role = UserRoles.normalizeRole(auth.userRole ?? '');
    if (!mounted) return;
    setState(() => _currentUserRole = role);
  }

  void _subscribeToChats() {
    _chatsSub = _chatService.getUserChats(_currentUserId!).listen((chats) {
      if (!mounted) return;
      // Keep only chats involving both current user and other user
      final relevant = chats
          .where((c) => c.participants.contains(widget.otherUserId))
          .toList();
      _rebuildTabs(relevant);
    });
  }

  void _rebuildTabs(List<ChatModel> chats) {
    final newEntries = _deriveTabs(chats);

    // Determine the target active index (preserve or find initialChatId)
    int targetIndex = 0;
    if (_tabs.isNotEmpty && _activeTabIndex < _tabs.length) {
      final previousChatId = _tabs[_activeTabIndex].chatId;
      final idx = newEntries.indexWhere((e) => e.chatId == previousChatId);
      targetIndex = idx >= 0 ? idx : 0;
    }
    if (widget.initialChatId != null && _tabs.isEmpty) {
      final idx =
          newEntries.indexWhere((e) => e.chatId == widget.initialChatId);
      if (idx >= 0) targetIndex = idx;
    }

    // Rebuild TabController only when tab count changes
    final needsNewController =
        _tabController == null || _tabController!.length != newEntries.length;
    if (needsNewController) {
      _tabController?.dispose();
      _tabController = TabController(
        length: newEntries.isEmpty ? 1 : newEntries.length,
        vsync: this,
        initialIndex:
            targetIndex < newEntries.length ? targetIndex : 0,
      );
      _tabController!.addListener(() {
        if (!mounted) return;
        setState(() => _activeTabIndex = _tabController!.index);
      });
    } else if (targetIndex != _activeTabIndex) {
      _tabController!.animateTo(targetIndex);
    }

    setState(() {
      _tabs = newEntries;
      _activeTabIndex =
          targetIndex < newEntries.length ? targetIndex : 0;
    });
  }

  List<_ChatTabEntry> _deriveTabs(List<ChatModel> chats) {
    final entries = <_ChatTabEntry>[];
    final uid = _currentUserId ?? '';

    // 1. Normal chat (not work, not job)
    final normalChats = chats
        .where((c) => !c.isWorkChat && !c.isJobChat)
        .toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    if (normalChats.isNotEmpty) {
      final c = normalChats.first;
      entries.add(_ChatTabEntry(
        chatId: c.id,
        label: 'Chat',
        icon: Icons.chat_bubble_outline_rounded,
        unreadCount: c.unreadCount[uid] ?? 0,
      ));
    }

    // 2. Hiring / work chat
    final hiringChats = chats
        .where((c) => c.isWorkChat && !c.isJobChat)
        .toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    if (hiringChats.isNotEmpty) {
      final c = hiringChats.first;
      entries.add(_ChatTabEntry(
        chatId: c.id,
        label: 'Hiring',
        icon: Icons.handshake_outlined,
        isHiring: true,
        unreadCount: c.unreadCount[uid] ?? 0,
      ));
    }

    // 3. Job chats (one per job, sorted by time)
    final jobChats = chats.where((c) => c.isJobChat).toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    // De-duplicate by jobId (keep newest per job)
    final seenJobIds = <String>{};
    for (final c in jobChats) {
      final jobKey = (c.jobId?.isNotEmpty == true) ? c.jobId! : c.id;
      if (seenJobIds.contains(jobKey)) continue;
      seenJobIds.add(jobKey);
      final title = (c.jobTitle?.trim().isNotEmpty == true)
          ? c.jobTitle!
          : 'Job Chat';
      entries.add(_ChatTabEntry(
        chatId: c.id,
        label: title,
        icon: Icons.work_history_rounded,
        isJob: true,
        jobTitle: title,
        unreadCount: c.unreadCount[uid] ?? 0,
      ));
    }

    // Fallback: if no chats exist at all, show a placeholder "Chat" tab with
    // a stub chatId so the pane can still send the first message.
    if (entries.isEmpty) {
      entries.add(const _ChatTabEntry(
        chatId: '__new__',
        label: 'Chat',
        icon: Icons.chat_bubble_outline_rounded,
      ));
    }

    return entries;
  }

  // ── Active tab helpers ────────────────────────────────────────────────────────
  _ChatTabEntry? get _activeTab =>
      _tabs.isNotEmpty && _activeTabIndex < _tabs.length
          ? _tabs[_activeTabIndex]
          : null;

  bool get _canSendOfferLetter =>
      _activeTab != null &&
      (_activeTab!.isHiring || _activeTab!.isJob) &&
      _currentUserRole == UserRoles.company &&
      _otherUserRole == UserRoles.skilledPerson;

  bool get _canShareProfile =>
      _activeTab != null &&
      (_activeTab!.isHiring || _activeTab!.isJob) &&
      _currentUserRole == UserRoles.skilledPerson &&
      _otherUserRole == UserRoles.company;

  bool get _isHiringConversation =>
      (_currentUserRole == UserRoles.company &&
          _otherUserRole == UserRoles.skilledPerson) ||
      (_currentUserRole == UserRoles.skilledPerson &&
          _otherUserRole == UserRoles.company);

  @override
  void dispose() {
    _chatsSub?.cancel();
    _otherRoleSub?.cancel();
    _tabController?.dispose();
    _bubbleCtrl.dispose();
    _gradientCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        toolbarHeight: 90,
        titleSpacing: 6,
        leadingWidth: 48,
        title: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: StreamBuilder<UserPresence>(
            stream: PresenceService.instance.watchUser(widget.otherUserId),
            builder: (context, presSnap) {
              final isOnline = presSnap.data?.isOnline ?? false;
              final lastSeen = presSnap.data?.lastSeen;
              String subtitle;
              if (isOnline) {
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
                        radius: 17,
                        backgroundColor: Colors.transparent,
                        child: UniversalAvatar(
                          photoUrl: widget.otherUserPhoto,
                          fallbackName: widget.otherUserName,
                          radius: 17,
                          animate: false,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppHelpers.capitalize(widget.otherUserName),
                          style: GoogleFonts.lora(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.lora(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOnline
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
        ),
        actions: _buildAppBarActions(),
        bottom: _tabs.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: _buildTabStrip(),
              )
            : null,
        flexibleSpace: _buildAppBarBackground(),
      ),
      body: _buildBody(),
    );
  }

  List<Widget> _buildAppBarActions() {
    final actions = <Widget>[];

    if (_canSendOfferLetter) {
      actions.add(IconButton(
        tooltip: 'Send Offer Letter',
        onPressed: _showOfferLetterDialog,
        icon: const Icon(Icons.description_rounded, color: Colors.white),
      ));
    }

    if (_canShareProfile) {
      actions.add(IconButton(
        tooltip: 'Share My Profile',
        onPressed: _shareProfileInChat,
        icon: const Icon(Icons.badge_rounded, color: Colors.white),
      ));
    }

    if (_isHiringConversation) {
      actions.add(IconButton(
        tooltip: _currentUserRole == UserRoles.company
            ? 'View Skilled Profile'
            : 'View Company Profile',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ProfileScreen(userId: widget.otherUserId)),
        ),
        icon: Icon(
          _currentUserRole == UserRoles.company
              ? Icons.person_search_rounded
              : Icons.apartment_rounded,
          color: Colors.white,
        ),
      ));
    }

    actions.add(PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      onSelected: (v) {
        if (v == 'offer_letter') _showOfferLetterDialog();
        if (v == 'share_profile') _shareProfileInChat();
        if (v == 'view_profile') {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    ProfileScreen(userId: widget.otherUserId)),
          );
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];
        if (_canSendOfferLetter) {
          items.add(const PopupMenuItem(
            value: 'offer_letter',
            child: Row(children: [
              Icon(Icons.description_rounded, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Send Offer Letter'),
            ]),
          ));
        }
        if (_canShareProfile) {
          items.add(const PopupMenuItem(
            value: 'share_profile',
            child: Row(children: [
              Icon(Icons.badge_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text('Share Full Profile'),
            ]),
          ));
        }
        items.add(const PopupMenuItem(
          value: 'view_profile',
          child: Row(children: [
            Icon(Icons.person_outline, color: Colors.grey),
            SizedBox(width: 8),
            Text('View Profile'),
          ]),
        ));
        return items;
      },
    ));

    return actions;
  }

  Widget _buildBody() {
    if (_tabs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tabs.length == 1) {
      // Single pane — no tab bar
      return _buildPane(_tabs.first);
    }

    // Multiple panes via IndexedStack (keeps state alive)
    return IndexedStack(
      index: _activeTabIndex < _tabs.length ? _activeTabIndex : 0,
      children: _tabs.map((t) => _buildPane(t)).toList(),
    );
  }

  Widget _buildPane(_ChatTabEntry entry) {
    if (entry.chatId == '__new__') {
      // No chat yet — show empty state with "start chatting" message
      return _NewChatPlaceholder(
        currentUserId: _currentUserId!,
        otherUserId: widget.otherUserId,
        otherUserName: widget.otherUserName,
        otherUserPhoto: widget.otherUserPhoto,
        chatService: _chatService,
      );
    }
    return _ChatPane(
      key: ValueKey(entry.chatId),
      chatId: entry.chatId,
      currentUserId: _currentUserId!,
      otherUserId: widget.otherUserId,
      otherUserName: widget.otherUserName,
      otherUserPhoto: widget.otherUserPhoto,
      currentUserRole: _currentUserRole,
      otherUserRole: _otherUserRole,
      isHiringChat: entry.isHiring,
      isJobChat: entry.isJob,
      onOfferLetter: _canSendOfferLetter ? _showOfferLetterDialog : null,
      onShareProfile: _canShareProfile ? _shareProfileInChat : null,
    );
  }

  // ── Tab Strip ─────────────────────────────────────────────────────────────────

  Widget _buildTabStrip() {
    if (_tabController == null || _tabs.length <= 1) return const SizedBox();

    return Container(
      height: 66,
      margin: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF3FB),
        border: Border(
          top: BorderSide(color: Color(0xFFD5DEEE)),
          bottom: BorderSide(color: Color(0xFFD5DEEE)),
        ),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final tab = _tabs[i];
          final isActive = _activeTabIndex == i;
          const br = BorderRadius.zero;

              // Color scheme per tab type
              List<Color> activeColors;
              if (tab.isHiring) {
                activeColors = const [
                  Color(0xFF1B5E20),
                  Color(0xFF2E7D32),
                  Color(0xFF43A047),
                ];
              } else if (tab.isJob) {
                activeColors = const [
                  Color(0xFF0D47A1),
                  Color(0xFF1565C0),
                  Color(0xFF1E88E5),
                ];
              } else {
                activeColors = const [
                  Color(0xFF4A148C),
                  Color(0xFF7B1FA2),
                  Color(0xFFAB47BC),
                ];
              }

              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: br,
                  child: InkWell(
                    borderRadius: br,
                    onTap: () {
                      if (_activeTabIndex == i) return;
                      setState(() => _activeTabIndex = i);
                      _tabController!.animateTo(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: isActive ? null : Colors.white,
                        gradient: isActive
                            ? LinearGradient(
                                colors: activeColors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        borderRadius: br,
                        border: Border.all(
                          color: isActive
                              ? Colors.transparent
                              : const Color(0xFFD7DEEF),
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: activeColors[1]
                                      .withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 18,
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF6D758D),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tab.label,
                                  style: GoogleFonts.lora(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF6D758D),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          // Unread badge
                          if (tab.unreadCount > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFFE91E63),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                child: Center(
                                  child: Text(
                                    tab.unreadCount > 99
                                        ? '99+'
                                        : '${tab.unreadCount}',
                                    style: TextStyle(
                                      color: isActive
                                          ? activeColors.first
                                          : Colors.white,
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
                  ),
                ),
              );
        }),
      ),
    );
  }

  // ── AppBar background ─────────────────────────────────────────────────────────

  Widget _buildAppBarBackground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_bubbleCtrl, _gradientCtrl]),
      builder: (context, _) {
        final t = _bubbleCtrl.value;
        final gt = Curves.easeInOut.transform(_gradientCtrl.value);
        final curr = _gradientPhases[_gradientPhase];
        final next =
            _gradientPhases[(_gradientPhase + 1) % _gradientPhases.length];
        final c1 = Color.lerp(curr[0], next[0], gt)!;
        final c2 = Color.lerp(curr[1], next[1], gt)!;
        final c3 = Color.lerp(curr[2], next[2], gt)!;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c1, c2, c3],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -10 + 28 * math.sin(t * 2 * math.pi),
              top: 4 + 12 * math.cos(t * 2 * math.pi),
              child: _bubble(56, Colors.white.withValues(alpha: 0.09)),
            ),
            Positioned(
              right: 70 + 22 * math.cos(t * 2 * math.pi + 1.2),
              top: -8 + 16 * math.sin(t * 2 * math.pi + 1.2),
              child: _bubble(36, Colors.white.withValues(alpha: 0.07)),
            ),
            Positioned(
              left: 60 + 18 * math.sin(t * 2 * math.pi + 2.4),
              bottom: 4 + 8 * math.cos(t * 2 * math.pi + 2.4),
              child: _bubble(28, Colors.white.withValues(alpha: 0.06)),
            ),
          ],
        );
      },
    );
  }

  Widget _bubble(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  // ── Offer Letter ─────────────────────────────────────────────────────────────

  Future<void> _showOfferLetterDialog() async {
    if (_currentUserId == null || _activeTab == null) return;
    if (!_canSendOfferLetter) {
      AppDialog.info(context,
          'Offer letter can be sent only from a company to a skilled person in a hiring or job chat.');
      return;
    }
    final chatId = _activeTab!.chatId;

    final posCtrl = TextEditingController();
    final compCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    InputDecoration fieldDeco(String label, String hint, IconData icon) =>
        InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF3949AB)),
          filled: true,
          fillColor: const Color(0xFFF5F3FF),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          labelStyle: const TextStyle(fontSize: 13),
        );

    final shouldSend = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1A237E),
                      Color(0xFF3949AB),
                      Color(0xFF5C6BC0)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.description_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Send Offer Letter',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('Fill in the hiring details below',
                              style:
                                  TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(false),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    children: [
                      TextField(
                          controller: posCtrl,
                          decoration: fieldDeco('Position / Role *',
                              'e.g., Senior Tailor', Icons.work_outline_rounded)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: compCtrl,
                          decoration: fieldDeco('Compensation *',
                              'e.g., ₹35,000/month',
                              Icons.currency_rupee_rounded),
                          keyboardType: TextInputType.text),
                      const SizedBox(height: 12),
                      TextField(
                          controller: locCtrl,
                          decoration: fieldDeco('Work Location',
                              'e.g., Chennai, Tamil Nadu',
                              Icons.location_on_outlined)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: dateCtrl,
                          decoration: fieldDeco('Joining Date',
                              'e.g., 20 March 2026',
                              Icons.calendar_today_outlined)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: notesCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: fieldDeco(
                              'Additional Terms',
                              'e.g., probation period, benefits',
                              Icons.notes_rounded)),
                      const SizedBox(height: 8),
                      Text('* Required fields',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: Color(0xFF3949AB)),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFF3949AB))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          icon: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                          label: const Text('Send Offer Letter',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final position = posCtrl.text.trim();
    final compensation = compCtrl.text.trim();
    if (shouldSend != true) {
      posCtrl.dispose();
      compCtrl.dispose();
      locCtrl.dispose();
      dateCtrl.dispose();
      notesCtrl.dispose();
      return;
    }
    if (position.isEmpty || compensation.isEmpty) {
      if (mounted) {
        AppDialog.error(context, 'Position and compensation are required.');
      }
      posCtrl.dispose();
      compCtrl.dispose();
      locCtrl.dispose();
      dateCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final buf = StringBuffer()
      ..writeln('Offer Letter')
      ..writeln('Position: $position')
      ..writeln('Compensation: $compensation');
    if (locCtrl.text.trim().isNotEmpty) {
      buf.writeln('Location: ${locCtrl.text.trim()}');
    }
    if (dateCtrl.text.trim().isNotEmpty) {
      buf.writeln('Joining Date: ${dateCtrl.text.trim()}');
    }
    if (notesCtrl.text.trim().isNotEmpty) {
      buf.writeln('Terms: ${notesCtrl.text.trim()}');
    }

    try {
      await _chatService.sendMessage(
        chatId: chatId,
        senderId: _currentUserId!,
        receiverId: widget.otherUserId,
        text: buf.toString().trim(),
        type: 'offer_letter',
      );
      if (!mounted) return;
      AppDialog.success(context, 'Offer letter sent successfully!');
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'Failed to send offer letter',
          detail: e.toString());
    } finally {
      posCtrl.dispose();
      compCtrl.dispose();
      locCtrl.dispose();
      dateCtrl.dispose();
      notesCtrl.dispose();
    }
  }

  // ── Share Profile ─────────────────────────────────────────────────────────────

  Future<void> _shareProfileInChat() async {
    if (_currentUserId == null || _activeTab == null) return;
    if (!_canShareProfile) {
      AppDialog.info(context,
          'Profile sharing is available only for skilled persons in a hiring or job chat.');
      return;
    }
    final chatId = _activeTab!.chatId;
    final fsService = FirestoreService();
    try {
      final user = await fsService.getUserById(_currentUserId!);
      final profile = await fsService.getSkilledUserProfile(_currentUserId!);
      if (profile == null) throw Exception('Skilled profile not found.');

      final location = [
        profile.city?.trim(),
        profile.state?.trim(),
        profile.address?.trim(),
      ].where((e) => e != null && e.isNotEmpty).map((e) => e!).toList();

      final profileText = StringBuffer()
        ..writeln('Shared Skilled Profile')
        ..writeln(
            'Name: ${(user?.name ?? profile.name ?? 'Skilled Person').trim()}')
        ..writeln('Category: ${(profile.category ?? 'Not specified').trim()}')
        ..writeln(
            'Skills: ${profile.skills.isEmpty ? 'Not specified' : profile.skills.join(', ')}')
        ..writeln(
            'Bio: ${profile.bio.isEmpty ? 'Not provided' : profile.bio}')
        ..writeln(
            'Location: ${location.isEmpty ? 'Not provided' : location.join(', ')}')
        ..writeln(
            'Rating: ${profile.rating.toStringAsFixed(1)} (${profile.reviewCount} reviews)')
        ..writeln('Completed Projects: ${profile.projectCount}')
        ..writeln('Portfolio Items: ${profile.portfolioImages.length}');

      if (profile.profilePicture != null &&
          profile.profilePicture!.trim().isNotEmpty) {
        profileText
            .writeln('Profile Photo: ${profile.profilePicture!.trim()}');
      }

      await _chatService.sendMessage(
        chatId: chatId,
        senderId: _currentUserId!,
        receiverId: widget.otherUserId,
        text: profileText.toString().trim(),
        type: 'profile_share',
      );

      if (!mounted) return;
      AppDialog.success(
          context, 'Your full profile has been shared with the company!');
    } catch (e) {
      if (!mounted) return;
      AppDialog.error(context, 'Failed to share profile',
          detail: e.toString());
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Placeholder when no chat exists yet
// ─────────────────────────────────────────────────────────────────────────────

class _NewChatPlaceholder extends StatelessWidget {
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final ChatService chatService;

  const _NewChatPlaceholder({
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.chatService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No messages yet',
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Start the conversation!',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey[500])),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.white),
          child: SafeArea(
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onSubmitted: (text) async {
                      if (text.trim().isEmpty) return;
                      try {
                        final cid = await chatService.getOrCreateChat(
                          currentUserId,
                          otherUserId,
                          {'name': '', 'photo': ''},
                          {'name': otherUserName, 'photo': otherUserPhoto ?? ''},
                        );
                        await chatService.sendMessage(
                          chatId: cid,
                          senderId: currentUserId,
                          receiverId: otherUserId,
                          text: text.trim(),
                          type: 'text',
                        );
                      } catch (_) {}
                    },
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
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF9C27B0), Color(0xFFE91E63)]),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ChatPane — a self-contained chat body for one chatId within the hub
// ─────────────────────────────────────────────────────────────────────────────

class _ChatPane extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String? currentUserRole;
  final String? otherUserRole;
  final bool isHiringChat;
  final bool isJobChat;
  final VoidCallback? onOfferLetter;
  final VoidCallback? onShareProfile;

  const _ChatPane({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    this.currentUserRole,
    this.otherUserRole,
    this.isHiringChat = false,
    this.isJobChat = false,
    this.onOfferLetter,
    this.onShareProfile,
  });

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final ChatService _chatService = ChatService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  late final Stream<List<MessageModel>> _messageStream;
  bool _isSending = false;
  bool _isLoading = false;
  bool _markingRead = false;
  MessageModel? _editingMsg;

  bool _otherUserOnline = false;
  StreamSubscription<UserPresence>? _presenceSub;

  @override
  void initState() {
    super.initState();
    _messageStream = _chatService.getMessages(widget.chatId, limit: 150);

    _presenceSub = PresenceService.instance
        .watchUser(widget.otherUserId)
        .listen((p) {
      if (!mounted) return;
      if (p.isOnline != _otherUserOnline) {
        setState(() => _otherUserOnline = p.isOnline);
      }
    });

    // Mark on open
    _chatService.markMessagesAsRead(widget.chatId, widget.currentUserId);
  }

  @override
  void dispose() {
    _presenceSub?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Sending ───────────────────────────────────────────────────────────────────

  Future<void> _sendMessage({String? imageUrl}) async {
    final text = _msgCtrl.text.trim();

    if (_editingMsg != null) {
      if (text.isEmpty) return;
      setState(() => _isSending = true);
      try {
        await _chatService.editMessage(
          chatId: widget.chatId,
          messageId: _editingMsg!.id,
          senderId: widget.currentUserId,
          newText: text,
        );
        _cancelEdit();
      } catch (e) {
        if (mounted) {
          AppPopup.show(context,
              message: 'Error editing: $e', type: PopupType.error);
        }
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      return;
    }

    if (text.isEmpty && imageUrl == null) return;
    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        receiverId: widget.otherUserId,
        text: imageUrl != null ? 'Image' : text,
        type: imageUrl != null ? 'image' : 'text',
        mediaUrl: imageUrl,
      );
      _msgCtrl.clear();
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error sending: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startEdit(MessageModel msg) {
    setState(() {
      _editingMsg = msg;
      _msgCtrl.text = msg.text;
      _msgCtrl.selection =
          TextSelection.collapsed(offset: msg.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMsg = null;
      _msgCtrl.clear();
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _chatService.deleteMessage(
        chatId: widget.chatId,
        messageId: msg.id,
        senderId: widget.currentUserId,
      );
    } catch (e) {
      if (mounted) {
        AppPopup.show(context,
            message: 'Error deleting: $e', type: PopupType.error);
      }
    }
  }

  void _showMsgOptions(MessageModel msg) {
    if (msg.isDeleted) return;
    final isMe = msg.senderId == widget.currentUserId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
              if (isMe && msg.type == 'text')
                ListTile(
                  leading: const Icon(Icons.edit_outlined,
                      color: Colors.deepPurple),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    _startEdit(msg);
                  },
                ),
              if (isMe)
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

  Future<void> _markAsReadIfNeeded(List<MessageModel> messages) async {
    if (_markingRead) return;
    final hasUnread = messages
        .any((m) => !m.isRead && m.senderId != widget.currentUserId);
    if (!hasUnread) return;
    _markingRead = true;
    try {
      await _chatService.markMessagesAsRead(
          widget.chatId, widget.currentUserId);
    } finally {
      _markingRead = false;
    }
  }

  // ── Image ─────────────────────────────────────────────────────────────────────

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? img = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (img == null) return;
      setState(() => _isLoading = true);
      final url = await _cloudinaryService.uploadImage(File(img.path),
          folder: 'chat_media');
      if (url != null) await _sendMessage(imageUrl: url);
    } on Exception catch (e) {
      if (mounted && !e.toString().contains('cancel')) {
        AppDialog.error(context, 'Error uploading image',
            detail: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? img = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (img == null) return;
      setState(() => _isLoading = true);
      final url = await _cloudinaryService.uploadImage(File(img.path),
          folder: 'chat_media');
      if (url != null) await _sendMessage(imageUrl: url);
    } on Exception catch (e) {
      if (mounted && !e.toString().contains('cancel')) {
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
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
        builder: (_) => _ImagePreviewPage(imageUrl: imageUrl)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
              unawaited(_markAsReadIfNeeded(messages));

              return ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == widget.currentUserId;
                  final showDate = index == messages.length - 1 ||
                      !_isSameDay(
                          msg.createdAt, messages[index + 1].createdAt);
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
                              AppHelpers.formatDate(msg.createdAt),
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[700]),
                            ),
                          ),
                        ),
                      _buildBubble(msg, isMe),
                    ],
                  );
                },
              );
            },
          ),
        ),
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
        if (_editingMsg != null)
          Container(
            color: Colors.deepPurple.withValues(alpha: 0.07),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.edit_outlined,
                    size: 16, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Editing: ${_editingMsg!.text}',
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
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Color(0xFF9C27B0)),
                  onPressed:
                      _isLoading || _isSending ? null : _showImageOptions,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
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
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isLoading && !_isSending,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF9C27B0), Color(0xFFE91E63)]),
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
                            _editingMsg != null
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

  // ── Message bubble ────────────────────────────────────────────────────────────

  Widget _buildBubble(MessageModel msg, bool isMe) {
    final isDeleted = msg.isDeleted;
    final isEdited = msg.editedAt != null && !isDeleted;
    final isHighlighted = _editingMsg?.id == msg.id;
    final isStructured =
        msg.type == 'offer_letter' || msg.type == 'profile_share';
    final isCompanyMsg =
        msg.senderId == widget.otherUserId &&
            widget.otherUserRole == UserRoles.company;

    return GestureDetector(
      onLongPress: () => _showMsgOptions(msg),
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
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        blurRadius: 8),
                  ],
                )
              : null,
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Company badge for company's messages
              if (isCompanyMsg)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3949AB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color:
                            const Color(0xFF3949AB).withValues(alpha: 0.25)),
                  ),
                  child: const Text(
                    'COMPANY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                      color: Color(0xFF3949AB),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe && !isDeleted && !isStructured
                      ? const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFFE91E63)])
                      : null,
                  color: isDeleted
                      ? Colors.grey[200]
                      : isStructured
                          ? (isMe
                              ? const Color(0xFFF3ECFF)
                              : const Color(0xFFEAF5FF))
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
                          Icon(Icons.block, size: 13, color: Colors.grey[500]),
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
                    : msg.type == 'image'
                        ? GestureDetector(
                            onTap: () => _showImagePreview(msg.mediaUrl!),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: WebImageLoader.loadImage(
                                imageUrl: msg.mediaUrl,
                                width: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        : isStructured
                            ? _buildStructuredCard(msg)
                            : Text(
                                msg.text,
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
                  Text(AppHelpers.formatTime(msg.createdAt),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600])),
                  if (isMe && !isDeleted) ...[
                    const SizedBox(width: 4),
                    Icon(
                        (msg.isRead || _otherUserOnline)
                            ? Icons.done_all
                            : Icons.done,
                        size: 14,
                        color: msg.isRead
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

  Widget _buildStructuredCard(MessageModel msg) {
    final lines = msg.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final title = lines.isNotEmpty ? lines.first : 'Message';
    final content =
        lines.length > 1 ? lines.skip(1).join('\n') : '';

    if (msg.type == 'offer_letter') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_rounded,
                  size: 16, color: Color(0xFF3949AB)),
              SizedBox(width: 6),
              Text('Offer Letter',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A237E),
                  )),
            ],
          ),
          if (title.toLowerCase() != 'offer letter') ...[
            const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF263238))),
          ],
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(content,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF37474F))),
          ],
        ],
      );
    }

    // profile_share
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_rounded, size: 16, color: Color(0xFF00796B)),
            SizedBox(width: 6),
            Text('Shared Full Profile',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF004D40),
                )),
          ],
        ),
        if (title.toLowerCase() != 'shared skilled profile') ...[
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF263238))),
        ],
        if (content.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(content,
              style: const TextStyle(
                  fontSize: 13, height: 1.35, color: Color(0xFF37474F))),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ProfileScreen(userId: msg.senderId)),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Open Shared Profile'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) =>
      d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Simple image preview page
// ─────────────────────────────────────────────────────────────────────────────

class _ImagePreviewPage extends StatelessWidget {
  final String imageUrl;
  const _ImagePreviewPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          child: WebImageLoader.loadImage(imageUrl: imageUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
