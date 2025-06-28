import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Convert to a StatefulWidget to manage the TabController and FAB state.
class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Add a listener to rebuild the widget when the tab changes, so the FAB updates.
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showLogEntryDialog(BuildContext context) {
    // Show a different dialog based on the current tab index.
    if (_tabController.index == 1) {
      // Weight Tab
      showModalBottomSheet(
        context: context,
        builder: (_) => _LogWeightSheet(),
        isScrollControlled:
            true, // Important for keyboard to not cover the sheet
      );
    } else if (_tabController.index == 2) {
      // Strength Tab
      showModalBottomSheet(
        context: context,
        builder: (_) => _LogStrengthSheet(),
        isScrollControlled: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // We now use a Scaffold here to host the FloatingActionButton.
    return Scaffold(
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Weight'),
              Tab(text: 'Strength'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(tabController: _tabController),
                _WeightProgressChart(),
                _StrengthProgressChart(),
              ],
            ),
          ),
        ],
      ),
      // --- The "Smart" Floating Action Button ---
      floatingActionButton: _tabController.index > 0
          ? FloatingActionButton(
              onPressed: () => _showLogEntryDialog(context),
              child: Icon(
                _tabController.index == 1
                    ? Icons.monitor_weight_outlined
                    : Icons.fitness_center,
              ),
            )
          : null, // Hide FAB on the overview tab
    );
  }
}

