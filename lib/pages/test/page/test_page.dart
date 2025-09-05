import 'dart:io';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:nftools/utils/utils.dart';

import '../../../utils/nf_widgets.dart';

class TestPage extends StatelessWidget {

  const TestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage.withPadding(
        header: PageHeader(title: const Text("测试")),
        content:
        Center(child: ProgressBar(value: 10, backgroundColor: isDark(context) ? const Color(0xFF333333) : null,))

    );
  }
}
