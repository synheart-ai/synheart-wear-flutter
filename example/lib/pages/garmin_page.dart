// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:synheart_wear/synheart_wear.dart';
// import '../controller/garmin_controller.dart';

// class GarminPage extends StatefulWidget {
//   const GarminPage({
//     super.key,
//     required this.controller,
//     this.onNavigateToSettings,
//     this.onMenuPressed,
//   });

//   final GarminController controller;
//   final VoidCallback? onNavigateToSettings;
//   final VoidCallback? onMenuPressed;

//   @override
//   State<GarminPage> createState() => _GarminPageState();
// }

// class _GarminPageState extends State<GarminPage> {
//   DateTime? _startDate;
//   DateTime? _endDate;

//   @override
//   void initState() {
//     super.initState();

//     // Set default date range (last 8 hours)
//     _endDate = DateTime.now();
//     _startDate = DateTime.now().subtract(const Duration(hours: 8));
//   }

//   Future<void> _selectStartDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate:
//           _startDate ?? DateTime.now().subtract(const Duration(hours: 8)),
//       firstDate: DateTime.now().subtract(const Duration(days: 90)),
//       lastDate: _endDate ?? DateTime.now(),
//     );
//     if (picked != null && picked != _startDate) {
//       setState(() {
//         _startDate = picked;
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
//         if (_startDate != null && _endDate!.isBefore(_startDate!)) {
//           _startDate = _endDate;
//         }
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return ListenableBuilder(
//       listenable: widget.controller,
//       builder: (context, _) {
//         return Scaffold(
//           appBar: AppBar(
//             leading: IconButton(
//               icon: const Icon(Icons.menu),
//               onPressed: widget.onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
//             ),
//             title: const Text('Garmin'),
//           ),
//           body: widget.controller.isConnected
//               ? _buildConnectedView(context)
//               : _buildNotConnectedView(context),
//         );
//       },
//     );
//   }

//   Widget _buildNotConnectedView(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           const SizedBox(height: 40),
//           const Icon(Icons.fitness_center, size: 80, color: Colors.orange),
//           const SizedBox(height: 24),
//           Text(
//             'Connect to Garmin',
//             style: Theme.of(context).textTheme.headlineMedium,
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 16),
//           Text(
//             'Connect your Garmin account to start syncing your health data.',
//             style: Theme.of(context).textTheme.bodyLarge,
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 32),

//           // Connect button
//           ElevatedButton.icon(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.orange,
//               padding: const EdgeInsets.symmetric(
//                 horizontal: 32,
//                 vertical: 16,
//               ),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             onPressed: !widget.controller.isConnected
//                 ? widget.controller.connect
//                 : null,
//             icon: const Icon(Icons.link, color: Colors.white, size: 28),
//             label: const Text(
//               'Connect to Garmin',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),

//           const SizedBox(height: 32),

//           // Status
//           if (widget.controller.status.isNotEmpty)
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Status: ${widget.controller.status}',
//                       style: Theme.of(context).textTheme.titleMedium,
//                     ),
//                     if (widget.controller.error.isNotEmpty) ...[
//                       const SizedBox(height: 8),
//                       Text(
//                         'Error: ${widget.controller.error}',
//                         style: const TextStyle(color: Colors.red),
//                       ),
//                       if (widget.controller.error.contains('Base URL') ||
//                           widget.controller.error
//                               .contains('Cannot connect')) ...[
//                         const SizedBox(height: 16),
//                         OutlinedButton.icon(
//                           onPressed: widget.onNavigateToSettings,
//                           icon: const Icon(Icons.settings),
//                           label: const Text(
//                               'Go to Settings to configure Base URL'),
//                         ),
//                       ],
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//           const SizedBox(height: 40),
//         ],
//       ),
//     );
//   }

