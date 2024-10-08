import 'package:flutter/material.dart';
import 'package:nftools/common/style.dart';

class NFCard extends StatelessWidget {
  const NFCard({Key? key, required this.child}) : super(key: key);
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(NFLayout.v1),
      padding: EdgeInsets.all(NFLayout.v2),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: child,
    );
  }
}
