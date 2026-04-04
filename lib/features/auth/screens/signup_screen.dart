import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../models/user_profile.dart';
import '../../../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _depositCountController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _showSubscriptionInfo = false;

  // 청약 정보
  int _noHouseYears = 0;
  int _dependents = 0;
  int _accountYears = 0;
  bool _isHouseHolder = false;
  bool _isMarried = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    _depositCountController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await signup(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 프로필 저장
      final depositCount = int.tryParse(_depositCountController.text.trim());
      final profile = UserProfile(
        email: _emailController.text.trim(),
        nickname: _nicknameController.text.trim(),
        noHouseYears: _showSubscriptionInfo ? _noHouseYears : null,
        dependents: _showSubscriptionInfo ? _dependents : null,
        accountYears: _showSubscriptionInfo ? _accountYears : null,
        depositCount: _showSubscriptionInfo ? depositCount : null,
        isHouseHolder: _showSubscriptionInfo ? _isHouseHolder : null,
        isMarried: _showSubscriptionInfo ? _isMarried : null,
      );
      await ref.read(userProfileProvider.notifier).setProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었어요!'),
            backgroundColor: AppColors.primary,
          ),
        );
        context.go('/home');
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message = '회원가입에 실패했어요';
        if (e.message.contains('already registered') || e.message.contains('already been registered')) {
          message = '이미 사용 중인 이메일이에요';
        } else if (e.message.contains('Password should be')) {
          message = '비밀번호가 너무 약해요. 6자 이상 입력해주세요';
        } else if (e.message.contains('invalid') && e.message.contains('email')) {
          message = '이메일 형식이 올바르지 않아요';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: const Text('인증 메일을 보냈어요', style: AppTypography.heading3),
        content: Text(
          '${_emailController.text.trim()}으로 인증 메일을 보냈어요.\n메일을 확인하고 인증을 완료해주세요.',
          style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/home');
            },
            child: Text(
              '확인',
              style: AppTypography.label2.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text('집잇에 오신 것을 환영해요!', style: AppTypography.heading2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '간단한 정보를 입력하고 시작해보세요',
                  style: AppTypography.body2.copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // 이메일
                _fieldLabel('이메일'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('이메일을 입력해주세요'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '이메일을 입력해주세요';
                    if (!v.contains('@')) return '올바른 이메일 형식이 아니에요';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // 닉네임
                _fieldLabel('닉네임'),
                TextFormField(
                  controller: _nicknameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('닉네임을 입력해주세요'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '닉네임을 입력해주세요';
                    if (v.trim().length < 2) return '닉네임은 2자 이상이어야 해요';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // 비밀번호
                _fieldLabel('비밀번호'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('비밀번호를 입력해주세요 (6자 이상)').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.gray400, size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 입력해주세요';
                    if (v.length < 6) return '비밀번호는 6자 이상이어야 해요';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // 비밀번호 확인
                _fieldLabel('비밀번호 확인'),
                TextFormField(
                  controller: _passwordConfirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration('비밀번호를 다시 입력해주세요').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.gray400, size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호 확인을 입력해주세요';
                    if (v != _passwordController.text) return '비밀번호가 일치하지 않아요';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // 청약 정보 (Expandable)
                _subscriptionInfoSection(),
                const SizedBox(height: AppSpacing.xxxl),

                // 회원가입 버튼
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.gray300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                          )
                        : Text('회원가입', style: AppTypography.label1.copyWith(color: AppColors.white)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(label, style: AppTypography.label2),
    );
  }

  Widget _subscriptionInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          // 헤더
          InkWell(
            onTap: () => setState(() => _showSubscriptionInfo = !_showSubscriptionInfo),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(Icons.apartment_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('청약 정보 입력', style: AppTypography.body1Bold),
                        Text('선택사항 - 나중에 설정에서 입력할 수 있어요',
                            style: AppTypography.caption1.copyWith(color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  Icon(
                    _showSubscriptionInfo ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.gray400,
                  ),
                ],
              ),
            ),
          ),
          // 내용
          if (_showSubscriptionInfo) ...[
            const Divider(height: 1, color: AppColors.borderLight),
            // 주의사항 안내
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(AppSpacing.cardPadding, AppSpacing.cardPadding, AppSpacing.cardPadding, 0),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '아래 정보를 입력해야 AI 청약 당첨확률 분석을 이용할 수 있어요. 미입력 시 정확한 분석이 어려워요.',
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.warning,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                children: [
                  _stepper('무주택 기간 (년)', _noHouseYears, 0, 15,
                      (v) => setState(() => _noHouseYears = v)),
                  const SizedBox(height: AppSpacing.md),
                  _stepper('부양가족 수 (명)', _dependents, 0, 6,
                      (v) => setState(() => _dependents = v)),
                  const SizedBox(height: AppSpacing.md),
                  _stepper('청약통장 가입 기간 (년)', _accountYears, 0, 15,
                      (v) => setState(() => _accountYears = v)),
                  const SizedBox(height: AppSpacing.md),

                  // 납입 횟수
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('납입 횟수', style: AppTypography.body2),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _depositCountController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: AppTypography.body1Bold,
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: AppTypography.body1Bold.copyWith(color: AppColors.textDisabled),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 세대주 여부
                  _switchRow('세대주 여부', _isHouseHolder,
                      (v) => setState(() => _isHouseHolder = v)),
                  const SizedBox(height: AppSpacing.md),

                  // 혼인 여부
                  _switchRow('혼인 여부', _isMarried,
                      (v) => setState(() => _isMarried = v)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body2),
          Row(
            children: [
              _stepBtn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
              SizedBox(
                width: 40,
                child: Text('$value', style: AppTypography.body1Bold, textAlign: TextAlign.center),
              ),
              _stepBtn(Icons.add, value < max ? () => onChanged(value + 1) : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.gray100 : AppColors.gray50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: onTap != null ? AppColors.textPrimary : AppColors.gray300),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body2),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body2.copyWith(color: AppColors.textDisabled),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.borderFocused, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}
