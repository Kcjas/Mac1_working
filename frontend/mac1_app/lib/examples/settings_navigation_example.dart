// Example: How to add a Settings button to your app
// This is just an example - integrate it into your existing navigation

import 'package:flutter/material.dart';
import '../Pages/settings_page.dart';

// Option 1: Add to AppBar
AppBar _buildAppBarWithSettings(BuildContext context) {
  return AppBar(
    title: const Text('Your App'),
    actions: [
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        },
      ),
    ],
  );
}

// Option 2: Add to Drawer
Drawer _buildDrawerWithSettings(BuildContext context) {
  return Drawer(
    child: ListView(
      children: [
        const DrawerHeader(
          child: Text('MAC1 App'),
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('Settings'),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          },
        ),
        // ... other menu items
      ],
    ),
  );
}

// Option 3: Add as a FloatingActionButton
FloatingActionButton _buildSettingsFloatingActionButton(BuildContext context) {
  return FloatingActionButton(
    child: const Icon(Icons.settings),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsPage()),
      );
    },
  );
}