//   Widget _buildConnectedView(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Connection status
//           Card(
//             color: Colors.green.shade50,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Row(
//                 children: [
//                   const Icon(Icons.check_circle, color: Colors.green),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Connected to Garmin',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 20),

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
//                     ? () => widget.controller.fetchDailies(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.calendar_view_day),
//                 label: const Text('Dailies'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchSleeps(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.bed),
//                 label: const Text('Sleep'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchHRV(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.favorite),
//                 label: const Text('HRV'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchEpochs(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.timeline),
//                 label: const Text('Epochs'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchStressDetails(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.mood),
//                 label: const Text('Stress'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: () => widget.controller.testFluxProcessing(context),
//                 icon: const Icon(Icons.science),
//                 label: const Text('Test Flux'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.purple,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchUserMetrics(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.trending_up),
//                 label: const Text('User Metrics'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchBodyComps(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.monitor_weight),
//                 label: const Text('Body Comp'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchPulseOx(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.air),
//                 label: const Text('Pulse Ox'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchRespiration(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.text_snippet),
//                 label: const Text('Respiration'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchHealthSnapshot(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.health_and_safety),
//                 label: const Text('Health Snapshot'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchBloodPressures(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.favorite_border),
//                 label: const Text('Blood Pressure'),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.fetchSkinTemp(
//                           start: _startDate,
//                           end: _endDate,
//                         )
//                     : null,
//                 icon: const Icon(Icons.thermostat),
//                 label: const Text('Skin Temp'),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // Backfill (Historical Data) Section
//           const Text(
//             'Request Historical Data (Backfill)',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Card(
//             color: Colors.blue.shade50,
//             child: Padding(
//               padding: const EdgeInsets.all(12.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(Icons.info_outline,
//                           size: 18, color: Colors.blue[700]),
//                       const SizedBox(width: 8),
//                       const Expanded(
//                         child: Text(
//                           'Backfill requests historical data (max 90 days). Data is delivered asynchronously via webhooks.',
//                           style: TextStyle(fontSize: 12),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 12),
//           Wrap(
//             spacing: 12,
//             runSpacing: 12,
//             children: [
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'dailies',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Dailies'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'sleeps',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Sleep'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'hrv',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill HRV'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'epochs',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Epochs'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'stressDetails',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Stress'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'userMetrics',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill User Metrics'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'bodyComps',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Body Comp'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'pulseox',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Pulse Ox'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'respiration',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Respiration'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'healthSnapshot',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Health Snapshot'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'bloodPressures',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Blood Pressure'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//               ElevatedButton.icon(
//                 onPressed: _startDate != null && _endDate != null
//                     ? () => widget.controller.requestBackfill(
//                           summaryType: 'skinTemp',
//                           start: _startDate!,
//                           end: _endDate!,
//                         )
//                     : null,
//                 icon: const Icon(Icons.history),
//                 label: const Text('Backfill Skin Temp'),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.white,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),

