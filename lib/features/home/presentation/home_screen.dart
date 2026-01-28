import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.school,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Faculty Pedia',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),

          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh data
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner
              _buildWelcomeBanner(context, authState),
              
              const SizedBox(height: 24),
              
              // Exam Categories
              _buildExamCategories(context),
              
              const SizedBox(height: 24),
              
              // Features Section
              _buildFeaturesSection(context),
              
              const SizedBox(height: 24),
              
              // Quick Actions
              _buildQuickActions(context),
              
              const SizedBox(height: 24),
              
              // Stats Section
              _buildStatsSection(context),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, AuthState authState) {
    final banners = [
      {
        'title': 'Meet your favorite educators',
        'subtitle': 'Join live classes and webinars with top educators',
        'gradient': [AppColors.primary, AppColors.primaryDark],
      },
      {
        'title': 'Start teaching online',
        'subtitle': 'Become an educator and share your knowledge',
        'gradient': [AppColors.secondary, AppColors.secondaryDark],
      },
      {
        'title': 'Prepare for exams',
        'subtitle': 'Access test series and study materials',
        'gradient': [AppColors.accent, AppColors.accentDark],
      },
    ];

    return CarouselSlider(
      options: CarouselOptions(
        height: 180,
        autoPlay: true,
        autoPlayInterval: const Duration(seconds: 5),
        enlargeCenterPage: true,
        viewportFraction: 0.9,
      ),
      items: banners.map((banner) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: banner['gradient'] as List<Color>,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (banner['gradient'] as List<Color>).first.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  banner['title'] as String,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  banner['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExamCategories(BuildContext context) {
    final exams = [
      {'name': 'IIT-JEE', 'icon': Icons.science, 'color': AppColors.primary, 'route': '/exam/iit-jee'},
      {'name': 'NEET', 'icon': Icons.medical_services, 'color': AppColors.secondary, 'route': '/exam/neet'},
      {'name': 'CBSE', 'icon': Icons.school, 'color': AppColors.accent, 'route': '/exam/cbse'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Exam Preparation',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              TextButton(
                onPressed: () => context.go('/exams'),
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // ✅ CENTER
            children: exams.map((exam) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () => context.push(exam['route'] as String),
                  child: Container(
                    width: 110,
                    height: 120,
                    decoration: BoxDecoration(
                      color: (exam['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (exam['color'] as Color).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: exam['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            exam['icon'] as IconData,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          exam['name'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: exam['color'] as Color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final features = [
      {'name': 'Courses', 'icon': Icons.play_circle_outline, 'route': '/courses'},
      {'name': 'Test Series', 'icon': Icons.assignment_outlined, 'route': '/test-series'},
      {'name': 'Webinars', 'icon': Icons.videocam_outlined, 'route': '/webinars'},
      {'name': 'Educators', 'icon': Icons.people_outline, 'route': '/educators'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Explore Features',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return GestureDetector(
                onTap: () => context.push(feature['route'] as String),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.grey100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        feature['icon'] as IconData,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feature['name'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          IntrinsicHeight( // ✅ makes both children match tallest height
            child: Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.play_circle_fill,
                    title: 'Start Learning',
                    subtitle: 'Browse courses',
                    color: AppColors.primary,
                    onTap: () => context.push('/courses'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.assignment,
                    title: 'Take Test',
                    subtitle: 'Practice now',
                    color: AppColors.secondary,
                    onTap: () => context.push('/test-series'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: double.infinity, // ✅ important
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, // ✅ IMPORTANT

            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // ✅ IMPORTANT
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.8),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final stats = [
      {'label': 'Educators', 'value': '500+', 'icon': Icons.people},
      {'label': 'Courses', 'value': '1000+', 'icon': Icons.play_circle},
      {'label': 'Students', 'value': '10K+', 'icon': Icons.school},
      {'label': 'Tests', 'value': '5000+', 'icon': Icons.assignment},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trusted by thousands',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: stats.map((stat) {
              return Column(
                children: [
                  Icon(
                    stat['icon'] as IconData,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stat['value'] as String,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stat['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
