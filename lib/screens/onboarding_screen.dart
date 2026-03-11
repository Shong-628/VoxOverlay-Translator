import 'package:flutter/material.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> slides = [
    {
      "title": "Welcome",
      "desc": "This app provides real-time translation using offline speech recognition.",
      "icon": "👋",
    },
    {
      "title": "Screen Recording Permission",
      "desc": "The app requires MediaProjection permission to capture audio from the device speaker. All processing is done locally.",
      "icon": "🛡️",
    },
    {
      "title": "Floating Overlay",
      "desc": "The translation will appear in a floating overlay. You can drag or hide the overlay anytime.",
      "icon": "☁️",
    },
    {
      "title": "You're Ready!",
      "desc": "Press Get Started to begin using the application.",
      "icon": "🚀",
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use secondary background color for a modern feel
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button at the top
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _controller.jumpToPage(slides.length - 1),
                child: const Text("Skip"),
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  return OnboardingSlide(
                    title: slides[index]["title"]!,
                    desc: slides[index]["desc"]!,
                    icon: slides[index]["icon"]!,
                  );
                },
              ),
            ),

            // Bottom UI Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  // Custom Smooth Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                          (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Dynamic Button (Next vs Get Started)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == slides.length - 1) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == slides.length - 1 ? "Get Started" : "Next",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingSlide extends StatelessWidget {
  final String title, desc, icon;
  const OnboardingSlide({
    super.key,
    required this.title,
    required this.desc,
    required this.icon
  });

  @override
  Widget build(BuildContext context) {
    // This grabs the appropriate text color for the current background
    final Color textColor = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              // Use opacity on the theme color instead of a fixed grey
              color: textColor.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}