import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';

class StaffQrScannerScreen extends StatefulWidget {
  const StaffQrScannerScreen({super.key});

  @override
  State<StaffQrScannerScreen> createState() => _StaffQrScannerScreenState();
}

class _StaffQrScannerScreenState extends State<StaffQrScannerScreen>
    with WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  bool _isScanning = true;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  final ApiService _apiService = ApiService();

  String _stationName = '';
  String _stationBrand = '';
  bool _hasScanned = false;

  bool _isVerifying = false;
  bool _verificationComplete = false;
  bool _verificationFailed = false;
  String? _verificationError;
  Map<String, dynamic>? _verifiedData;

  String _litresInput = '';
  TextEditingController _litresController = TextEditingController();
  bool _isRefilling = false;

  List<VerificationStep> _steps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScanner();
    _loadStationData();
    _litresController.addListener(() {
      setState(() {});
    });
    _initializeSteps();
  }

  void _initializeSteps() {
    _steps = [
      VerificationStep(
        id: 'step1',
        title: 'QR Validation',
        subtitle: 'Validating QR code signature',
        status: VerificationStatus.pending,
        icon: Icons.qr_code_rounded,
      ),
      VerificationStep(
        id: 'step2',
        title: 'Fuel Pass Verification',
        subtitle: 'Verifying vehicle passcode',
        status: VerificationStatus.pending,
        icon: Icons.verified_user_rounded,
      ),
      VerificationStep(
        id: 'step3',
        title: 'Quota Check',
        subtitle: 'Checking available fuel quota',
        status: VerificationStatus.pending,
        icon: Icons.local_gas_station_rounded,
      ),
      VerificationStep(
        id: 'step4',
        title: 'Wallet Balance',
        subtitle: 'Verifying wallet balance',
        status: VerificationStatus.pending,
        icon: Icons.account_balance_wallet_rounded,
      ),
      VerificationStep(
        id: 'step5',
        title: 'Load Data',
        subtitle: 'Loading vehicle information',
        status: VerificationStatus.pending,
        icon: Icons.cloud_download_rounded,
      ),
    ];
  }

  Future<void> _loadStationData() async {
    final staffData = await _apiService.getStaffData();
    if (staffData != null && mounted) {
      setState(() {
        _stationName = staffData['stationName'] ?? 'Fuel Station';
        _stationBrand = staffData['stationBrand'] ?? '';
      });
    }
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: _cameraFacing,
      torchEnabled: _isTorchOn,
      autoStart: true,
      returnImage: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _scannerController.start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        _scannerController.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    _litresController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing || _hasScanned || _isVerifying) return;

    final barcode = capture.barcodes.first;
    final rawValue = barcode.rawValue;

    if (rawValue == null || rawValue.isEmpty) return;

    if (_lastScannedCode == rawValue &&
        _lastScanTime != null &&
        DateTime.now().difference(_lastScanTime!) <
            const Duration(seconds: 2)) {
      return;
    }

    setState(() {
      _isScanning = false;
      _isProcessing = true;
      _lastScannedCode = rawValue;
      _lastScanTime = DateTime.now();
    });

    try {
      await HapticFeedback.mediumImpact();

      // Check QR version and send full QR data to backend
      if (rawValue.startsWith('FUELIX|2.0|')) {
        // Version 2.0 - Send full QR data with signature
        await _verifyQrWithBackend(rawValue);
      } else if (rawValue.startsWith('FUELIX|')) {
        // Legacy QR - Extract passcode and send
        final extractedValue = _extractPasscode(rawValue);
        await _verifyLegacyQr(extractedValue);
      } else {
        setState(() {
          _errorMessage = 'Invalid QR format';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to process QR code';
        _isProcessing = false;
      });
    }
  }

  String _extractPasscode(String rawValue) {
    try {
      if (rawValue.startsWith('{') && rawValue.endsWith('}')) {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('passcode'))
            return decoded['passcode'].toString();
          if (decoded.containsKey('fuelPassCode'))
            return decoded['fuelPassCode'].toString();
          if (decoded.containsKey('code')) return decoded['code'].toString();
        }
        return rawValue;
      }

      if (rawValue.toLowerCase().startsWith('fuelix://')) {
        final uri = Uri.parse(rawValue);
        final queryParams = uri.queryParameters;
        if (queryParams.containsKey('code')) return queryParams['code']!;
        if (queryParams.containsKey('passcode'))
          return queryParams['passcode']!;
        return rawValue;
      }

      if (rawValue.toUpperCase().startsWith('FUELIX|')) {
        final parts = rawValue.split('|');
        if (parts.length >= 2) return parts[1];
      }

      if (rawValue.toUpperCase().startsWith('FUELIX,')) {
        final parts = rawValue.split(',');
        if (parts.length >= 2) return parts[1];
      }

      return rawValue;
    } catch (e) {
      debugPrint('Error extracting value: $e');
      return rawValue;
    }
  }

  Future<void> _verifyQrWithBackend(String qrData) async {
    // Reset steps
    for (int i = 0; i < _steps.length; i++) {
      _steps[i] = _steps[i].copyWith(
        status: VerificationStatus.pending,
        message: null,
      );
    }

    setState(() {
      _isVerifying = true;
      _isProcessing = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.emerald,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Verifying QR Code',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _steps
                    .map((step) => _buildVerificationStepWidget(step))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resetToScan();
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Step 1: QR Validation (signature check)
    _updateStep(0, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    // Send full QR data to backend for validation
    final result = await _apiService.staffVerifyQrV2(qrData);

    if (!result['success']) {
      _updateStep(
        0,
        VerificationStatus.failed,
        message: result['error'] ?? 'QR validation failed',
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog(result['error'] ?? 'QR validation failed');
      }
      return;
    }

    _updateStep(0, VerificationStatus.completed, message: 'Signature verified');
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 2: Fuel Pass Verification
    _updateStep(1, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    final vehicle = result['vehicle'];
    if (vehicle == null) {
      _updateStep(1, VerificationStatus.failed, message: 'Vehicle not found');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog('Vehicle not found');
      }
      return;
    }

    _updateStep(
      1,
      VerificationStatus.completed,
      message: 'Vehicle: ${vehicle['registrationNo']}',
    );
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 3: Quota Check
    _updateStep(2, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    final quota = result['quota'];
    final remainingQuota = quota['remainingQuota'] as double;

    if (remainingQuota < 1.0) {
      _updateStep(
        2,
        VerificationStatus.failed,
        message: 'Insufficient quota: ${remainingQuota.toStringAsFixed(1)} L',
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog(
          'Insufficient quota available. Remaining: ${remainingQuota.toStringAsFixed(1)} L',
        );
      }
      return;
    }

    _updateStep(
      2,
      VerificationStatus.completed,
      message: 'Available: ${remainingQuota.toStringAsFixed(1)} L',
    );
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 4: Wallet Check
    _updateStep(3, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    final wallet = result['wallet'];
    final balance = wallet['balance'] as double;

    if (balance < 100.0) {
      _updateStep(
        3,
        VerificationStatus.failed,
        message: 'Low balance: LKR ${balance.toStringAsFixed(2)}',
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog(
          'Low wallet balance. Current: LKR ${balance.toStringAsFixed(2)}',
        );
      }
      return;
    }

    _updateStep(
      3,
      VerificationStatus.completed,
      message: 'Balance: LKR ${balance.toStringAsFixed(2)}',
    );
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 5: Load Data
    _updateStep(4, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    setState(() {
      _verifiedData = {
        'vehicleId': vehicle['id'],
        'userId': vehicle['userId'],
        'registrationNo': vehicle['registrationNo'],
        'vehicleType': vehicle['vehicleType'],
        'make': vehicle['make'],
        'model': vehicle['model'],
        'fuelType': vehicle['fuelType'],
        'tokenId': result['tokenId'],
        'remainingQuota': remainingQuota,
        'quotaLitres': quota['quotaLitres'],
        'usedLitres': quota['usedLitres'],
        'balance': balance,
      };
    });

    _updateStep(4, VerificationStatus.completed, message: 'Ready for refill');
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.pop(context);
      setState(() {
        _verificationComplete = true;
        _isVerifying = false;
        _litresInput = '';
        _litresController.clear();
      });
    }
  }

  Future<void> _verifyLegacyQr(String passcode) async {
    // Reset steps
    for (int i = 0; i < _steps.length; i++) {
      _steps[i] = _steps[i].copyWith(
        status: VerificationStatus.pending,
        message: null,
      );
    }

    setState(() {
      _isVerifying = true;
      _isProcessing = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.emerald,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Verifying Fuel Pass',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _steps
                    .map((step) => _buildVerificationStepWidget(step))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _resetToScan();
                },
                child: Text(
                  'Cancel',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Step 1: QR Validation (skip for legacy)
    _updateStep(0, VerificationStatus.completed, message: 'Legacy QR format');
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 2: Fuel Pass Verification
    _updateStep(1, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    final result = await _apiService.staffVerifyPasscode(passcode);

    if (!result['success']) {
      _updateStep(
        1,
        VerificationStatus.failed,
        message: 'Invalid Fuel Pass Code',
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog('Invalid Fuel Pass Code');
      }
      return;
    }

    _updateStep(1, VerificationStatus.completed);
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 3: Quota Check
    _updateStep(2, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    if (result.containsKey('step2') && !result['step2']['success']) {
      _updateStep(
        2,
        VerificationStatus.failed,
        message: result['step2']['message'],
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog(result['step2']['message']);
      }
      return;
    }

    _updateStep(2, VerificationStatus.completed);
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 4: Wallet Check
    _updateStep(3, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    if (result.containsKey('step3') && !result['step3']['success']) {
      _updateStep(
        3,
        VerificationStatus.failed,
        message: result['step3']['message'],
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog(result['step3']['message']);
      }
      return;
    }

    _updateStep(3, VerificationStatus.completed);
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 5: Load Data
    _updateStep(4, VerificationStatus.loading);
    await Future.delayed(const Duration(milliseconds: 200));

    if (result.containsKey('step4') && result['step4']['success']) {
      final step4Data = result['step4'];
      setState(() {
        _verifiedData = {
          'vehicleId': step4Data['vehicleId'],
          'userId': step4Data['userId'],
          'registrationNo': step4Data['registrationNo'],
          'vehicleType': step4Data['vehicleType'],
          'make': step4Data['make'],
          'model': step4Data['model'],
          'fuelType': step4Data['fuelType'],
          'remainingQuota': step4Data['remainingQuota'],
          'balance': step4Data['balance'],
        };
      });
      _updateStep(4, VerificationStatus.completed);
      await Future.delayed(const Duration(milliseconds: 500));
    } else {
      _updateStep(4, VerificationStatus.failed, message: 'Failed to load data');
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.pop(context);
        _showErrorDialog('Failed to load vehicle data');
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context);
      setState(() {
        _verificationComplete = true;
        _isVerifying = false;
        _litresInput = '';
        _litresController.clear();
      });
    }
  }

  void _updateStep(int index, VerificationStatus status, {String? message}) {
    if (!mounted) return;
    setState(() {
      _steps[index] = _steps[index].copyWith(status: status, message: message);
    });
  }

  Widget _buildVerificationStepWidget(VerificationStep step) {
    Color getStatusColor() {
      switch (step.status) {
        case VerificationStatus.completed:
          return AppColors.emerald;
        case VerificationStatus.failed:
          return AppColors.error;
        case VerificationStatus.loading:
          return AppColors.ocean;
        default:
          return Colors.grey;
      }
    }

    IconData getStatusIcon() {
      switch (step.status) {
        case VerificationStatus.completed:
          return Icons.check_circle_rounded;
        case VerificationStatus.failed:
          return Icons.error_outline;
        case VerificationStatus.loading:
          return Icons.hourglass_empty_rounded;
        default:
          return step.icon;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: getStatusColor().withOpacity(0.1),
            ),
            child: step.status == VerificationStatus.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        getStatusColor(),
                      ),
                    ),
                  )
                : Icon(getStatusIcon(), size: 18, color: getStatusColor()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  step.message ?? step.subtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text(
              'Verification Failed',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetToScan();
            },
            child: Text(
              'Scan Again',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: AppColors.ocean,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetToScan() {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _isProcessing = false;
      _hasScanned = false;
      _isVerifying = false;
      _verificationComplete = false;
      _verificationFailed = false;
      _verificationError = null;
      _verifiedData = null;
      _litresInput = '';
      _litresController.clear();
      _isRefilling = false;
    });
    _scannerController.start();
  }

  void _exitToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _toggleTorch() {
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
    _scannerController.toggleTorch();
    HapticFeedback.lightImpact();
  }

  void _switchCamera() {
    HapticFeedback.mediumImpact();
    setState(() {
      _cameraFacing = _cameraFacing == CameraFacing.back
          ? CameraFacing.front
          : CameraFacing.back;
    });
    _scannerController.switchCamera();
  }

  void _onNumberPadTap(String value) {
    setState(() {
      if (value == 'clear') {
        _litresInput = '';
        _litresController.clear();
      } else if (value == '.') {
        if (!_litresInput.contains('.')) {
          _litresInput += value;
          _litresController.text = _litresInput;
        }
      } else {
        _litresInput += value;
        _litresController.text = _litresInput;
      }

      double entered = double.tryParse(_litresInput) ?? 0;
      double availableQuota = _verifiedData?['remainingQuota'] ?? 0;
      if (entered > availableQuota && availableQuota > 0) {
        _litresInput = availableQuota.toString();
        _litresController.text = _litresInput;
      }
    });
  }

  void _onRefillPressed() {
    double litres = double.tryParse(_litresInput) ?? 0;
    double availableQuota = _verifiedData?['remainingQuota'] ?? 0;

    if (litres <= 0) return;
    if (litres > availableQuota) {
      _litresInput = availableQuota.toString();
      _litresController.text = _litresInput;
      litres = availableQuota;
    }

    _showPaymentConfirmation(litres);
  }

  void _showPaymentConfirmation(double litres) {
    double pricePerLitre = 350.0;
    double totalCost = litres * pricePerLitre;
    double balance = _verifiedData?['balance'] ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.payment_rounded, color: AppColors.emerald, size: 28),
            const SizedBox(width: 12),
            Text(
              'Confirm Refill',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoRow(
              Icons.opacity_rounded,
              'Litres',
              '${litres.toStringAsFixed(2)} L',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.currency_rupee_rounded,
              'Total Cost',
              'LKR ${totalCost.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.account_balance_wallet_rounded,
              'Wallet Balance',
              'LKR ${balance.toStringAsFixed(2)}',
            ),
            if (totalCost > balance)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: AppColors.error.withOpacity(0.1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Insufficient balance. Please top up your wallet.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                color: AppColors.ocean,
              ),
            ),
          ),
          if (totalCost <= balance)
            GradientButton(
              label: 'Confirm Refill',
              onPressed: () {
                Navigator.pop(ctx);
                _processRefill(litres, totalCost);
              },
              height: 45,
            ),
        ],
      ),
    );
  }

  Future<void> _processRefill(double litres, double totalCost) async {
    setState(() {
      _isRefilling = true;
    });

    try {
      final result = await _apiService.addFuelLogFromStaff(
        vehicleId: _verifiedData?['vehicleId'],
        userId: _verifiedData?['userId'],
        litres: litres,
        fuelType: _verifiedData?['fuelType'] ?? 'Petrol',
        vehicleType: _verifiedData?['vehicleType'] ?? 'Car',
        stationName: _stationName,
      );

      if (_verifiedData?['tokenId'] != null) {
        final staffData = await _apiService.getStaffData();
        await _apiService.completeRefill(
          tokenId: _verifiedData!['tokenId'],
          staffId: staffData?['staffId'] ?? 0,
          fuelLogData: result['data'] ?? {},
        );
      }

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refill successful! ${litres.toStringAsFixed(2)} L added',
            ),
            backgroundColor: AppColors.emerald,
            duration: const Duration(seconds: 2),
          ),
        );
        _resetToScan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Refill failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefilling = false;
        });
      }
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13))),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final scanAreaSize = screenSize.width - 100;
    final scanAreaTop = screenSize.height * 0.2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Staff QR Scanner',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _isTorchOn
                  ? Icons.flashlight_on_rounded
                  : Icons.flashlight_off_rounded,
              color: _isTorchOn ? AppColors.amber : null,
            ),
          ),
          IconButton(
            onPressed: _switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [AppColors.emerald, AppColors.ocean],
                    ),
                  ),
                  child: const Icon(
                    Icons.local_gas_station_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stationName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                      if (_stationBrand.isNotEmpty)
                        Text(
                          _stationBrand,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.emerald.withOpacity(0.1),
                  ),
                  child: Text(
                    'STAFF',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_verificationComplete && _verifiedData != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    AppColors.emerald.withOpacity(0.1),
                    AppColors.ocean.withOpacity(0.1),
                  ],
                ),
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        size: 20,
                        color: AppColors.emerald,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Registration No',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      Text(
                        _verifiedData?['registrationNo'] ?? 'N/A',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.opacity_rounded,
                        size: 20,
                        color: AppColors.emerald,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Available Quota',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${(_verifiedData?['remainingQuota'] ?? 0).toStringAsFixed(1)} L',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 20,
                        color: AppColors.emerald,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Wallet Balance',
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                      ),
                      Text(
                        'LKR ${(_verifiedData?['balance'] ?? 0).toStringAsFixed(2)}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Expanded(
            child: _verificationComplete && _verifiedData != null
                ? _buildRefillScreen(isDark)
                : _buildScannerScreen(isDark, scanAreaTop, scanAreaSize),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildScannerScreen(
    bool isDark,
    double scanAreaTop,
    double scanAreaSize,
  ) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleBarcode,
          errorBuilder: (context, error, child) {
            return Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Camera Error',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: 'Retry',
                      onPressed: _resetToScan,
                      height: 45,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        CustomPaint(
          painter: StaffScannerOverlayPainter(
            scanAreaRect: Rect.fromLTWH(
              50,
              scanAreaTop,
              scanAreaSize,
              scanAreaSize,
            ),
          ),
          child: Container(width: double.infinity, height: double.infinity),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.emerald,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Processing QR Code...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRefillScreen(bool isDark) {
    double availableQuota = _verifiedData?['remainingQuota'] ?? 0;
    double enteredLitres = double.tryParse(_litresInput) ?? 0;
    bool isRefillEnabled =
        _litresInput.isNotEmpty &&
        enteredLitres > 0 &&
        enteredLitres <= availableQuota;

    return Container(
      width: double.infinity,
      color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isDark ? AppColors.darkSurface : Colors.white,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.opacity_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: IgnorePointer(
                      ignoring: true,
                      child: TextField(
                        controller: _litresController,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                          border: InputBorder.none,
                          suffixText: 'L',
                          suffixStyle: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildNumberPad(isDark),
            const SizedBox(height: 16),
            Text(
              'Max available: ${availableQuota.toStringAsFixed(1)} L',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.ocean),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad(bool isDark) {
    final buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'clear'],
    ];

    return Column(
      children: buttons.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((btn) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onNumberPadTap(btn),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    height: 65,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: btn == 'clear'
                          ? Icon(
                              Icons.backspace_rounded,
                              size: 28,
                              color: AppColors.error,
                            )
                          : Text(
                              btn,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    double enteredLitres = double.tryParse(_litresInput) ?? 0;
    bool isRefillEnabled =
        _verificationComplete &&
        _verifiedData != null &&
        _litresInput.isNotEmpty &&
        enteredLitres > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: _verificationComplete && _verifiedData != null
            ? SizedBox(
                width: double.infinity,
                child: GradientButton(
                  label: _isRefilling ? 'Processing...' : 'Refill',
                  onPressed: isRefillEnabled && !_isRefilling
                      ? _onRefillPressed
                      : null,
                  isLoading: _isRefilling,
                ),
              )
            : OutlinedAppButton(
                label: 'Cancel',
                onPressed: _exitToLogin,
                icon: Icons.close_rounded,
              ),
      ),
    );
  }
}

class StaffScannerOverlayPainter extends CustomPainter {
  final Rect scanAreaRect;
  StaffScannerOverlayPainter({required this.scanAreaRect});

  @override
  void paint(Canvas canvas, Size size) {
    final Path overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanAreaRect)
      ..fillType = PathFillType.evenOdd;
    final Paint overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    final borderPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.emerald, AppColors.ocean],
      ).createShader(scanAreaRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(scanAreaRect, borderPaint);

    final cornerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.emerald, AppColors.ocean],
      ).createShader(scanAreaRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final cornerLength = 30.0;
    final left = scanAreaRect.left,
        right = scanAreaRect.right,
        top = scanAreaRect.top,
        bottom = scanAreaRect.bottom;

    canvas.drawLine(
      Offset(left, top + cornerLength),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + cornerLength, top),
      Offset(left, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - cornerLength, top),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, top + cornerLength),
      Offset(right, top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left, bottom - cornerLength),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(left + cornerLength, bottom),
      Offset(left, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right - cornerLength, bottom),
      Offset(right, bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(right, bottom - cornerLength),
      Offset(right, bottom),
      cornerPaint,
    );

    final circlePaint = Paint()
      ..color = AppColors.emerald
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(left + 10, top + 10), 3, circlePaint);
    canvas.drawCircle(Offset(right - 10, top + 10), 3, circlePaint);
    canvas.drawCircle(Offset(left + 10, bottom - 10), 3, circlePaint);
    canvas.drawCircle(Offset(right - 10, bottom - 10), 3, circlePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum VerificationStatus { pending, loading, completed, failed }

class VerificationStep {
  final String id;
  final String title;
  final String subtitle;
  final VerificationStatus status;
  final IconData icon;
  final String? message;

  VerificationStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
    this.message,
  });

  VerificationStep copyWith({
    String? id,
    String? title,
    String? subtitle,
    VerificationStatus? status,
    IconData? icon,
    String? message,
  }) {
    return VerificationStep(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      message: message ?? this.message,
    );
  }
}
