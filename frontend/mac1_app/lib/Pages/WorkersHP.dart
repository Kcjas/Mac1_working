import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/WorkerProfile.dart';
import '../services/api_service.dart';
import '../services/Booking_preview.dart';
import '../services/profilerow.dart';

class Workershp extends StatefulWidget{
  final int userId;
  const Workershp({super.key,required this.userId});
  
  @override
  State<Workershp> createState() => _workersHPState();
}


class _workersHPState extends State<Workershp>{
  late Future<Workerprofile> workerFuture;
  late Future<double> ratingFuture;

  @override
  void initState() {
    super.initState();
    workerFuture = ApiService.fetchWorkerdata(widget.userId);
    ratingFuture = ApiService.fetchWorkerRating(widget.userId);
  }


  
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: const Text("Workers Dashboard")),
      body: FutureBuilder<Workerprofile>(
        future: workerFuture, 
        builder: (context,snapshot){
          if(snapshot.connectionState == ConnectionState.waiting){
            return const Center(child: CircularProgressIndicator());
          }else if(snapshot.hasError){
            return Center(child: Text("Error: ${snapshot.error}"));
          }else if(!snapshot.hasData || snapshot.hasData ==null){
            return const Center(child: Text('No Data Found'));
          }

          final worker = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.grey,blurRadius: 6,offset: Offset(0, 3))]
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.person, size:40,color: Colors.white)
                      ),
                      const SizedBox(width: 20),
                      Container(height: 200,width: 2,color: Colors.grey.shade300,),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                        "Name: ${worker.name}",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      ProfileRow(label: "Age", value: "${worker.age}"),
                      ProfileRow(label: "Gender", value: worker.gender),
                      ProfileRow(label: "Skill", value: worker.skill),
                      ProfileRow(label: "Experience", value: "${worker.experience} years"),
                      ProfileRow(label: "Hourly Rate", value: "₹${worker.hourlyRate.toStringAsFixed(2)}"),
                          ],
                        )
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),

                BookingPreview(userId: widget.userId, type: 'pending'),

                BookingPreview(userId: widget.userId, type: 'completed'),

                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (){
                          Navigator.pushNamed(context, '/incomingRequests', arguments: widget.userId);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          
                        ),
                        child: const Text("Incoming Request", textAlign: TextAlign.center, style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 16,),), 
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (){
                          Navigator.pushNamed(context, '/wallet', arguments: widget.key);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Wallet", textAlign: TextAlign.center, style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,fontSize: 16,),),                     
                      )
                    )
                  ],
                ),
                const SizedBox(height: 30),
                FutureBuilder<double>(
                  future: ratingFuture, 
                  builder: (context,snapshot){
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return const Text("Failed to load rating");
                    }else{
                      final rating = snapshot.data!;
                      return Column(
                        children: [
                          const Text("Your rating", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height:8),
                          RatingBarIndicator(
                            rating: rating,
                            itemBuilder: (context, index)=>const Icon(Icons.star, color: Colors.amber),
                            itemCount: 5,
                            itemSize: 30.0,
                            direction: Axis.horizontal,
                          ),
                          const SizedBox(height:8),
                          Text("$rating / 5",style: const TextStyle(fontSize: 16))
                        ], 
                      );
                    }
                  }
                ),
                const SizedBox(height: 30),
                FutureBuilder(
                  future: ApiService.fetchLeaderboard(), 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    } else if (snapshot.hasError) {
                      return const Text("Failed to load leaderboard");
                    }

                    final leaderboard = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Top rated worker", style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
                        const SizedBox(height: 10,),
                        ...leaderboard.map((worker){
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.star, color: Colors.amber),
                              title: Text(worker['name']),
                              trailing: Text("${worker['avg_rating']} ⭐"),
                            ),
                          );
                        }).toList()
                      ],
                    );
                  }
                ),
                const SizedBox(height:20)
              ],
            )
          );
        }
      )
    );
  }
}
