import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Make sure to import your new detail screen
import 'repo_detail_screen.dart';  // ← Add this line

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  List<dynamic> _myRepos = [];
  List<dynamic> _searchRepos = [];

  bool _isLoading = false;
  String? _error;

  int _selectedTab = 0; // 0 = My Repos, 1 = Search

  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedTab == 0) {
        _fetchMyRepositories();
      }
    });
  }

  Future<String?> _getStoredGitHubToken() async {
    return await _storage.read(key: 'github_access_token');
  }

  Future<void> _fetchMyRepositories() async {
    final token = await _getStoredGitHubToken();

    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'GitHub token not found';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _myRepos = [];
    });

    try {
      final uri = Uri.https('api.github.com', '/user/repos', {
        'per_page': '50',
        'sort': 'updated',
        'direction': 'desc',
        'type': 'all',
      });

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'Authorization': 'token $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final repos = (data as List<dynamic>?) ?? [];

        setState(() {
          _myRepos = repos;
          if (repos.isEmpty) {
            _error =
            'GitHub par aapke koi repositories nahi hain (public/private dono).\n\nYa phir token mein repo scope missing hai.';
          }
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _error =
          'Token invalid ya expire ho gaya (GitHub ne revoke kar diya hoga).\nSign out → GitHub se dobara login karo.';
        });
        await _storage.delete(key: 'github_access_token');
      } else if (response.statusCode == 403) {
        setState(() {
          _error = 'Permission issue (repo scope nahi mila) ya rate limit.\nGitHub settings check karo.';
        });
      } else {
        setState(() {
          _error =
          'GitHub se error: ${response.statusCode}\n${response.body.substring(0, 200)}...';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network ya parsing error: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchRepositories(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _searchRepos = [];
    });

    try {
      final uri = Uri.https('api.github.com', '/search/repositories', {
        'q': query,
        'sort': 'stars',
        'order': 'desc',
        'per_page': '15',
      });

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchRepos = (data['items'] as List<dynamic>?) ?? [];
        });
      } else {
        setState(() {
          _error = 'Search error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentList = _selectedTab == 0 ? _myRepos : _searchRepos;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (user?.photoURL != null)
              CircleAvatar(
                  radius: 18, backgroundImage: NetworkImage(user!.photoURL!))
            else
              const CircleAvatar(radius: 18, child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                user?.displayName ?? 'GitHub User',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              try {
                await _storage.delete(key: 'github_access_token');

                final logoutUrl = Uri.parse('https://github.com/logout');
                if (await canLaunchUrl(logoutUrl)) {
                  await launchUrl(logoutUrl,
                      mode: LaunchMode.externalApplication);
                }
                await Future.delayed(const Duration(seconds: 2));

                await FirebaseAuth.instance.signOut();

                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Logged out successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Logout failed: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedTab == 1)
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search GitHub repos...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _searchRepositories,
                  ),
                const SizedBox(height: 12),
                ToggleButtons(
                  isSelected: [_selectedTab == 0, _selectedTab == 1],
                  onPressed: (index) {
                    setState(() {
                      _selectedTab = index;
                      if (index == 0 &&
                          _myRepos.isEmpty &&
                          _error == null) {
                        _fetchMyRepositories();
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  selectedColor: Colors.white,
                  fillColor: Theme.of(context).colorScheme.primary,
                  children: const [
                    Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      child: Text('My Repos'),
                    ),
                    Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      child: Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 16),
                ),
              ),
            )
                : currentList.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedTab == 0
                        ? Icons.folder_open
                        : Icons.search_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedTab == 0
                        ? 'No repositories found\n(or token/scope issue)'
                        : 'Search for repositories',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: currentList.length,
              itemBuilder: (context, index) {
                final repo = currentList[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                        repo['owner']?['avatar_url'] ?? ''),
                  ),
                  title: Text(
                    repo['full_name'] ?? 'Unknown',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (repo['description'] != null)
                        Text(
                          repo['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_border,
                              size: 16),
                          Text(
                              ' ${repo['stargazers_count'] ?? 0}  '),
                          const Icon(Icons.call_split,
                              size: 16),
                          Text(' ${repo['forks_count'] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.open_in_new,
                      size: 18),
                  onTap: () {
                    // Navigate to detail screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RepoDetailScreen(repo: repo),
                      ),
                    );

                    // Optional: also open in browser
                    // final url = repo['html_url']?.toString();
                    // if (url != null) {
                    //   launchUrl(Uri.parse(url),
                    //       mode: LaunchMode.externalApplication);
                    // }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}