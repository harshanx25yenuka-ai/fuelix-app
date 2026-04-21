import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

class FamilyNotificationScreen extends StatefulWidget {
  final UserModel user;
  final int familyId;

  const FamilyNotificationScreen({
    super.key,
    required this.user,
    required this.familyId,
  });

  @override
  State<FamilyNotificationScreen> createState() =>
      _FamilyNotificationScreenState();
}

class _FamilyNotificationScreenState extends State<FamilyNotificationScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadNotifications();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    // Get all notifications for user (includes family notifications)
    final result = await _apiService.getUserNotifications(widget.user.id!);

    if (result['success'] && mounted) {
      final List<dynamic> notifications = result['data'] ?? [];
      // Filter family-related notifications
      setState(() {
        _notifications = notifications
            .where((n) {
              final data = n['data'];
              if (data is Map) {
                final type = data['type'];
                return type == 'FAMILY_INVITE' ||
                    type == 'MEMBER_JOINED' ||
                    type == 'VEHICLE_SHARED' ||
                    type == 'WALLET_TOPUP';
              }
              return false;
            })
            .cast<Map<String, dynamic>>()
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0D1117), const Color(0xFF0A1628)]
                : [const Color(0xFFF0FDF8), const Color(0xFFEFF6FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildAppBar(isDark),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.emerald,
                          ),
                        )
                      : _notifications.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final notification = _notifications[index];
                            return _NotificationCard(
                              notification: notification,
                              isDark: isDark,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? AppColors.darkSurfaceAlt
                    : AppColors.lightSurfaceAlt,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Family Notifications',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          GestureDetector(
            onTap: _loadNotifications,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? AppColors.darkSurfaceAlt
                    : AppColors.lightSurfaceAlt,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.emerald.withOpacity(0.15),
                  AppColors.ocean.withOpacity(0.15),
                ],
              ),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 40,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Family Notifications',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When family members join or share vehicles,\nit will appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final bool isDark;

  const _NotificationCard({required this.notification, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final data = notification['data'] is Map ? notification['data'] as Map : {};
    final type = data['type'] ?? '';
    final createdAt =
        DateTime.tryParse(notification['createdAt'] ?? '') ?? DateTime.now();

    IconData icon;
    Color color;
    String title;
    String message;

    switch (type) {
      case 'FAMILY_INVITE':
        icon = Icons.person_add_rounded;
        color = AppColors.emerald;
        title = 'Family Invitation';
        message =
            'You\'ve been invited to join ${data['familyName'] ?? 'a family'}';
        break;
      case 'MEMBER_JOINED':
        icon = Icons.people_rounded;
        color = AppColors.ocean;
        title = 'New Member Joined';
        message = 'A new member has joined your family';
        break;
      case 'VEHICLE_SHARED':
        icon = Icons.directions_car_rounded;
        color = AppColors.amber;
        title = 'Vehicle Shared';
        message = data['vehicleRegNo'] != null
            ? '${data['vehicleRegNo']} has been shared with you'
            : 'A vehicle has been shared with you';
        break;
      case 'WALLET_TOPUP':
        icon = Icons.account_balance_wallet_rounded;
        color = const Color(0xFF7C3AED);
        title = 'Wallet Top Up';
        message =
            'LKR ${data['amount']?.toString() ?? '0'} added to family wallet';
        break;
      default:
        icon = Icons.notifications_rounded;
        color = AppColors.ocean;
        title = notification['title'] ?? 'Notification';
        message = notification['message'] ?? '';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSub
                        : AppColors.lightTextSub,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(createdAt),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
