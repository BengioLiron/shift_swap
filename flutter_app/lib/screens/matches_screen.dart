// lib/screens/matches_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/swap_request_model.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class MatchesScreen extends StatelessWidget {
  final UserModel user;
  final DateTime giveDate;
  final List<DateTime> takeDates;
  final List<SwapRequest> matches;

  const MatchesScreen({
    super.key,
    required this.user,
    required this.giveDate,
    required this.takeDates,
    required this.matches,
  });

  String _initials(String name) => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase())
      .take(2)
      .join();

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[d.weekday % 7]} ${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final hasMatches = matches.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          Container(
            color: const Color(0xFF1A2332),
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
                    (r) => false,
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_back_ios, color: Color(0xFF8BA5C4), size: 14),
                    Text('Home', style: TextStyle(color: Color(0xFF8BA5C4), fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 10),
                Text(
                  hasMatches ? 'Matches found!' : 'Request saved',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  hasMatches
                      ? '${matches.length} match${matches.length > 1 ? 'es' : ''} found for your swap'
                      : "No matches yet — you'll be notified when someone matches",
                  style: const TextStyle(color: Color(0xFF8BA5C4), fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: hasMatches
                ? ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: matches.length,
                    itemBuilder: (_, i) {
                      final m = matches[i];
                      return _MatchCard(
                        match: m,
                        myGiveDate: giveDate,
                        onMarkDone: () async {
                          try {
                            await ApiService.markDone(
                              myRequestId: 'local',
                              theirRequestId: m.id,
                            );
                          } catch (_) {}
                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            builder: (_) => _DoneDialog(
                              name: m.userName,
                              onConfirm: () => Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
                                (r) => false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 16),
                          const Text('No matches yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          const Text(
                            'Your request has been saved. We\'ll match you when someone with the same role posts a compatible swap.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF888780), fontSize: 14, height: 1.5),
                          ),
                          const SizedBox(height: 28),
                          OutlinedButton(
                            onPressed: () => Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
                              (r) => false,
                            ),
                            child: const Text('Back to home'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final SwapRequest match;
  final DateTime myGiveDate;
  final VoidCallback onMarkDone;

  const _MatchCard({required this.match, required this.myGiveDate, required this.onMarkDone});

  String _initials(String name) => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase())
      .take(2)
      .join();

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[d.weekday % 7]} ${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1A2332),
                radius: 20,
                child: Text(_initials(match.userName),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(match.userName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                Text(match.userRole,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
              ]),
            ]),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Pill(text: 'Gives ${_formatDate(match.giveDate)}', type: 'give'),
                const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF888780)),
                _Pill(text: 'Takes ${_formatDate(myGiveDate)}', type: 'take'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1A2332)),
                  foregroundColor: const Color(0xFF1A2332),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onMarkDone,
                child: Text('Mark as done with ${match.userName.split(' ').first}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final String type;
  const _Pill({required this.text, required this.type});

  @override
  Widget build(BuildContext context) {
    final isGive = type == 'give';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGive ? const Color(0xFFFAEEDA) : const Color(0xFFEAF3DE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isGive ? const Color(0xFF854F0B) : const Color(0xFF3B6D11),
        ),
      ),
    );
  }
}

class _DoneDialog extends StatelessWidget {
  final String name;
  final VoidCallback onConfirm;

  const _DoneDialog({required this.name, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Confirm swap', style: TextStyle(fontWeight: FontWeight.w500)),
      content: Text(
        'This will mark the swap with ${name.split(' ').first} as complete and remove both requests.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
