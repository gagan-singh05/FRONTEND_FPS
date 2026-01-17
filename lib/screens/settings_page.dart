import 'package:flutter/material.dart';
import '../theme/palette.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final allPalettes = PaletteManager.all;
    final currentIndex = PaletteManager.index;

    return Scaffold(
      backgroundColor: kBgBottom,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: kBgTop,
        foregroundColor: kTextPrimary,
        elevation: 0,
      ),
      body: ValueListenableBuilder<AppPalette>(
        valueListenable: PaletteManager.instance,
        builder: (context, palette, _) {
          final currentIndex = PaletteManager.index;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a theme that suits your style.',
                  style: TextStyle(
                    color: kTextPrimary.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: allPalettes.length,
                  itemBuilder: (context, index) {
                    final itemPalette = allPalettes[index];
                    final isSelected = index == currentIndex;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => PaletteManager.setTheme(index),
                        customBorder: const CircleBorder(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: itemPalette.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? kTextPrimary : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: itemPalette.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'v1.0.0',
                    style: TextStyle(
                      color: kTextPrimary.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
