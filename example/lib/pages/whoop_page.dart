// import 'package:flutter/material.dart';
// import 'package:synheart_wear/synheart_wear.dart';
// import '../controller/whoop_controller.dart';
// import '../models/recovery_record.dart';
// import '../models/sleep_record.dart';
// import '../models/workout_record.dart';

// class WhoopPage extends StatefulWidget {
//   const WhoopPage({
//     super.key,
//     required this.controller,
//     this.onMenuPressed,
//   });

//   final WhoopController controller;
//   final VoidCallback? onMenuPressed;

//   @override
//   State<WhoopPage> createState() => _WhoopPageState();
// }

// class _WhoopPageState extends State<WhoopPage>
//     with SingleTickerProviderStateMixin {
//   DateTime? _startDate;
//   DateTime? _endDate;
//   late TabController _tabController;

//   @override
//   void initState() {
//     super.initState();
//     // Set default date range (last 30 days)
//     _endDate = DateTime.now();
//     _startDate = DateTime.now().subtract(const Duration(days: 30));
//     // Initialize tab controller
//     _tabController = TabController(length: 2, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _selectStartDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate:
//           _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
//       firstDate: DateTime(2020),
//       lastDate: _endDate ?? DateTime.now(),
//     );
//     if (picked != null && picked != _startDate) {
//       setState(() {
//         _startDate = picked;
//         // Ensure start date is not after end date
//         if (_endDate != null && _startDate!.isAfter(_endDate!)) {
//           _endDate = _startDate;
//         }
//       });
//     }
//   }

//   Future<void> _selectEndDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _endDate ?? DateTime.now(),
//       firstDate: _startDate ?? DateTime(2020),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null && picked != _endDate) {
//       setState(() {
//         _endDate = picked;
//         // Ensure end date is not before start date
//         if (_startDate != null && _endDate!.isBefore(_startDate!)) {
//           _startDate = _endDate;
//         }
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: IconButton(
//           icon: const Icon(Icons.menu),
//           onPressed: widget.onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
//         ),
//         title: const Text('WHOOP Data'),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(icon: Icon(Icons.history), text: 'Historical'),
//             Tab(icon: Icon(Icons.live_tv), text: 'Real-time'),
//           ],
//         ),
//       ),
//       body: ListenableBuilder(
//         listenable: widget.controller,
//         builder: (context, _) {
//           return TabBarView(
//             controller: _tabController,
//             children: [
//               // Historical Tab
//               _buildHistoricalTab(),
//               // Real-time Tab
//               _buildRealtimeTab(),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   Widget _buildHistoricalTab() {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Date Range Selection
//           Card(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Date Range',
//                     style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: OutlinedButton.icon(
//                           onPressed: () => _selectStartDate(context),
//                           icon: const Icon(Icons.calendar_today, size: 18),
//                           label: Text(
//                             _startDate != null
//                                 ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}'
//                                 : 'Start Date',
//                           ),
//                         ),
//                       ),
//                       const Padding(
//                         padding: EdgeInsets.symmetric(horizontal: 8),
//                         child: Text('to', style: TextStyle(fontSize: 14)),
//                       ),
//                       Expanded(
//                         child: OutlinedButton.icon(
//                           onPressed: () => _selectEndDate(context),
//                           icon: const Icon(Icons.calendar_today, size: 18),
//                           label: Text(
//                             _endDate != null
//                                 ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
//                                 : 'End Date',
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 20),

//           // Data fetching buttons
//           const Text(
//             'Fetch Data',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Wrap(
//             spacing: 12,
//             runSpacing: 12,
//             children: [
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchRecovery(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.health_and_safety),
//                 label: const Text('Recovery'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchSleep(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.bed),
//                 label: const Text('Sleep'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchWorkouts(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.fitness_center),
//                 label: const Text('Workouts'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchHeartRate(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.favorite),
//                 label: const Text('Heart Rate'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchStrain(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.trending_up),
//                 label: const Text('Strain'),
//               ),
//               const SizedBox(width: 8),
//               ElevatedButton.icon(
//                 onPressed: widget.controller.isConnected
//                     ? () => widget.controller.testFluxProcessing(context)
//                     : null,
//                 icon: const Icon(Icons.science),
//                 label: const Text('Test Flux'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.purple,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // Status
//           if (widget.controller.status.isNotEmpty)
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Status: ${widget.controller.status}',
//                       style: Theme.of(context).textTheme.bodyMedium,
//                     ),
//                     if (widget.controller.error.isNotEmpty) ...[
//                       const SizedBox(height: 8),
//                       Text(
//                         'Error: ${widget.controller.error}',
//                         style: const TextStyle(color: Colors.red),
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           const SizedBox(height: 16),

