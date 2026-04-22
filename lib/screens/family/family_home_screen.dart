import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';
import 'family_members_screen.dart';
import 'shared_vehicles_screen.dart';
import 'shared_wallet_screen.dart';
import 'family_notification_screen.dart';
import 'invite_member_screen.dart';
import 'share_vehicle_screen.dart';
import 'edit_permissions_screen.dart';

class FamilyHomeScreen extends StatefulWidget {
  final UserModel user;

  const FamilyHomeScreen({super.key, required this.user});

  @override
  State<FamilyHomeScreen> createState() => _FamilyHomeScreenState();
}

class _FamilyHomeScreenState extends State<FamilyHomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  FamilyInfo? _familyInfo;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  int _sharedVehiclesCount = 0;
  int _sharedByMeCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadFamilyInfo();
    _loadSharedCounts();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyInfo() async {
    setState(() => _isLoading = true);

    final result = await _apiService.getFamilyInfo();

    if (result['success'] && mounted) {
      setState(() {
        _familyInfo = FamilyInfo.fromJson(result['data']);
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result['error'];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSharedCounts() async {
    // Get vehicles shared with me
    final sharedWithMeResult = await _apiService.getSharedVehicles();
    if (sharedWithMeResult['success']) {
      final List<dynamic> data = sharedWithMeResult['data'] ?? [];
      setState(() {
        _sharedVehiclesCount = data.length;
      });
    }

    // Get vehicles shared by me
    final sharedByMeResult = await _apiService.getVehiclesSharedByMe();
    if (sharedByMeResult['success']) {
      final List<dynamic> data = sharedByMeResult['data'] ?? [];
      setState(() {
        _sharedByMeCount = data.length;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadFamilyInfo();
    await _loadSharedCounts();
  }

  bool get _canShareVehicle {
    // User can share vehicle only if they have at least one vehicle with fuel pass
    return _familyInfo?.myPermissions['can_share_vehicle'] == true;
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
                      : _errorMessage != null
                      ? _buildErrorState(isDark)
                      : _familyInfo == null || !_familyInfo!.hasFamily
                      ? _buildNoFamilyState(isDark)
                      : RefreshIndicator(
                          onRefresh: _refreshData,
                          color: AppColors.emerald,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                            child: Column(
                              children: [
                                _buildFamilyHeader(isDark),
                                const SizedBox(height: 20),
                                _buildStatsGrid(isDark),
                                const SizedBox(height: 20),
                                _buildActionCards(isDark),
                              ],
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
              'Family Sharing',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyNotificationScreen(
                    user: widget.user,
                    familyId: _familyInfo!.familyId!,
                  ),
                ),
              );
            },
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
                Icons.notifications_outlined,
                size: 18,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withOpacity(0.1),
            ),
            child: Icon(Icons.error_outline, size: 40, color: AppColors.error),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
            ),
          ),
          const SizedBox(height: 20),
          GradientButton(label: 'Retry', onPressed: _refreshData, height: 45),
        ],
      ),
    );
  }

  Widget _buildNoFamilyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
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
                Icons.family_restroom_rounded,
                size: 50,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Family Yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a family to share vehicles,\nwallet and manage fuel together.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
            const SizedBox(height: 32),
            GradientButton(
              label: 'Create Family',
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/create_family',
                  arguments: widget.user,
                );
                if (result == true) {
                  await _refreshData();
                }
              },
              colors: [AppColors.emerald, AppColors.ocean],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.emerald, AppColors.ocean],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _familyInfo!.familyName!,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_familyInfo!.members.length} members',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white.withOpacity(0.2),
            ),
            child: Text(
              _familyInfo!.myRole!,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.people_rounded,
            label: 'Members',
            value: '${_familyInfo!.members.length}',
            color: AppColors.ocean,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FamilyMembersScreen(
                    user: widget.user,
                    familyInfo: _familyInfo!,
                    onMemberChanged: _refreshData,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.directions_car_rounded,
            label: 'Shared With Me',
            value: '$_sharedVehiclesCount',
            color: AppColors.emerald,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SharedVehiclesScreen(user: widget.user),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.share_rounded,
            label: 'Shared By Me',
            value: '$_sharedByMeCount',
            color: AppColors.amber,
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SharedVehiclesScreen(user: widget.user),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCards(bool isDark) {
    return Column(
      children: [
        _ActionCard(
          icon: Icons.person_add_rounded,
          title: 'Invite Members',
          subtitle: 'Add family members to share fuel',
          gradient: [AppColors.ocean, AppColors.emerald],
          isDark: isDark,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InviteMemberScreen(
                  user: widget.user,
                  familyId: _familyInfo!.familyId!,
                ),
              ),
            );
            if (result == true) {
              await _refreshData();
            }
          },
          enabled: _familyInfo!.canInvite,
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.share_rounded,
          title: 'Share Vehicle',
          subtitle: _canShareVehicle
              ? 'Share your vehicles with family'
              : 'Add a vehicle with Fuel Pass first',
          gradient: [AppColors.emerald, const Color(0xFF7C3AED)],
          isDark: isDark,
          onTap: _canShareVehicle
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShareVehicleScreen(user: widget.user),
                    ),
                  );
                }
              : null,
          enabled: _canShareVehicle,
        ),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Family Wallet',
          subtitle: 'View and manage shared wallet',
          gradient: [const Color(0xFF7C3AED), AppColors.ocean],
          isDark: isDark,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SharedWalletScreen(
                  user: widget.user,
                  familyId: _familyInfo!.familyId!,
                  isOwner: _familyInfo!.isOwner,
                ),
              ),
            );
          },
          enabled: true,
        ),
        const SizedBox(height: 12),
        if (_familyInfo!.isOwner)
          _ActionCard(
            icon: Icons.admin_panel_settings_rounded,
            title: 'Manage Permissions',
            subtitle: 'Control member permissions',
            gradient: [AppColors.amber, AppColors.ocean],
            isDark: isDark,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditPermissionsScreen(
                    user: widget.user,
                    familyInfo: _familyInfo!,
                    onPermissionsUpdated: _refreshData,
                  ),
                ),
              );
            },
            enabled: true,
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final bool isDark;
  final VoidCallback? onTap;
  final bool enabled;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.isDark,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(icon, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
