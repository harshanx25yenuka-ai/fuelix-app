import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';

class EditPermissionsScreen extends StatefulWidget {
  final UserModel user;
  final FamilyInfo familyInfo;
  final VoidCallback onPermissionsUpdated;

  const EditPermissionsScreen({
    super.key,
    required this.user,
    required this.familyInfo,
    required this.onPermissionsUpdated,
  });

  @override
  State<EditPermissionsScreen> createState() => _EditPermissionsScreenState();
}

class _EditPermissionsScreenState extends State<EditPermissionsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<FamilyMember> _members = [];
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Permission configurations
  final Map<String, Map<String, bool>> _tempPermissions = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadMembers();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);

    // Get fresh member list
    final result = await _apiService.getFamilyMembers(
      widget.familyInfo.familyId!,
    );

    if (result['success'] && mounted) {
      final List<dynamic> data = result['data'];
      setState(() {
        _members = data.map((json) => FamilyMember.fromJson(json)).toList();

        // Initialize temp permissions
        for (var member in _members) {
          if (!member.isOwner) {
            _tempPermissions[member.userId.toString()] = {
              'can_refuel': member.canRefuel,
              'can_topup': member.canTopUp,
              'can_view_wallet': member.canViewWallet,
              'can_share_vehicle':
                  member.permissions['can_share_vehicle'] ?? false,
            };
          }
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePermissions(int memberId) async {
    final permissions = _tempPermissions[memberId.toString()];
    if (permissions == null) return;

    setState(() => _isLoading = true);

    final result = await _apiService.updateMemberPermissions(
      widget.familyInfo.familyId!,
      memberId,
      permissions,
    );

    if (!mounted) return;

    if (result['success']) {
      showAppSnackbar(
        context,
        message: 'Permissions updated successfully',
        isSuccess: true,
      );
      widget.onPermissionsUpdated();
      await _loadMembers();
    } else {
      showAppSnackbar(
        context,
        message: result['error'] ?? 'Failed to update permissions',
        isError: true,
      );
      setState(() => _isLoading = false);
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
                      : _members.where((m) => !m.isOwner).isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          itemCount: _members.where((m) => !m.isOwner).length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (_, index) {
                            final member = _members
                                .where((m) => !m.isOwner)
                                .toList()[index];
                            return _PermissionCard(
                              member: member,
                              permissions:
                                  _tempPermissions[member.userId.toString()] ??
                                  {},
                              isDark: isDark,
                              onPermissionChanged: (String key, bool value) {
                                setState(() {
                                  _tempPermissions[member.userId
                                          .toString()]?[key] =
                                      value;
                                });
                              },
                              onSave: () => _savePermissions(member.userId),
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
              'Manage Permissions',
              style: Theme.of(context).textTheme.headlineMedium,
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
              Icons.admin_panel_settings_rounded,
              size: 40,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Members to Manage',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite family members first to manage their permissions.',
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

class _PermissionCard extends StatelessWidget {
  final FamilyMember member;
  final Map<String, bool> permissions;
  final bool isDark;
  final Function(String, bool) onPermissionChanged;
  final VoidCallback onSave;

  const _PermissionCard({
    required this.member,
    required this.permissions,
    required this.isDark,
    required this.onPermissionChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [AppColors.ocean, AppColors.emerald],
                  ),
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Text(
                      member.email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSub
                            : AppColors.lightTextSub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 12),

          // Permission Toggles
          _PermissionTile(
            title: 'Refuel Vehicles',
            description: 'Can refuel shared vehicles using family wallet',
            value: permissions['can_refuel'] ?? false,
            onChanged: (value) => onPermissionChanged('can_refuel', value),
            isDark: isDark,
            icon: Icons.local_gas_station_rounded,
          ),
          const SizedBox(height: 8),
          _PermissionTile(
            title: 'Top Up Wallet',
            description: 'Can add money to family wallet',
            value: permissions['can_topup'] ?? false,
            onChanged: (value) => onPermissionChanged('can_topup', value),
            isDark: isDark,
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 8),
          _PermissionTile(
            title: 'View Wallet',
            description: 'Can view family wallet balance and transactions',
            value: permissions['can_view_wallet'] ?? false,
            onChanged: (value) => onPermissionChanged('can_view_wallet', value),
            isDark: isDark,
            icon: Icons.visibility_rounded,
          ),
          const SizedBox(height: 8),
          _PermissionTile(
            title: 'Share Vehicles',
            description: 'Can share their own vehicles with family',
            value: permissions['can_share_vehicle'] ?? false,
            onChanged: (value) =>
                onPermissionChanged('can_share_vehicle', value),
            isDark: isDark,
            icon: Icons.share_rounded,
          ),

          const SizedBox(height: 16),
          GradientButton(
            label: 'Save Permissions',
            onPressed: onSave,
            height: 45,
            colors: [AppColors.emerald, AppColors.ocean],
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;
  final IconData icon;

  const _PermissionTile({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.emerald.withOpacity(0.15),
          ),
          child: Icon(icon, size: 16, color: AppColors.emerald),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Text(
                description,
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
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.emerald,
        ),
      ],
    );
  }
}
