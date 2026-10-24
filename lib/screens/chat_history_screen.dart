
import 'package:flutter/material.dart';

import '../services/services.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Shows past AI Tutor chats and allows users to delete conversations.
class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<dynamic> _chats = [];
  bool _loading = true;
  String? _error;
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final r = await api.get('/api/chat/conversations');

      if (!mounted) return;

      setState(() {
        _chats = listOf(r);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete(dynamic id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          'Are you sure you want to delete "$title"? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _deleteChat(id);
  }

  Future<void> _deleteChat(dynamic id) async {
    final key = id.toString();

    if (_deletingIds.contains(key)) return;

    setState(() {
      _deletingIds.add(key);
    });

    try {
      await api.delete('/api/chat/conversations/$id/delete');

      if (!mounted) return;

      setState(() {
        _chats.removeWhere(
              (chat) => chat is Map && chat['id']?.toString() == key,
        );
        _deletingIds.remove(key);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat deleted successfully.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deletingIds.remove(key);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete chat: ${friendlyError(e)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat history'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const ListSkeleton();

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: ErrorBanner(
          message: _error!,
          onRetry: _load,
        ),
      );
    }

    if (_chats.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No chats yet',
        message: 'Your conversations with the AI Tutor will show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _chats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = _chats[i];
          final id = c is Map ? c['id'] : null;

          final title = pickStr(
            c,
            ['title', 'name', 'last_message', 'preview'],
            'Chat #$id',
          );

          final date = shortDate(
            c is Map ? (c['updated_at'] ?? c['created_at']) : null,
          );

          final isDeleting =
              id != null && _deletingIds.contains(id.toString());

          return AppCard(
            onTap: id == null || isDeleting
                ? null
                : () => Navigator.pop(context, id),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (date.isNotEmpty)
                        Text(
                          date,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete chat',
                  onPressed: id == null || isDeleting
                      ? null
                      : () => _confirmDelete(id, title),
                  icon: isDeleting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.muted,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
