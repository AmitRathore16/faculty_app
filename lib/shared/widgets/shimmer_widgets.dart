import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

class AppShimmer extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? child;
  
  const AppShimmer({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.grey800 : AppColors.grey200,
      highlightColor: isDark ? AppColors.grey700 : AppColors.grey100,
      child: child ?? Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.grey800 : AppColors.grey200,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  final double? width;
  final double height;
  
  const ShimmerCard({
    super.key,
    this.width,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Flexible(
            child: AppShimmer(
              height: double.infinity,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppShimmer(height: 16, width: double.infinity),
                  const SizedBox(height: 8),
                  AppShimmer(height: 12, width: MediaQuery.of(context).size.width * 0.6),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const AppShimmer(height: 24, width: 24, borderRadius: BorderRadius.all(Radius.circular(12))),
                      const SizedBox(width: 8),
                      Expanded(child: AppShimmer(height: 12, width: MediaQuery.of(context).size.width * 0.3)),
                    ],
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsets? padding;
  
  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 80,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding ?? const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Row(
            children: [
              AppShimmer(
                width: itemHeight,
                height: itemHeight,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppShimmer(height: 14, width: double.infinity),
                      const SizedBox(height: 8),
                      AppShimmer(height: 12, width: MediaQuery.of(context).size.width * 0.4),
                      const SizedBox(height: 10,),
                      AppShimmer(height: 10, width: MediaQuery.of(context).size.width * 0.3),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        );
      },
    );
  }
}
