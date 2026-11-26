import 'package:flutter/widgets.dart';

/// Keeps an already visited page and its descendants mounted between tab visits.
/// Removing the surrounding account/app shell still disposes the whole subtree.
class RetainedTab extends StatefulWidget {
  const RetainedTab({super.key, required this.child});

  final Widget child;

  @override
  State<RetainedTab> createState() => _RetainedTabState();
}

class _RetainedTabState extends State<RetainedTab>
    with AutomaticKeepAliveClientMixin<RetainedTab> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
