import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';
import 'invite_member_screen.dart';
import 'generate_invite_qr_screen.dart';

class FamilyMembersScreen extends StatefulWidget {
  final UserModel user;
  final FamilyInfo familyInfo;
  final VoidCallback onMemberChanged;

  const FamilyMembersScreen({
    super.key,
    required this.user,
    required this.familyInfo,
    required this.onMemberChanged,
  });

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _removeMember(int memberId, String memberName) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        title: Text(
          'Remove Member',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          'Remove $memberName from family?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRemoving = true);

    final result = await _apiService.removeFamilyMember(
      widget.familyInfo.familyId!,
      memberId,
    );

    if (!mounted) return;

    if (result['success']) {
      showAppSnackbar(context, message: 'Member removed', isSuccess: true);
      widget.onMemberChanged();
      Navigator.pop(context, true);
    } else {
      showAppSnackbar(context, message: result['error'], isError: true);
    }

    setState(() => _isRemoving = false);
  }

  Future<void> _inviteMember() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InviteMemberScreen(
          user: widget.user,
          familyId: widget.familyInfo.familyId!,
        ),
      ),
    );
    if (result == true) {
      widget.onMemberChanged();
    }
  }

  void _generateInviteQr() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GenerateInviteQrScreen(
          user: widget.user,
          familyId: widget.familyInfo.familyId!,
          familyName: widget.familyInfo.familyName!,
        ),
      ),
    );
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
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    itemCount: widget.familyInfo.members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final member = widget.familyInfo.members[index];
                      final isCurrentUser = member.userId == widget.user.id;
                      final canRemove =
                          widget.familyInfo.canRemoveMembers &&
                          !isCurrentUser &&
                          !member.isOwner;

                      return _MemberCard(
                        member: member,
                        isDark: isDark,
                        isRemoving: _isRemoving,
                        onRemove: canRemove
                            ? () => _removeMember(member.userId, member.name)
                            : null,
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
              'Family Members',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          if (widget.familyInfo.canInvite) ...[
            IconButton(
              icon: Icon(Icons.qr_code_rounded, color: AppColors.emerald),
              onPressed: _generateInviteQr,
              tooltip: 'Generate QR Invite',
            ),
            IconButton(
              icon: Icon(Icons.person_add_rounded, color: AppColors.emerald),
              onPressed: _inviteMember,
              tooltip: 'Invite Member',
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.emerald.withOpacity(0.15),
            ),
            child: Text(
              '${widget.familyInfo.members.length} members',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.emerald,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyMember member;
  final bool isDark;
  final bool isRemoving;
  final VoidCallback? onRemove;

  const _MemberCard({
    required this.member,
    required this.isDark,
    required this.isRemoving,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: member.isOwner
              ? AppColors.emerald.withOpacity(0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: member.isOwner ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: member.isOwner
                    ? [AppColors.emerald, AppColors.ocean]
                    : [AppColors.ocean, AppColors.emeraldLight],
              ),
            ),
            child: Center(
              child: Text(
                member.name.isNotEmpty ? member.name[0].toUpperCase() : 'U',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.name,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ),
                    if (member.isOwner)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.emerald.withOpacity(0.15),
                        ),
                        child: Text(
                          'OWNER',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member.email,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSub
                        : AppColors.lightTextSub,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Joined ${_formatDate(member.joinedAt)}',
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
          if (onRemove != null)
            Opacity(
              opacity: isRemoving ? 0.5 : 1.0,
              child: IconButton(
                onPressed: onRemove,
                icon: Icon(
                  Icons.person_remove_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
