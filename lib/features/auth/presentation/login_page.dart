import 'package:flutter/material.dart';
import 'auth_controller.dart';
import 'verify_code_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
    _authController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _authController.removeListener(_onControllerChanged);
    _authController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSubmit {
    final digits = _extractDigits(_phoneController.text);
    return digits.length == 10 && !_authController.isLoading;
  }

  String _extractDigits(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _onPhoneChanged(String value) {
    final digits = _extractDigits(value);
    final safe = digits.length > 10 ? digits.substring(0, 10) : digits;
    final formatted = _formatPhone(safe);

    if (formatted != value) {
      _phoneController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    setState(() {});
  }

  String _formatPhone(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6 || i == 8) buffer.write('-');
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final localDigits = _extractDigits(_phoneController.text);
    final normalizedPhone = '+7$localDigits';

    final ok = await _authController.requestCode(normalizedPhone);

    if (!mounted) return;

    if (ok) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyCodePage(phone: normalizedPhone),
        ),
      );
      return;
    }

    final message =
        _authController.error.isNotEmpty
            ? _authController.error
            : 'Не удалось отправить код';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF3FAE2A);
    const darkGreen = Color(0xFF2E7D32);
    const subtitle = Color(0xFF8E8E93);
    const inputBg = Color(0xFFF5F5F7);
    const inputBorder = Color(0xFFE7E7EC);
    const hint = Color(0xFFB7B7BF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: green,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delivery_dining_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Вход для курьера',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Войдите по номеру телефона',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: subtitle,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: inputBorder),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Text(
                            '+7',
                            style: TextStyle(
                              color: subtitle,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: inputBorder,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              onChanged: _onPhoneChanged,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                              decoration: const InputDecoration(
                                hintText: '(700) 000-00-00',
                                hintStyle: TextStyle(
                                  color: hint,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _canSubmit ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: green,
                          disabledBackgroundColor: const Color(0xFFE5E5E5),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ).copyWith(
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.disabled)) {
                              return const Color(0xFFE5E5E5);
                            }
                            if (states.contains(WidgetState.pressed)) {
                              return darkGreen;
                            }
                            return green;
                          }),
                        ),
                        child:
                            _authController.isLoading
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text(
                                  'Войти',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Продолжая, вы соглашаетесь с условиями сервиса',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: subtitle,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}