// lib/screens/request_board_screen.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/swap_request_model.dart';
import '../services/api_service.dart';
import 'submit_request_screen.dart';

class RequestBoardScreen extends StatefulWidget {
  final UserModel user;
  const RequestBoardScreen({super.key, required this.user});

  @override
  State<RequestBoardScreen> createState() => _RequestBoardScreenState();
}

class _RequestBoardScreenState extends State<RequestBoardScreen> {
  List<SwapRequest> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when returning to this screen
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await ApiService.getAllRequests(widget.user.role);
      if (mounted) {
        setState(() {
          _requests = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _requests = [];
          _isLoading = false;
        });
      }
    }
  }

  void _submitMatchingRequest(SwapRequest request) {
    // Navigate to submit screen with pre-filled matching data
    // For matching: give what they take, take what they give
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubmitRequestScreen(
          user: widget.user,
          initialGiveDate: request.takeDates.first, // Give one of what they take
          initialTakeDates: [request.giveDate], // Take what they give
        ),
      ),
    );
  }

  Widget _buildActionButton(SwapRequest request) {
    final isPending = request.status == 'pending';
    final isOwnRequest = request.userId == widget.user.id;

    if (isPending && !isOwnRequest) {
      return ElevatedButton(
        onPressed: () => _submitMatchingRequest(request),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A2332),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Submit Matching Request'),
      );
    } else {
      return Center(
        child: Text(
          isOwnRequest ? 'Your request' : 'Already matched',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF888780),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFA726); // Orange
      case 'matched':
        return const Color(0xFF4CAF50); // Green
      case 'completed':
        return const Color(0xFF2196F3); // Blue
      default:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  String _formatDate(DateTime d) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return '${days[d.weekday % 7]} ${months[d.month - 1]} ${d.day}';
  }

  String _getWeekLabel(DateTime date) {
    final now = DateTime.now();
    final thisSunday = now.subtract(Duration(days: (now.weekday) % 7));
    final nextSunday = thisSunday.add(const Duration(days: 7));
    
    if (date.isBefore(nextSunday) && date.isAfter(thisSunday.subtract(const Duration(days: 1)))) {
      return 'This Week';
    } else if (date.isBefore(nextSunday.add(const Duration(days: 7))) && date.isAfter(nextSunday.subtract(const Duration(days: 1)))) {
      return 'Next Week';
    } else {
      return 'Future';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_ios, color: Color(0xFF8BA5C4), size: 14),
                      Text('Back', style: TextStyle(color: Color(0xFF8BA5C4), fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Request Board (Debug)',
                  style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All requests from ${widget.user.role}s',
                  style: const TextStyle(color: Color(0xFF8BA5C4), fontSize: 12),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadRequests,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _requests.isEmpty
                      ? const Center(
                          child: Text(
                            'No pending requests',
                            style: TextStyle(color: Color(0xFF888780)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _requests.length,
                          itemBuilder: (_, i) => _buildRequestCard(_requests[i]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(SwapRequest request) {
    final weekLabel = _getWeekLabel(request.giveDate);
    final isPending = request.status == 'pending';
    final isOwnRequest = request.userId == widget.user.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                request.userName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A2332),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request.userRole,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1A2332),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                weekLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888780),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Gives: ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A2332),
                ),
              ),
              Text(
                _formatDate(request.giveDate),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A2332),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Takes: ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A2332),
                ),
              ),
              Expanded(
                child: Text(
                  request.takeDates.map(_formatDate).join(', '),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A2332),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionButton(request),
        ],
      ),
    );
  }
}