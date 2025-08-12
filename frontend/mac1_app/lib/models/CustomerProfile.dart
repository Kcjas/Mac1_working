class Customerprofile {
  final String name;
  final int age;
  final String gender;
 

  Customerprofile({
    required this.name,
    required this.age,
    required this.gender,
  });

  factory Customerprofile.fromJson(Map<String, dynamic>json){
    return Customerprofile(
      name: json['name'], 
      age: json['age'], 
      gender: json['gender'], 
    );
  }
}