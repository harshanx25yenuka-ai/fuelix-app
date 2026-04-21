import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/vehicle_model.dart';
import '../../models/family_models.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button.dart';

class ShareVehicleScreen extends StatefulWidget {
  final UserModel user;

  const ShareVehicleScreen({super.key, required this.user});

  @override
  State<ShareVehicleScreen> createState() => _ShareVehicleScreenState();
}

class _ShareVehicleScreenState extends State<ShareVehicleScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<VehicleModel> _vehicles = [];
  List<FamilyMember> _familyMembers = [];
  VehicleModel? _selectedVehicle;
  FamilyMember? _selectedMember;
  bool _isLoading = true;
  bool _isSharing = false;
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
    _loadData();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load user's vehicles
    final vehiclesResult = await _apiService.getVehicles(widget.user.id!);
    if (vehiclesResult['success']) {
      final List<dynamic> vehiclesJson = vehiclesResult['data'];
      setState(() {
        _vehicles = vehiclesJson
            .map(
              (json) => VehicleModel(
                id: json['id'],
                userId: json['userId'],
                type: json['type'],
                make: json['make'],
                model: json['model'],
                year: json['year'],
                registrationNo: json['registrationNo'],
                fuelType: json['fuelType'],
                engineCC: json['engineCC'] ?? '',
                color: json['color'] ?? '',
                fuelPassCode: json['fuelPassCode'],
                qrGeneratedAt: json['qrGeneratedAt'] != null
                    ? DateTime.tryParse(json['qrGeneratedAt'])
                    : null,
                createdAt: json['createdAt'] != null
                    ? DateTime.tryParse(json['createdAt'])
                    : null,
              ),
            )
            .toList();
      });
    }

    // Load family members
    final familyResult = await _apiService.getFamilyInfo();
    if (familyResult['success'] && familyResult['data']['hasFamily']) {
      final familyInfo = FamilyInfo.fromJson(familyResult['data']);
      setState(() {
        _familyMembers = familyInfo.members
            .where((m) => m.userId != widget.user.id)
            .toList();
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _shareVehicle() async {
    if (_selectedVehicle == null) {
      showAppSnackbar(
        context,
        message: 'Please select a vehicle',
        isError: true,
      );
      return;
    }

    if (_selectedMember == null) {
      showAppSnackbar(
        context,
        message: 'Please select a family member',
        isError: true,
      );
      return;
    }

    setState(() => _isSharing = true);

    final result = await _apiService.shareVehicle(
      _selectedVehicle!.id!,
      _selectedMember!.userId,
    );

    if (!mounted) return;

    if (result['success']) {
      showAppSnackbar(
        context,
        message: 'Vehicle shared successfully!',
        isSuccess: true,
      );
      Navigator.pop(context, true);
    } else {
      showAppSnackbar(
        context,
        message: result['error'] ?? 'Failed to share vehicle',
        isError: true,
      );
    }

    setState(() => _isSharing = false);
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
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(isDark),
                              const SizedBox(height: 28),
                              _buildSectionTitle('Select Vehicle', isDark),
                              const SizedBox(height: 10),
                              _buildVehicleDropdown(isDark),
                              const SizedBox(height: 24),
                              _buildSectionTitle(
                                'Select Family Member',
                                isDark,
                              ),
                              const SizedBox(height: 10),
                              _buildMemberDropdown(isDark),
                              const SizedBox(height: 28),
                              _buildInfoBox(isDark),
                              const SizedBox(height: 28),
                              GradientButton(
                                label: 'Share Vehicle',
                                onPressed: _shareVehicle,
                                isLoading: _isSharing,
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
              'Share Vehicle',
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
          child: const Icon(Icons.share_rounded, size: 30, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share with Family',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              Text(
                'Family members can refuel using your quota',
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

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextSub : AppColors.lightTextSub,
      ),
    );
  }

  Widget _buildVehicleDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<VehicleModel>(
          value: _selectedVehicle,
          isExpanded: true,
          hint: Text(
            'Select a vehicle',
            style: GoogleFonts.inter(
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          dropdownColor: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          items: _vehicles.map((vehicle) {
            return DropdownMenuItem(
              value: vehicle,
              child: Text(
                vehicle.displayName,
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedVehicle = value),
        ),
      ),
    );
  }

  Widget _buildMemberDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<FamilyMember>(
          value: _selectedMember,
          isExpanded: true,
          hint: Text(
            _familyMembers.isEmpty
                ? 'No other family members'
                : 'Select a family member',
            style: GoogleFonts.inter(
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          dropdownColor: isDark
              ? AppColors.darkSurface
              : AppColors.lightSurface,
          items: _familyMembers.map((member) {
            return DropdownMenuItem(
              value: member,
              child: Text(
                member.name,
                style: GoogleFonts.inter(
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            );
          }).toList(),
          onChanged: _familyMembers.isEmpty
              ? null
              : (value) => setState(() => _selectedMember = value),
        ),
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
              'Shared vehicles can be refueled using the family wallet. The owner maintains full control.',
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
