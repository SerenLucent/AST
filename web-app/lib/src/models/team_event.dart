class TeamEvent {
  const TeamEvent({
    required this.title,
    required this.scheduledAt,
    required this.location,
  });

  final String title;
  final DateTime scheduledAt;
  final String location;

  bool isVisibleAt(DateTime now) {
    final eventDayEnds = DateTime(
      scheduledAt.year,
      scheduledAt.month,
      scheduledAt.day + 1,
    );
    return now.isBefore(eventDayEnds);
  }
}

List<TeamEvent> upcomingEvents(Iterable<TeamEvent> events, DateTime now) {
  final visible = events.where((event) => event.isVisibleAt(now)).toList();
  visible.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return visible;
}
