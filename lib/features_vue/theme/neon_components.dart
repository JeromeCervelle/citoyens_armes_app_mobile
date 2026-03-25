import 'dart:ui';
import 'package:flutter/material.dart';

class NeonBackground extends StatelessWidget {
  const NeonBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF050B18),
        child: CustomPaint(painter: GridPainter()));
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FF85).withOpacity(0.05)
      ..strokeWidth = 1.5;
    for (var i = -100; i < size.width + 100; i += 40) {
      canvas.drawLine(
          Offset(i.toDouble(), 0), Offset(i.toDouble() - 200, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? accentColor;

  const GlassCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.accentColor});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor?.withOpacity(0.2) ??
                      Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(icon, color: accentColor ?? Colors.white, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  final String title;
  final Color color;

  const GameCard({super.key, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withOpacity(0.3), color.withOpacity(0.8)]),
      ),
      child: Center(
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }
}

class TournamentTile extends StatelessWidget {
  final String title;
  final String game;
  final String status;

  const TournamentTile(
      {super.key,
      required this.title,
      required this.game,
      required this.status});

  Color _getStatusColor() {
    switch (status.toUpperCase()) {
      case 'ONGOING':
      case 'IN_PROGRESS':
      case 'STARTED':
        return const Color(0xFF00FF85); // Neon Green
      case 'OPEN':
        return const Color(0xFF3B82F6); // Blue
      case 'DRAFT':
        return Colors.orangeAccent;
      case 'FINISHED':
        return Colors.white54;
      case 'CANCELLED':
        return Colors.redAccent;
      default:
        return const Color(0xFF00FF85);
    }
  }

  String _getStatusLabel() {
    switch (status.toUpperCase()) {
      case 'ONGOING':
      case 'IN_PROGRESS':
      case 'STARTED':
        return 'EN COURS';
      case 'OPEN':
        return 'OUVERT';
      case 'DRAFT':
        return 'BROUILLON';
      case 'FINISHED':
        return 'TERMINÉ';
      case 'CANCELLED':
        return 'ANNULÉ';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withOpacity(0.15), width: 1),
            boxShadow: [
              if (status.toUpperCase() == 'ONGOING')
                BoxShadow(
                  color: statusColor.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sports_esports, color: statusColor, size: 26),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getStatusLabel(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      game,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: statusColor.withOpacity(0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class MatchNeonCard extends StatelessWidget {
  final String team1;
  final String team2;
  final int score1;
  final int score2;
  final String tournamentName;

  const MatchNeonCard({
    super.key,
    required this.team1,
    required this.team2,
    required this.score1,
    required this.score2,
    required this.tournamentName,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 220,
          margin: const EdgeInsets.only(right: 15),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00FF85).withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tournamentName.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF00FF85),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(team1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 10),
                  Text("$score1", style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(team2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 10),
                  Text("$score2", style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF85).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  "EN COURS",
                  style: TextStyle(color: Color(0xFF00FF85), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
