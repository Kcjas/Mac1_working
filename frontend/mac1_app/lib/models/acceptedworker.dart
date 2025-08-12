class AcceptedWorker {
  final int workerId;
  final String name;
  final String skill;
  final double hourlyRate;
  final double rating;
  final double distance;
  final double customerLat;
  final double customerLon;
  final String date;     // NEW
  final String time; 
  


  AcceptedWorker({
    required this.workerId,
    required this.name,
    required this.skill,
    required this.hourlyRate,
    required this.rating,
    required this.distance,
    required this.customerLat,
    required this.customerLon,
    required this.date,
    required this.time,
  });

  factory AcceptedWorker.fromJson(Map<String, dynamic> json) {
    return AcceptedWorker(
      workerId: json['worker_id'],
      name: json['name'],
      skill: json['skill'],
      hourlyRate: (json['hourly_rate'] as num).toDouble(),
      rating: (json['rating'] as num).toDouble(),
      distance: (json['distance'] as num).toDouble(),
      customerLat: (json['customer_lat'] as num).toDouble(),
      customerLon: (json['customer_lon'] as num).toDouble(),
      date: json['date'],  
      time: json['time'],
    );
  }
}