//           // Webhook Events Section
//           const Text(
//             'Webhook Events (Real-time Data)',
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Card(
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(
//                         widget.controller.isSSESubscribed
//                             ? Icons.check_circle
//                             : Icons.cancel,
//                         color: widget.controller.isSSESubscribed
//                             ? Colors.green
//                             : Colors.red,
//                         size: 32,
//                       ),
//                       const SizedBox(width: 16),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               widget.controller.isSSESubscribed
//                                   ? 'Subscribed to Real-time Events'
//                                   : 'Not Subscribed',
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               '${widget.controller.sseEvents.length} events received',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       if (!widget.controller.isSSESubscribed)
//                         ElevatedButton.icon(
//                           onPressed: widget.controller.isConnected
//                               ? () => widget.controller.subscribeToEvents()
//                               : null,
//                           icon: const Icon(Icons.play_arrow),
//                           label: const Text('Subscribe'),
//                         )
//                       else
//                         ElevatedButton.icon(
//                           onPressed: () =>
//                               widget.controller.unsubscribeFromEvents(),
//                           icon: const Icon(Icons.stop),
//                           label: const Text('Unsubscribe'),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.red,
//                             foregroundColor: Colors.white,
//                           ),
//                         ),
//                     ],
//                   ),
//                   if (widget.controller.backfillData.isNotEmpty) ...[
//                     const SizedBox(height: 16),
//                     const Divider(),
//                     const SizedBox(height: 8),
//                     const Text(
//                       'Received Backfill Data:',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     ...widget.controller.backfillData.entries.map((entry) {
//                       return Card(
//                         color: Colors.green.shade50,
//                         margin: const EdgeInsets.only(bottom: 8),
//                         child: ListTile(
//                           leading: const Icon(Icons.check_circle,
//                               color: Colors.green),
//                           title: Text(
//                             '${entry.key}',
//                             style: const TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                           subtitle: Text(
//                             'Data received via webhook',
//                             style: TextStyle(
//                                 fontSize: 12, color: Colors.grey[600]),
//                           ),
//                           trailing: IconButton(
//                             icon: const Icon(Icons.visibility),
//                             onPressed: () => _showBackfillData(
//                                 context, entry.key, entry.value),
//                           ),
//                         ),
//                       );
//                     }),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),

//           // Events List
//           if (widget.controller.sseEvents.isNotEmpty) ...[
//             const Text(
//               'Recent Events:',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 8),
//             SizedBox(
//               height: 200,
//               child: ListView.builder(
//                 itemCount: widget.controller.sseEvents.length,
//                 itemBuilder: (context, index) {
//                   final event = widget.controller.sseEvents[index];
//                   return Card(
//                     margin: const EdgeInsets.only(bottom: 8),
//                     child: InkWell(
//                       onTap: () => _showEventDetails(context, event),
//                       child: Padding(
//                         padding: const EdgeInsets.all(12.0),
//                         child: Row(
//                           children: [
//                             Icon(
//                               _getEventIcon(event.event),
//                               color: _getEventColor(event.event),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     event.event ?? 'Unknown',
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                   Text(
//                                     _formatEventTime(event.timestamp),
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.grey[600],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const Icon(Icons.chevron_right),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//             const SizedBox(height: 8),
//             TextButton.icon(
//               onPressed: () => widget.controller.clearSSEEvents(),
//               icon: const Icon(Icons.clear),
//               label: const Text('Clear Events'),
//             ),
//             const SizedBox(height: 20),
//           ],

//           // Status and error
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

//           // Data display
//           if (widget.controller.data != null) ...[
//             Text(
//               'Data (${widget.controller.currentDataType ?? 'unknown'}):',
//               style: const TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 8),
//             Card(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: _buildDataDisplay(widget.controller.data!),
//               ),
//             ),
//           ] else ...[
//             const Text(
//               'No data yet – fetch data to see records',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.grey,
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildDataDisplay(List<WearMetrics> data) {
//     if (data.isEmpty) {
//       return const Text('No records found');
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Records: ${data.length}',
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 14,
//           ),
//         ),
//         const SizedBox(height: 12),
//         ...data.take(10).map((WearMetrics metrics) {
//           final metricItems = <Widget>[];

//           // Add timestamp
//           metricItems.add(
//             Text(
//               _formatTimestamp(metrics.timestamp),
//               style: const TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 13,
//                 color: Colors.blue,
//               ),
//             ),
//           );
//           metricItems.add(const SizedBox(height: 6));

//           // Display Score data prominently if available
//           final scoreData = _extractScoreData(metrics.meta);
//           if (scoreData.isNotEmpty) {
//             metricItems.add(
//               Container(
//                 padding: const EdgeInsets.all(8.0),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.shade50,
//                   borderRadius: BorderRadius.circular(8.0),
//                   border: Border.all(color: Colors.blue.shade200),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(Icons.star, size: 16, color: Colors.blue[700]),
//                         const SizedBox(width: 6),
//                         Text(
//                           'Scores:',
//                           style: TextStyle(
//                             fontWeight: FontWeight.bold,
//                             fontSize: 12,
//                             color: Colors.blue[700],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 6),
//                     ...scoreData.map((scoreEntry) {
//                       return Padding(
//                         padding: const EdgeInsets.only(top: 4.0),
//                         child: Row(
//                           children: [
//                             const SizedBox(width: 22),
//                             Expanded(
//                               child: Text(
//                                 '${scoreEntry['label'] ?? ''}: ',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[700],
//                                 ),
//                               ),
//                             ),
//                             Text(
//                               scoreEntry['value'] ?? '',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.blue[900],
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     }),
//                   ],
//                 ),
//               ),
//             );
//             metricItems.add(const SizedBox(height: 8));
//           }

//           // Display ALL metrics from the map
//           if (metrics.metrics.isNotEmpty) {
//             metrics.metrics.forEach((key, value) {
//               if (value != null) {
//                 final label = _formatMetricLabel(key);
//                 final formattedValue = _formatMetricValue(key, value);
//                 final icon = _getMetricIcon(key);
//                 metricItems.add(_buildMetricRow(label, formattedValue, icon));
//               }
//             });
//           } else {
//             metricItems.add(
//               Text(
//                 'No metrics available',
//                 style: TextStyle(color: Colors.grey[600], fontSize: 12),
//               ),
//             );
//           }

//           // Display ALL meta fields (excluding score data which is shown above)
//           final otherMeta = <String, Object?>{};
//           metrics.meta.forEach((key, value) {
//             // Skip score-related fields as they're shown in the score section
//             if (!key.toLowerCase().contains('score') && value != null) {
//               otherMeta[key] = value;
//             }
//           });

//           if (otherMeta.isNotEmpty) {
//             metricItems.add(const SizedBox(height: 8));
//             metricItems.add(
//               const Divider(),
//             );
//             metricItems.add(
//               Padding(
//                 padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
//                 child: Text(
//                   'Additional Info:',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize: 12,
//                     color: Colors.grey[700],
//                   ),
//                 ),
//               ),
//             );
//             otherMeta.forEach((key, value) {
//               if (value != null) {
//                 metricItems.add(
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 2.0),
//                     child: Row(
//                       children: [
//                         Icon(Icons.info_outline,
//                             size: 14, color: Colors.grey[600]),
//                         const SizedBox(width: 8),
//                         Text(
//                           '${_formatMetaLabel(key)}: ',
//                           style: TextStyle(
//                             fontSize: 11,
//                             color: Colors.grey[700],
//                           ),
//                         ),
//                         Expanded(
//                           child: Text(
//                             _formatMetaValue(value),
//                             style: TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.w500,
//                               color: Colors.black87,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 );
//               }
//             });
//           }

//           return Padding(
//             padding: const EdgeInsets.only(bottom: 12.0),
//             child: Card(
//               elevation: 2,
//               child: Padding(
//                 padding: const EdgeInsets.all(12.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: metricItems,
//                 ),
//               ),
//             ),
//           );
//         }),
//         if (data.length > 10)
//           Padding(
//             padding: const EdgeInsets.only(top: 8.0),
//             child: Text(
//               '... and ${data.length - 10} more records',
//               style: TextStyle(
//                 fontSize: 12,
//                 color: Colors.grey[600],
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//           ),
//       ],
//     );
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

//   IconData _getEventIcon(String? eventType) {
//     switch (eventType) {
//       case 'connected':
//         return Icons.link;
//       case 'dailies':
//         return Icons.calendar_today;
//       case 'sleeps':
//         return Icons.bedtime;
//       case 'hrv':
//         return Icons.favorite;
//       case 'epochs':
//         return Icons.timeline;
//       case 'stressDetails':
//         return Icons.psychology;
//       default:
//         return Icons.event;
//     }
//   }

//   Color _getEventColor(String? eventType) {
//     switch (eventType) {
//       case 'connected':
//         return Colors.green;
//       case 'dailies':
//         return Colors.blue;
//       case 'sleeps':
//         return Colors.purple;
//       case 'hrv':
//         return Colors.red;
//       case 'epochs':
//         return Colors.orange;
//       case 'stressDetails':
//         return Colors.amber;
//       default:
//         return Colors.grey;
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
//       return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
//     }
//   }

//   void _showEventDetails(BuildContext context, WearServiceEvent event) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Event: ${event.event ?? 'Unknown'}'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (event.id != null) ...[
//                 Text('ID: ${event.id}'),
//                 const SizedBox(height: 8),
//               ],
//               Text('Time: ${_formatEventTime(event.timestamp)}'),
//               const SizedBox(height: 16),
//               const Text(
//                 'Data:',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 const JsonEncoder().convert(event.data ?? {}),
//                 style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//               ),
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

//   void _showBackfillData(BuildContext context, String dataType, dynamic data) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Backfill Data: $dataType'),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Text(
//                 'Data:',
//                 style: TextStyle(fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 const JsonEncoder().convert(data),
//                 style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
//               ),
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
// }
