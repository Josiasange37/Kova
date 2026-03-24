// parent_profile_screen.dart — KOVA Parent Profile Setup
// Collects: first name, WhatsApp number, 4-digit PIN
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';

class ParentProfileScreen extends StatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _pinVisible = false;
  bool _confirmPinVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KovaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KovaSpacing.lg,
            vertical: KovaSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ── Title ──
              Text(
                'Your profile',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: KovaColors.primary,
                ),
              ),
              const SizedBox(height: 28),

              // ── First Name ──
              _buildLabel('Your first name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hint: 'Enter your name',
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // ── WhatsApp Number ──
              _buildLabel('Your WhatsApp number'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _phoneController,
                hint: '+237',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                ],
              ),
              const SizedBox(height: 24),

              // ── Create PIN ──
              _buildLabel('Create a 4-digit PIN'),
              const SizedBox(height: 8),
              _buildPinField(
                controller: _pinController,
                visible: _pinVisible,
                onToggleVisibility: () {
                  setState(() => _pinVisible = !_pinVisible);
                },
              ),
              const SizedBox(height: 10),
              _buildPinDots(_pinController),
              const SizedBox(height: 24),

              // ── Confirm PIN ──
              _buildLabel('Confirm PIN'),
              const SizedBox(height: 8),
              _buildPinField(
                controller: _confirmPinController,
                visible: _confirmPinVisible,
                onToggleVisibility: () {
                  setState(() => _confirmPinVisible = !_confirmPinVisible);
                },
              ),
              const SizedBox(height: 10),
              _buildPinDots(_confirmPinController),
              const SizedBox(height: 20),

              // ── Info text ──
              Text(
                'This PIN protects your settings and lets you view\ndetected content.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: KovaColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // ── Continue Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KovaColors.primary,
                    foregroundColor: KovaColors.textOnDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KovaRadius.pill),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Label ──
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: KovaColors.textPrimary,
      ),
    );
  }

  // ── Standard text field ──
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: GoogleFonts.nunito(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: KovaColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: KovaColors.textSecondary.withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: KovaColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
          borderSide: BorderSide(
            color: KovaColors.divider,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
          borderSide: BorderSide(
            color: KovaColors.divider,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
          borderSide: BorderSide(
            color: KovaColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ── PIN text field with visibility toggle ──
  Widget _buildPinField({
    required TextEditingController controller,
    required bool visible,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: KovaColors.textPrimary,
        letterSpacing: 8,
      ),
      decoration: InputDecoration(
        counterText: '', // hide the default counter
        filled: true,
        fillColor: KovaColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
          borderSide: BorderSide(color: KovaColors.divider, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
          borderSide: BorderSide(color: KovaColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
          borderSide: BorderSide(color: KovaColors.primary, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: KovaColors.textSecondary,
            size: 22,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }

  // ── PIN dot indicators ──
  Widget _buildPinDots(TextEditingController controller) {
    final filled = controller.text.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? KovaColors.primary
                : Colors.transparent,
            border: Border.all(
              color: KovaColors.primary.withValues(alpha: isFilled ? 1.0 : 0.3),
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  // ── Continue button handler ──
  void _onContinue() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (name.isEmpty) {
      _showSnackBar('Please enter your name');
      return;
    }
    if (phone.isEmpty) {
      _showSnackBar('Please enter your WhatsApp number');
      return;
    }
    if (pin.length != 4) {
      _showSnackBar('PIN must be 4 digits');
      return;
    }
    if (pin != confirmPin) {
      _showSnackBar('PINs do not match');
      return;
    }

    // TODO: Save profile data and navigate to next setup screen
    Navigator.of(context).pushReplacementNamed(KovaRoutes.childProfile);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
        ),
        backgroundColor: KovaColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
        ),
      ),
    );
  }
}
