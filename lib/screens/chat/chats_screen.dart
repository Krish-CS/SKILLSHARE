import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import '../../utils/app_helpers.dart';
import '../../utils/app_constants.dart';
import '../../utils/user_roles.dart';
import '../../widgets/universal_avatar.dart';
import 'chat_detail_screen.dart';
import 'company_chat_hub_screen.dart';

// ─── Helper: groups multiple chat types for the same person ─────────────────
class _PersonChatGroup {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  ChatModel? normalChat;
  ChatModel? hiringChat;
  final List<ChatModel> jobChats = [];

  _PersonChatGroup({
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  void addChat(ChatModel chat) {
    if (chat.isJobChat || chat.id.startsWith('jobchat_')) {
      jobChats.add(chat);
    } else if (chat.isWorkChat || chat.id.startsWith('work_')) {
      if (hiringChat == null ||
          chat.lastMessageTime.isAfter(hiringChat!.lastMessageTime)) {
        hiringChat = chat;
      }
    } else {
      if (normalChat == null ||
          chat.lastMessageTime.isAfter(normalChat!.lastMessageTime)) {
        normalChat = chat;
      }
    }
  }

  /// Total unread across all chats for a given userId.
  int totalUnread(String currentUserId) {
    int count = 0;
    if (normalChat != null) count += normalChat!.unreadCount[currentUserId] ?? 0;
    if (hiringChat != null) count += hiringChat!.unreadCount[currentUserId] ?? 0;
    for (final j in jobChats) {
      count += j.unreadCount[currentUserId] ?? 0;
    }
    return count;
  }

  /// Latest message time across all chats.
  DateTime get latestTime {
    final times = <DateTime>[
      if (normalChat != null) normalChat!.lastMessageTime,
      if (hiringChat != null) hiringChat!.lastMessageTime,
      ...jobChats.map((j) => j.lastMessageTime),
    ];
    if (times.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return times.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// The most recent last-message text (for subtitle in list item).
  String get latestMessage {
    final all = <ChatModel>[
      if (normalChat != null) normalChat!,
      if (hiringChat != null) hiringChat!,
      ...jobChats,
    ];
    if (all.isEmpty) return '';
    all.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return all.first.lastMessage;
  }

  /// How many distinct chat types exist beyond just a single normal chat.
  bool get hasMultipleTypes {
    int count = 0;
    if (normalChat != null) count++;
    if (hiringChat != null) count++;
    count += jobChats.length;
    return count > 1;
  }
}

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String?> _roleCache = {};
  final Set<String> _roleLoading = {};

  String _searchQuery = '';
  String? _currentUserId;
  Stream<List<ChatModel>>? _chatsStream;
  List<ChatModel> _lastKnownChats = const <ChatModel>[];

  /// Map of chatId → number of pending work requests for that chat.
  /// Updated via a real subscription so amber badges are always in sync.
  Map<String, int> _pendingWorkCounts = {};
  StreamSubscription<QuerySnapshot>? _workReqSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userRoleSub;
  StreamSubscription<User?>? _authSub;
  String? _currentUserRole;
  final Set<String> _ghostCleanupScheduled = <String>{};

  String _friendlyChatsError(Object error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'Chat access is restricted for one or more conversations.';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'Network issue while loading chats. Please retry.';
      }
    }
    return 'Unable to load chats right now.';
  }

  bool _isGhostEmptyDirectChat(ChatModel chat) {
    if (_isJobChat(chat) || _isHiringChat(chat) || chat.isWorkChat || chat.isJobChat) {
      return false;
    }
    if (chat.participants.length != 2) return false;
    if (chat.lastMessage.trim().isNotEmpty) return false;
    final hasUnread =
      chat.unreadCount.values.any((unreadValue) => unreadValue > 0);
    if (hasUnread) return false;
    return true;
  }

  void _scheduleGhostChatCleanup(List<ChatModel> chats) {
    final uid = _currentUserId;
    if (uid == null) return;

    final toPrune = chats
        .where(_isGhostEmptyDirectChat)
        .where((chat) => !_ghostCleanupScheduled.contains(chat.id))
        .toList();
    if (toPrune.isEmpty) return;

    for (final chat in toPrune) {
      _ghostCleanupScheduled.add(chat.id);
    }

    unawaited(
      _chatService.pruneEmptyDirectChatsForUser(uid, toPrune).catchError((_) {
        for (final chat in toPrune) {
          _ghostCleanupScheduled.remove(chat.id);
        }
      }),
    );
  }

  void _bindCurrentUser(String? userId) {
    _workReqSub?.cancel();
    _workReqSub = null;
    _userRoleSub?.cancel();
    _userRoleSub = null;

    _currentUserId = userId;
    _chatsStream = null;
    _currentUserRole = null;
    _pendingWorkCounts = {};
    _lastKnownChats = const <ChatModel>[];
    _ghostCleanupScheduled.clear();

    if (userId == null || userId.isEmpty) {
      return;
    }

    _chatsStream = _chatService.getUserChats(userId);

    _userRoleSub = FirebaseFirestore.instance
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .listen((doc) {
      final role = (doc.data()?['role'] as String?)?.trim();
      if (!mounted) return;
      setState(() => _currentUserRole = role);
    });

    // Listen to pending work requests for this user and keep the count map
    // updated so chat list badges remain fresh.
    _workReqSub = FirebaseFirestore.instance
        .collection(AppConstants.requestsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .listen((snap) {
      final newCounts = <String, int>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final type = (d['type'] as String?) ?? '';
        final serviceId = (d['serviceId'] as String?) ?? '';
        final status = (d['status'] as String?) ?? '';
        final chatId = (d['chatId'] as String?) ?? '';
        if ((type == 'chat_work_request' || serviceId == 'direct_hire') &&
            status == AppConstants.requestStatusPending &&
            chatId.isNotEmpty) {
          newCounts[chatId] = (newCounts[chatId] ?? 0) + 1;
        }
      }
      if (mounted) setState(() => _pendingWorkCounts = newCounts);
    });
  }

  Future<void> _openChatSafely(ChatModel chat) async {
    final liveUserId = FirebaseAuth.instance.currentUser?.uid ?? _currentUserId;
    if (liveUserId == null || liveUserId.isEmpty) {
      return;
    }

    final otherUserId = chat.participants.firstWhere(
      (id) => id != liveUserId,
      orElse: () => '',
    );
    if (otherUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this chat right now.')),
      );
      return;
    }

    final otherUserDetails = chat.participantDetails[otherUserId];
    final otherUserName = otherUserDetails?['name'] ?? 'Unknown';
    final otherUserPhoto = otherUserDetails?['photo'];

    var targetChatId = chat.id;
    final isDirectChat = !_isJobChat(chat) && !_isHiringChat(chat);
    if (isDirectChat) {
      try {
        targetChatId = await _chatService.resolveAccessibleDirectChatId(
          preferredChatId: chat.id,
          currentUserId: liveUserId,
          otherUserId: otherUserId,
        );
      } on FirebaseException catch (e) {
        debugPrint('Direct chat resolve failed for ${chat.id}: ${e.code}');
      } catch (e) {
        debugPrint('Direct chat resolve failed for ${chat.id}: $e');
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          chatId: targetChatId,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          otherUserPhoto: otherUserPhoto,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bindCurrentUser(FirebaseAuth.instance.currentUser?.uid);

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final nextUserId = user?.uid;
      if (nextUserId == _currentUserId) return;
      if (!mounted) return;
      setState(() => _bindCurrentUser(nextUserId));
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _workReqSub?.cancel();
    _userRoleSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chats', style: TextStyle(color: Colors.white)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: const Center(
          child: Text('Please sign in to view chats'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Chats List
          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              stream: _chatsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  _lastKnownChats = List<ChatModel>.from(snapshot.data!);
                }

                final hasCachedChats = _lastKnownChats.isNotEmpty;
                final hasSnapshotChats =
                    snapshot.hasData && snapshot.data!.isNotEmpty;

                if (snapshot.hasError) {
                  final isPermissionError =
                      snapshot.error is FirebaseException &&
                      (snapshot.error as FirebaseException).code ==
                          'permission-denied';

                  if (hasCachedChats && !isPermissionError) {
                    return _buildGroupedChatList(chats: _lastKnownChats);
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _friendlyChatsError(snapshot.error!),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!hasSnapshotChats && hasCachedChats) {
                  return _buildGroupedChatList(chats: _lastKnownChats);
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                List<ChatModel> chats = snapshot.data!;

                _scheduleGhostChatCleanup(chats);
                chats = chats.where((chat) => !_isGhostEmptyDirectChat(chat)).toList();

                // Filter chats based on search
                if (_searchQuery.isNotEmpty) {
                  chats = chats.where((chat) {
                    final otherUserId = chat.participants.firstWhere(
                      (id) => id != _currentUserId,
                      orElse: () => '',
                    );
                    final otherUserDetails =
                        chat.participantDetails[otherUserId];
                    final name =
                        otherUserDetails?['name']?.toString().toLowerCase() ??
                            '';
                    final lastMessage = chat.lastMessage.toLowerCase();

                    return name.contains(_searchQuery) ||
                        lastMessage.contains(_searchQuery);
                  }).toList();
                }

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No chats found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return _buildGroupedChatList(chats: chats);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedChatList({
    required List<ChatModel> chats,
  }) {
    final visibleChats = _collapseChatsByParticipant(chats)
        .where((chat) => !_isGhostEmptyDirectChat(chat))
        .toList();
    _warmRoleCacheForChats(visibleChats);

    final jobChats = <ChatModel>[];
    final companyChats = <ChatModel>[];
    final customerChats = <ChatModel>[];
    final skilledChats = <ChatModel>[];
    final deliveryChats = <ChatModel>[];
    final unknownChats = <ChatModel>[];

    for (final chat in visibleChats) {
      if (_isJobChat(chat)) {
        jobChats.add(chat);
        continue;
      }
      final otherRole = _resolvedOtherRoleForChat(chat);
      if (otherRole == UserRoles.company) {
        companyChats.add(chat);
      } else if (otherRole == UserRoles.deliveryPartner) {
        deliveryChats.add(chat);
      } else if (otherRole == UserRoles.skilledPerson) {
        skilledChats.add(chat);
      } else if (otherRole == UserRoles.customer) {
        customerChats.add(chat);
      } else {
        unknownChats.add(chat);
      }
    }

    final isSkilledPerson =
        UserRoles.normalizeRole(_currentUserRole) == UserRoles.skilledPerson;
    final isCustomer =
        UserRoles.normalizeRole(_currentUserRole) == UserRoles.customer;
    if (isSkilledPerson) {
      return _buildSkilledRoleTabs(
        customerChats: customerChats,
        skilledChats: [...skilledChats, ...unknownChats],
        companyChats: [...jobChats, ...companyChats],
      );
    }

    if (isCustomer) {
      if (visibleChats.isEmpty) {
        return _buildEmptyState();
      }
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: visibleChats.map(_buildChatItem).toList(),
      );
    }

    final sectionWidgets = <Widget>[];

    // ── Merge job chats with matching same-person chats for company hub ──────
    // Any person who has BOTH a job chat AND a regular/hiring chat will be
    // grouped into a single hub entry.  We collect all "company-related" chats
    // (job + company bucket) together and group them by person.
    final allCompanyRelated = <ChatModel>[...jobChats, ...companyChats];
    final companyGroups = _groupCompanyChats(allCompanyRelated);

    // Rebuild per-bucket lists excluding already-grouped persons
    final groupedPersonIds =
        companyGroups.map((g) => g.otherUserId).toSet();
    final soloCustomerChats = customerChats
        .where((c) => !groupedPersonIds.contains(_otherUserId(c)))
        .toList();

    // Company hub section (grouped single entries per company/person)
    if (companyGroups.isNotEmpty) {
      sectionWidgets.add(_buildSectionHeader(
        title: 'Company Chats',
        icon: Icons.apartment_rounded,
        color: const Color(0xFF3949AB),
      ));
      sectionWidgets.addAll(companyGroups.map(_buildPersonGroupItem));
    }

    final orderedRegularSections = [
      ('Customer Chats', Icons.person_outline_rounded, const Color(0xFF2E7D32),
          soloCustomerChats),
      ('Skilled Chats', Icons.groups_2_outlined, const Color(0xFF7B1FA2),
        [...skilledChats, ...unknownChats]),
      ('Delivery Chats', Icons.local_shipping_outlined,
          const Color(0xFFEF6C00), deliveryChats),
    ];

    for (final section in orderedRegularSections) {
      final chatsInSection = section.$4;
      if (chatsInSection.isEmpty) continue;
      sectionWidgets.add(_buildSectionHeader(
        title: section.$1,
        icon: section.$2,
        color: section.$3,
      ));
      sectionWidgets.addAll(chatsInSection.map(_buildChatItem));
    }

    if (sectionWidgets.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: sectionWidgets,
    );
  }

  // ── Group a mixed list of company-related chats by person ─────────────────
  List<_PersonChatGroup> _groupCompanyChats(List<ChatModel> chats) {
    final map = <String, _PersonChatGroup>{};
    for (final chat in chats) {
      final uid = _otherUserId(chat);
      if (uid.isEmpty) continue;
      final details = chat.participantDetails[uid];
      final name = (details?['name'] as String? ?? '').trim();
      final photo = details?['photo'] as String?;
      map.putIfAbsent(
        uid,
        () => _PersonChatGroup(
          otherUserId: uid,
          otherUserName: name.isEmpty ? 'Unknown' : name,
          otherUserPhoto: photo?.isEmpty == true ? null : photo,
        ),
      );
      map[uid]!.addChat(chat);
    }
    final groups = map.values.toList()
      ..sort((a, b) => b.latestTime.compareTo(a.latestTime));
    return groups;
  }

  Widget _buildSkilledRoleTabs({
    required List<ChatModel> customerChats,
    required List<ChatModel> skilledChats,
    required List<ChatModel> companyChats,
  }) {
    Widget buildTabList(List<ChatModel> chatsInTab, String emptyLabel) {
      if (chatsInTab.isEmpty) {
        return Center(
          child: Text(
            emptyLabel,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: chatsInTab.map(_buildChatItem).toList(),
      );
    }

    // Company tab uses grouped view (one entry per company, tabs inside hub)
    Widget buildCompanyGroupedList(List<ChatModel> allCompanyChats) {
      if (allCompanyChats.isEmpty) {
        return Center(
          child: Text(
            'No company chats',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }
      final groups = _groupCompanyChats(allCompanyChats);
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: groups.map(_buildPersonGroupItem).toList(),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelPadding: EdgeInsets.symmetric(horizontal: 14),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Color(0xFF8E24AA),
              tabs: [
                Tab(
                  icon: Icon(Icons.person_outline_rounded),
                  text: 'Customer Chats',
                ),
                Tab(
                  icon: Icon(Icons.groups_2_outlined),
                  text: 'Skilled Chats',
                ),
                Tab(
                  icon: Icon(Icons.apartment_rounded),
                  text: 'Company Chats',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                buildTabList(customerChats, 'No customer chats'),
                buildTabList(skilledChats, 'No skilled chats'),
                buildCompanyGroupedList(companyChats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _otherUserRoleForChat(ChatModel chat) {
    final otherUserId = _otherUserId(chat);
    if (otherUserId.isEmpty) return null;
    final cached = _roleCache[otherUserId];
    if (cached != null && cached.trim().isNotEmpty) {
      final normalizedCached = UserRoles.normalizeRole(cached);
      if (normalizedCached != null) return normalizedCached;
    }

    final details = chat.participantDetails[otherUserId];
    final rawRole = (details is Map) ? details['role']?.toString() : null;
    if (rawRole?.trim().toLowerCase() == 'delivery') {
      return UserRoles.deliveryPartner;
    }
    return UserRoles.normalizeRole(rawRole);
  }

  String _resolvedOtherRoleForChat(ChatModel chat) {
    final category = (chat.chatCategory ?? '').trim().toLowerCase();
    if (category.contains('company')) return UserRoles.company;
    if (category.contains('customer')) return UserRoles.customer;
    if (category.contains('skilled')) return UserRoles.skilledPerson;
    if (category.contains('delivery')) return UserRoles.deliveryPartner;

    final role = _otherUserRoleForChat(chat);
    if (role == UserRoles.company) return UserRoles.company;
    if (role == UserRoles.deliveryPartner) return UserRoles.deliveryPartner;
    if (role == UserRoles.skilledPerson) return UserRoles.skilledPerson;
    if (role == UserRoles.customer) return UserRoles.customer;

    // Fallbacks for partially loaded/legacy participant role metadata.
    if (_isJobChat(chat)) return UserRoles.company;
    if (_isHiringChat(chat)) {
      final normalizedCurrentRole = UserRoles.normalizeRole(_currentUserRole);
      return normalizedCurrentRole == UserRoles.skilledPerson
          ? UserRoles.customer
          : UserRoles.skilledPerson;
    }

    return 'unknown';
  }

  List<ChatModel> _collapseChatsByParticipant(List<ChatModel> chats) {
    final byBucket = <String, ChatModel>{};

    for (final chat in chats) {
      final otherUserId = _otherUserId(chat);
      if (otherUserId.isEmpty) continue;
      final bucketKey = _collapseBucketKey(chat, otherUserId);

      final existing = byBucket[bucketKey];
      if (existing == null) {
        byBucket[bucketKey] = chat;
        continue;
      }

      final existingIsWork = _isHiringChat(existing);
      final nextIsWork = _isHiringChat(chat);

      // Prefer the regular chat over work-chat clones for the same person.
      if (existingIsWork && !nextIsWork) {
        byBucket[bucketKey] = chat;
        continue;
      }
      if (!existingIsWork && nextIsWork) {
        continue;
      }

      if (chat.lastMessageTime.isAfter(existing.lastMessageTime)) {
        byBucket[bucketKey] = chat;
      }
    }

    final collapsed = byBucket.values.toList()
      ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return collapsed;
  }

  String _collapseBucketKey(ChatModel chat, String otherUserId) {
    if (_isJobChat(chat)) {
      final jobId = (chat.jobId ?? '').trim();
      if (jobId.isNotEmpty) return 'job:$otherUserId:$jobId';
      return 'job:$otherUserId:${chat.id}';
    }
    return 'user:$otherUserId';
  }

  bool _isHiringChat(ChatModel chat) =>
      chat.isWorkChat || chat.id.startsWith('work_');

  bool _isJobChat(ChatModel chat) => chat.isJobChat || chat.id.startsWith('jobchat_');

  String _otherUserId(ChatModel chat) {
    return chat.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
  }

  void _warmRoleCacheForChats(List<ChatModel> chats) {
    for (final chat in chats) {
      final otherUserId = _otherUserId(chat);
      if (otherUserId.isEmpty) continue;
      if (_roleCache.containsKey(otherUserId) || _roleLoading.contains(otherUserId)) {
        continue;
      }
      _loadRoleForUser(otherUserId);
    }
  }

  Future<void> _loadRoleForUser(String userId) async {
    if (_roleLoading.contains(userId)) return;
    _roleLoading.add(userId);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      final role = (userDoc.data()?['role'] as String?)?.trim();
      if (!mounted) return;
      setState(() {
        _roleCache[userId] = role;
      });
    } catch (_) {
      // Keep fallback classification when role lookup fails.
    } finally {
      _roleLoading.remove(userId);
    }
  }

  // ── Grouped company-hub list tile ─────────────────────────────────────────
  Widget _buildPersonGroupItem(_PersonChatGroup group) {
    final name = group.otherUserName;
    final photo = group.otherUserPhoto;
    final unreadCount = group.totalUnread(_currentUserId ?? '');
    final latestMsg = group.latestMessage;
    final latestTime = group.latestTime;

    // Build type-labels for the small chips row
    final chips = <Widget>[];
    if (group.normalChat != null) {
      chips.add(_chatTypeChip('Chat', const Color(0xFF7B1FA2)));
    }
    if (group.hiringChat != null) {
      chips.add(_chatTypeChip('Hiring', const Color(0xFF2E7D32)));
    }
    for (final jc in group.jobChats) {
      final title = (jc.jobTitle ?? '').trim();
      chips.add(_chatTypeChip(
        title.isNotEmpty ? title : 'Job Chat',
        const Color(0xFF1565C0),
        icon: Icons.work_history_outlined,
      ));
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompanyChatHubScreen(
              otherUserId: group.otherUserId,
              otherUserName: name,
              otherUserPhoto: photo,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with presence dot
            StreamBuilder<UserPresence>(
              stream: PresenceService.instance.watchUser(group.otherUserId),
              builder: (context, snap) {
                final isOnline = snap.data?.isOnline ?? false;
                return Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.transparent,
                      child: UniversalAvatar(
                        photoUrl: photo,
                        fallbackName: name,
                        radius: 28,
                        animate: false,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE91E63),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 12),

            // Name + latest message + chip row
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppHelpers.capitalize(name),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        AppHelpers.getRelativeTime(latestTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? const Color(0xFFE91E63)
                              : Colors.grey[600],
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    latestMsg.isEmpty ? 'No messages yet' : latestMsg,
                    style: TextStyle(
                      fontSize: 14,
                      color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                      fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 4, runSpacing: 2, children: chips),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatTypeChip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(ChatModel chat) {
    final activeUserId = _currentUserId;
    final otherUserId = chat.participants.firstWhere(
      (id) => id != activeUserId,
      orElse: () => '',
    );
    final otherUserDetails = chat.participantDetails[otherUserId];
    final name = otherUserDetails?['name'] ?? 'Unknown';
    final photo = otherUserDetails?['photo'];
    final unreadCount = activeUserId == null ? 0 : (chat.unreadCount[activeUserId] ?? 0);
    final pendingWork = _pendingWorkCounts[chat.id] ?? 0;
    final isJobChat = _isJobChat(chat);
    final jobTitle = (chat.jobTitle ?? '').trim();

    return InkWell(
      onTap: () => _openChatSafely(chat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // Amber left-border accent when there are pending work requests
          color: pendingWork > 0
              ? const Color(0xFFFFF8E1) // very light amber tint
              : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
            left: pendingWork > 0
                ? const BorderSide(color: Color(0xFFFF8F00), width: 4)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Profile Photo
            StreamBuilder<UserPresence>(
              stream: PresenceService.instance.watchUser(otherUserId),
              builder: (context, presenceSnap) {
                final isOnline = presenceSnap.data?.isOnline ?? false;
                return Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.transparent,
                      child: UniversalAvatar(
                        photoUrl: photo,
                        fallbackName: name,
                        radius: 28,
                        animate: false,
                      ),
                    ),
                    // Online indicator dot
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    // Unread badge (red, top-right)
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE91E63),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Pending work request badge (amber, top-left)
                    if (pendingWork > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF8F00),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              pendingWork > 99 ? '99+' : pendingWork.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 12),

            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppHelpers.capitalize(name),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        AppHelpers.getRelativeTime(chat.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? const Color(0xFFE91E63)
                              : Colors.grey[600],
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chat.lastMessageType == 'image')
                        const Icon(
                          Icons.image,
                          size: 16,
                          color: Colors.grey,
                        ),
                      if (chat.lastMessageType == 'image')
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          chat.lastMessage.isEmpty
                              ? 'No messages yet'
                              : chat.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (isJobChat) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.work_history_outlined,
                            size: 13, color: Color(0xFF1565C0)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            jobTitle.isNotEmpty
                                ? 'Job Chat: $jobTitle'
                                : 'Job Chat',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Amber work-request indicator row
                  if (pendingWork > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.work_outline,
                            size: 13, color: Color(0xFFFF8F00)),
                        const SizedBox(width: 4),
                        Text(
                          pendingWork == 1
                              ? '1 pending work request'
                              : '$pendingWork pending work requests',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF8F00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with skilled professionals',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
