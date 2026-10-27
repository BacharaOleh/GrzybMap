import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'O aplikacji i Zasady',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App header
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.emeraldDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.emeraldNeon, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emeraldNeon.withValues(alpha: 0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🍄', style: TextStyle(fontSize: 32)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'GrzybMap Polska',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Wersja 1.0 • Radar Grzybiarza & BDL',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Card 1: Jak działa aplikacja
          _buildInfoSection(
            icon: Icons.lightbulb_outline,
            iconColor: AppColors.emeraldNeon,
            title: 'Jak działa GrzybMap?',
            content:
                'Aplikacja łączy oficjalne dane Banku Danych o Lasach (BDL) Lasów Państwowych '
                'z historią opadów deszczu z ostatnich 10 dni (Open-Meteo). '
                'Na tej podstawie algorytm szacuje prawdopodobieństwo występowania '
                'poszczególnych gatunków grzybów w wybranym fragmencie lasu.',
          ),
          const SizedBox(height: 14),

          // Card 2: Zasady zbioru w Polsce
          _buildInfoSection(
            icon: Icons.gavel,
            iconColor: AppColors.goldAmber,
            title: 'Zasady zbioru w Lasach Państwowych',
            content:
                '• W Polsce zbiór grzybów w lasach państwowych jest całkowicie darmowy i dozwolony dla każdego.\n'
                '• ZAKAZ zbierania obowiązuje w: rezerwatach przyrody, parkach narodowych, '
                'uprawach leśnych do 4m wysokości oraz drzewostanach nasiennych.\n'
                '• Samochód należy zostawiać WYŁĄCZNIE na wyznaczonych miejscach postoju leśnego (parkingach).',
          ),
          const SizedBox(height: 14),

          // Card 3: Bezpieczeństwo
          _buildInfoSection(
            icon: Icons.health_and_safety_outlined,
            iconColor: AppColors.danger,
            title: 'Złota zasada bezpieczeństwa',
            content:
                '⚠️ Zbieraj TYLKO te grzyby, co do których masz 100% pewności! '
                'Aplikacja jest asystentem i nie zastępuje wiedzy atlasowej. '
                'Zwracaj szczególną uwagę na ostrzeżenia o trujących sobowtórach.',
          ),
          const SizedBox(height: 14),

          // Card 4: Zrzeczenie się odpowiedzialności (Legal Disclaimer)
          _buildInfoSection(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFFEF4444),
            title: 'Oświadczenie prawne i zrzeczenie się odpowiedzialności',
            content:
                '1. Aplikacja GrzybMap Polska ma charakter wyłącznie edukacyjno-informacyjny i modeluje prawdopodobieństwo na podstawie otwartych danych BDL i Open-Meteo.\n\n'
                '2. Aplikacja NIE jest narzędziem diagnostycznym, nie zastępuje certyfikowanego mykologa i NIE daje 100% gwarancji jadalności znalezionych grzybów.\n\n'
                '3. Spożycie gatunków silnie trujących (zwłaszcza Muchomora sromotnikowego) może prowadzić do zgonu lub trwałego inwalidztwa.\n\n'
                '4. Twórcy aplikacji nie ponoszą jakiejkolwiek odpowiedzialności za zatrucia, błędy rozpoznania gatunków ani szkody wynikłe z niewłaściwego korzystania z aplikacji.',
          ),
          const SizedBox(height: 24),

          // Footer
          const Center(
            child: Text(
              'Dane leśne: Bank Danych o Lasach (BDL)\n'
              'Dane pogodowe: Open-Meteo API\n'
              'Fotografie atlasowe: Wikimedia Commons (CC-BY-SA / Public Domain)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textDim, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
