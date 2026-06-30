import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class SearchPage extends StatelessWidget {
  const SearchPage({super.key, @QueryParam('q') this.q = ''});
  final String q;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Search: $q')));
}
