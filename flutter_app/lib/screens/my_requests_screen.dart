// lib/screens/my_requests_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/swap_request_model.dart';
import '../services/api_service.dart';

class MyRequestsScreen extends StatefulWidget {
  final UserModel user;
  const MyRequestsScreen({super.key, required this.user});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  late Future<List<SwapRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _requestsFuture = ApiService.getMyRequests(widget.user.id).catchError((_) {
      // Return mock data if backend unavailable
      return <SwapRequest>[
        SwapRequest(
          id: 'mock-req-1',
          userId: widget.user.id,
          userName: widget.user.name,
          userRole: widget.user.role,
          giveDay: 'Tuesday',
          takeDays: ['Thursday', 'Friday'],
          status: 'matched',
          matches: [
            MatchResult(
              requestId: 'mock-2',
              userName: 'Sarah K.',
              giveDay: 'Thursday',
              takeDays: ['Tuesday'],
            ),
          ],
        ),
        SwapRequest(
          id: 'mock-req-2',
          userId: widget.user.id,
          userName: widget.user.name,
          userRole: widget.user.role,
          giveDay: 'Saturday',
          takeDays: ['Wednesday'],
          status: 'pending',
          matches: [],
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => Navigator.pop(context),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.arrow_back_ios, color: Color(0xFF8BA5C4), size: 14),
                    Text('Home', style: TextStyle(color: Color(0xFF8BA5C4), fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 10),
                const Text('My requests',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('Track your active swap requests',
                    style: TextStyle(color: Color(0xFF8BA5C4), fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SwapRequest>>(
              future: _requestsFuture,
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final requests = snapshot.data ?? [];
                if (requests.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('📭', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 16),
                        Text('No active requests',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        SizedBox(height: 8),
                        Text('Submit a swap request from the home screen.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF888780), fontSize: 14)),
                      ]),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (_, i) => _RequestCard(
                    request: requests[i],
                    onMarkDone: (theirId) async {
                      try {
                        await ApiService.markDone(
                          myRequestId: requests[i].id,
                          theirRequestId: theirId,
                        );
                      } catch (_) {}
                      setState(_load);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final SwapRequest request;
  final Function(String theirRequestId) onMarkDone;

  const _RequestCard({required this.request, required this.onMarkDone});

  String _initials(String name) => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase())
      .take(2)
      .join();

  @override
  Widget build(BuildContext context) {
    final hasMatch = request.matches.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Give ${request.giveDay}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Take: ${request.takeDays.join(', ')}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF888780))),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasMatch ? const Color(0xFFEAF3DE) : const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasMatch ? 'Match!' : 'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hasMatch ? const Color(0xFF3B6D11) : const Color(0xFF854F0B),
                    ),
                  ),
                ),
              ],
            ),
            if (hasMatch) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFEEEEEE)),
              ),
              const Text(
                'POTENTIAL MATCHES',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: Color(0xFF888780), letterSpacing: 0.5),
              ),
              const SizedBox(height: 10),
              ...request.matches.map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF1A2332),
                          radius: 16,
                          child: Text(_initials(m.userName),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.userName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            Text('Gives ${m.giveDay} · takes ${request.giveDay}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                          ]),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => onMarkDone(m.requestId),
                          child: const Text('Done', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
