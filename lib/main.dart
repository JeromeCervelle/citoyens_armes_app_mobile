import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'Tournois/repository_tournois.dart';
import 'Tournois/view_tournois_list.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TournamentApiService>(create: (_) => TournamentApiService()),
      ],
      child: MaterialApp(
        title: 'Citoyens Armes',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const TournamentListScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
