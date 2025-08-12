import 'package:geocoding/geocoding.dart';

class LocationHelper {
  static Future<String> getAddressFromLatLng(double lat, double lon) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        return "${placemark.name}, ${placemark.street}, ${placemark.locality}, ${placemark.administrativeArea}, ${placemark.postalCode}";
      } else {
        return "Unknown location";
      }
    } catch (e) {
      print("Error getting address: $e");
      return "Error retrieving address";
    }
  }
}
