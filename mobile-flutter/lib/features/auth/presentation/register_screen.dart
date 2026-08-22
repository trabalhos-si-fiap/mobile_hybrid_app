import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../notifications/data/messaging_service.dart';
import '../data/auth_api.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authApi = AuthApi();
  String? _selectedEducation;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;

  // Must match the backend `EducationLevel` enum values exactly.
  static const _educationLevels = [
    '9º ano',
    '1º ano',
    '2º ano',
    '3º ano',
    'Vestibulando',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1930),
      lastDate: now,
    );
    if (picked != null) {
      _birthDateController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _handleRegister() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await _authApi.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        birthDate: _birthDateController.text.trim(),
        educationLevel: _selectedEducation!,
        password: _passwordController.text,
      );
      // A JWT now exists; register this device for push notifications.
      // Best-effort: never block navigation on it.
      await MessagingService().syncToken();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {'justRegistered': true},
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Informe a senha';
    if (value.length < 8) return 'Mínimo de 8 caracteres';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Deve conter pelo menos um caractere especial';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _Header(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildCard(),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text.rich(
                  TextSpan(
                    text: 'Já tem uma conta? ',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      TextSpan(
                        text: 'Entrar',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.purple,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            currentIndex: 1,
            onTap: (index) {
              if (index == 0) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            backgroundColor: AppColors.white,
            selectedItemColor: AppColors.purple,
            unselectedItemColor: AppColors.textSecondary,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.login),
                label: 'Entrar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_add_outlined),
                label: 'Cadastro',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      transform: Matrix4.translationValues(0, -20, 0),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Nome'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Seu nome completo'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('E-mail'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'nome@email.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                if (!v.contains('@')) return 'E-mail inválido';
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildLabel('Telefone'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: '(11) 99999-9999'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Informe o telefone' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('Data de nascimento'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _birthDateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                hintText: 'DD/MM/AAAA',
                suffixIcon: Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Informe a data de nascimento'
                  : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('Escolaridade'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedEducation,
              decoration: const InputDecoration(hintText: 'Selecione'),
              items: _educationLevels
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedEducation = v),
              validator: (v) => v == null ? 'Selecione a escolaridade' : null,
            ),
            const SizedBox(height: 20),
            _buildLabel('Senha'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Mín. 8 caracteres + especial',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 20),
            _buildLabel('Confirmar senha'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Repita a senha',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirme a senha';
                if (v != _passwordController.text) {
                  return 'As senhas não coincidem';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _submitting ? null : _handleRegister,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edu IA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Crie sua conta!',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Junte-se à nossa comunidade e\ntransforme sua jornada de\naprendizado com inteligência.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}
