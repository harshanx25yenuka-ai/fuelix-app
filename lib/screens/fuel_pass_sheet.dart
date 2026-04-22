import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuelix_app/widgets/custom_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../models/vehicle_model.dart';
import '../models/quota_model.dart';
import '../services/api_service.dart';
import '../services/quota_service.dart';

class FuelPassSheet extends StatefulWidget {
  final VehicleModel vehicle;
  final ApiService apiService;
  final VoidCallback onQuotaUpdated;
  final bool isSharedVehicle;
  final int? sharedWithUserId;
  final int? ownerId;
  final bool canRefuel;

  const FuelPassSheet({
    super.key,
    required this.vehicle,
    required this.apiService,
    required this.onQuotaUpdated,
    this.isSharedVehicle = false,
    this.sharedWithUserId,
    this.ownerId,
    this.canRefuel = false,
  });

  @override
  State<FuelPassSheet> createState() => _FuelPassSheetState();
}

class _FuelPassSheetState extends State<FuelPassSheet> {
  String? _qrData;
  String? _tokenId;
  int _remainingSeconds = 300;
  int _expiresIn = 300;
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isValid = true;
  Timer? _countdownTimer;
  FuelQuotaModel? _quota;
  String? _errorMessage;
  bool _isOwner = true;

  @override
  void initState() {
    super.initState();
    _isOwner = !widget.isSharedVehicle;
    _generateToken();
    _loadQuota();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuota() async {
    if (widget.vehicle.id == null) return;

    try {
      final result = await widget.apiService.getCurrentQuota(
        widget.vehicle.id!,
        widget.vehicle.type,
      );

      if (result['success'] && mounted) {
        final data = result['data'];
        final quota = FuelQuotaModel(
          id: data['id'],
          vehicleId: data['vehicleId'],
          weekStart: DateTime.parse(data['weekStart']),
          weekEnd: DateTime.parse(data['weekEnd']),
          quotaLitres: (data['quotaLitres'] as num).toDouble(),
          usedLitres: (data['usedLitres'] as num).toDouble(),
        );
        setState(() => _quota = quota);
      }
    } catch (e) {
      print('Error loading quota: $e');
    }
  }

  Future<void> _generateToken() async {
    if (_isRefreshing) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.isSharedVehicle) {
      if (!widget.canRefuel) {
        setState(() {
          _errorMessage =
              'You don\'t have permission to view this Fuel Pass. Contact the vehicle owner.';
          _isLoading = false;
          _isRefreshing = false;
        });
        return;
      }

      // For shared vehicles with permission, show QR but no generation
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
      return;
    }

    final result = await widget.apiService.generateDynamicQr(
      widget.vehicle.id!,
    );

    if (result['success'] && mounted) {
      if (_tokenId != null) {
        await widget.apiService.invalidateToken(_tokenId!);
      }

      setState(() {
        _qrData = result['qrData'];
        _tokenId = result['tokenId'];
        _expiresIn = result['expiresIn'];
        _remainingSeconds = result['expiresIn'];
        _isValid = true;
        _isLoading = false;
        _isRefreshing = false;
      });
      _startCountdown();
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Failed to generate QR';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        setState(() => _isValid = false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _generateToken();
        });
      }
    });
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await _generateToken();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  bool get _isExpiringSoon => _remainingSeconds < 60 && _remainingSeconds > 0;
  bool get _isExpired => _remainingSeconds <= 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _vehicleTypeColor(widget.vehicle.type);
    final showQr =
        (!widget.isSharedVehicle) ||
        (widget.isSharedVehicle && widget.canRefuel);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.isSharedVehicle
                                  ? 'SHARED VEHICLE'
                                  : 'FUEL PASS',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 2,
                              ),
                            ),
                            if (widget.isSharedVehicle) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: widget.canRefuel
                                      ? AppColors.emerald.withOpacity(0.2)
                                      : AppColors.error.withOpacity(0.2),
                                ),
                                child: Text(
                                  widget.canRefuel
                                      ? 'Refuel Allowed'
                                      : 'Refuel Disabled',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: widget.canRefuel
                                        ? AppColors.emerald
                                        : AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          widget.vehicle.displayName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                        if (widget.isSharedVehicle)
                          Text(
                            widget.canRefuel
                                ? 'You can refuel this vehicle'
                                : 'You cannot refuel this vehicle',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: widget.canRefuel
                                  ? AppColors.emerald
                                  : AppColors.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!widget.isSharedVehicle)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _isValid
                            ? (_isExpiringSoon
                                  ? AppColors.amber.withOpacity(0.15)
                                  : AppColors.emerald.withOpacity(0.15))
                            : AppColors.error.withOpacity(0.15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isValid
                                ? (_isExpiringSoon
                                      ? Icons.timer_outlined
                                      : Icons.check_circle)
                                : Icons.error_outline,
                            size: 14,
                            color: _isValid
                                ? (_isExpiringSoon
                                      ? AppColors.amber
                                      : AppColors.emerald)
                                : AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isValid
                                ? (_isExpiringSoon ? 'Expiring soon' : 'Active')
                                : 'Expired',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _isValid
                                  ? (_isExpiringSoon
                                        ? AppColors.amber
                                        : AppColors.emerald)
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    colors: [
                      accent,
                      accent.withOpacity(0.75),
                      AppColors.ocean.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (!widget.isSharedVehicle)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: _isExpiringSoon
                                  ? AppColors.amber
                                  : Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Valid for: ${_formatTime(_remainingSeconds)}',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isExpiringSoon
                                    ? AppColors.amber
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // QR Code Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _isLoading
                            ? Container(
                                width: 200,
                                height: 200,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.emerald,
                                  ),
                                ),
                              )
                            : _errorMessage != null
                            ? Container(
                                width: 200,
                                height: 200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : !showQr
                            ? Container(
                                width: 200,
                                height: 200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_scanner,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'QR Code Disabled',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You don\'t have permission to refuel this vehicle',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _qrData != null &&
                                  _isValid &&
                                  !widget.isSharedVehicle
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  QrImageView(
                                    data: _qrData!,
                                    version: QrVersions.auto,
                                    size: 200,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Color(0xFF000000),
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Color(0xFF000000),
                                    ),
                                  ),
                                  if (_isExpiringSoon)
                                    Positioned(
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: AppColors.amber,
                                        ),
                                        child: Text(
                                          'Expires in ${_remainingSeconds}s',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : widget.isSharedVehicle && showQr
                            ? Container(
                                width: 200,
                                height: 200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_scanner,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'QR Code Available to Owner Only',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Contact vehicle owner for refuel',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppColors.ocean,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                width: 200,
                                height: 200,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_scanner,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'QR Expired',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: _generateToken,
                                      child: Text(
                                        'Tap to refresh',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: AppColors.emerald,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (!widget.isSharedVehicle &&
                        widget.vehicle.fuelPassCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.vehicle.fuelPassCode!,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: widget.vehicle.fuelPassCode!,
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code copied!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _PassDetail(
                              label: 'REG NO',
                              value: widget.vehicle.registrationNo,
                            ),
                          ),
                          Expanded(
                            child: _PassDetail(
                              label: 'FUEL TYPE',
                              value: widget.vehicle.fuelType,
                            ),
                          ),
                          Expanded(
                            child: _PassDetail(
                              label: 'VEHICLE TYPE',
                              value: widget.vehicle.type,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (_quota != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _QuotaCard(
                  quota: _quota!,
                  vehicleType: widget.vehicle.type,
                  isDark: isDark,
                  isSharedVehicle: widget.isSharedVehicle,
                ),
              ),

            const SizedBox(height: 16),

            if (!widget.isSharedVehicle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GradientButton(
                  label: _isRefreshing ? 'Generating...' : 'Generate New QR',
                  onPressed: _manualRefresh,
                  isLoading: _isRefreshing,
                  colors: [AppColors.ocean, AppColors.emerald],
                ),
              ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _Notice(
                icon: Icons.security_rounded,
                color: AppColors.emerald,
                isDark: isDark,
                text: widget.isSharedVehicle
                    ? (widget.canRefuel
                          ? 'You can view the fuel quota and vehicle details. Contact the owner for QR code.'
                          : 'You don\'t have permission to refuel this vehicle. Contact the owner to enable permission.')
                    : 'This QR code expires after 5 minutes OR after first scan. Generate a fresh one if needed.',
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
              child: _Notice(
                icon: Icons.info_outline_rounded,
                color: AppColors.ocean,
                isDark: isDark,
                text: widget.isSharedVehicle
                    ? 'This vehicle is shared with you. You can view quota but cannot generate QR code.'
                    : 'Show this QR code at Fuelix-partnered stations. Staff will scan to verify your fuel pass.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const m = [
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
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Color _vehicleTypeColor(String type) {
    switch (type) {
      case 'Car':
        return AppColors.ocean;
      case 'Motorcycle':
        return AppColors.amber;
      case 'Van':
        return AppColors.emerald;
      case 'Truck':
        return const Color(0xFFEF4444);
      case 'Bus':
        return const Color(0xFF7C3AED);
      case 'Three-Wheeler':
        return const Color(0xFFF97316);
      default:
        return AppColors.emerald;
    }
  }
}

class _PassDetail extends StatelessWidget {
  final String label, value;
  const _PassDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.65),
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final String text;
  const _Notice({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: color.withOpacity(isDark ? 0.08 : 0.05),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 12, color: color, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class _QuotaCard extends StatelessWidget {
  final FuelQuotaModel quota;
  final String vehicleType;
  final bool isDark;
  final bool isSharedVehicle;

  const _QuotaCard({
    required this.quota,
    required this.vehicleType,
    required this.isDark,
    this.isSharedVehicle = false,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = quota.remainingLitres;
    final used = quota.usedLitres;
    final total = quota.quotaLitres;
    final pct = quota.usedPercent;
    final exhausted = quota.isExhausted;

    Color gaugeColor;
    if (pct < 0.5) {
      gaugeColor = AppColors.emerald;
    } else if (pct < 0.85) {
      gaugeColor = AppColors.amber;
    } else {
      gaugeColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border.all(
          color: exhausted
              ? AppColors.error.withOpacity(0.4)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: exhausted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: exhausted
                        ? [AppColors.error, AppColors.error.withOpacity(0.7)]
                        : [AppColors.emerald, AppColors.ocean],
                  ),
                ),
                child: Icon(
                  exhausted
                      ? Icons.no_meals_rounded
                      : Icons.local_gas_station_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSharedVehicle
                          ? 'Vehicle Quota (Shared)'
                          : 'Weekly Fuel Quota',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkText
                            : AppColors.lightText,
                      ),
                    ),
                    Text(
                      QuotaService.weekLabel(quota.weekStart),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: (exhausted ? AppColors.error : AppColors.emerald)
                      .withOpacity(isDark ? 0.15 : 0.10),
                  border: Border.all(
                    color: (exhausted ? AppColors.error : AppColors.emerald)
                        .withOpacity(0.35),
                  ),
                ),
                child: Text(
                  exhausted
                      ? 'Exhausted'
                      : QuotaService.daysRemainingLabel(DateTime.now()),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: exhausted ? AppColors.error : AppColors.emerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _QuotaStat(
                label: 'Remaining',
                value: '${remaining.toStringAsFixed(1)} L',
                color: exhausted ? AppColors.error : AppColors.emerald,
                isDark: isDark,
                large: true,
              ),
              _vDivider(isDark),
              _QuotaStat(
                label: 'Used',
                value: '${used.toStringAsFixed(1)} L',
                color: AppColors.amber,
                isDark: isDark,
              ),
              _vDivider(isDark),
              _QuotaStat(
                label: 'Weekly Total',
                value: '${total.toStringAsFixed(0)} L',
                color: AppColors.ocean,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: isDark
                  ? AppColors.darkSurfaceAlt
                  : AppColors.lightSurfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(pct * 100).toStringAsFixed(0)}% used',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
              Text(
                'Resets next Monday',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          if (exhausted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.error.withOpacity(isDark ? 0.12 : 0.07),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSharedVehicle
                          ? 'Vehicle quota is exhausted. Owner can refuel when quota resets.'
                          : 'Your weekly quota is exhausted. Balance resets every Monday.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.error,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vDivider(bool isDark) => Container(
    width: 1,
    height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
  );
}

class _QuotaStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark, large;
  const _QuotaStat({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: large ? 22 : 17,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
      ],
    ),
  );
}
