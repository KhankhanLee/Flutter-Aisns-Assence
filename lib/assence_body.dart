import 'package:flutter/material.dart';
import 'package:assence/assence_list.dart';

class AssenceBody extends StatelessWidget {
  const AssenceBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Flexible(child: AssenceList()),
      ],
    );
  }
}
