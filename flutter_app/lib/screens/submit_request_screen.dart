// lib/screens/submit_request_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/swap_request_model.dart';
import '../services/api_service.dart';
import 'matches_screen.dart';

class SubmitRequestScreen extends StatefulWidget {
  final UserModel user;
  const SubmitRequestScreen({super.key, required this.user});

  @override
  State<SubmitRequestScreen> createState() => _SubmitRequestScreenState();
}

class _SubmitRequestScreenState extends State<SubmitRequestScreen> {
  int _step = 0; // 0 = Give, 1 = Take, 2 = Submitting
  String? _giveDay;
  final Set<String> _takeDays = {};
  bool _isLoading = false;

  static const List<String> _weekDays = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  List<String> get _weekDates {
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    return List.generate(7, (i) {
      final d = sunday.add(Duration(days: i));
      return '${_monthName(d.month)} ${d.day}';
    });
  }

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final matches = await ApiService.submitRequest(
        userId: widget.user.id,
        userName: widget.user.name,
        userRole: widget.user.role,
        giveDay: _giveDay!,
        takeDays: _takeDays.toList(),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MatchesScreen(
            user: widget.user,
            giveDay: _giveDay!,
            takeDays: _takeDays.toList(),
            matches: matches,
          ),
        ),
      );
    } catch (e) {
      // For MVP demo without backend, show mock matches
      if (!mounted) return;
      final mockMatches = _getMockMatches();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MatchesScreen(
            user: widget.user,
            giveDay: _giveDay!,
            takeDays: _takeDays.toList(),
            matches: mockMatches,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SwapRequest> _getMockMatches() {
    // Returns mock matches for demo. In production, backend provides these.
    if (_giveDay == 'Tuesday' || _takeDays.contains('Thursday')) {
      return [
        SwapRequest(
          id: 'mock-1',
          userId: 'u2',
          userName: 'Sarah K.',
          userRole: widget.user.role,
          giveDay: _takeDays.first,
          takeDays: [_giveDay!],
          matches: [],
        ),
      ];
    }
    return [];
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dates = _weekDates;
    return Scaffold(
      body: Column(
        children: [
          // App bar
          Container(
            color: const Color(0xFF1A2332),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_step > 0) {
                      setState(() => _step--);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios, color: Color(0xFF8BA5C4), size: 14),
                      Text('Back', style: TextStyle(color: Color(0xFF8BA5C4), fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _step == 0 ? 'Give away a shift' : 'Days you can take',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _step == 0
                      ? 'Select the shift you want to give away'
                      : 'Select the days you are willing to accept',
                  style: const TextStyle(color: Color(0xFF8BA5C4), fontSize: 12),
                ),
                const SizedBox(height: 14),
                // Step indicator
                Row(
                  children: List.generate(3, (i) => Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? Colors.white
                            : Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
                ),
              ],
            ),
          ),

          // Day list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 7,
              itemBuilder: (_, i) {
                final day = _weekDays[i];
                final date = dates[i];
                final isGiveStep = _step == 0;

                if (!isGiveStep && day == _giveDay) return const SizedBox.shrink();

                final isSelected = isGiveStep
                    ? _giveDay == day
                    : _takeDays.contains(day);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isGiveStep) {
                        _giveDay = day;
                      } else {
                        if (_takeDays.contains(day)) {
                          _takeDays.remove(day);
                        } else {
                          _takeDays.add(day);
                        }
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEEF2F6) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1A2332)
                            : const Color(0xFFEEEEEE),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                                  color: const Color(0xFF1A2332),
                                ),
                              ),
                              Text(date,
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF888780))),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFF1A2332) : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF1A2332)
                                  : const Color(0xFFCCCCCC),
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 13, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom action
          Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 20, top: 8,
            ),
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      if (_step == 0) {
                        if (_giveDay == null) {
                          _showSnack('Please select a day to give away.');
                          return;
                        }
                        setState(() => _step = 1);
                      } else {
                        if (_takeDays.isEmpty) {
                          _showSnack('Please select at least one day you can take.');
                          return;
                        }
                        _submit();
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(_step == 0 ? 'Next: choose take days →' : 'Submit & find matches →'),
            ),
          ),
        ],
      ),
    );
  }
}
