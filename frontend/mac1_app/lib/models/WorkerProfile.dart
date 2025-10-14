class Workerprofile {
  final String name;
  final int age;
  final String gender;
  final String skill;
  final int experience;
  final double hourlyRate;

  Workerprofile({
    required this.name,
    required this.age,
    required this.gender,
    required this.skill,
    required this.experience,
    required this.hourlyRate
  });

  factory Workerprofile.fromJson(Map<String, dynamic>json){
    return Workerprofile(
      name: json['name'], 
      age: json['age'], 
      gender: json['gender'], 
      skill: json['skill'], 
      experience: json['experience'],
      hourlyRate: (json['hourly_rate'] as num).toDouble(),
    );
    }}