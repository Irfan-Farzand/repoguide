import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final _auth = FirebaseAuth.instance;

  // ───────────────────────────────────────────────
  //   SECURITY WARNING – PRODUCTION MUST CHANGE THIS
  // ───────────────────────────────────────────────
  // NEVER ship client_secret in mobile app!
  // Options:
  // 1. Use Firebase built-in GithubAuthProvider (recommended)
  // 2. Move token exchange to YOUR backend (send code → get token)
  // 3. Use PKCE (proof key for code exchange) – GitHub supports it
  static const String _clientId = 'Ov23lierXMJfHXyKwhaG';
  static const String _clientSecret = '1cf326a81e27c94abecff79815875520f4366b71'; // ← DELETE BEFORE RELEASE!
  static const String _redirectUri = 'https://repoguide-78df2.firebaseapp.com/__/auth/handler';
  static const String _scope = 'user:email read:user';

  String? _state; // CSRF protection

  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();

    _appLinks.uriLinkStream.listen((uri) {
      if (uri != null) {
        debugPrint('Deep link received: $uri');
        _handleDeepLink(uri);
      }
    });

    _checkInitialDeepLink();
  }

  Future<void> _checkInitialDeepLink() async {
    try {
      final initialUri = await _appLinks.getInitialLink(); // updated method name in recent versions
      if (initialUri != null) {
        debugPrint('Initial deep link: $initialUri');
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error checking initial link: $e');
    }
  }

  // login_screen.dart mein replace karo _signInWithGitHub() ko

  Future<void> _signInWithGitHub() async {
    setState(() => _isLoading = true);

    try {
      final provider = GithubAuthProvider();
      provider.addScope('user:email');     // optional but good
      provider.addScope('read:user');

      final userCredential = await FirebaseAuth.instance.signInWithProvider(provider);

      debugPrint('Signed in user: ${userCredential.user?.uid}');

      // No need for ScaffoldMessenger here — AuthGate will navigate automatically
      // But you can keep welcome message if you want
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome ${userCredential.user?.displayName ?? "User"}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('GitHub sign-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> _handleDeepLink(Uri uri) async {
    final code = uri.queryParameters['code'];
    final incomingState = uri.queryParameters['state'];

    if (code == null) {
      debugPrint('No code in redirect');
      setState(() => _isLoading = false);
      return;
    }

    if (incomingState != _state) {
      debugPrint('State mismatch – possible attack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security check failed')),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('Exchanging code for token...');

      final response = await http.post(
        Uri.https('github.com', '/login/oauth/access_token'),
        headers: {'Accept': 'application/json'},
        body: {
          'client_id': _clientId,
          'client_secret': _clientSecret, // ← this line MUST move to backend in prod
          'code': code,
          'redirect_uri': _redirectUri,
        },
      );

      debugPrint('Token response: ${response.statusCode} ${response.body}');

      if (response.statusCode != 200) {
        throw 'Token exchange failed (${response.statusCode})';
      }

      final data = jsonDecode(response.body);
      final accessToken = data['access_token'] as String?;

      if (accessToken == null || accessToken.isEmpty) {
        throw 'No access_token received';
      }

      final credential = GithubAuthProvider.credential(accessToken);

      final userCredential = await _auth.signInWithCredential(credential);

      debugPrint('Signed in: ${userCredential.user?.uid}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome ${userCredential.user?.displayName ?? "User"}!'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e, stack) {
      debugPrint('Login error: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String _generateRandomString(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Login (Testing)'), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Connecting to GitHub...'),
            ],
          )
              : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.code, size: 80, color: Colors.black87),
                const SizedBox(height: 24),
                const Text(
                  'Sign in with GitHub',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Custom OAuth flow (testing only)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGitHub,
                  icon: const Icon(Icons.login),
                  label: const Text('Login with GitHub'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}