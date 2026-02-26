import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../services/admin_api_service.dart';
import 'admin_user_detail_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  final String? adminKey;
  const AdminUsersScreen({super.key, this.adminKey});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = AdminApiService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  int _total = 0;
  bool _loading = true;
  String? _error;
  Timer? _debounce;
  int _offset = 0;
  static const _limit = 50;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _offset = 0;
      _load(reset: true);
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) setState(() => _loading = true);
    final key = widget.adminKey ?? await _api.getAdminKey();
    final data = await _api.fetchUsers(
      key,
      limit: _limit,
      offset: _offset,
      search: _searchController.text,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = data == null ? (_api.lastError ?? 'Ошибка') : null;
      if (data != null) {
        _total = data['total'] as int? ?? 0;
        final items = (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        if (reset || _offset == 0) {
          _users = items;
        } else {
          _users = [..._users, ...items];
        }
      }
    });
  }

  Future<void> _toggleBlock(Map<String, dynamic> user) async {
    final key = widget.adminKey ?? await _api.getAdminKey();
    final id = user['id'] as String;
    final isActive = user['is_active'] as bool? ?? true;
    final ok = isActive
        ? await _api.blockUser(key, id)
        : await _api.unblockUser(key, id);
    if (ok && mounted) {
      setState(() {
        final idx = _users.indexWhere((u) => u['id'] == id);
        if (idx != -1) _users[idx] = {..._users[idx], 'is_active': !isActive};
      });
    }
  }

  void _openDetail(Map<String, dynamic> user) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AdminUserDetailScreen(
        userId: user['id'] as String,
        adminKey: widget.adminKey,
      ),
    )).then((_) => _load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? _buildError()
                  : _buildList(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по номеру, имени, @username...',
                hintStyle: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _offset = 0;
                          _load(reset: true);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _StatBadge(label: 'Всего', value: _total.toString()),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: () { _offset = 0; _load(reset: true); },
            tooltip: 'Обновить',
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: AppTypography.bodyMedium.copyWith(color: AppColors.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => _load(reset: true), child: const Text('Повторить')),
          ],
        ),
      );

  Widget _buildList() {
    if (_users.isEmpty) {
      return Center(
        child: Text('Пользователи не найдены',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textTertiary)),
      );
    }
    return RefreshIndicator(
      onRefresh: () async { _offset = 0; await _load(reset: true); },
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _users.length + (_users.length < _total ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i >= _users.length) {
            return _LoadMoreButton(onTap: () {
              _offset += _limit;
              _load();
            });
          }
          return _UserCard(
            user: _users[i],
            onTap: () => _openDetail(_users[i]),
            onToggleBlock: () => _toggleBlock(_users[i]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final VoidCallback onToggleBlock;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onToggleBlock,
  });

  @override
  Widget build(BuildContext context) {
    final tg = user['telegram'] as Map<String, dynamic>?;
    final name = tg?['display_name'] as String?;
    final username = tg?['username'] as String?;
    final photoUrl = tg?['photo_url'] as String?;
    final phone = user['phone'] as String? ?? '';
    final isActive = user['is_active'] as bool? ?? true;
    final createdAt = _formatDate(user['created_at'] as String?);

    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _Avatar(name: name ?? phone, photoUrl: photoUrl, isActive: isActive),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (name != null) ...[
                          Text(name,
                              style: AppTypography.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(width: 6),
                        ],
                        if (username != null)
                          Text('@$username',
                              style: AppTypography.labelSmall
                                  .copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(phone,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Badge(
                          label: isActive ? 'Активен' : 'Заблокирован',
                          color: isActive ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        if (tg != null)
                          _Badge(label: 'Telegram', color: AppColors.primary),
                        const Spacer(),
                        Text(createdAt,
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.textTertiary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (v) {
                  if (v == 'toggle') onToggleBlock();
                  if (v == 'detail') onTap();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'detail', child: Text('Подробнее')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      isActive ? 'Заблокировать' : 'Разблокировать',
                      style: TextStyle(
                          color: isActive ? AppColors.error : AppColors.success),
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

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isActive;
  const _Avatar({required this.name, this.photoUrl, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipOval(
          child: photoUrl != null
              ? CachedNetworkImage(
                  imageUrl: photoUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _initials(),
                )
              : _initials(),
        ),
        if (!isActive)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: const Icon(Icons.block, color: Colors.white, size: 8),
            ),
          ),
      ],
    );
  }

  Widget _initials() {
    final letters = name.trim().split(' ').where((e) => e.isNotEmpty).take(2).map((e) => e[0].toUpperCase()).join();
    return Container(
      width: 44,
      height: 44,
      color: AppColors.primaryLight,
      child: Center(
        child: Text(letters.isEmpty ? '?' : letters,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: AppTypography.labelSmall.copyWith(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  const _StatBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppTypography.titleSmall.copyWith(color: AppColors.primary)),
        Text(label, style: AppTypography.labelSmall.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoadMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: const Text('Загрузить ещё'),
    );
  }
}
