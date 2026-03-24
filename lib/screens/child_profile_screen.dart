import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kova/core/constants.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  int _age = 10;
  bool _isNameFilled = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      final filled = _nameController.text.trim().isNotEmpty;
      if (filled != _isNameFilled) {
        setState(() => _isNameFilled = filled);
      }
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    // Start animation
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _incrementAge() {
    if (_age < 18) setState(() => _age++);
  }

  void _decrementAge() {
    if (_age > 3) setState(() => _age--);
  }

  void _onContinue() {
    if (!_isNameFilled) return;
    // Hide keyboard
    FocusScope.of(context).unfocus();
    // Navigate to next screen, perhaps whatsappConnect or dashboard
    Navigator.of(context).pushReplacementNamed(KovaRoutes.dashboard);
  }

  // Helper for mode config
  String get _modeName {
    if (_age < 8) return 'Strict mode';
    if (_age <= 12) return 'Standard mode';
    return 'Teen mode';
  }

  String get _modeDescription {
    if (_age < 8) return 'Maximum protection for young kids';
    if (_age <= 12) return 'Balanced protection for pre-teens';
    return 'Flexible protection for teenagers';
  }

  Color get _modeColor {
    if (_age < 8) return KovaColors.primary;
    if (_age <= 12) return KovaColors.success;
    return KovaColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KovaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: KovaColors.textPrimary,
          iconSize: 20,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: KovaSpacing.lg,
                vertical: KovaSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your child\'s profile',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: KovaColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Avatar Area ──
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: KovaColors.cardWhite,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: KovaColors.divider,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 48,
                            color: KovaColors.divider,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () {
                              // Avatar pick logic placeholder
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: KovaColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: KovaColors.cardWhite,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Name Field ──
                  _buildLabel('Child\'s first name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Enter child\'s name',
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 24),

                  // ── Age Field ──
                  _buildLabel('Age'),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: KovaColors.cardWhite,
                      borderRadius: BorderRadius.circular(KovaRadius.button),
                      border: Border.all(color: KovaColors.divider, width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _decrementAge,
                          icon: const Icon(Icons.remove_rounded),
                          color: _age > 3
                              ? KovaColors.textPrimary
                              : KovaColors.textSecondary.withValues(alpha: 0.5),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Text(
                            '$_age',
                            key: ValueKey<int>(_age),
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: KovaColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _incrementAge,
                          icon: const Icon(Icons.add_rounded),
                          color: _age < 18
                              ? KovaColors.textPrimary
                              : KovaColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Protection Mode Card ──
                  AnimatedOpacity(
                    opacity: _isNameFilled ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KovaColors.cardWhite,
                        borderRadius: BorderRadius.circular(KovaRadius.card),
                        border: Border.all(
                          color: _modeColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: KovaColors.primary.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _modeColor.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(KovaRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 14,
                                  color: _modeColor,
                                ),
                                const SizedBox(width: 4),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  child: Text(
                                    _modeName,
                                    key: ValueKey<String>(_modeName),
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _modeColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _modeDescription,
                              key: ValueKey<String>(_modeDescription),
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: KovaColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Continue Button ──
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isNameFilled ? _onContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isNameFilled
                            ? KovaColors.primary
                            : KovaColors.primary.withValues(alpha: 0.3),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
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
          borderSide: const BorderSide(
            color: KovaColors.divider,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
          borderSide: const BorderSide(
            color: KovaColors.divider,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KovaRadius.button),
          borderSide: const BorderSide(
            color: KovaColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
