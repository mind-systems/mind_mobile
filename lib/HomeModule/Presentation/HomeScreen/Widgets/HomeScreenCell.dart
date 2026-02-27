import 'package:flutter/material.dart';
import 'package:mind/HomeModule/Presentation/HomeScreen/Models/ModuleItem.dart';
import 'package:mind/Views/app_dimensions.dart';

class HomeScreenCell extends StatelessWidget {
  final ModuleItem item;

  const HomeScreenCell({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(kCardCornerRadius),
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(kCardCornerRadius),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(onSurface, BlendMode.srcIn),
                  child: Image.asset(item.iconPath, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          item.title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: onSurface,
              ),
        ),
      ],
    );
  }
}
