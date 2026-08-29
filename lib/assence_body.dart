import 'package:flutter/material.dart';
import 'package:assence/assence_list.dart';

class AssenceBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        // Expanded(flex: 1, child: AssenceStories()),
        Flexible(child: AssenceList())
      ],
    );
  }
}
