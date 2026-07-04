import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sos_history_item.dart';
import '../services/sos_api_service.dart';

class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key});

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  final SosApiService _sosApiService = SosApiService();

  List<SosHistoryItem> _historyItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  static const Color _dangerRed = Color(0xFFE53935);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _darkText = Color(0xFF111827);
  static const Color _mutedText = Color(0xFF6B7280);
  static const Color _softBg = Color(0xFFF8FAFC);
  static const Color _borderColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    loadSosHistory();
  }

  String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  String formatCoordinate(dynamic value) {
    if (value == null) {
      return 'Not available';
    }

    if (value is num) {
      return value.toStringAsFixed(6);
    }

    return value.toString();
  }

  String formatStatus(String status) {
    if (status.trim().isEmpty) {
      return 'Unknown';
    }

    final cleanStatus = status.trim().toLowerCase();

    if (cleanStatus == 'offline_sms') {
      return 'Offline SMS';
    }

    return cleanStatus[0].toUpperCase() + cleanStatus.substring(1);
  }

  Future<void> loadSosHistory() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final history = await _sosApiService.getSosHistory();

      if (!mounted) {
        return;
      }

      setState(() {
        _historyItems = history;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load SOS history';
      });
    }
  }

  Color getStatusColor(String status) {
    final cleanStatus = status.toLowerCase();

    if (cleanStatus == 'active') {
      return Colors.green;
    }

    if (cleanStatus == 'cancelled') {
      return _dangerRed;
    }

    if (cleanStatus == 'offline_sms') {
      return Colors.orange;
    }

    return Colors.grey;
  }

  IconData getStatusIcon(String status) {
    final cleanStatus = status.toLowerCase();

    if (cleanStatus == 'active') {
      return Icons.radio_button_checked_rounded;
    }

    if (cleanStatus == 'cancelled') {
      return Icons.cancel_rounded;
    }

    if (cleanStatus == 'offline_sms') {
      return Icons.sms_outlined;
    }

    return Icons.info_outline_rounded;
  }

  Widget buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_historyItems.isEmpty) {
      return _buildEmptyState();
    }

    return _buildHistoryList();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: _dangerRed,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _dangerRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: _dangerRed,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mutedText,
                    fontSize: 14.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: loadSosHistory,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _dangerRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.09),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: _dangerRed,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No SOS history yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _darkText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your emergency alert history will appear here after you start an SOS session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 14.5,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: loadSosHistory,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return RefreshIndicator(
      color: _dangerRed,
      onRefresh: loadSosHistory,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCard(),
                  const SizedBox(height: 18),
                  const Text(
                    'Recent SOS Alerts',
                    style: TextStyle(
                      color: _darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(_historyItems.length, (index) {
                    final item = _historyItems[index];
                    final displayNumber = _historyItems.length - index;

                    return _buildHistoryCard(
                      item: item,
                      displayNumber: displayNumber,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final int activeCount = _historyItems
        .where((item) => item.status.toLowerCase() == 'active')
        .length;

    final int cancelledCount = _historyItems
        .where((item) => item.status.toLowerCase() == 'cancelled')
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _dangerRed,
            _dangerDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _dangerRed.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_historyItems.length} SOS Alert${_historyItems.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Active: $activeCount  •  Cancelled: $cancelledCount',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard({
    required SosHistoryItem item,
    required int displayNumber,
  }) {
    final Color statusColor = getStatusColor(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _dangerRed.withOpacity(0.1),
                child: Text(
                  '$displayNumber',
                  style: const TextStyle(
                    color: _dangerRed,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SOS Alert (ID #${item.id})',
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildStatusChip(item.status),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.wifi_tethering_rounded,
            label: 'Network',
            value: item.networkMode,
          ),
          _buildInfoRow(
            icon: Icons.my_location_rounded,
            label: 'Latitude',
            value: formatCoordinate(item.initialLatitude),
          ),
          _buildInfoRow(
            icon: Icons.location_on_outlined,
            label: 'Longitude',
            value: formatCoordinate(item.initialLongitude),
          ),
          _buildInfoRow(
            icon: Icons.access_time_rounded,
            label: 'Created At',
            value: formatDateTime(item.createdAt),
          ),
          if (item.cancelledAt != null)
            _buildInfoRow(
              icon: Icons.cancel_outlined,
              label: 'Cancelled At',
              value: formatDateTime(item.cancelledAt!),
              valueColor: statusColor,
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final Color statusColor = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: statusColor.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            getStatusIcon(status),
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 5),
          Text(
            formatStatus(status),
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: _mutedText,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _darkText,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBg,
      appBar: AppBar(
        title: const Text('SOS History'),
        backgroundColor: _softBg,
        foregroundColor: _darkText,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.of(context).maybePop();
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : loadSosHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: buildBody(),
      ),
    );
  }
}