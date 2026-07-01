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

  String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  @override
  void initState() {
    super.initState();
    loadSosHistory();
  }

  Future<void> loadSosHistory() async {
    try {
      final history = await _sosApiService.getSosHistory();

      setState(() {
        _historyItems = history;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load SOS history';
      });
    }
  }

  Color getStatusColor(String status) {
    if (status == 'active') {
      return Colors.green;
    }

    if (status == 'cancelled') {
      return Colors.red;
    }

    return Colors.grey;
  }

  Widget buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(_errorMessage!),
      );
    }

    if (_historyItems.isEmpty) {
      return const Center(
        child: Text('No SOS history found.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _historyItems.length,
      separatorBuilder: (context, index) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        final item = _historyItems[index];
        final displayNumber = _historyItems.length - index;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SOS $displayNumber',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Chip(
                      label: Text(item.status),
                      backgroundColor: getStatusColor(item.status).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: getStatusColor(item.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Network: ${item.networkMode}'),
                Text('Latitude: ${item.initialLatitude}'),
                Text('Longitude: ${item.initialLongitude}'),
                Text('Created At: ${formatDateTime(item.createdAt)}'),
                Text('SOS ID: #${item.id}'),
                if (item.cancelledAt != null)
                  Text('Cancelled At: ${formatDateTime(item.cancelledAt!)}'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS History'),
        centerTitle: true,
      ),
      body: buildBody(),
    );
  }
}