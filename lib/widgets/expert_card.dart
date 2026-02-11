import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/skilled_user_profile.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/chat/chat_detail_screen.dart';
import '../utils/web_image_loader.dart';

class ExpertCard extends StatefulWidget {
  final SkilledUserProfile profile;

  const ExpertCard({super.key, required this.profile});

  @override
  State<ExpertCard> createState() => _ExpertCardState();
}

class _ExpertCardState extends State<ExpertCard> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(userId: widget.profile.userId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile Image with verification badge
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.profile.isVerified
                            ? const Color(0xFF2196F3)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (widget.profile.profilePicture != null &&
                              widget.profile.profilePicture!.isNotEmpty)
                          ? WebImageLoader.getImageProvider(widget.profile.profilePicture)
                          : null,
                      child: (widget.profile.profilePicture == null ||
                              widget.profile.profilePicture!.isEmpty)
                          ? const Icon(Icons.person, size: 36, color: Colors.grey)
                          : null,
                    ),
                  ),
                  if (widget.profile.isVerified)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 20,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User name
                    Text(
                      widget.profile.name ?? 'Professional',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Category as a chip/tag
                    if (widget.profile.category != null && widget.profile.category!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.profile.category!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE91E63),
                          ),
                        ),
                      ),
                    // Bio preview
                    if (widget.profile.bio.isNotEmpty)
                      Text(
                        widget.profile.bio,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    // Skills preview
                    if (widget.profile.skills.isNotEmpty)
                      Text(
                        widget.profile.skills.take(2).join(', '),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: widget.profile.rating,
                          itemBuilder: (context, index) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.profile.rating.toStringAsFixed(1)} (${widget.profile.reviewCount} reviews)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.work_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.profile.projectCount} Projects',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (widget.profile.city != null) ...[
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.profile.city!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Quick Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: widget.profile.userId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_outline),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    onPressed: () => _startChat(context),
                    icon: const Icon(Icons.message_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startChat(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Get current user details
      final myUser = await FirestoreService().getUserById(currentUser.uid);
      if (myUser == null) return;

      final chatService = ChatService();
      final chatId = await chatService.getOrCreateChat(
        currentUser.uid,
        widget.profile.userId,
        {'name': myUser.name, 'photo': myUser.profilePhoto ?? ''},
        {'name': '', 'photo': widget.profile.profilePicture ?? ''},
      );

      // Get other user's name
      final otherUser = await FirestoreService().getUserById(widget.profile.userId);

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatId: chatId,
            otherUserId: widget.profile.userId,
            otherUserName: otherUser?.name ?? 'User',
            otherUserPhoto: widget.profile.profilePicture,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: $e')),
      );
    }
  }
}
