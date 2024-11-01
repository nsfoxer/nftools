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
