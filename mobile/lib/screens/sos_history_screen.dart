import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static const Color _bgColor = Color(0xFF0B1120);
  static const Color _cardColor = Color(0xFF111827);
  static const Color _fieldColor = Color(0xFF0F172A);
  static const Color _borderColor = Color(0xFF243041);
  static const Color _dangerRed = Color(0xFFEF4444);
  static const Color _dangerDark = Color(0xFFB91C1C);
  static const Color _successGreen = Color(0xFF22C55E);
  static const Color _mapBlue = Color(0xFF3B82F6);
  static const Color _warningAmber = Color(0xFFF59E0B);
  static const Color _primaryText = Color(0xFFF8FAFC);
  static const Color _mutedText = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    loadSosHistory();
  }

  String formatDateTime(DateTime dateTime) {
    final istDateTime = dateTime.toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );

    return '${DateFormat('dd MMM yyyy, hh:mm a').format(istDateTime)} IST';
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

  Future<void> openLastUpdatedLocation(String? url) async {
    if (url == null || url.trim().isEmpty) {
      return;
    }

    final uri = Uri.parse(url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
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
      return _successGreen;
    }

    if (cleanStatus == 'cancelled') {
      return _dangerRed;
    }

    if (cleanStatus == 'offline_sms') {
      return _warningAmber;
    }

    return _mutedText;
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
      child: SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(
          color: _dangerRed,
          strokeWidth: 3,
        ),
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
              color: _cardColor,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.26),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: _dangerRed.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _dangerRed.withOpacity(0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: _dangerRed,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _primaryText,
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
                    label: const Text(
                      'Try Again',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: _dangerRed.withOpacity(0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _dangerRed.withOpacity(0.28),
                    ),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: _dangerRed,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No SOS history yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _primaryText,
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
                    label: const Text(
                      'Refresh',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCBD5E1),
                      side: const BorderSide(
                        color: _borderColor,
                      ),
                      backgroundColor: _fieldColor,
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

  Widget _buildHistoryList() {
    return RefreshIndicator(
      color: _dangerRed,
      backgroundColor: _cardColor,
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
                      color: _primaryText,
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

    final int offlineSmsCount = _historyItems
        .where((item) => item.status.toLowerCase() == 'offline_sms')
        .length;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF111827),
            Color(0xFF172033),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _dangerRed.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _dangerRed.withOpacity(0.35),
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: _dangerRed,
                  size: 34,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${_historyItems.length} SOS Alert${_historyItems.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: _primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildSummaryChip(
                label: 'Active: $activeCount',
                color: _successGreen,
                icon: Icons.radio_button_checked_rounded,
              ),
              _buildSummaryChip(
                label: 'Cancelled: $cancelledCount',
                color: _dangerRed,
                icon: Icons.cancel_rounded,
              ),
              _buildSummaryChip(
                label: 'Offline SMS: $offlineSmsCount',
                color: _warningAmber,
                icon: Icons.sms_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
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
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          childrenPadding: const EdgeInsets.fromLTRB(17, 0, 17, 17),
          iconColor: _mutedText,
          collapsedIconColor: _mutedText,
          initiallyExpanded: false,
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: _dangerRed.withOpacity(0.14),
            child: Text(
              '$displayNumber',
              style: const TextStyle(
                color: _dangerRed,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          title: Text(
            'SOS Alert #${item.id}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _primaryText,
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildStatusChip(item.status),
                Text(
                  formatDateTime(item.createdAt),
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          children: [
            _buildInfoRow(
              icon: Icons.wifi_tethering_rounded,
              label: 'Network',
              value: item.networkMode,
              iconColor: _mapBlue,
            ),
            _buildInfoRow(
              icon: Icons.my_location_rounded,
              label: 'Start Lat',
              value: formatCoordinate(item.startingLatitude),
              iconColor: _successGreen,
            ),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Start Lng',
              value: formatCoordinate(item.startingLongitude),
              iconColor: _successGreen,
            ),
            _buildInfoRow(
              icon: Icons.update_rounded,
              label: 'Last Update',
              value: item.lastUpdatedAt == null
                  ? 'Not available'
                  : formatDateTime(item.lastUpdatedAt!),
              iconColor: _warningAmber,
            ),
            const SizedBox(height: 4),
            _buildMapButton(item.lastUpdatedGoogleMapsUrl),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.access_time_rounded,
              label: 'Created At',
              value: formatDateTime(item.createdAt),
              iconColor: _mapBlue,
            ),
            if (item.cancelledAt != null)
              _buildInfoRow(
                icon: Icons.cancel_outlined,
                label: 'Cancelled At',
                value: formatDateTime(item.cancelledAt!),
                valueColor: statusColor,
                iconColor: statusColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton(String? url) {
    final bool hasUrl = url != null && url.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: hasUrl
            ? () {
          openLastUpdatedLocation(url);
        }
            : null,
        icon: const Icon(Icons.map_rounded),
        label: const Text(
          'Open Last Updated Location',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: hasUrl ? _mapBlue : _mutedText,
          side: BorderSide(
            color: hasUrl ? _mapBlue.withOpacity(0.45) : _borderColor,
          ),
          backgroundColor: _fieldColor,
          disabledForegroundColor: _mutedText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final Color statusColor = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: statusColor.withOpacity(0.24),
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
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color: iconColor ?? _mutedText,
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
                color: valueColor ?? _primaryText,
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
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'SOS History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Container(
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _borderColor,
              ),
            ),
            child: IconButton(
              tooltip: 'Back',
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).maybePop();
              },
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _borderColor,
                ),
              ),
              child: IconButton(
                tooltip: 'Refresh',
                onPressed: _isLoading ? null : loadSosHistory,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF08101E),
              Color(0xFF0B1120),
              Color(0xFF111827),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: buildBody(),
        ),
      ),
    );
  }
}