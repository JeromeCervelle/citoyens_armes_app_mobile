import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'Tournois/repository_tournois.dart';
import 'match/services/match_api_service.dart';
import 'features_vue/dashboard_view.dart';

import 'Rounds/round_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

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
        Provider<MatchApiService>(create: (_) => MatchApiService()),

        Provider<RoundService>(create: (_) => RoundService()),
      ],
      child: MaterialApp(
        title: 'Citoyens Armes',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF050B18),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00FF85),
            primary: const Color(0xFF00FF85),
          ),
        ),
        home: const DashboardView(),
        navigatorObservers: [routeObserver],
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
