class TelemetryBuffer {
  final int capacity;
  final List<Map<String, dynamic>> _buffer = [];
  int _droppedCount = 0;

  TelemetryBuffer({this.capacity = 500});

  void enqueue(Map<String, dynamic> sample) {
    if (_buffer.length >= capacity) {
      _buffer.removeAt(0);
      _droppedCount++;
    }
    _buffer.add(sample);
  }

  List<Map<String, dynamic>> flush() {
    final items = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    return items;
  }

  bool get isEmpty => _buffer.isEmpty;

  int get droppedCount => _droppedCount;

  void resetDropCount() {
    _droppedCount = 0;
  }
}