//           // Records list
//           const Text(
//             'Records:',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           widget.controller.records.isEmpty
//               ? const Padding(
//                   padding: EdgeInsets.symmetric(vertical: 32.0),
//                   child: Center(
//                     child: Text('No data yet – fetch data to see records'),
//                   ),
//                 )
//               : ListView.builder(
//                   shrinkWrap: true,
//                   physics: const NeverScrollableScrollPhysics(),
//                   itemCount: widget.controller.records.length,
//                   itemBuilder: (context, i) {
//                     final record = widget.controller.records[i];
//                     return Card(
//                       margin: const EdgeInsets.only(bottom: 8),
//                       child: _buildRecordTile(record, i),
//                     );
//                   },
//                 ),
//         ],
//       ),
//     );
//   }

//   Widget _buildRealtimeTab() {
//     final sseEvents = widget.controller.sseEvents;
//     final isSubscribed = widget.controller.isSSESubscribed;

//     return Column(
//       children: [
//         // Subscription status card
//         Card(
//           margin: const EdgeInsets.all(16.0),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               children: [
//                 Icon(
//                   isSubscribed ? Icons.check_circle : Icons.cancel,
//                   color: isSubscribed ? Colors.green : Colors.red,
//                   size: 32,
//                 ),
//                 const SizedBox(width: 16),
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         isSubscribed
//                             ? 'Subscribed to Real-time Events'
//                             : 'Not Subscribed',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         '${sseEvents.length} events received',
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 if (!isSubscribed)
//                   ElevatedButton.icon(
//                     onPressed: widget.controller.isConnected
//                         ? () => widget.controller.subscribeToEvents()
//                         : null,
//                     icon: const Icon(Icons.play_arrow),
//                     label: const Text('Subscribe'),
//                   )
//                 else
//                   ElevatedButton.icon(
//                     onPressed: () => widget.controller.unsubscribeFromEvents(),
//                     icon: const Icon(Icons.stop),
//                     label: const Text('Unsubscribe'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                       foregroundColor: Colors.white,
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),

