import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'submit_request_screen.dart';
import 'my_requests_screen.dart';
import 'request_board_screen.dart';

class HomeScreen extends StatelessWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  String get _initials => user.name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase())
      .take(2)
      .join();

  @override
  Widget build(BuildContext context) {
    final firstName = user.name.split(' ').first;

    return Scaffold(
      body: Column(
        children: [
          // Hero
          Container(
            color: const Color(0xFF1A2332),
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 24,
              right: 24,
              bottom: 28,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: const Color(0xFF4A9EFF),
                        child: Text(
                          _initials,
                          style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.role,
                        style: const TextStyle(
                            color: Color(0xFFC5D8EC), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Good morning,\n$firstName.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ready to swap a shift?',
                  style: TextStyle(color: Color(0xFF8BA5C4), fontSize: 14),
                ),
              ],
            ),
          ),

          // Cards
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'ACTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF888780),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _NavCard(
                    icon: '📤',
                    title: 'Submit request',
                    subtitle: 'Post a shift you want to swap',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubmitRequestScreen(user: user),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _NavCard(
                    icon: '📋',
                    title: 'My requests',
                    subtitle: 'View status and matches',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyRequestsScreen(user: user),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _NavCard(
                    icon: '📊',
                    title: 'Request board',
                    subtitle: 'Browse all pending requests',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestBoardScreen(user: user),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Text(icon,
                        style: const TextStyle(fontSize: 20))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF888780))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB4B2A9)),
            ],
          ),
        ),
      ),
    );
  }
}