// =================================================================
// OVERVIEW WIDGET with new sections
// =================================================================
class _OverviewTab extends StatelessWidget {
  final TabController tabController;
  const _OverviewTab({required this.tabController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // --- NEW: Consistency Tracker ---
        Text(
          'This Week\'s Consistency',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const _ConsistencyTracker(),
        const SizedBox(height: 32),

        Text(
          'Weight',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => tabController.animateTo(1),
          child: _StatCard(
            title: 'Current Weight',
            value: '150',
            unit: 'lbs',
            trend: 'Last 30 days -2%',
            trendColor: Colors.red.shade400,
            chart: const _MiniWeightChart(),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Strength',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => tabController.animateTo(2),
          child: _StatCard(
            title: 'Bench Press (1RM)',
            value: '180',
            unit: 'lbs',
            trend: 'Last 30 days +5%',
            trendColor: Colors.green.shade600,
            chart: const _MiniStrengthChart(),
          ),
        ),
        const SizedBox(height: 32),
        // --- NEW: Personal Records ---
        Text(
          'Personal Records',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const _PersonalRecordCard(exercise: 'Squat', record: '225 lbs'),
        const _PersonalRecordCard(exercise: 'Deadlift', record: '315 lbs'),
      ],
    );
  }
}

// =================================================================
// UPDATED WIDGETS: Data entry sheets with Date Pickers
// =================================================================
class _LogWeightSheet extends StatefulWidget {
  const _LogWeightSheet();
  @override
  State<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends State<_LogWeightSheet> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      // --- FIX IS HERE: Wrapped Column in a SingleChildScrollView ---
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Your Weight',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            // --- Date Selector Field ---
            TextField(
              controller: TextEditingController(
                text: DateFormat.yMMMd().format(_selectedDate),
              ),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Weight (lbs)',
                border: OutlineInputBorder(),
                suffixText: 'lbs',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogStrengthSheet extends StatefulWidget {
  const _LogStrengthSheet();
  @override
  State<_LogStrengthSheet> createState() => _LogStrengthSheetState();
}

class _LogStrengthSheetState extends State<_LogStrengthSheet> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      // --- FIX IS HERE: Wrapped Column in a SingleChildScrollView ---
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Your Lift',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            // --- Date Selector Field ---
            TextField(
              controller: TextEditingController(
                text: DateFormat.yMMMd().format(_selectedDate),
              ),
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Exercise Name (e.g., Bench Press)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Weight (lbs)',
                border: OutlineInputBorder(),
                suffixText: 'lbs',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// NEW WIDGETS for Overview tab
// =================================================================
class _ConsistencyTracker extends StatelessWidget {
  const _ConsistencyTracker();

  @override
  Widget build(BuildContext context) {
    // Placeholder data - true means workout was logged that day
    final days = [true, false, true, true, false, true, false];
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        return Column(
          children: [
            Text(
              dayLabels[index],
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            CircleAvatar(
              radius: 18,
              backgroundColor: days[index]
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              child: days[index]
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
                    )
                  : null,
            ),
          ],
        );
      }),
    );
  }
}

class _PersonalRecordCard extends StatelessWidget {
  final String exercise;
  final String record;
  const _PersonalRecordCard({required this.exercise, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.star_border,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 16),
            Text(exercise, style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              record,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// WEIGHT CHART: Refactored to be more comprehensive
// =================================================================
class _WeightProgressChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // --- Main Chart ---
        const Text(
          'Weight',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              '150',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Text(
              'lbs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              'Last 30 days -2%',
              style: TextStyle(fontSize: 14, color: Colors.red.shade400),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(fontSize: 12);
                      Widget text;
                      switch (value.toInt()) {
                        case 0:
                          text = const Text('Jan', style: style);
                          break;
                        case 1:
                          text = const Text('Feb', style: style);
                          break;
                        case 2:
                          text = const Text('Mar', style: style);
                          break;
                        case 3:
                          text = const Text('Apr', style: style);
                          break;
                        case 4:
                          text = const Text('May', style: style);
                          break;
                        case 5:
                          text = const Text('Jun', style: style);
                          break;
                        default:
                          text = const Text('', style: style);
                          break;
                      }
                      return SideTitleWidget(child: text, meta: meta);
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: const [
                    FlSpot(0, 155),
                    FlSpot(1, 152),
                    FlSpot(2, 153),
                    FlSpot(3, 148),
                    FlSpot(4, 150),
                    FlSpot(5, 154),
                    FlSpot(5.5, 150),
                  ],
                  isCurved: true,
                  color: theme.colorScheme.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // --- NEW: Key Statistics Grid ---
        Text(
          'Key Statistics',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.0,
          children: const [
            _WeightStatCard(label: 'BMI', value: '22.8'),
            _WeightStatCard(label: '7-Day Change', value: '-0.5 lbs'),
            _WeightStatCard(label: 'All-Time High', value: '160 lbs'),
            _WeightStatCard(label: 'All-Time Low', value: '148 lbs'),
          ],
        ),
        const SizedBox(height: 32),

        // --- NEW: Recent History List ---
        Text(
          'Recent History',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _HistoryListItem(date: 'June 25, 2025', details: '150.2 lbs'),
        _HistoryListItem(date: 'June 23, 2025', details: '150.7 lbs'),
        _HistoryListItem(date: 'June 21, 2025', details: '150.5 lbs'),
      ],
    );
  }
}

// =================================================================
// NEW WIDGET for the Key Statistics Grid
// =================================================================
class _WeightStatCard extends StatelessWidget {
  final String label;
  final String value;
  const _WeightStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// =================================================================
// STRENGTH CHART: Refactored to be interactive
// =================================================================
class _StrengthProgressChart extends StatefulWidget {
  @override
  State<_StrengthProgressChart> createState() => _StrengthProgressChartState();
}

class _StrengthProgressChartState extends State<_StrengthProgressChart> {
  // State for the dropdown
  String _selectedExercise = 'Bench Press';
  final List<String> _exercises = ['Bench Press', 'Squat', 'Deadlift'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const Text(
          'Strength',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // --- NEW: Exercise Selector Dropdown ---
        DropdownButtonFormField<String>(
          value: _selectedExercise,
          items: _exercises.map((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedExercise = newValue!;
            });
          },
          decoration: const InputDecoration(
            labelText: 'Select Exercise',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            const Text(
              '180',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Text(
              'lbs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              'Last 30 days +5%',
              style: TextStyle(fontSize: 14, color: Colors.green.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _selectedExercise,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: BarChart(
            // Chart would now update based on _selectedExercise
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 200,
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      const style = TextStyle(fontSize: 12);
                      Widget text;
                      switch (value.toInt()) {
                        case 0:
                          text = const Text('Jan', style: style);
                          break;
                        case 1:
                          text = const Text('Feb', style: style);
                          break;
                        case 2:
                          text = const Text('Mar', style: style);
                          break;
                        case 3:
                          text = const Text('Apr', style: style);
                          break;
                        case 4:
                          text = const Text('May', style: style);
                          break;
                        case 5:
                          text = const Text('Jun', style: style);
                          break;
                        default:
                          text = const Text('', style: style);
                          break;
                      }
                      return SideTitleWidget(child: text, meta: meta);
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                _makeBar(0, 160, theme.colorScheme),
                _makeBar(1, 165, theme.colorScheme),
                _makeBar(2, 170, theme.colorScheme),
                _makeBar(3, 175, theme.colorScheme),
                _makeBar(4, 178, theme.colorScheme),
                _makeBar(5, 180, theme.colorScheme),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        // --- NEW: Recent History List ---
        Text(
          'Recent Lifts',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // In a real app, this would be a ListView.builder with real data
        _HistoryListItem(date: 'June 25, 2025', details: '180 lbs x 5 reps'),
        _HistoryListItem(date: 'June 18, 2025', details: '175 lbs x 5 reps'),
        _HistoryListItem(date: 'June 11, 2025', details: '175 lbs x 4 reps'),
      ],
    );
  }

  BarChartGroupData _makeBar(int x, double y, ColorScheme colors) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: colors.primary.withOpacity(0.3),
          width: 22,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

// =================================================================
// NEW WIDGET for Strength History List
// =================================================================
class _HistoryListItem extends StatelessWidget {
  final String date;
  final String details;

  const _HistoryListItem({required this.date, required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          details,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(date, style: theme.textTheme.bodyMedium),
        trailing: IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () {
            /* Show options like edit/delete */
          },
        ),
      ),
    );
  }
}

// --- Other widgets like _StatCard, _WeightProgressChart, etc., remain the same ---
// (Code for these widgets is omitted for brevity but would be included here)

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String trend;
  final Color trendColor;
  final Widget chart;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.trend,
    required this.trendColor,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(unit, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            Text(
              trend,
              style: TextStyle(color: trendColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 100, child: chart),
          ],
        ),
      ),
    );
  }
}

class _MiniWeightChart extends StatelessWidget {
  const _MiniWeightChart();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3),
              FlSpot(1, 1.5),
              FlSpot(2, 2),
              FlSpot(3, 1),
              FlSpot(4, 2.5),
              FlSpot(5, 2.2),
              FlSpot(6, 3.5),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _MiniStrengthChart extends StatelessWidget {
  const _MiniStrengthChart();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeBar(0, 8, theme.colorScheme),
          _makeBar(1, 9.5, theme.colorScheme),
          _makeBar(2, 11, theme.colorScheme),
          _makeBar(3, 12, theme.colorScheme),
          _makeBar(4, 14, theme.colorScheme),
        ],
      ),
    );
  }

  BarChartGroupData _makeBar(int x, double y, ColorScheme colors) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: colors.primary.withOpacity(0.3),
          width: 15,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }
}
