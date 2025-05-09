import 'package:flutter/material.dart';
import 'package:splitwise/providers/app_data.dart';
import 'package:splitwise/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AppData(), // Initialize the provider
      child: MaterialApp(
        title: 'Local Expense Splitter',
        theme: ThemeData(
          primarySwatch: Colors.teal, // Or any color you like
           // Use Material 3 design
           useMaterial3: true,
           // Define a color scheme for better M3 compatibility
           colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light, // Or Brightness.dark
           ),
          // Optional: Customize input decoration globally
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          ),
           // Optional: Customize button styles
          elevatedButtonTheme: ElevatedButtonThemeData(
             style: ElevatedButton.styleFrom(
               padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
             ),
          ),
          // Define text themes if needed
          // textTheme: ...,
          appBarTheme: const AppBarTheme(
             elevation: 2, // Add subtle elevation
             // centerTitle: true, // Optional: Center titles
          )
        ),
        darkTheme: ThemeData( // Optional Dark Theme
           useMaterial3: true,
           colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
           ),
           inputDecorationTheme: const InputDecorationTheme(
             border: OutlineInputBorder(),
             contentPadding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
           ),
           elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
              ),
           ),
           // appBarTheme: ...
        ),
        themeMode: ThemeMode.system, // Or ThemeMode.light / ThemeMode.dark
        home: const HomeScreen(),
      ),
    );
  }
}