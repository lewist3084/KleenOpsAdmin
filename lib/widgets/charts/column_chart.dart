import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:shared_widgets/theme/app_palette.dart';

/// A simple data class for one period’s Actual vs Scheduled hours.
/// Add an optional percent value when you need a secondary axis.
class ChartData {
  final DateTime period;
  final double actual;
  final double scheduled;
  final double? percent;

  ChartData(
    this.period,
    this.actual,
    this.scheduled, {
    this.percent,
  });
}

/// A reusable column chart that supports zoom/pan, tooltips, point taps,
/// and an *optional* percent axis/series.
class ColumnChart extends StatelessWidget {
  /// Data points to plot
  final List<ChartData> data;
  
  /// Label for the first column series (blue)
  final String column1;
  
  /// Label for the second column series (orange)
  final String column2;

  /// If provided, a right-hand percent axis appears and values are plotted as a line.
  final String? percentLabel;

  /// Optional axis overrides for custom date labeling.
  final DateTimeAxis? xAxis;
  final NumericAxis? yAxis;

  /// Callback when a data point is tapped: seriesIndex 0=column1,1=column2,2=percent
  final void Function(int seriesIndex, int pointIndex)? onPointSelected;

  // Zoom & pan support
  final ZoomPanBehavior _zoomPanBehavior = ZoomPanBehavior(
    enablePinching: true,
    enablePanning: true,
    zoomMode: ZoomMode.x,
  );

  // Tooltips on hover/long-press
  final TooltipBehavior _tooltipBehavior = TooltipBehavior(enable: true);

  ColumnChart({
    super.key,
    required this.data,
    required this.column1,
    required this.column2,
    this.percentLabel,
    this.xAxis,
    this.yAxis,
    this.onPointSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteScope.of(context);
    final primaryColor = palette.primary2;
    return SfCartesianChart(
      backgroundColor: Colors.white,
      plotAreaBackgroundColor: Colors.white,
      zoomPanBehavior: _zoomPanBehavior,
      tooltipBehavior: _tooltipBehavior,
      primaryXAxis: xAxis ?? DateTimeAxis(),
      primaryYAxis: yAxis ?? NumericAxis(minimum: 0),
      axes: percentLabel != null
          ? [
              NumericAxis(
                name: 'percentAxis',
                opposedPosition: true,
                minimum: 0,
                labelFormat: '{value}%',
              ),
            ]
          : [],
      legend: Legend(isVisible: true),
      series: [
        ColumnSeries<ChartData, DateTime>(
          dataSource: data,
          xValueMapper: (d, _) => d.period,
          yValueMapper: (d, _) => d.actual,
          name: column1,
          onPointTap: (details) {
            if (onPointSelected != null) {
              onPointSelected!(details.seriesIndex!, details.pointIndex!);
            }
          },
        ),
        ColumnSeries<ChartData, DateTime>(
          dataSource: data,
          xValueMapper: (d, _) => d.period,
          yValueMapper: (d, _) => d.scheduled,
          name: column2,
          onPointTap: (details) {
            if (onPointSelected != null) {
              onPointSelected!(details.seriesIndex!, details.pointIndex!);
            }
          },
        ),
        if (percentLabel != null)
          LineSeries<ChartData, DateTime>(
            dataSource: data,
            xValueMapper: (d, _) => d.period,
            yValueMapper: (d, _) => d.percent ?? 0,
            yAxisName: 'percentAxis',
            name: percentLabel!,
            markerSettings: MarkerSettings(isVisible: true),
            onPointTap: (details) {
              if (onPointSelected != null) {
                onPointSelected!(details.seriesIndex!, details.pointIndex!);
              }
            },
            color: primaryColor,
          ),
      ],
    );
  }
}
