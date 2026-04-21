import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';

class InviteMemberScreen extends StatefulWidget {
  final UserModel user;
  final int familyId;

  const InviteMemberScreen({
    super.key,
    required this.user,
    required this.familyId,
  });

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _isEmailSelected = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    String identifier = _isEmailSelected
        ? _emailController.text.trim()
        : _mobileController.text.trim();

    if (identifier.isEmpty) {
      showAppSnackbar(
        context,
        message: 'Please enter email or mobile number',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _apiService.inviteToFamily(
      widget.familyId,
      identifier,
    );

    if (!mounted) return;

    if (result['success']) {
      showAppSnackbar(
        context,
        message: 'Invitation sent successfully!',
        isSuccess: true,
      );
      Navigator.pop(context, true);
    } else {
      showAppSnackbar(
        context,
        message: result['error'] ?? 'Failed to send invitation',
        isError: true,
      );
    }

    setState(() => _isLoading = false);
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
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  _buildAppBar(isDark),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(isDark),
                          const SizedBox(height: 28),
                          _buildToggle(isDark),
                          const SizedBox(height: 20),
                          if (_isEmailSelected)
                            AppTextField(
                              label: 'Email Address',
                              hint: 'family@example.com',
                              controller: _emailController,
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            )
                          else
                            AppTextField(
                              label: 'Mobile Number',
                              hint: '0771234567',
                              controller: _mobileController,
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          const SizedBox(height: 20),
                          _buildInfoBox(isDark),
                          const SizedBox(height: 28),
                          GradientButton(
                            label: 'Send Invitation',
                            onPressed: _sendInvitation,
                            isLoading: _isLoading,
                            colors: [AppColors.emerald, AppColors.ocean],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                Icons.close_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Invite Member',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [AppColors.emerald, AppColors.ocean],
            ),
          ),
          child: const Icon(
            Icons.person_add_rounded,
            size: 30,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite Family Member',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Text(
                'They will receive a notification',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSub
                      : AppColors.lightTextSub,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightSurfaceAlt,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: 'Email',
            isSelected: _isEmailSelected,
            isDark: isDark,
            onTap: () => setState(() => _isEmailSelected = true),
          ),
          _ToggleOption(
            label: 'Mobile',
            isSelected: !_isEmailSelected,
            isDark: isDark,
            onTap: () => setState(() => _isEmailSelected = false),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.ocean.withOpacity(isDark ? 0.08 : 0.05),
        border: Border.all(color: AppColors.ocean.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.ocean),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Invited members will be able to view shared vehicles and use family wallet (based on permissions).',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.ocean,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.emerald, AppColors.ocean],
                  )
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.darkTextSub : AppColors.lightTextSub),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
