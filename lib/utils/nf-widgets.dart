import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/common/style.dart';

// card 内容体
class NFCardContent extends StatelessWidget {
  NFCardContent({Key? key, required this.child}) : super(key: key);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(NFLayout.v2),
      padding: const EdgeInsets.all(NFLayout.v1),
      decoration: BoxDecoration(
        border: Border.all(color: FluentTheme.of(context).cardColor, width: 1),
        borderRadius: BorderRadius.circular(10.0),
        color: FluentTheme.of(context).cardColor
      ),
      child: child,
    );
  }
}

class NFCard extends StatelessWidget {
  const NFCard({super.key, required this.title, required this.child});
  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    Typography typography = FluentTheme.of(context).typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: typography.subtitle),
        NFLayout.vlineh2,
        NFCardContent(child: child),
        NFLayout.vlineh1,
      ],
    );
  }
}

// 加载组件
class LoadingWidgets extends StatelessWidget {
  final Widget child;
  final bool loading;

  const LoadingWidgets(
      {super.key,
        required this.child,
        required this.loading,
        });

  @override
  Widget build(BuildContext context) {
    if (!loading) {
      return child;
    }
    return IgnorePointer(child:  Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: child,
        ),
         const Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             ProgressRing(),
             NFLayout.vlineh1,
             Text("加载中...")
           ],
         ),
      ],
    ));
  }
}
