import 'package:flutter/material.dart';
import '../utils/responsive_sizes.dart';
import '../utils/app_colors_streamlined.dart';

/// Pure UI builder for WorkManager scheduled jobs viewer
/// Displays all scheduled jobs with their details in card format
class WorkManagerJobsViewerUI {
  final BuildContext context;
  final dynamic state; // State object from _WorkManagerJobsViewerState

  WorkManagerJobsViewerUI({
    required this.context,
    required this.state,
  });

  /// Build the main scaffold for the jobs viewer
  Widget buildScaffold() {
    final colors = AppColorsStreamlined(context);
    final responsive = ResponsiveSizes(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.header_bg,
        foregroundColor: colors.header_txt,
        title: Text(
          'WorkManager',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: responsive.titleSize,
            color: colors.header_txt,
          ),
        ),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: state.refreshJobs,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear History',
            onPressed: state.clearHistory,
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
              ? _buildErrorWidget(colors, responsive)
              : state.scheduledJobs.isEmpty
                  ? _buildEmptyState(colors, responsive)
                  : _buildJobsList(colors, responsive),
    );
  }

  /// Build the error state widget
  Widget _buildErrorWidget(AppColorsStreamlined colors, ResponsiveSizes responsive) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error_txt),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.surface_txt),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: state.refreshJobs,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the empty state widget
  Widget _buildEmptyState(AppColorsStreamlined colors, ResponsiveSizes responsive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: colors.surface_subtxt,
          ),
          const SizedBox(height: 16),
          Text(
            'No scheduled jobs',
            style: TextStyle(
              fontSize: responsive.bodySize,
              color: colors.surface_subtxt,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: state.refreshJobs,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Again'),
          ),
        ],
      ),
    );
  }

  /// Build the list of scheduled jobs
  Widget _buildJobsList(AppColorsStreamlined colors, ResponsiveSizes responsive) {
    return RefreshIndicator(
      onRefresh: () async => state.refreshJobs(),
      child: ListView.builder(
        padding: responsive.paddingHorizontal,
        itemCount: state.scheduledJobs.length,
        itemBuilder: (context, index) {
          final job = state.scheduledJobs[index];
          return _buildJobCard(job, colors, responsive);
        },
      ),
    );
  }

  /// Build a single job card
  Widget _buildJobCard(
    Map<String, dynamic> job,
    AppColorsStreamlined colors,
    ResponsiveSizes responsive,
  ) {
    return Card(
      margin: EdgeInsets.symmetric(
        vertical: responsive.spacingS,
      ),
      color: colors.primarycontainer_bg,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStateColor(job['currentState'] as String?, colors),
          width: 2,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(responsive.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Job ID - with truncation for long IDs
            Padding(
              padding: EdgeInsets.only(bottom: responsive.spacingS),
              child: Tooltip(
                message: 'ID: ${job['id'] ?? 'N/A'}',
                child: Text(
                  'ID: ${_truncateId(job['id'] as String?)}',
                  style: TextStyle(
                    fontSize: responsive.bodySize * 0.9,
                    color: colors.primarycontainer_subtxt,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Work Tags
            Padding(
              padding: EdgeInsets.only(bottom: responsive.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work Tags',
                    style: TextStyle(
                      fontSize: responsive.bodySize,
                      fontWeight: FontWeight.w600,
                      color: colors.primarycontainer_txt,
                    ),
                  ),
                  SizedBox(height: responsive.spacingXS),
                  if (job['tags'] != null && (job['tags'] as List).isNotEmpty)
                    ...((job['tags'] as List).cast<String>().map((tag) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(color: colors.primarycontainer_subtxt),
                            ),
                            Expanded(
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: responsive.bodySize * 0.85,
                                  color: colors.primarycontainer_subtxt,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }))
                  else
                    Text(
                      'No tags',
                      style: TextStyle(
                        fontSize: responsive.bodySize * 0.85,
                        color: colors.primarycontainer_subtxt,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),

            // Current State
            Padding(
              padding: EdgeInsets.only(bottom: responsive.spacingS),
              child: Row(
                children: [
                  Text(
                    'Current State: ',
                    style: TextStyle(
                      fontSize: responsive.bodySize,
                      fontWeight: FontWeight.w600,
                      color: colors.primarycontainer_txt,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStateColor(job['currentState'] as String?, colors)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getStateColor(job['currentState'] as String?, colors),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        job['currentState'] as String? ?? 'UNKNOWN',
                        style: TextStyle(
                          fontSize: responsive.bodySize * 0.9,
                          fontWeight: FontWeight.w600,
                          color: _getStateColor(job['currentState'] as String?, colors),
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Next Scheduled Run
            Padding(
              padding: EdgeInsets.only(bottom: responsive.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Scheduled Run',
                    style: TextStyle(
                      fontSize: responsive.bodySize,
                      fontWeight: FontWeight.w600,
                      color: colors.primarycontainer_txt,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    job['nextScheduledRun'] as String? ?? 'N/A',
                    style: TextStyle(
                      fontSize: responsive.bodySize * 0.85,
                      color: colors.primarycontainer_subtxt,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            // Attempt Number
            Row(
              children: [
                Text(
                  'Attempt Number: ',
                  style: TextStyle(
                    fontSize: responsive.bodySize,
                    fontWeight: FontWeight.w600,
                    color: colors.primarycontainer_txt,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.button_on.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${job['attemptNumber'] ?? 0}',
                    style: TextStyle(
                      fontSize: responsive.bodySize * 0.9,
                      fontWeight: FontWeight.w600,
                      color: colors.primarycontainer_subtxt,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Get color based on job state
  Color _getStateColor(String? state, AppColorsStreamlined colors) {
    switch (state?.toUpperCase()) {
      case 'ENQUEUED':
        return Colors.blue;
      case 'RUNNING':
        return Colors.orange;
      case 'SUCCEEDED':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'BLOCKED':
        return Colors.purple;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return colors.primarycontainer_subtxt;
    }
  }

  /// Truncate long IDs for display
  String _truncateId(String? id) {
    if (id == null || id.isEmpty) return 'N/A';
    if (id.length <= 16) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 8)}';
  }
}
