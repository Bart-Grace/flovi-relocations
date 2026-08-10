import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/gigs/available_gigs_page.dart';
import 'features/gigs/my_gigs_page.dart';
import 'phone_frame.dart';
import 'theme.dart';

// Config arrives via --dart-define only. There is no committed constants file, and these
// names are exactly the ones scripts/deploy-driver.sh passes.
const String kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String kSupabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final missing = <String>[
    if (kSupabaseUrl.isEmpty) 'SUPABASE_URL',
    if (kSupabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
  ];
  if (missing.isNotEmpty) {
    // Same contract as the web app: name the missing variable, never boot into a blank screen.
    runApp(ConfigErrorApp(missing: missing));
    return;
  }

  await Supabase.initialize(
    url: kSupabaseUrl,
    publishableKey: kSupabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  runApp(const FloviDriverApp());
}

class FloviDriverApp extends StatelessWidget {
  const FloviDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flovi Driver',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // Everything the app renders lives inside the device frame on wide viewports.
      builder: (context, child) => PhoneFrame(child: child ?? const SizedBox.shrink()),
      home: const AuthGate(),
    );
  }
}

/// The whole routing story: one StreamBuilder on onAuthStateChange. No go_router, no Riverpod.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        // Branch on currentSession, not on the snapshot: the stream has emitted nothing on
        // the first frame, but the session may already have been restored from storage.
        final session = auth.currentSession;
        return session == null ? const SignInScreen() : const HomeShell();
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        // The TRAILING SLASH is load-bearing. The allow-list entry is
        // `https://flovi-driver-bl.vercel.app/**`, and that glob does not match a bare
        // origin — `Uri.base.origin` returns no trailing slash. Without it Supabase
        // rejects the target and silently falls back to the Site URL, which is the
        // DISPATCHER app: the driver signs in and lands in the wrong product, holding a
        // perfectly valid session, with nothing that looks like an error.
        // The SDK already forces webOnlyWindowName '_self' internally, so this navigates
        // the current tab and the PKCE verifier stays on the origin that started the flow.
        redirectTo: kIsWeb ? '${Uri.base.origin}/' : 'com.flovi.driver://login-callback',
        authScreenLaunchMode:
            kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );
      // Write no callback-handling code: the SDK strips the params and onAuthStateChange fires.
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FLOVI',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Driver', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Find relocation gigs near you and book them in one tap.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_busy ? 'Opening Google…' : 'Continue with Google'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = user?.userMetadata?['full_name'] as String? ?? user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flovi Driver'),
        actions: [
          if (name.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(name, style: Theme.of(context).textTheme.labelLarge),
              ),
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => Supabase.instance.client.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      // IndexedStack so each tab keeps its state — and, from prompt 10, its stream
      // subscription — across switches.
      body: IndexedStack(
        index: _index,
        children: [
          const AvailableGigsPage(),
          MyGigsPage(onBrowseAvailable: () => setState(() => _index = 0)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Available'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'My gigs'),
        ],
      ),
    );
  }
}

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.missing});
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF450A0A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Configuration missing: ${missing.join(', ')}.\n'
              'Pass it with --dart-define at build time, then redeploy.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
