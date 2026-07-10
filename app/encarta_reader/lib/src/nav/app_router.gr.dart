// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [ArticlePage]
class ArticleRoute extends PageRouteInfo<ArticleRouteArgs> {
  ArticleRoute({
    Key? key,
    required int refid,
    String? paraId,
    List<PageRouteInfo>? children,
  }) : super(
         ArticleRoute.name,
         args: ArticleRouteArgs(key: key, refid: refid, paraId: paraId),
         rawPathParams: {'refid': refid},
         rawQueryParams: {'para': paraId},
         initialChildren: children,
       );

  static const String name = 'ArticleRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final queryParams = data.queryParams;
      final args = data.argsAs<ArticleRouteArgs>(
        orElse: () => ArticleRouteArgs(
          refid: pathParams.getInt('refid'),
          paraId: queryParams.optString('para'),
        ),
      );
      return ArticlePage(key: args.key, refid: args.refid, paraId: args.paraId);
    },
  );
}

class ArticleRouteArgs {
  const ArticleRouteArgs({this.key, required this.refid, this.paraId});

  final Key? key;

  final int refid;

  final String? paraId;

  @override
  String toString() {
    return 'ArticleRouteArgs{key: $key, refid: $refid, paraId: $paraId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArticleRouteArgs) return false;
    return key == other.key && refid == other.refid && paraId == other.paraId;
  }

  @override
  int get hashCode => key.hashCode ^ refid.hashCode ^ paraId.hashCode;
}

/// generated route for
/// [HomePage]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomePage();
    },
  );
}

/// generated route for
/// [MindMazePage]
class MindMazeRoute extends PageRouteInfo<void> {
  const MindMazeRoute({List<PageRouteInfo>? children})
    : super(MindMazeRoute.name, initialChildren: children);

  static const String name = 'MindMazeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MindMazePage();
    },
  );
}

/// generated route for
/// [SearchPage]
class SearchRoute extends PageRouteInfo<SearchRouteArgs> {
  SearchRoute({Key? key, String q = '', List<PageRouteInfo>? children})
    : super(
        SearchRoute.name,
        args: SearchRouteArgs(key: key, q: q),
        rawQueryParams: {'q': q},
        initialChildren: children,
      );

  static const String name = 'SearchRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final queryParams = data.queryParams;
      final args = data.argsAs<SearchRouteArgs>(
        orElse: () => SearchRouteArgs(q: queryParams.getString('q', '')),
      );
      return SearchPage(key: args.key, q: args.q);
    },
  );
}

class SearchRouteArgs {
  const SearchRouteArgs({this.key, this.q = ''});

  final Key? key;

  final String q;

  @override
  String toString() {
    return 'SearchRouteArgs{key: $key, q: $q}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchRouteArgs) return false;
    return key == other.key && q == other.q;
  }

  @override
  int get hashCode => key.hashCode ^ q.hashCode;
}

/// generated route for
/// [ToursPage]
class ToursRoute extends PageRouteInfo<ToursRouteArgs> {
  ToursRoute({
    Key? key,
    required String tourId,
    AssetBundle? bundleOverride,
    List<PageRouteInfo>? children,
  }) : super(
         ToursRoute.name,
         args: ToursRouteArgs(
           key: key,
           tourId: tourId,
           bundleOverride: bundleOverride,
         ),
         rawPathParams: {'tourId': tourId},
         initialChildren: children,
       );

  static const String name = 'ToursRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ToursRouteArgs>(
        orElse: () => ToursRouteArgs(tourId: pathParams.getString('tourId')),
      );
      return ToursPage(
        key: args.key,
        tourId: args.tourId,
        bundleOverride: args.bundleOverride,
      );
    },
  );
}

class ToursRouteArgs {
  const ToursRouteArgs({this.key, required this.tourId, this.bundleOverride});

  final Key? key;

  final String tourId;

  final AssetBundle? bundleOverride;

  @override
  String toString() {
    return 'ToursRouteArgs{key: $key, tourId: $tourId, bundleOverride: $bundleOverride}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ToursRouteArgs) return false;
    return key == other.key &&
        tourId == other.tourId &&
        bundleOverride == other.bundleOverride;
  }

  @override
  int get hashCode => key.hashCode ^ tourId.hashCode ^ bundleOverride.hashCode;
}
