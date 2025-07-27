import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/utils/constants.dart';

class DateSelector extends StatefulWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChanged;
  final int daysToShow;
  final bool showMonthHeader;
  final bool enableScrollToToday;

  const DateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.daysToShow = 30,
    this.showMonthHeader = true,
    this.enableScrollToToday = true,
  });

  @override
  State<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  String _currentMonth = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Auto-scroll to selected date on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedDate();
    });

    _updateCurrentMonth();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollToSelectedDate() {
    final now = DateTime.now();
    final daysDifference = widget.selectedDate.difference(now).inDays;

    if (daysDifference >= 0 && daysDifference < widget.daysToShow) {
      final scrollPosition =
          (daysDifference * 64.0) -
          (MediaQuery.of(context).size.width / 2) +
          32;

      _scrollController.animateTo(
        scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _updateCurrentMonth() {
    final newMonth = DateFormat('MMMM yyyy').format(widget.selectedDate);
    if (newMonth != _currentMonth) {
      setState(() {
        _currentMonth = newMonth;
      });
    }
  }

  void _scrollToToday() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    widget.onDateChanged(DateTime.now());
  }

  Widget _buildDateItem(DateTime date, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isSelected = DateHelpers.isSameDay(date, widget.selectedDate);
    final isToday = DateHelpers.isToday(date);
    final isTomorrow = DateHelpers.isTomorrow(date);
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    Color getBackgroundColor() {
      if (isSelected) return colorScheme.primary;
      if (isToday) {
        return theme.brightness == Brightness.dark
            ? colorScheme.primaryContainer.withOpacity(0.5)
            : colorScheme.primaryContainer.withOpacity(0.3);
      }
      return Colors.transparent;
    }

    Color getTextColor() {
      if (isSelected) return colorScheme.onPrimary;
      if (isToday) return colorScheme.primary;
      if (isWeekend) {
        return theme.brightness == Brightness.dark
            ? colorScheme.onSurfaceVariant.withOpacity(0.8)
            : colorScheme.onSurfaceVariant.withOpacity(0.7);
      }
      return colorScheme.onSurface;
    }

    Color getBorderColor() {
      if (isSelected) return colorScheme.primary;
      if (isToday) return colorScheme.primary;
      return theme.brightness == Brightness.dark
          ? colorScheme.outline.withOpacity(0.3)
          : colorScheme.outline.withOpacity(0.2);
    }

    String getDateLabel() {
      if (isToday) return 'Today';
      if (isTomorrow) return 'Tomorrow';
      return DateFormat('EEE').format(date);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 72,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: getBackgroundColor(),
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: getBorderColor(),
          width: isSelected || isToday ? 2 : 1,
        ),
        boxShadow:
            isSelected
                ? [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(
                      theme.brightness == Brightness.dark ? 0.4 : 0.3,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : theme.brightness == Brightness.dark
                ? []
                : [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onDateChanged(date);
            _updateCurrentMonth();

            // Haptic feedback
            HapticFeedback.selectionClick();
          },
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Day label
              Flexible(
                child: Text(
                  getDateLabel(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: getTextColor(),
                    fontWeight:
                        isToday || isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 2),

              // Date number
              Text(
                DateFormat('dd').format(date),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: getTextColor(),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              // Small indicator dot for special dates
              SizedBox(
                height: 8,
                child:
                    isToday || isSelected
                        ? Center(
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: getTextColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color:
                theme.brightness == Brightness.dark
                    ? colorScheme.outline.withOpacity(0.2)
                    : colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Header
          if (widget.showMonthHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentMonth,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),

                  // Scroll to Today button
                  if (widget.enableScrollToToday &&
                      !DateHelpers.isSameDay(
                        widget.selectedDate,
                        DateTime.now(),
                      ))
                    TextButton.icon(
                      onPressed: _scrollToToday,
                      icon: Icon(
                        Icons.today_rounded,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      label: Text(
                        'Today',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor:
                            theme.brightness == Brightness.dark
                                ? colorScheme.primaryContainer.withOpacity(0.2)
                                : colorScheme.primaryContainer.withOpacity(0.1),
                      ),
                    ),
                ],
              ),
            ),

          // Date Selector
          SizedBox(
            height: 80,
            child: NotificationListener<ScrollUpdateNotification>(
              onNotification: (notification) {
                // Update month header based on scroll position
                if (widget.showMonthHeader) {
                  final scrollOffset = _scrollController.offset;
                  final itemWidth = 64.0;
                  final visibleIndex = (scrollOffset / itemWidth).round();

                  if (visibleIndex >= 0 && visibleIndex < widget.daysToShow) {
                    final visibleDate = DateTime.now().add(
                      Duration(days: visibleIndex),
                    );
                    final newMonth = DateFormat(
                      'MMMM yyyy',
                    ).format(visibleDate);

                    if (newMonth != _currentMonth) {
                      setState(() {
                        _currentMonth = newMonth;
                      });
                    }
                  }
                }
                return false;
              },
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                itemCount: widget.daysToShow,
                itemBuilder: (context, index) {
                  final date = DateTime.now().add(Duration(days: index));
                  return _buildDateItem(date, index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension for haptic feedback
extension HapticFeedback on DateSelector {
  static void selectionClick() {
    // Add haptic feedback if available
    // This would require the services plugin
    // HapticFeedback.selectionClick();
  }
}
