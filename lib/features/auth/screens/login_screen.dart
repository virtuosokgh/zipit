import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/constants/app_spacing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        context.pop();
      }
    } on AuthException catch (e) {
      if (mounted) {
        String message = '로그인에 실패했어요';
        if (e.message.contains('Invalid login credentials')) {
          message = '이메일 또는 비밀번호가 올바르지 않아요';
        } else if (e.message.contains('Email not confirmed')) {
          message = '이메일 인증이 완료되지 않았어요. 메일함을 확인해주세요';
        } else if (e.message.contains('Too many requests')) {
          message = '너무 많은 시도가 있었어요. 잠시 후 다시 시도해주세요';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),
                Text('다시 만나서 반가워요!', style: AppTypography.heading2),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '로그인하고 집잇의 모든 기능을 이용해보세요',
                  style: AppTypography.body2.copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // 이메일
                Text('이메일', style: AppTypography.label2),
                const SizedBox(height: AppSpacing.sm),
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

                // 비밀번호
                Text('비밀번호', style: AppTypography.label2),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: _inputDecoration('비밀번호를 입력해주세요').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.gray400,
                        size: 20,
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
                const SizedBox(height: AppSpacing.xxxl),

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: AppSpacing.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
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
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Text('로그인', style: AppTypography.label1.copyWith(color: AppColors.white)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // 회원가입 링크
                Center(
                  child: GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: RichText(
                      text: TextSpan(
                        text: '계정이 없으신가요? ',
                        style: AppTypography.body2.copyWith(color: AppColors.textTertiary),
                        children: [
                          TextSpan(
                            text: '회원가입',
                            style: AppTypography.body2Bold.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
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
