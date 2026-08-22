import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/token_store.dart';
import '../../../core/utils/jwt_utils.dart';
import '../../logistics/presentation/picking_queue_screen.dart';
import '../../logistics/presentation/delivery_queue_screen.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../notifications/data/messaging_service.dart';
import '../data/auth_api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authApi = AuthApi();
  final _tokenStore = TokenStore();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _erro;
  final int _currentTabIndex = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _checkedResetFlag = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedResetFlag) return;
    _checkedResetFlag = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['passwordReset'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida! Faça login com a nova senha.'),
          ),
        );
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _submitting = true;
      _erro = null;
    });
    try {
      await _authApi.login(email: email, password: password);
      // Now that a JWT exists, register this device for push notifications.
      // Best-effort: never block navigation on it.
      await MessagingService().syncToken();
      if (!mounted) return;
      await _redirecionarPorPapel();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Lê o claim `role` do access token recém-salvo e decide para onde
  /// navegar. Separador e entregador têm seu próprio ponto de entrada;
  /// aluno segue para a home de sempre.
  Future<void> _redirecionarPorPapel() async {
    final accessToken = await _tokenStore.readAccessToken();
    final role = accessToken != null ? extrairRoleDoToken(accessToken) : null;

    if (!mounted) return;

    switch (role) {
      case 'separador':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SeparadorFilaScreen()),
        );
        break;
      case 'entregador':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EntregadorFilaScreen()),
        );
        break;
      case 'admin':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
        break;
      case 'student':
      default:
        Navigator.pushReplacementNamed(
          context,
          '/home',
          arguments: {'justLoggedIn': true},
        );
    }
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
              child: _LoginCard(
                formKey: _formKey,
                emailController: _emailController,
                passwordController: _passwordController,
                obscurePassword: _obscurePassword,
                submitting: _submitting,
                erro: _erro,
                onToggleObscure: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                onLogin: _handleLogin,
                onForgotPassword: () =>
                    Navigator.pushNamed(context, '/forgot-password'),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/register'),
              child: Text.rich(
                TextSpan(
                  text: 'Não tem uma conta? ',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: 'Inscreva-se no Edu IA',
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
            // Nota: o antigo link "Acessar Edu Logistics" foi removido —
            // com RBAC unificado, separador/entregador entram por este
            // mesmo formulário e são redirecionados automaticamente
            // (ver _redirecionarPorPapel). Ver STATUS.md para detalhes.
          ],
          ),
        ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            if (index == 1) {
              Navigator.pushReplacementNamed(context, '/register');
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
          Center(
            child: Column(
              children: [
                Text(
                  'Bem vindo(a)\nde volta!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Insira suas credenciais para continuar\nsua jornada intelectual.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.submitting,
    required this.erro,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onForgotPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool submitting;
  final String? erro;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
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
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'E-mail',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'nome@email.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                if (!v.contains('@')) return 'E-mail inválido';
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Senha',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onLogin(),
              decoration: InputDecoration(
                hintText: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Informe a senha' : null,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onForgotPassword,
                child: const Text(
                  'Esqueceu sua senha?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.purple,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (erro != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        erro!,
                        style: const TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: submitting ? null : onLogin,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 24),
            const _Divider(),
            const SizedBox(height: 24),
            const _SocialButtons(),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.inputBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Ou entre com',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
        Expanded(child: Divider(color: AppColors.inputBorder)),
      ],
    );
  }
}

class _SocialButtons extends StatelessWidget {
  const _SocialButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Text(
              'G',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            label: const Text(
              'Google',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.inputBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Text(
              'iOS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            label: const Text(
              'Apple',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.inputBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
