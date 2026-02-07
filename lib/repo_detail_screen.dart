import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RepoDetailScreen extends StatelessWidget {
  final Map<String, dynamic> repo;

  const RepoDetailScreen({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    final String? repoName = repo['name'] as String?;
    final String? fullName = repo['full_name'] as String?;
    final String? htmlUrl = repo['html_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          repoName ?? 'Repository',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Repo name (thoda sa context ke liye)
              Text(
                fullName ?? 'Unknown Repository',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Sirf URL + button
              if (htmlUrl != null && htmlUrl.isNotEmpty) ...[
                SelectableText(
                  htmlUrl,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open in Browser'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    launchUrl(
                      Uri.parse(htmlUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ] else ...[
                const Text(
                  'No URL available for this repository',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 40),

              // Optional: wapas jaane ka button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}