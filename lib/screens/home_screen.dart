import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../theme.dart';
import '../utils.dart';
import 'chat_screen.dart';
import 'dashboard_tab.dart';
import 'documents_tab.dart';
import 'progress_tab.dart';
import 'quiz_screen.dart';

/// The main shell: 5 tabs with a bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;

  // Plays a soft fade + rise every time the person switches tab.
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardTab(onGoTo: _go),
      const ChatScreen(),
      const DocumentsTab(),
      const QuizScreen(),
      const ProgressTab(),
    ];
  }

  void _go(int i) {
    setState(() => _index = i);
    tabChanged.value = i;
    _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // Light headers need dark status-bar icons, dark headers need light ones.
    // Tabs with the vivid gradient header need light icons. The AI Tutor tab
    // has a plain surface header, so in light mode it needs dark icons.
    final overlay = (context.isDark || _index != 1)
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(
                begin: const Offset(0, 0.015), end: Offset.zero)
                .animate(CurvedAnimation(
                parent: _fade, curve: Curves.easeOutCubic)),
            child: IndexedStack(index: _index, children: _pages),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.hairline)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _go,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: _Pop(Icon(Icons.home)),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.smart_toy_outlined),
                  selectedIcon: _Pop(Icon(Icons.smart_toy)),
                  label: 'AI Tutor'),
              NavigationDestination(
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  selectedIcon: _Pop(Icon(Icons.picture_as_pdf)),
                  label: 'PDFs'),
              NavigationDestination(
                  icon: Icon(Icons.quiz_outlined),
                  selectedIcon: _Pop(Icon(Icons.quiz)),
                  label: 'Quizzes'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: _Pop(Icon(Icons.bar_chart)),
                  label: 'Progress'),
            ],
          ),
        ),
      ),
    );
  }
}


/// Makes the selected tab icon pop in with a little bounce.
class _Pop extends StatelessWidget {
  const _Pop(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.55, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}