//         // Events list
//         Expanded(
//           child: sseEvents.isEmpty
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.event_note,
//                         size: 64,
//                         color: Colors.grey[400],
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         isSubscribed
//                             ? 'Waiting for real-time events...'
//                             : 'Subscribe to receive real-time events',
//                         style: TextStyle(
//                           fontSize: 16,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//                       if (!isSubscribed) ...[
//                         const SizedBox(height: 8),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 32.0),
//                           child: Text(
//                             'Events will appear here when WHOOP sends webhook notifications',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey[500],
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 )
//               : ListView.builder(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   itemCount: sseEvents.length,
//                   itemBuilder: (context, index) {
//                     final event = sseEvents[index];
//                     return Card(
//                       margin: const EdgeInsets.only(bottom: 12),
//                       child: InkWell(
//                         onTap: () => _showEventDetails(context, event),
//                         child: Padding(
//                           padding: const EdgeInsets.all(16.0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Row(
//                                 children: [
//                                   _getEventIcon(event.event ?? 'unknown'),
//                                   const SizedBox(width: 12),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment:
//                                           CrossAxisAlignment.start,
//                                       children: [
//                                         Text(
//                                           event.event ?? 'Unknown Event',
//                                           style: const TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.bold,
//                                           ),
//                                         ),
//                                         if (event.data?['type'] != null)
//                                           Text(
//                                             event.data!['type'],
//                                             style: TextStyle(
//                                               fontSize: 12,
//                                               color: Colors.grey[600],
//                                             ),
//                                           ),
//                                       ],
//                                     ),
//                                   ),
//                                   Text(
//                                     _formatEventTime(event.timestamp),
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey[500],
//                                       fontFamily: 'monospace',
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               if (event.data?['vendor'] != null) ...[
//                                 const SizedBox(height: 8),
//                                 Chip(
//                                   label: Text(
//                                     'Vendor: ${event.data!['vendor']}',
//                                     style: const TextStyle(fontSize: 12),
//                                   ),
//                                   avatar: const Icon(Icons.cloud, size: 16),
//                                 ),
//                               ],
//                               if (event.data?['user_id'] != null) ...[
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   'User: ${event.data!['user_id']}',
//                                   style: TextStyle(
//                                     fontSize: 12,
//                                     color: Colors.grey[600],
//                                   ),
//                                 ),
//                               ],
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//         ),

//         // Clear events button
//         if (sseEvents.isNotEmpty)
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: OutlinedButton.icon(
//               onPressed: () => widget.controller.clearSSEEvents(),
//               icon: const Icon(Icons.clear_all),
//               label: const Text('Clear Events'),
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _getEventIcon(String eventType) {
//     switch (eventType.toLowerCase()) {
//       case 'sleep':
//         return const Icon(Icons.bed, color: Colors.blue, size: 24);
//       case 'workout':
//         return const Icon(Icons.fitness_center, color: Colors.orange, size: 24);
//       case 'recovery':
//         return const Icon(Icons.health_and_safety,
//             color: Colors.green, size: 24);
//       case 'connected':
//         return const Icon(Icons.link, color: Colors.green, size: 24);
//       case 'heartbeat':
//         return const Icon(Icons.favorite, color: Colors.red, size: 24);
//       default:
//         return const Icon(Icons.event, color: Colors.grey, size: 24);
//     }
//   }

//   String _formatEventTime(DateTime timestamp) {
//     final now = DateTime.now();
//     final difference = now.difference(timestamp);

//     if (difference.inSeconds < 60) {
//       return '${difference.inSeconds}s ago';
//     } else if (difference.inMinutes < 60) {
//       return '${difference.inMinutes}m ago';
//     } else if (difference.inHours < 24) {
//       return '${difference.inHours}h ago';
//     } else {
//       return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
//     }
//   }

//   void _showEventDetails(BuildContext context, WearServiceEvent event) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(event.event ?? 'Event Details'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (event.id != null) ...[
//                 const Text('ID:',
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 Text(event.id!,
//                     style: const TextStyle(fontFamily: 'monospace')),
//                 const SizedBox(height: 12),
//               ],
//               const Text('Timestamp:',
//                   style: TextStyle(fontWeight: FontWeight.bold)),
//               Text(_formatTimestamp(event.timestamp)),
//               const SizedBox(height: 12),
//               if (event.data != null) ...[
//                 const Text('Data:',
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 8),
//                 Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Text(
//                     _formatEventData(event.data!),
//                     style: const TextStyle(
//                       fontFamily: 'monospace',
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatEventData(Map<String, dynamic> data) {
//     final buffer = StringBuffer();
//     data.forEach((key, value) {
//       buffer.writeln('$key: $value');
//     });
//     return buffer.toString();
//   }

//   Widget _buildRecordTile(dynamic record, int index) {
//     // Build tile based on data type - now using WearMetrics
//     if (record is WearMetrics) {
//       final metricItems = <Widget>[];

//       // Add timestamp
//       metricItems.add(
//         Text(
//           _formatTimestamp(record.timestamp),
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 13,
//             color: Colors.blue,
//           ),
//         ),
//       );
//       metricItems.add(const SizedBox(height: 6));

//       // Display Score data prominently if available
//       final scoreData = _extractScoreData(record.meta);
//       if (scoreData.isNotEmpty) {
//         metricItems.add(
//           Container(
//             padding: const EdgeInsets.all(8.0),
//             decoration: BoxDecoration(
//               color: Colors.blue.shade50,
//               borderRadius: BorderRadius.circular(8.0),
//               border: Border.all(color: Colors.blue.shade200),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Icon(Icons.star, size: 16, color: Colors.blue[700]),
//                     const SizedBox(width: 6),
//                     Text(
//                       'Scores:',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 12,
//                         color: Colors.blue[700],
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 6),
//                 ...scoreData.map((scoreEntry) {
//                   return Padding(
//                     padding: const EdgeInsets.only(top: 4.0),
//                     child: Row(
//                       children: [
//                         const SizedBox(width: 22),
//                         Expanded(
//                           child: Text(
//                             '${scoreEntry['label']}: ',
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey[700],
//                             ),
//                           ),
//                         ),
//                         Text(
//                           scoreEntry['value'] ?? '',
//                           style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.blue[900],
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 }),
//               ],
//             ),
//           ),
//         );
//         metricItems.add(const SizedBox(height: 8));
//       }

//       // Display ALL metrics from the map
//       if (record.metrics.isNotEmpty) {
//         metricItems.add(
//           Padding(
//             padding: const EdgeInsets.only(bottom: 4.0),
//             child: Text(
//               'Metrics:',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 12,
//                 color: Colors.grey[700],
//               ),
//             ),
//           ),
//         );
//         record.metrics.forEach((key, value) {
//           if (value != null) {
//             final label = _formatMetricLabel(key);
//             final formattedValue = _formatMetricValue(key, value);
//             final icon = _getMetricIcon(key);
//             metricItems.add(_buildMetricRow(label, formattedValue, icon));
//           }
//         });
//       } else {
//         // metricItems.add(
//         //   Text(
//         //     'No metrics available',
//         //     style: TextStyle(color: Colors.grey[600], fontSize: 12),
//         //   ),
//         // );
//       }

//       // Display ALL meta fields (excluding score data which is shown above)
//       final otherMeta = <String, Object?>{};
//       record.meta.forEach((key, value) {
//         // Skip score-related fields as they're shown in the score section
//         if (!key.toLowerCase().contains('score') && value != null) {
//           otherMeta[key] = value;
//         }
//       });

//       if (otherMeta.isNotEmpty) {
//         metricItems.add(const SizedBox(height: 8));
//         metricItems.add(
//           const Divider(),
//         );
//         metricItems.add(
//           Padding(
//             padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
//             child: Text(
//               'Additional Info:',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 12,
//                 color: Colors.grey[700],
//               ),
//             ),
//           ),
//         );
//         otherMeta.forEach((key, value) {
//           if (value != null) {
//             metricItems.add(
//               Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 2.0),
//                 child: Row(
//                   children: [
//                     Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${_formatMetaLabel(key)}: ',
//                       style: TextStyle(
//                         fontSize: 11,
//                         color: Colors.grey[700],
//                       ),
//                     ),
//                     Expanded(
//                       child: Text(
//                         _formatMetaValue(value),
//                         style: TextStyle(
//                           fontSize: 11,
//                           fontWeight: FontWeight.w500,
//                           color: Colors.black87,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           }
//         });
//       }

//       return Card(
//         elevation: 2,
//         margin: const EdgeInsets.symmetric(vertical: 4.0),
//         child: Padding(
//           padding: const EdgeInsets.all(12.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Record #${index + 1}',
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 14,
//                 ),
//               ),
//               const SizedBox(height: 8),
//               ...metricItems,
//             ],
//           ),
//         ),
//       );
//     } else if (record is RecoveryRecord) {
//       return ListTile(
//         title: Text('Recovery #${index + 1}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (record.score != null) ...[
//               if (record.score!.recoveryScore != null)
//                 Text('Recovery Score: ${record.score!.recoveryScore}'),
//               if (record.score!.restingHeartRate != null)
//                 Text('Resting HR: ${record.score!.restingHeartRate} bpm'),
//               if (record.score!.hrvRmssdMilli != null)
//                 Text(
//                     'HRV RMSSD: ${record.score!.hrvRmssdMilli!.toStringAsFixed(1)} ms'),
//               if (record.score!.skinTempCelsius != null)
//                 Text(
//                     'Skin Temp: ${record.score!.skinTempCelsius!.toStringAsFixed(1)}°C'),
//               if (record.score!.spo2Percentage != null)
//                 Text(
//                     'SpO2: ${record.score!.spo2Percentage!.toStringAsFixed(1)}%'),
//             ],
//             if (record.scoreState != null) Text('State: ${record.scoreState}'),
//             if (record.createdAt != null)
//               Text('Date: ${_formatDate(record.createdAt!)}'),
//           ],
//         ),
//         isThreeLine: true,
//       );
//     } else if (record is SleepRecord) {
//       return ListTile(
//         title: Text('Sleep #${index + 1}${record.nap == true ? " (Nap)" : ""}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (record.score != null) ...[
//               if (record.score!.sleepPerformancePercentage != null)
//                 Text(
//                     'Performance: ${record.score!.sleepPerformancePercentage!.toStringAsFixed(1)}%'),
//               if (record.score!.sleepEfficiencyPercentage != null)
//                 Text(
//                     'Efficiency: ${record.score!.sleepEfficiencyPercentage!.toStringAsFixed(1)}%'),
//               if (record.score!.respiratoryRate != null)
//                 Text(
//                     'Respiratory Rate: ${record.score!.respiratoryRate!.toStringAsFixed(1)}'),
//               if (record.score!.stageSummary != null) ...[
//                 if (record.score!.stageSummary!.totalRemSleepTimeMilli != null)
//                   Text(
//                       'REM: ${_formatDuration(record.score!.stageSummary!.totalRemSleepTimeMilli! ~/ 1000)}'),
//                 if (record.score!.stageSummary!.totalLightSleepTimeMilli !=
//                     null)
//                   Text(
//                       'Light: ${_formatDuration(record.score!.stageSummary!.totalLightSleepTimeMilli! ~/ 1000)}'),
//                 if (record.score!.stageSummary!.totalSlowWaveSleepTimeMilli !=
//                     null)
//                   Text(
//                       'Deep: ${_formatDuration(record.score!.stageSummary!.totalSlowWaveSleepTimeMilli! ~/ 1000)}'),
//               ],
//             ],
//             if (record.scoreState != null) Text('State: ${record.scoreState}'),
//             if (record.start != null && record.end != null)
//               Text(
//                   'Duration: ${_formatDuration(record.end!.difference(record.start!).inSeconds)}'),
//             if (record.createdAt != null)
//               Text('Date: ${_formatDate(record.createdAt!)}'),
//           ],
//         ),
//         isThreeLine: true,
//       );
//     } else if (record is WorkoutRecord) {
//       return ListTile(
//         title: Text('Workout #${index + 1}'),
//         subtitle: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (record.sportName != null) Text('Sport: ${record.sportName}'),
//             if (record.score != null) ...[
//               if (record.score!.strain != null)
//                 Text('Strain: ${record.score!.strain!.toStringAsFixed(1)}'),
//               if (record.score!.averageHeartRate != null)
//                 Text('Avg HR: ${record.score!.averageHeartRate} bpm'),
//               if (record.score!.maxHeartRate != null)
//                 Text('Max HR: ${record.score!.maxHeartRate} bpm'),
//               if (record.score!.kilojoule != null)
//                 Text(
//                     'Energy: ${record.score!.kilojoule!.toStringAsFixed(1)} kJ'),
//               if (record.score!.distanceMeter != null)
//                 Text(
//                     'Distance: ${(record.score!.distanceMeter! / 1000).toStringAsFixed(2)} km'),
//             ],
//             if (record.scoreState != null) Text('State: ${record.scoreState}'),
//             if (record.start != null && record.end != null)
//               Text(
//                   'Duration: ${_formatDuration(record.end!.difference(record.start!).inSeconds)}'),
//             if (record.createdAt != null)
//               Text('Date: ${_formatDate(record.createdAt!)}'),
//           ],
//         ),
//         isThreeLine: true,
//       );
//     } else {
//       // Fallback for unknown types - show as JSON
//       return ListTile(
//         title: Text('Record #${index + 1}'),
//         subtitle: Text(
//           record.toString(),
//           style: const TextStyle(
//             fontFamily: 'monospace',
//             fontSize: 10,
//           ),
//           maxLines: 5,
//           overflow: TextOverflow.ellipsis,
//         ),
//         isThreeLine: true,
//       );
//     }
//   }

//   Widget _buildMetricRow(String label, String value, IconData icon,
//       [Color? color]) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2.0),
//       child: Row(
//         children: [
//           Icon(icon, size: 16, color: color ?? Colors.grey[700]),
//           const SizedBox(width: 8),
//           Text(
//             '$label: ',
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey[700],
//             ),
//           ),
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//               color: color ?? Colors.black87,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatTimestamp(DateTime timestamp) {
//     return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
//   }

//   String _formatMetricLabel(String key) {
//     // Convert snake_case to Title Case
//     return key
//         .split('_')
//         .map((word) => word[0].toUpperCase() + word.substring(1))
//         .join(' ');
//   }

//   String _formatMetricValue(String key, num? value) {
//     if (value == null) return 'N/A';

//     // Format based on metric type
//     switch (key) {
//       case 'hr':
//         return '${value.toStringAsFixed(0)} bpm';
//       case 'hrv_rmssd':
//       case 'hrv_sdnn':
//         return '${value.toStringAsFixed(1)} ms';
//       case 'steps':
//         return value.toStringAsFixed(0);
//       case 'calories':
//         return '${value.toStringAsFixed(0)} kcal';
//       case 'distance':
//         return '${value.toStringAsFixed(2)} km';
//       case 'stress':
//         return value.toStringAsFixed(1);
//       default:
//         return value.toString();
//     }
//   }

//   IconData _getMetricIcon(String key) {
//     switch (key) {
//       case 'hr':
//         return Icons.favorite;
//       case 'hrv_rmssd':
//       case 'hrv_sdnn':
//         return Icons.heart_broken;
//       case 'steps':
//         return Icons.directions_walk;
//       case 'calories':
//         return Icons.local_fire_department;
//       case 'distance':
//         return Icons.straighten;
//       case 'stress':
//         return Icons.mood;
//       default:
//         return Icons.info;
//     }
//   }

//   String _formatMetaLabel(String key) {
//     return key
//         .split('_')
//         .map((word) => word[0].toUpperCase() + word.substring(1))
//         .join(' ');
//   }

//   List<Map<String, String>> _extractScoreData(Map<String, Object?> meta) {
//     final scores = <Map<String, String>>[];

//     meta.forEach((key, value) {
//       if (key.toLowerCase().contains('score') && value != null) {
//         String label = _formatMetaLabel(key);
//         String formattedValue;

//         if (value is Map) {
//           // If score is a nested object, display its properties
//           final scoreEntries = <String>[];
//           value.forEach((nestedKey, nestedValue) {
//             if (nestedValue != null) {
//               scoreEntries.add(
//                   '${_formatMetaLabel(nestedKey.toString())}: ${_formatMetaValue(nestedValue)}');
//             }
//           });
//           formattedValue = scoreEntries.join(', ');
//         } else {
//           formattedValue = _formatScoreValue(value);
//         }

//         scores.add({
//           'label': label,
//           'value': formattedValue,
//         });
//       }
//     });

//     return scores;
//   }

//   String _formatScoreValue(dynamic value) {
//     if (value is num) {
//       // Scores are typically 0-100 or 0-1
//       if (value >= 0 && value <= 1 && value.toString().contains('.')) {
//         return '${(value * 100).toStringAsFixed(1)}%';
//       } else if (value >= 0 && value <= 100) {
//         return value.toStringAsFixed(1);
//       }
//       return value.toStringAsFixed(1);
//     } else if (value is String) {
//       return value;
//     } else {
//       return value.toString();
//     }
//   }

//   String _formatMetaValue(dynamic value) {
//     if (value is bool) {
//       return value ? 'Yes' : 'No';
//     } else if (value is num) {
//       // If it's a percentage (0-1), format as percentage
//       if (value >= 0 && value <= 1 && value.toString().contains('.')) {
//         return '${(value * 100).toStringAsFixed(0)}%';
//       }
//       return value.toString();
//     } else if (value is String) {
//       return value;
//     } else if (value is Map) {
//       // Handle nested objects
//       final entries = <String>[];
//       value.forEach((k, v) {
//         if (v != null) {
//           entries
//               .add('${_formatMetaLabel(k.toString())}: ${_formatMetaValue(v)}');
//         }
//       });
//       return entries.join(', ');
//     } else {
//       return value.toString();
//     }
//   }

//   String _formatDate(DateTime date) {
//     return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
//   }

//   String _formatDuration(int seconds) {
//     final hours = seconds ~/ 3600;
//     final minutes = (seconds % 3600) ~/ 60;
//     if (hours > 0) {
//       return '${hours}h ${minutes}m';
//     }
//     return '${minutes}m';
//   }
// }
