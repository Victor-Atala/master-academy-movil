import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/course_interaction_service.dart';

class YoutubeStyleCommentsSection extends StatefulWidget {
  final dynamic courseId;
  final int? lessonId;
  final String courseTitle;

  const YoutubeStyleCommentsSection({
    super.key,
    required this.courseId,
    this.lessonId,
    required this.courseTitle,
  });

  @override
  State<YoutubeStyleCommentsSection> createState() => _YoutubeStyleCommentsSectionState();
}

class _YoutubeStyleCommentsSectionState extends State<YoutubeStyleCommentsSection> {
  final _commentInputController = TextEditingController();
  final _replyControllers = <String, TextEditingController>{};
  final Set<String> _expandedReplies = {};
  final Set<String> _activeReplyBox = {};

  List<CourseComment> _comments = [];
  bool _isLoading = true;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentInputController.dispose();
    for (var c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final service = sl<CourseInteractionService>();
      final list = await service.getComments(widget.courseId);
      if (mounted) {
        setState(() {
          _comments = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postComment() async {
    final text = _commentInputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      final service = sl<CourseInteractionService>();
      final newComment = await service.addComment(
        courseId: widget.courseId,
        lessonId: widget.lessonId,
        userName: 'Estudiante',
        content: text,
      );

      _commentInputController.clear();
      if (mounted) FocusScope.of(context).unfocus();

      if (mounted) {
        setState(() {
          _comments.insert(0, newComment);
          _isPosting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _postReply(String parentCommentId) async {
    final controller = _replyControllers[parentCommentId];
    if (controller == null) return;
    final text = controller.text.trim();
    if (text.isEmpty) return;

    try {
      final service = sl<CourseInteractionService>();
      await service.addReply(
        courseId: widget.courseId,
        parentCommentId: parentCommentId,
        userName: 'Estudiante',
        content: text,
      );

      controller.clear();
      if (mounted) {
        setState(() {
          _activeReplyBox.remove(parentCommentId);
          _expandedReplies.add(parentCommentId);
        });
        await _loadComments();
      }
    } catch (_) {}
  }

  Future<void> _toggleLike(String commentId) async {
    try {
      final service = sl<CourseInteractionService>();
      await service.toggleLike(widget.courseId, commentId);
      if (mounted) {
        setState(() {
          for (var c in _comments) {
            if (c.id == commentId) {
              c.isLikedByMe = !c.isLikedByMe;
              c.likesCount += c.isLikedByMe ? 1 : -1;
              break;
            }
            for (var r in c.replies) {
              if (r.id == commentId) {
                r.isLikedByMe = !r.isLikedByMe;
                r.likesCount += r.isLikedByMe ? 1 : -1;
                break;
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) {
      return 'Hace ${(diff.inDays / 30).floor()} meses';
    } else if (diff.inDays > 0) {
      return 'Hace ${diff.inDays} ${diff.inDays == 1 ? 'día' : 'días'}';
    } else if (diff.inHours > 0) {
      return 'Hace ${diff.inHours} ${diff.inHours == 1 ? 'hora' : 'horas'}';
    } else if (diff.inMinutes > 0) {
      return 'Hace ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minuto' : 'minutos'}';
    } else {
      return 'Hace un momento';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalComments = _comments.fold<int>(
      _comments.length,
      (acc, c) => acc + c.replies.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.mode_comment_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Comentarios y Recomendaciones',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$totalComments',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // YouTube-style Input Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary,
                    child: const Text('E', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentInputController,
                      maxLines: null,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Añade un comentario o recomendación...',
                        hintStyle: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      _commentInputController.clear();
                      FocusScope.of(context).unfocus();
                    },
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    child: Text('Cancelar', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.textMuted, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isPosting ? null : _postComment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: _isPosting
                        ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Comentar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Comments List
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_comments.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 36, color: isDark ? Colors.white24 : Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'Sé el primero en dejar una recomendación o pregunta',
                  style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildCommentCard(_comments[index], isDark);
            },
          ),
      ],
    );
  }

  Widget _buildCommentCard(CourseComment comment, bool isDark) {
    final hasReplies = comment.replies.isNotEmpty;
    final isRepliesExpanded = _expandedReplies.contains(comment.id);
    final isReplying = _activeReplyBox.contains(comment.id);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: comment.userName.contains('Instructor')
                    ? AppColors.primary
                    : (isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade100),
                child: Text(
                  comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: comment.userName.contains('Instructor')
                        ? Colors.white
                        : (isDark ? Colors.white : AppColors.textPrimary),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          comment.userName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        if (comment.userName.contains('Instructor'))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DOCENTE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        Text(
                          _formatTimeAgo(comment.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.content,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Action row: Likes, Reply, and Replies dropdown
          Row(
            children: [
              const SizedBox(width: 42),
              // Like button
              GestureDetector(
                onTap: () => _toggleLike(comment.id),
                child: Row(
                  children: [
                    Icon(
                      comment.isLikedByMe ? Icons.thumb_up_rounded : Icons.thumb_up_alt_outlined,
                      size: 15,
                      color: comment.isLikedByMe ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                    ),
                    if (comment.likesCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${comment.likesCount}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: comment.isLikedByMe ? AppColors.primary : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 18),
              // Reply Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_activeReplyBox.contains(comment.id)) {
                      _activeReplyBox.remove(comment.id);
                    } else {
                      _activeReplyBox.add(comment.id);
                      _replyControllers.putIfAbsent(comment.id, () => TextEditingController());
                    }
                  });
                },
                child: Text(
                  'Responder',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ),
              const Spacer(),
              if (hasReplies)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isRepliesExpanded) {
                        _expandedReplies.remove(comment.id);
                      } else {
                        _expandedReplies.add(comment.id);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        isRepliesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${comment.replies.length} ${comment.replies.length == 1 ? 'respuesta' : 'respuestas'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Inline Reply input box
          if (isReplying) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 36),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyControllers.putIfAbsent(comment.id, () => TextEditingController()),
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white : AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu respuesta...',
                        hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, size: 16, color: AppColors.primary),
                    onPressed: () => _postReply(comment.id),
                  ),
                ],
              ),
            ),
          ],

          // Nested Replies List
          if (hasReplies && isRepliesExpanded) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 28),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
              ),
              padding: const EdgeInsets.only(left: 12),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comment.replies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, rIdx) {
                  final reply = comment.replies[rIdx];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: reply.userName.contains('Instructor')
                            ? AppColors.primary
                            : (isDark ? Colors.blueGrey.shade700 : Colors.blueGrey.shade200),
                        child: Text(
                          reply.userName.isNotEmpty ? reply.userName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Text(
                                  reply.userName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                                if (reply.userName.contains('Instructor'))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('DOCENTE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ),
                                Text(
                                  _formatTimeAgo(reply.createdAt),
                                  style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              reply.content,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: isDark ? Colors.white70 : AppColors.textSecondary,
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
          ],
        ],
      ),
    );
  }
}
