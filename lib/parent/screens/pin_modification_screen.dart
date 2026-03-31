import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/app_mode.dart';
import 'package:kova/core/constants.dart';

class PinModificationScreen extends StatefulWidget {
  const PinModificationScreen({super.key});

  @override
  State<PinModificationScreen> createState() => _PinModificationScreenState();
}

class _PinModificationScreenState extends State<PinModificationScreen> {
  int _currentStep = 0; // 0: Old PIN, 1: New PIN, 2: Confirm PIN
  final _pinController = TextEditingController();
  String _newPin = '';
  bool _isError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_pinController.text.length < 4) {
      setState(() {
        _pinController.text += digit;
        _isError = false;
      });

      if (_pinController.text.length == 4) {
        _handleStepCompletion();
      }
    }
  }

  void _onBackPressed() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text = _pinController.text.substring(0, _pinController.text.length - 1);
        _isError = false;
      });
    }
  }

  Future<void> _handleStepCompletion() async {
    final pin = _pinController.text;

    if (_currentStep == 0) {
      // Verify Old PIN
      final isValid = await AppModeManager.verifyPin(pin);
      if (isValid) {
        setState(() {
          _currentStep = 1;
          _pinController.clear();
        });
      } else {
        setState(() {
          _isError = true;
          _errorMessage = 'Incorrect current PIN';
          _pinController.clear();
        });
      }
    } else if (_currentStep == 1) {
      // Set New PIN
      setState(() {
        _newPin = pin;
        _currentStep = 2;
        _pinController.clear();
      });
    } else if (_currentStep == 2) {
      // Confirm New PIN
      if (pin == _newPin) {
        await AppModeManager.setParentMode(pin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PIN updated successfully'),
              backgroundColor: KovaColors.success,
            ),
          );
          context.pop();
        }
      } else {
        setState(() {
          _isError = true;
          _errorMessage = 'PINs do not match';
          _pinController.clear();
        });
      }
    }
  }

  String get _title {
    switch (_currentStep) {
      case 0:
        return 'Enter current PIN';
      case 1:
        return 'Enter new PIN';
      case 2:
        return 'Confirm new PIN';
      default:
        return '';
    }
  }

  String get _subtitle {
    switch (_currentStep) {
      case 0:
        return 'Please verify your identity to change your PIN';
      case 1:
        return 'Create a new 4-digit security PIN';
      case 2:
        return 'Repeat the new PIN to confirm';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KovaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: KovaColors.textPrimary,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: KovaColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: KovaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),

            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pinController.text.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? KovaColors.primary : Colors.transparent,
                    border: Border.all(
                      color: _isError ? KovaColors.danger : KovaColors.primary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_isError) ...[
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                style: GoogleFonts.nunito(
                  color: KovaColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const Spacer(),

            // Numpad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                children: [
                  _buildNumpadRow(['1', '2', '3']),
                  const SizedBox(height: 20),
                  _buildNumpadRow(['4', '5', '6']),
                  const SizedBox(height: 20),
                  _buildNumpadRow(['7', '8', '9']),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 70), // Spacer for align
                      _buildNumpadButton('0'),
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: IconButton(
                          onPressed: _onBackPressed,
                          icon: const Icon(Icons.backspace_rounded, color: KovaColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildNumpadButton(d)).toList(),
    );
  }

  Widget _buildNumpadButton(String digit) {
    return InkWell(
      onTap: () => _onDigitPressed(digit),
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: KovaColors.cardWhite,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: KovaColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
