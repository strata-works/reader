import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ArticlePage extends StatelessWidget {
  const ArticlePage({
    super.key,
    @PathParam('refid') required this.refid,
    @QueryParam('para') this.paraId,
  });
  final int refid;
  final String? paraId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Article $refid')));
}
