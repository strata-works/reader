// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class Article extends Table with TableInfo<Article, ArticleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Article(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _refidMeta = const VerificationMeta('refid');
  late final GeneratedColumn<int> refid = GeneratedColumn<int>(
    'refid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _xmlMeta = const VerificationMeta('xml');
  late final GeneratedColumn<Uint8List> xml = GeneratedColumn<Uint8List>(
    'xml',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [refid, source, title, xml];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'article';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('refid')) {
      context.handle(
        _refidMeta,
        refid.isAcceptableOrUnknown(data['refid']!, _refidMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('xml')) {
      context.handle(
        _xmlMeta,
        xml.isAcceptableOrUnknown(data['xml']!, _xmlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {refid};
  @override
  ArticleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleData(
      refid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refid'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      xml: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}xml'],
      ),
    );
  }

  @override
  Article createAlias(String alias) {
    return Article(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ArticleData extends DataClass implements Insertable<ArticleData> {
  final int refid;
  final String? source;
  final String? title;
  final Uint8List? xml;
  const ArticleData({required this.refid, this.source, this.title, this.xml});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['refid'] = Variable<int>(refid);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || xml != null) {
      map['xml'] = Variable<Uint8List>(xml);
    }
    return map;
  }

  ArticleCompanion toCompanion(bool nullToAbsent) {
    return ArticleCompanion(
      refid: Value(refid),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      xml: xml == null && nullToAbsent ? const Value.absent() : Value(xml),
    );
  }

  factory ArticleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleData(
      refid: serializer.fromJson<int>(json['refid']),
      source: serializer.fromJson<String?>(json['source']),
      title: serializer.fromJson<String?>(json['title']),
      xml: serializer.fromJson<Uint8List?>(json['xml']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'refid': serializer.toJson<int>(refid),
      'source': serializer.toJson<String?>(source),
      'title': serializer.toJson<String?>(title),
      'xml': serializer.toJson<Uint8List?>(xml),
    };
  }

  ArticleData copyWith({
    int? refid,
    Value<String?> source = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<Uint8List?> xml = const Value.absent(),
  }) => ArticleData(
    refid: refid ?? this.refid,
    source: source.present ? source.value : this.source,
    title: title.present ? title.value : this.title,
    xml: xml.present ? xml.value : this.xml,
  );
  ArticleData copyWithCompanion(ArticleCompanion data) {
    return ArticleData(
      refid: data.refid.present ? data.refid.value : this.refid,
      source: data.source.present ? data.source.value : this.source,
      title: data.title.present ? data.title.value : this.title,
      xml: data.xml.present ? data.xml.value : this.xml,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticleData(')
          ..write('refid: $refid, ')
          ..write('source: $source, ')
          ..write('title: $title, ')
          ..write('xml: $xml')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(refid, source, title, $driftBlobEquality.hash(xml));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticleData &&
          other.refid == this.refid &&
          other.source == this.source &&
          other.title == this.title &&
          $driftBlobEquality.equals(other.xml, this.xml));
}

class ArticleCompanion extends UpdateCompanion<ArticleData> {
  final Value<int> refid;
  final Value<String?> source;
  final Value<String?> title;
  final Value<Uint8List?> xml;
  const ArticleCompanion({
    this.refid = const Value.absent(),
    this.source = const Value.absent(),
    this.title = const Value.absent(),
    this.xml = const Value.absent(),
  });
  ArticleCompanion.insert({
    this.refid = const Value.absent(),
    this.source = const Value.absent(),
    this.title = const Value.absent(),
    this.xml = const Value.absent(),
  });
  static Insertable<ArticleData> custom({
    Expression<int>? refid,
    Expression<String>? source,
    Expression<String>? title,
    Expression<Uint8List>? xml,
  }) {
    return RawValuesInsertable({
      if (refid != null) 'refid': refid,
      if (source != null) 'source': source,
      if (title != null) 'title': title,
      if (xml != null) 'xml': xml,
    });
  }

  ArticleCompanion copyWith({
    Value<int>? refid,
    Value<String?>? source,
    Value<String?>? title,
    Value<Uint8List?>? xml,
  }) {
    return ArticleCompanion(
      refid: refid ?? this.refid,
      source: source ?? this.source,
      title: title ?? this.title,
      xml: xml ?? this.xml,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (refid.present) {
      map['refid'] = Variable<int>(refid.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (xml.present) {
      map['xml'] = Variable<Uint8List>(xml.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticleCompanion(')
          ..write('refid: $refid, ')
          ..write('source: $source, ')
          ..write('title: $title, ')
          ..write('xml: $xml')
          ..write(')'))
        .toString();
  }
}

class Asset extends Table with TableInfo<Asset, AssetData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Asset(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _baggageIdMeta = const VerificationMeta(
    'baggageId',
  );
  late final GeneratedColumn<String> baggageId = GeneratedColumn<String>(
    'baggage_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    baggageId,
    hash,
    kind,
    ext,
    path,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('baggage_id')) {
      context.handle(
        _baggageIdMeta,
        baggageId.isAcceptableOrUnknown(data['baggage_id']!, _baggageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_baggageIdMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {baggageId};
  @override
  AssetData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetData(
      baggageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baggage_id'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
    );
  }

  @override
  Asset createAlias(String alias) {
    return Asset(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class AssetData extends DataClass implements Insertable<AssetData> {
  final String baggageId;
  final String? hash;
  final String? kind;
  final String? ext;
  final String? path;
  final String? source;
  const AssetData({
    required this.baggageId,
    this.hash,
    this.kind,
    this.ext,
    this.path,
    this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['baggage_id'] = Variable<String>(baggageId);
    if (!nullToAbsent || hash != null) {
      map['hash'] = Variable<String>(hash);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || ext != null) {
      map['ext'] = Variable<String>(ext);
    }
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    return map;
  }

  AssetCompanion toCompanion(bool nullToAbsent) {
    return AssetCompanion(
      baggageId: Value(baggageId),
      hash: hash == null && nullToAbsent ? const Value.absent() : Value(hash),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      ext: ext == null && nullToAbsent ? const Value.absent() : Value(ext),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
    );
  }

  factory AssetData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetData(
      baggageId: serializer.fromJson<String>(json['baggage_id']),
      hash: serializer.fromJson<String?>(json['hash']),
      kind: serializer.fromJson<String?>(json['kind']),
      ext: serializer.fromJson<String?>(json['ext']),
      path: serializer.fromJson<String?>(json['path']),
      source: serializer.fromJson<String?>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'baggage_id': serializer.toJson<String>(baggageId),
      'hash': serializer.toJson<String?>(hash),
      'kind': serializer.toJson<String?>(kind),
      'ext': serializer.toJson<String?>(ext),
      'path': serializer.toJson<String?>(path),
      'source': serializer.toJson<String?>(source),
    };
  }

  AssetData copyWith({
    String? baggageId,
    Value<String?> hash = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    Value<String?> ext = const Value.absent(),
    Value<String?> path = const Value.absent(),
    Value<String?> source = const Value.absent(),
  }) => AssetData(
    baggageId: baggageId ?? this.baggageId,
    hash: hash.present ? hash.value : this.hash,
    kind: kind.present ? kind.value : this.kind,
    ext: ext.present ? ext.value : this.ext,
    path: path.present ? path.value : this.path,
    source: source.present ? source.value : this.source,
  );
  AssetData copyWithCompanion(AssetCompanion data) {
    return AssetData(
      baggageId: data.baggageId.present ? data.baggageId.value : this.baggageId,
      hash: data.hash.present ? data.hash.value : this.hash,
      kind: data.kind.present ? data.kind.value : this.kind,
      ext: data.ext.present ? data.ext.value : this.ext,
      path: data.path.present ? data.path.value : this.path,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetData(')
          ..write('baggageId: $baggageId, ')
          ..write('hash: $hash, ')
          ..write('kind: $kind, ')
          ..write('ext: $ext, ')
          ..write('path: $path, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(baggageId, hash, kind, ext, path, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetData &&
          other.baggageId == this.baggageId &&
          other.hash == this.hash &&
          other.kind == this.kind &&
          other.ext == this.ext &&
          other.path == this.path &&
          other.source == this.source);
}

class AssetCompanion extends UpdateCompanion<AssetData> {
  final Value<String> baggageId;
  final Value<String?> hash;
  final Value<String?> kind;
  final Value<String?> ext;
  final Value<String?> path;
  final Value<String?> source;
  final Value<int> rowid;
  const AssetCompanion({
    this.baggageId = const Value.absent(),
    this.hash = const Value.absent(),
    this.kind = const Value.absent(),
    this.ext = const Value.absent(),
    this.path = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetCompanion.insert({
    required String baggageId,
    this.hash = const Value.absent(),
    this.kind = const Value.absent(),
    this.ext = const Value.absent(),
    this.path = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : baggageId = Value(baggageId);
  static Insertable<AssetData> custom({
    Expression<String>? baggageId,
    Expression<String>? hash,
    Expression<String>? kind,
    Expression<String>? ext,
    Expression<String>? path,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (baggageId != null) 'baggage_id': baggageId,
      if (hash != null) 'hash': hash,
      if (kind != null) 'kind': kind,
      if (ext != null) 'ext': ext,
      if (path != null) 'path': path,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetCompanion copyWith({
    Value<String>? baggageId,
    Value<String?>? hash,
    Value<String?>? kind,
    Value<String?>? ext,
    Value<String?>? path,
    Value<String?>? source,
    Value<int>? rowid,
  }) {
    return AssetCompanion(
      baggageId: baggageId ?? this.baggageId,
      hash: hash ?? this.hash,
      kind: kind ?? this.kind,
      ext: ext ?? this.ext,
      path: path ?? this.path,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (baggageId.present) {
      map['baggage_id'] = Variable<String>(baggageId.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetCompanion(')
          ..write('baggageId: $baggageId, ')
          ..write('hash: $hash, ')
          ..write('kind: $kind, ')
          ..write('ext: $ext, ')
          ..write('path: $path, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Media extends Table with TableInfo<Media, MediaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Media(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _refidMeta = const VerificationMeta('refid');
  late final GeneratedColumn<int> refid = GeneratedColumn<int>(
    'refid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _groupMeta = const VerificationMeta('group');
  late final GeneratedColumn<String> group = GeneratedColumn<String>(
    'group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _creditMeta = const VerificationMeta('credit');
  late final GeneratedColumn<String> credit = GeneratedColumn<String>(
    'credit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    refid,
    group,
    title,
    credit,
    caption,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('refid')) {
      context.handle(
        _refidMeta,
        refid.isAcceptableOrUnknown(data['refid']!, _refidMeta),
      );
    }
    if (data.containsKey('group')) {
      context.handle(
        _groupMeta,
        group.isAcceptableOrUnknown(data['group']!, _groupMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('credit')) {
      context.handle(
        _creditMeta,
        credit.isAcceptableOrUnknown(data['credit']!, _creditMeta),
      );
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {refid};
  @override
  MediaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaData(
      refid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refid'],
      )!,
      group: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      credit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credit'],
      ),
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
    );
  }

  @override
  Media createAlias(String alias) {
    return Media(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class MediaData extends DataClass implements Insertable<MediaData> {
  final int refid;
  final String? group;
  final String? title;
  final String? credit;
  final String? caption;
  final String? source;
  const MediaData({
    required this.refid,
    this.group,
    this.title,
    this.credit,
    this.caption,
    this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['refid'] = Variable<int>(refid);
    if (!nullToAbsent || group != null) {
      map['group'] = Variable<String>(group);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || credit != null) {
      map['credit'] = Variable<String>(credit);
    }
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    return map;
  }

  MediaCompanion toCompanion(bool nullToAbsent) {
    return MediaCompanion(
      refid: Value(refid),
      group: group == null && nullToAbsent
          ? const Value.absent()
          : Value(group),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      credit: credit == null && nullToAbsent
          ? const Value.absent()
          : Value(credit),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
    );
  }

  factory MediaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaData(
      refid: serializer.fromJson<int>(json['refid']),
      group: serializer.fromJson<String?>(json['group']),
      title: serializer.fromJson<String?>(json['title']),
      credit: serializer.fromJson<String?>(json['credit']),
      caption: serializer.fromJson<String?>(json['caption']),
      source: serializer.fromJson<String?>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'refid': serializer.toJson<int>(refid),
      'group': serializer.toJson<String?>(group),
      'title': serializer.toJson<String?>(title),
      'credit': serializer.toJson<String?>(credit),
      'caption': serializer.toJson<String?>(caption),
      'source': serializer.toJson<String?>(source),
    };
  }

  MediaData copyWith({
    int? refid,
    Value<String?> group = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> credit = const Value.absent(),
    Value<String?> caption = const Value.absent(),
    Value<String?> source = const Value.absent(),
  }) => MediaData(
    refid: refid ?? this.refid,
    group: group.present ? group.value : this.group,
    title: title.present ? title.value : this.title,
    credit: credit.present ? credit.value : this.credit,
    caption: caption.present ? caption.value : this.caption,
    source: source.present ? source.value : this.source,
  );
  MediaData copyWithCompanion(MediaCompanion data) {
    return MediaData(
      refid: data.refid.present ? data.refid.value : this.refid,
      group: data.group.present ? data.group.value : this.group,
      title: data.title.present ? data.title.value : this.title,
      credit: data.credit.present ? data.credit.value : this.credit,
      caption: data.caption.present ? data.caption.value : this.caption,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaData(')
          ..write('refid: $refid, ')
          ..write('group: $group, ')
          ..write('title: $title, ')
          ..write('credit: $credit, ')
          ..write('caption: $caption, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(refid, group, title, credit, caption, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaData &&
          other.refid == this.refid &&
          other.group == this.group &&
          other.title == this.title &&
          other.credit == this.credit &&
          other.caption == this.caption &&
          other.source == this.source);
}

class MediaCompanion extends UpdateCompanion<MediaData> {
  final Value<int> refid;
  final Value<String?> group;
  final Value<String?> title;
  final Value<String?> credit;
  final Value<String?> caption;
  final Value<String?> source;
  const MediaCompanion({
    this.refid = const Value.absent(),
    this.group = const Value.absent(),
    this.title = const Value.absent(),
    this.credit = const Value.absent(),
    this.caption = const Value.absent(),
    this.source = const Value.absent(),
  });
  MediaCompanion.insert({
    this.refid = const Value.absent(),
    this.group = const Value.absent(),
    this.title = const Value.absent(),
    this.credit = const Value.absent(),
    this.caption = const Value.absent(),
    this.source = const Value.absent(),
  });
  static Insertable<MediaData> custom({
    Expression<int>? refid,
    Expression<String>? group,
    Expression<String>? title,
    Expression<String>? credit,
    Expression<String>? caption,
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (refid != null) 'refid': refid,
      if (group != null) 'group': group,
      if (title != null) 'title': title,
      if (credit != null) 'credit': credit,
      if (caption != null) 'caption': caption,
      if (source != null) 'source': source,
    });
  }

  MediaCompanion copyWith({
    Value<int>? refid,
    Value<String?>? group,
    Value<String?>? title,
    Value<String?>? credit,
    Value<String?>? caption,
    Value<String?>? source,
  }) {
    return MediaCompanion(
      refid: refid ?? this.refid,
      group: group ?? this.group,
      title: title ?? this.title,
      credit: credit ?? this.credit,
      caption: caption ?? this.caption,
      source: source ?? this.source,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (refid.present) {
      map['refid'] = Variable<int>(refid.value);
    }
    if (group.present) {
      map['group'] = Variable<String>(group.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (credit.present) {
      map['credit'] = Variable<String>(credit.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaCompanion(')
          ..write('refid: $refid, ')
          ..write('group: $group, ')
          ..write('title: $title, ')
          ..write('credit: $credit, ')
          ..write('caption: $caption, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }
}

class MediaFile extends Table with TableInfo<MediaFile, MediaFileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MediaFile(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaRefidMeta = const VerificationMeta(
    'mediaRefid',
  );
  late final GeneratedColumn<int> mediaRefid = GeneratedColumn<int>(
    'media_refid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _baggageIdMeta = const VerificationMeta(
    'baggageId',
  );
  late final GeneratedColumn<String> baggageId = GeneratedColumn<String>(
    'baggage_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [mediaRefid, role, baggageId, ext];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_file';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaFileData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_refid')) {
      context.handle(
        _mediaRefidMeta,
        mediaRefid.isAcceptableOrUnknown(data['media_refid']!, _mediaRefidMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaRefidMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('baggage_id')) {
      context.handle(
        _baggageIdMeta,
        baggageId.isAcceptableOrUnknown(data['baggage_id']!, _baggageIdMeta),
      );
    }
    if (data.containsKey('ext')) {
      context.handle(
        _extMeta,
        ext.isAcceptableOrUnknown(data['ext']!, _extMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaRefid, role};
  @override
  MediaFileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaFileData(
      mediaRefid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_refid'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      baggageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baggage_id'],
      ),
      ext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ext'],
      ),
    );
  }

  @override
  MediaFile createAlias(String alias) {
    return MediaFile(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(media_refid, role)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class MediaFileData extends DataClass implements Insertable<MediaFileData> {
  final int mediaRefid;
  final String role;
  final String? baggageId;
  final String? ext;
  const MediaFileData({
    required this.mediaRefid,
    required this.role,
    this.baggageId,
    this.ext,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_refid'] = Variable<int>(mediaRefid);
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || baggageId != null) {
      map['baggage_id'] = Variable<String>(baggageId);
    }
    if (!nullToAbsent || ext != null) {
      map['ext'] = Variable<String>(ext);
    }
    return map;
  }

  MediaFileCompanion toCompanion(bool nullToAbsent) {
    return MediaFileCompanion(
      mediaRefid: Value(mediaRefid),
      role: Value(role),
      baggageId: baggageId == null && nullToAbsent
          ? const Value.absent()
          : Value(baggageId),
      ext: ext == null && nullToAbsent ? const Value.absent() : Value(ext),
    );
  }

  factory MediaFileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaFileData(
      mediaRefid: serializer.fromJson<int>(json['media_refid']),
      role: serializer.fromJson<String>(json['role']),
      baggageId: serializer.fromJson<String?>(json['baggage_id']),
      ext: serializer.fromJson<String?>(json['ext']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'media_refid': serializer.toJson<int>(mediaRefid),
      'role': serializer.toJson<String>(role),
      'baggage_id': serializer.toJson<String?>(baggageId),
      'ext': serializer.toJson<String?>(ext),
    };
  }

  MediaFileData copyWith({
    int? mediaRefid,
    String? role,
    Value<String?> baggageId = const Value.absent(),
    Value<String?> ext = const Value.absent(),
  }) => MediaFileData(
    mediaRefid: mediaRefid ?? this.mediaRefid,
    role: role ?? this.role,
    baggageId: baggageId.present ? baggageId.value : this.baggageId,
    ext: ext.present ? ext.value : this.ext,
  );
  MediaFileData copyWithCompanion(MediaFileCompanion data) {
    return MediaFileData(
      mediaRefid: data.mediaRefid.present
          ? data.mediaRefid.value
          : this.mediaRefid,
      role: data.role.present ? data.role.value : this.role,
      baggageId: data.baggageId.present ? data.baggageId.value : this.baggageId,
      ext: data.ext.present ? data.ext.value : this.ext,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaFileData(')
          ..write('mediaRefid: $mediaRefid, ')
          ..write('role: $role, ')
          ..write('baggageId: $baggageId, ')
          ..write('ext: $ext')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaRefid, role, baggageId, ext);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaFileData &&
          other.mediaRefid == this.mediaRefid &&
          other.role == this.role &&
          other.baggageId == this.baggageId &&
          other.ext == this.ext);
}

class MediaFileCompanion extends UpdateCompanion<MediaFileData> {
  final Value<int> mediaRefid;
  final Value<String> role;
  final Value<String?> baggageId;
  final Value<String?> ext;
  final Value<int> rowid;
  const MediaFileCompanion({
    this.mediaRefid = const Value.absent(),
    this.role = const Value.absent(),
    this.baggageId = const Value.absent(),
    this.ext = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaFileCompanion.insert({
    required int mediaRefid,
    required String role,
    this.baggageId = const Value.absent(),
    this.ext = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : mediaRefid = Value(mediaRefid),
       role = Value(role);
  static Insertable<MediaFileData> custom({
    Expression<int>? mediaRefid,
    Expression<String>? role,
    Expression<String>? baggageId,
    Expression<String>? ext,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaRefid != null) 'media_refid': mediaRefid,
      if (role != null) 'role': role,
      if (baggageId != null) 'baggage_id': baggageId,
      if (ext != null) 'ext': ext,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaFileCompanion copyWith({
    Value<int>? mediaRefid,
    Value<String>? role,
    Value<String?>? baggageId,
    Value<String?>? ext,
    Value<int>? rowid,
  }) {
    return MediaFileCompanion(
      mediaRefid: mediaRefid ?? this.mediaRefid,
      role: role ?? this.role,
      baggageId: baggageId ?? this.baggageId,
      ext: ext ?? this.ext,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaRefid.present) {
      map['media_refid'] = Variable<int>(mediaRefid.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (baggageId.present) {
      map['baggage_id'] = Variable<String>(baggageId.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaFileCompanion(')
          ..write('mediaRefid: $mediaRefid, ')
          ..write('role: $role, ')
          ..write('baggageId: $baggageId, ')
          ..write('ext: $ext, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ArticleMedia extends Table
    with TableInfo<ArticleMedia, ArticleMediaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ArticleMedia(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _articleRefidMeta = const VerificationMeta(
    'articleRefid',
  );
  late final GeneratedColumn<int> articleRefid = GeneratedColumn<int>(
    'article_refid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _mediaRefidMeta = const VerificationMeta(
    'mediaRefid',
  );
  late final GeneratedColumn<int> mediaRefid = GeneratedColumn<int>(
    'media_refid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [articleRefid, mediaRefid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'article_media';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleMediaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('article_refid')) {
      context.handle(
        _articleRefidMeta,
        articleRefid.isAcceptableOrUnknown(
          data['article_refid']!,
          _articleRefidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_articleRefidMeta);
    }
    if (data.containsKey('media_refid')) {
      context.handle(
        _mediaRefidMeta,
        mediaRefid.isAcceptableOrUnknown(data['media_refid']!, _mediaRefidMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaRefidMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {articleRefid, mediaRefid};
  @override
  ArticleMediaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleMediaData(
      articleRefid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}article_refid'],
      )!,
      mediaRefid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_refid'],
      )!,
    );
  }

  @override
  ArticleMedia createAlias(String alias) {
    return ArticleMedia(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(article_refid, media_refid)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class ArticleMediaData extends DataClass
    implements Insertable<ArticleMediaData> {
  final int articleRefid;
  final int mediaRefid;
  const ArticleMediaData({
    required this.articleRefid,
    required this.mediaRefid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['article_refid'] = Variable<int>(articleRefid);
    map['media_refid'] = Variable<int>(mediaRefid);
    return map;
  }

  ArticleMediaCompanion toCompanion(bool nullToAbsent) {
    return ArticleMediaCompanion(
      articleRefid: Value(articleRefid),
      mediaRefid: Value(mediaRefid),
    );
  }

  factory ArticleMediaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleMediaData(
      articleRefid: serializer.fromJson<int>(json['article_refid']),
      mediaRefid: serializer.fromJson<int>(json['media_refid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'article_refid': serializer.toJson<int>(articleRefid),
      'media_refid': serializer.toJson<int>(mediaRefid),
    };
  }

  ArticleMediaData copyWith({int? articleRefid, int? mediaRefid}) =>
      ArticleMediaData(
        articleRefid: articleRefid ?? this.articleRefid,
        mediaRefid: mediaRefid ?? this.mediaRefid,
      );
  ArticleMediaData copyWithCompanion(ArticleMediaCompanion data) {
    return ArticleMediaData(
      articleRefid: data.articleRefid.present
          ? data.articleRefid.value
          : this.articleRefid,
      mediaRefid: data.mediaRefid.present
          ? data.mediaRefid.value
          : this.mediaRefid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticleMediaData(')
          ..write('articleRefid: $articleRefid, ')
          ..write('mediaRefid: $mediaRefid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(articleRefid, mediaRefid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticleMediaData &&
          other.articleRefid == this.articleRefid &&
          other.mediaRefid == this.mediaRefid);
}

class ArticleMediaCompanion extends UpdateCompanion<ArticleMediaData> {
  final Value<int> articleRefid;
  final Value<int> mediaRefid;
  final Value<int> rowid;
  const ArticleMediaCompanion({
    this.articleRefid = const Value.absent(),
    this.mediaRefid = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticleMediaCompanion.insert({
    required int articleRefid,
    required int mediaRefid,
    this.rowid = const Value.absent(),
  }) : articleRefid = Value(articleRefid),
       mediaRefid = Value(mediaRefid);
  static Insertable<ArticleMediaData> custom({
    Expression<int>? articleRefid,
    Expression<int>? mediaRefid,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (articleRefid != null) 'article_refid': articleRefid,
      if (mediaRefid != null) 'media_refid': mediaRefid,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticleMediaCompanion copyWith({
    Value<int>? articleRefid,
    Value<int>? mediaRefid,
    Value<int>? rowid,
  }) {
    return ArticleMediaCompanion(
      articleRefid: articleRefid ?? this.articleRefid,
      mediaRefid: mediaRefid ?? this.mediaRefid,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (articleRefid.present) {
      map['article_refid'] = Variable<int>(articleRefid.value);
    }
    if (mediaRefid.present) {
      map['media_refid'] = Variable<int>(mediaRefid.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticleMediaCompanion(')
          ..write('articleRefid: $articleRefid, ')
          ..write('mediaRefid: $mediaRefid, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Xref extends Table with TableInfo<Xref, XrefData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Xref(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _refidMeta = const VerificationMeta('refid');
  late final GeneratedColumn<int> refid = GeneratedColumn<int>(
    'refid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _targetRefidMeta = const VerificationMeta(
    'targetRefid',
  );
  late final GeneratedColumn<int> targetRefid = GeneratedColumn<int>(
    'target_refid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [refid, targetRefid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'xref';
  @override
  VerificationContext validateIntegrity(
    Insertable<XrefData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('refid')) {
      context.handle(
        _refidMeta,
        refid.isAcceptableOrUnknown(data['refid']!, _refidMeta),
      );
    } else if (isInserting) {
      context.missing(_refidMeta);
    }
    if (data.containsKey('target_refid')) {
      context.handle(
        _targetRefidMeta,
        targetRefid.isAcceptableOrUnknown(
          data['target_refid']!,
          _targetRefidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetRefidMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {refid, targetRefid};
  @override
  XrefData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return XrefData(
      refid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refid'],
      )!,
      targetRefid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_refid'],
      )!,
    );
  }

  @override
  Xref createAlias(String alias) {
    return Xref(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(refid, target_refid)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class XrefData extends DataClass implements Insertable<XrefData> {
  final int refid;
  final int targetRefid;
  const XrefData({required this.refid, required this.targetRefid});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['refid'] = Variable<int>(refid);
    map['target_refid'] = Variable<int>(targetRefid);
    return map;
  }

  XrefCompanion toCompanion(bool nullToAbsent) {
    return XrefCompanion(refid: Value(refid), targetRefid: Value(targetRefid));
  }

  factory XrefData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return XrefData(
      refid: serializer.fromJson<int>(json['refid']),
      targetRefid: serializer.fromJson<int>(json['target_refid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'refid': serializer.toJson<int>(refid),
      'target_refid': serializer.toJson<int>(targetRefid),
    };
  }

  XrefData copyWith({int? refid, int? targetRefid}) => XrefData(
    refid: refid ?? this.refid,
    targetRefid: targetRefid ?? this.targetRefid,
  );
  XrefData copyWithCompanion(XrefCompanion data) {
    return XrefData(
      refid: data.refid.present ? data.refid.value : this.refid,
      targetRefid: data.targetRefid.present
          ? data.targetRefid.value
          : this.targetRefid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('XrefData(')
          ..write('refid: $refid, ')
          ..write('targetRefid: $targetRefid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(refid, targetRefid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is XrefData &&
          other.refid == this.refid &&
          other.targetRefid == this.targetRefid);
}

class XrefCompanion extends UpdateCompanion<XrefData> {
  final Value<int> refid;
  final Value<int> targetRefid;
  final Value<int> rowid;
  const XrefCompanion({
    this.refid = const Value.absent(),
    this.targetRefid = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  XrefCompanion.insert({
    required int refid,
    required int targetRefid,
    this.rowid = const Value.absent(),
  }) : refid = Value(refid),
       targetRefid = Value(targetRefid);
  static Insertable<XrefData> custom({
    Expression<int>? refid,
    Expression<int>? targetRefid,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (refid != null) 'refid': refid,
      if (targetRefid != null) 'target_refid': targetRefid,
      if (rowid != null) 'rowid': rowid,
    });
  }

  XrefCompanion copyWith({
    Value<int>? refid,
    Value<int>? targetRefid,
    Value<int>? rowid,
  }) {
    return XrefCompanion(
      refid: refid ?? this.refid,
      targetRefid: targetRefid ?? this.targetRefid,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (refid.present) {
      map['refid'] = Variable<int>(refid.value);
    }
    if (targetRefid.present) {
      map['target_refid'] = Variable<int>(targetRefid.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('XrefCompanion(')
          ..write('refid: $refid, ')
          ..write('targetRefid: $targetRefid, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ArticleFts extends Table
    with
        TableInfo<ArticleFts, ArticleFt>,
        VirtualTableInfo<ArticleFts, ArticleFt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ArticleFts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [body];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'article_fts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleFt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  ArticleFt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleFt(
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
    );
  }

  @override
  ArticleFts createAlias(String alias) {
    return ArticleFts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs =>
      'fts5(body, content=\'\', contentless_delete=1, tokenize=\'unicode61\')';
}

class ArticleFt extends DataClass implements Insertable<ArticleFt> {
  final String body;
  const ArticleFt({required this.body});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['body'] = Variable<String>(body);
    return map;
  }

  ArticleFtsCompanion toCompanion(bool nullToAbsent) {
    return ArticleFtsCompanion(body: Value(body));
  }

  factory ArticleFt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleFt(body: serializer.fromJson<String>(json['body']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'body': serializer.toJson<String>(body)};
  }

  ArticleFt copyWith({String? body}) => ArticleFt(body: body ?? this.body);
  ArticleFt copyWithCompanion(ArticleFtsCompanion data) {
    return ArticleFt(body: data.body.present ? data.body.value : this.body);
  }

  @override
  String toString() {
    return (StringBuffer('ArticleFt(')
          ..write('body: $body')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => body.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ArticleFt && other.body == this.body);
}

class ArticleFtsCompanion extends UpdateCompanion<ArticleFt> {
  final Value<String> body;
  final Value<int> rowid;
  const ArticleFtsCompanion({
    this.body = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticleFtsCompanion.insert({
    required String body,
    this.rowid = const Value.absent(),
  }) : body = Value(body);
  static Insertable<ArticleFt> custom({
    Expression<String>? body,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (body != null) 'body': body,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticleFtsCompanion copyWith({Value<String>? body, Value<int>? rowid}) {
    return ArticleFtsCompanion(
      body: body ?? this.body,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticleFtsCompanion(')
          ..write('body: $body, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$EncartaDatabase extends GeneratedDatabase {
  _$EncartaDatabase(QueryExecutor e) : super(e);
  $EncartaDatabaseManager get managers => $EncartaDatabaseManager(this);
  late final Article article = Article(this);
  late final Asset asset = Asset(this);
  late final Media media = Media(this);
  late final MediaFile mediaFile = MediaFile(this);
  late final ArticleMedia articleMedia = ArticleMedia(this);
  late final Xref xref = Xref(this);
  late final ArticleFts articleFts = ArticleFts(this);
  Selectable<int> ftsRowidUnmapped() {
    return customSelect(
      'SELECT count(*) AS unmapped FROM article_fts AS f WHERE NOT EXISTS (SELECT 1 AS _c0 FROM article AS a WHERE a.refid = f."rowid")',
      variables: [],
      readsFrom: {},
    ).map((QueryRow row) => row.read<int>('unmapped'));
  }

  Selectable<FtsSeedArticleResult> ftsSeedArticle(int offset) {
    return customSelect(
      'SELECT refid, xml FROM article WHERE length(xml) > 200 ORDER BY refid LIMIT 1 OFFSET ?1',
      variables: [Variable<int>(offset)],
      readsFrom: {},
    ).map(
      (QueryRow row) => FtsSeedArticleResult(
        refid: row.readNullable<String>('refid'),
        xml: row.readNullable<String>('xml'),
      ),
    );
  }

  Selectable<String?> ftsMatchToken(String token) {
    return customSelect(
      'SELECT "rowid" FROM article_fts WHERE article_fts MATCH ?1',
      variables: [Variable<String>(token)],
      readsFrom: {},
    ).map((QueryRow row) => row.readNullable<String>('rowid'));
  }

  Selectable<GetArticleByRefidResult> getArticleByRefid(String refid) {
    return customSelect(
      'SELECT refid, title, source, xml FROM article WHERE refid = ?1',
      variables: [Variable<String>(refid)],
      readsFrom: {},
    ).map(
      (QueryRow row) => GetArticleByRefidResult(
        refid: row.readNullable<String>('refid'),
        title: row.readNullable<String>('title'),
        source: row.readNullable<String>('source'),
        xml: row.readNullable<String>('xml'),
      ),
    );
  }

  Selectable<String?> firstTitledRefid() {
    return customSelect(
      'SELECT refid FROM article WHERE title IS NOT NULL ORDER BY refid LIMIT 1',
      variables: [],
      readsFrom: {},
    ).map((QueryRow row) => row.readNullable<String>('refid'));
  }

  Selectable<SearchArticlesResult> searchArticles(
    String query,
    int limit,
    int offset,
  ) {
    return customSelect(
      'SELECT f."rowid" AS refid, a.title AS title, CAST(bm25(article_fts) AS REAL) AS rank FROM article_fts AS f JOIN article AS a ON a.refid = f."rowid" WHERE article_fts MATCH ?1 ORDER BY rank LIMIT ?2 OFFSET ?3',
      variables: [
        Variable<String>(query),
        Variable<int>(limit),
        Variable<int>(offset),
      ],
      readsFrom: {},
    ).map(
      (QueryRow row) => SearchArticlesResult(
        refid: row.readNullable<String>('refid'),
        title: row.readNullable<String>('title'),
        rank: row.read<double>('rank'),
      ),
    );
  }

  Selectable<MediaForArticleResult> mediaForArticle(String refid) {
    return customSelect(
      'SELECT m.refid AS mediaRefid, mf.role AS role, m."group" AS mgroup, m.title AS title, m.caption AS caption, m.credit AS credit, a.path AS assetPath, a.ext AS ext, a.kind AS kind FROM article_media AS am JOIN media AS m ON m.refid = am.media_refid JOIN media_file AS mf ON mf.media_refid = am.media_refid JOIN asset AS a ON a.baggage_id = mf.baggage_id WHERE am.article_refid = ?1 ORDER BY mf.role',
      variables: [Variable<String>(refid)],
      readsFrom: {},
    ).map(
      (QueryRow row) => MediaForArticleResult(
        mediaRefid: row.readNullable<String>('mediaRefid'),
        role: row.readNullable<String>('role'),
        mgroup: row.readNullable<String>('mgroup'),
        title: row.readNullable<String>('title'),
        caption: row.readNullable<String>('caption'),
        credit: row.readNullable<String>('credit'),
        assetPath: row.readNullable<String>('assetPath'),
        ext: row.readNullable<String>('ext'),
        kind: row.readNullable<String>('kind'),
      ),
    );
  }

  Selectable<String?> mostMediaRefid() {
    return customSelect(
      'SELECT a.refid AS refid FROM article_media AS am JOIN article AS a ON a.refid = am.article_refid GROUP BY a.refid ORDER BY count(*) DESC LIMIT 1',
      variables: [],
      readsFrom: {},
    ).map((QueryRow row) => row.readNullable<String>('refid'));
  }

  Selectable<AssetByBaggageIdResult> assetByBaggageId(String id) {
    return customSelect(
      'SELECT baggage_id, hash, kind, ext, path FROM asset WHERE baggage_id = ?1',
      variables: [Variable<String>(id)],
      readsFrom: {},
    ).map(
      (QueryRow row) => AssetByBaggageIdResult(
        baggageId: row.readNullable<String>('baggage_id'),
        hash: row.readNullable<String>('hash'),
        kind: row.readNullable<String>('kind'),
        ext: row.readNullable<String>('ext'),
        path: row.readNullable<String>('path'),
      ),
    );
  }

  Selectable<String?> anyBaggageId() {
    return customSelect(
      'SELECT baggage_id FROM asset LIMIT 1',
      variables: [],
      readsFrom: {},
    ).map((QueryRow row) => row.readNullable<String>('baggage_id'));
  }

  Selectable<TitlesIndexResult> titlesIndex(
    String prefix,
    int limit,
    int offset,
  ) {
    return customSelect(
      'SELECT refid, title FROM article WHERE title IS NOT NULL AND title LIKE ?1 || \'%\' ORDER BY title LIMIT ?2 OFFSET ?3',
      variables: [
        Variable<String>(prefix),
        Variable<int>(limit),
        Variable<int>(offset),
      ],
      readsFrom: {},
    ).map(
      (QueryRow row) => TitlesIndexResult(
        refid: row.readNullable<String>('refid'),
        title: row.readNullable<String>('title'),
      ),
    );
  }

  Selectable<OutboundXrefsResult> outboundXrefs(String refid) {
    return customSelect(
      'SELECT x.target_refid AS targetRefid, a.title AS title FROM xref AS x JOIN article AS a ON a.refid = x.target_refid WHERE x.refid = ?1 AND a.title IS NOT NULL ORDER BY a.title',
      variables: [Variable<String>(refid)],
      readsFrom: {},
    ).map(
      (QueryRow row) => OutboundXrefsResult(
        targetRefid: row.readNullable<String>('targetRefid'),
        title: row.readNullable<String>('title'),
      ),
    );
  }

  Selectable<String?> anyXrefSourceRefid() {
    return customSelect(
      'SELECT x.refid AS refid FROM xref AS x JOIN article AS a ON a.refid = x.target_refid LIMIT 1',
      variables: [],
      readsFrom: {},
    ).map((QueryRow row) => row.readNullable<String>('refid'));
  }

  Selectable<RandomArticleInRangeResult> randomArticleInRange() {
    return customSelect(
      'SELECT refid, title, source, xml FROM article WHERE refid >= (SELECT min(refid) + abs(random()) %(max(refid) - min(refid) + 1)FROM article) AND title IS NOT NULL ORDER BY refid LIMIT 1',
      variables: [],
      readsFrom: {},
    ).map(
      (QueryRow row) => RandomArticleInRangeResult(
        refid: row.readNullable<String>('refid'),
        title: row.readNullable<String>('title'),
        source: row.readNullable<String>('source'),
        xml: row.readNullable<String>('xml'),
      ),
    );
  }

  Selectable<RandomArticleFallbackResult> randomArticleFallback() {
    return customSelect(
      'SELECT refid, title, source, xml FROM article WHERE title IS NOT NULL ORDER BY refid LIMIT 1',
      variables: [],
      readsFrom: {},
    ).map(
      (QueryRow row) => RandomArticleFallbackResult(
        refid: row.readNullable<String>('refid'),
        title: row.readNullable<String>('title'),
        source: row.readNullable<String>('source'),
        xml: row.readNullable<String>('xml'),
      ),
    );
  }

  Selectable<FeaturedHomeArticlesResult> featuredHomeArticles(int limit) {
    return customSelect(
      'SELECT a.refid AS refid, a.title AS title FROM media AS m JOIN article_media AS am ON am.media_refid = m.refid JOIN article AS a ON a.refid = am.article_refid WHERE m."group" = \'home\' AND a.title IS NOT NULL GROUP BY a.refid ORDER BY m.refid LIMIT ?1',
      variables: [Variable<int>(limit)],
      readsFrom: {},
    ).map(
      (QueryRow row) => FeaturedHomeArticlesResult(
        refid: row.readNullable<String>('refid'),
        title: row.readNullable<String>('title'),
      ),
    );
  }

  Selectable<FeaturedByMediaCountResult> featuredByMediaCount(int limit) {
    return customSelect(
      'SELECT a.refid AS refid, a.title AS title FROM article_media AS am JOIN article AS a ON a.refid = am.article_refid WHERE a.title IS NOT NULL GROUP BY a.refid ORDER BY count(*) DESC LIMIT ?1',
      variables: [Variable<int>(limit)],
      readsFrom: {},
    ).map(
      (QueryRow row) => FeaturedByMediaCountResult(
        refid: row.readNullable<String>('refid'),
        title: row.readNullable<String>('title'),
      ),
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    article,
    asset,
    media,
    mediaFile,
    articleMedia,
    xref,
    articleFts,
  ];
}

typedef $ArticleCreateCompanionBuilder =
    ArticleCompanion Function({
      Value<int> refid,
      Value<String?> source,
      Value<String?> title,
      Value<Uint8List?> xml,
    });
typedef $ArticleUpdateCompanionBuilder =
    ArticleCompanion Function({
      Value<int> refid,
      Value<String?> source,
      Value<String?> title,
      Value<Uint8List?> xml,
    });

class $ArticleFilterComposer extends Composer<_$EncartaDatabase, Article> {
  $ArticleFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get refid => $composableBuilder(
    column: $table.refid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get xml => $composableBuilder(
    column: $table.xml,
    builder: (column) => ColumnFilters(column),
  );
}

class $ArticleOrderingComposer extends Composer<_$EncartaDatabase, Article> {
  $ArticleOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get refid => $composableBuilder(
    column: $table.refid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get xml => $composableBuilder(
    column: $table.xml,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ArticleAnnotationComposer extends Composer<_$EncartaDatabase, Article> {
  $ArticleAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get refid =>
      $composableBuilder(column: $table.refid, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<Uint8List> get xml =>
      $composableBuilder(column: $table.xml, builder: (column) => column);
}

class $ArticleTableManager
    extends
        RootTableManager<
          _$EncartaDatabase,
          Article,
          ArticleData,
          $ArticleFilterComposer,
          $ArticleOrderingComposer,
          $ArticleAnnotationComposer,
          $ArticleCreateCompanionBuilder,
          $ArticleUpdateCompanionBuilder,
          (
            ArticleData,
            BaseReferences<_$EncartaDatabase, Article, ArticleData>,
          ),
          ArticleData,
          PrefetchHooks Function()
        > {
  $ArticleTableManager(_$EncartaDatabase db, Article table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ArticleFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ArticleOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ArticleAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> refid = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<Uint8List?> xml = const Value.absent(),
              }) => ArticleCompanion(
                refid: refid,
                source: source,
                title: title,
                xml: xml,
              ),
          createCompanionCallback:
              ({
                Value<int> refid = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<Uint8List?> xml = const Value.absent(),
              }) => ArticleCompanion.insert(
                refid: refid,
                source: source,
                title: title,
                xml: xml,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ArticleProcessedTableManager =
    ProcessedTableManager<
      _$EncartaDatabase,
      Article,
      ArticleData,
      $ArticleFilterComposer,
      $ArticleOrderingComposer,
      $ArticleAnnotationComposer,
      $ArticleCreateCompanionBuilder,
      $ArticleUpdateCompanionBuilder,
      (ArticleData, BaseReferences<_$EncartaDatabase, Article, ArticleData>),
      ArticleData,
      PrefetchHooks Function()
    >;
typedef $AssetCreateCompanionBuilder =
    AssetCompanion Function({
      required String baggageId,
      Value<String?> hash,
      Value<String?> kind,
      Value<String?> ext,
      Value<String?> path,
      Value<String?> source,
      Value<int> rowid,
    });
typedef $AssetUpdateCompanionBuilder =
    AssetCompanion Function({
      Value<String> baggageId,
      Value<String?> hash,
      Value<String?> kind,
      Value<String?> ext,
      Value<String?> path,
      Value<String?> source,
      Value<int> rowid,
    });

class $AssetFilterComposer extends Composer<_$EncartaDatabase, Asset> {
  $AssetFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get baggageId => $composableBuilder(
    column: $table.baggageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $AssetOrderingComposer extends Composer<_$EncartaDatabase, Asset> {
  $AssetOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get baggageId => $composableBuilder(
    column: $table.baggageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $AssetAnnotationComposer extends Composer<_$EncartaDatabase, Asset> {
  $AssetAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get baggageId =>
      $composableBuilder(column: $table.baggageId, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $AssetTableManager
    extends
        RootTableManager<
          _$EncartaDatabase,
          Asset,
          AssetData,
          $AssetFilterComposer,
          $AssetOrderingComposer,
          $AssetAnnotationComposer,
          $AssetCreateCompanionBuilder,
          $AssetUpdateCompanionBuilder,
          (AssetData, BaseReferences<_$EncartaDatabase, Asset, AssetData>),
          AssetData,
          PrefetchHooks Function()
        > {
  $AssetTableManager(_$EncartaDatabase db, Asset table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $AssetFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $AssetOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $AssetAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> baggageId = const Value.absent(),
                Value<String?> hash = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetCompanion(
                baggageId: baggageId,
                hash: hash,
                kind: kind,
                ext: ext,
                path: path,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String baggageId,
                Value<String?> hash = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetCompanion.insert(
                baggageId: baggageId,
                hash: hash,
                kind: kind,
                ext: ext,
                path: path,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $AssetProcessedTableManager =
    ProcessedTableManager<
      _$EncartaDatabase,
      Asset,
      AssetData,
      $AssetFilterComposer,
      $AssetOrderingComposer,
      $AssetAnnotationComposer,
      $AssetCreateCompanionBuilder,
      $AssetUpdateCompanionBuilder,
      (AssetData, BaseReferences<_$EncartaDatabase, Asset, AssetData>),
      AssetData,
      PrefetchHooks Function()
    >;
typedef $MediaCreateCompanionBuilder =
    MediaCompanion Function({
      Value<int> refid,
      Value<String?> group,
      Value<String?> title,
      Value<String?> credit,
      Value<String?> caption,
      Value<String?> source,
    });
typedef $MediaUpdateCompanionBuilder =
    MediaCompanion Function({
      Value<int> refid,
      Value<String?> group,
      Value<String?> title,
      Value<String?> credit,
      Value<String?> caption,
      Value<String?> source,
    });

class $MediaFilterComposer extends Composer<_$EncartaDatabase, Media> {
  $MediaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get refid => $composableBuilder(
    column: $table.refid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credit => $composableBuilder(
    column: $table.credit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $MediaOrderingComposer extends Composer<_$EncartaDatabase, Media> {
  $MediaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get refid => $composableBuilder(
    column: $table.refid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get group => $composableBuilder(
    column: $table.group,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credit => $composableBuilder(
    column: $table.credit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MediaAnnotationComposer extends Composer<_$EncartaDatabase, Media> {
  $MediaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get refid =>
      $composableBuilder(column: $table.refid, builder: (column) => column);

  GeneratedColumn<String> get group =>
      $composableBuilder(column: $table.group, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get credit =>
      $composableBuilder(column: $table.credit, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $MediaTableManager
    extends
        RootTableManager<
          _$EncartaDatabase,
          Media,
          MediaData,
          $MediaFilterComposer,
          $MediaOrderingComposer,
          $MediaAnnotationComposer,
          $MediaCreateCompanionBuilder,
          $MediaUpdateCompanionBuilder,
          (MediaData, BaseReferences<_$EncartaDatabase, Media, MediaData>),
          MediaData,
          PrefetchHooks Function()
        > {
  $MediaTableManager(_$EncartaDatabase db, Media table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MediaFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MediaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MediaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> refid = const Value.absent(),
                Value<String?> group = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> credit = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String?> source = const Value.absent(),
              }) => MediaCompanion(
                refid: refid,
                group: group,
                title: title,
                credit: credit,
                caption: caption,
                source: source,
              ),
          createCompanionCallback:
              ({
                Value<int> refid = const Value.absent(),
                Value<String?> group = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> credit = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String?> source = const Value.absent(),
              }) => MediaCompanion.insert(
                refid: refid,
                group: group,
                title: title,
                credit: credit,
                caption: caption,
                source: source,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MediaProcessedTableManager =
    ProcessedTableManager<
      _$EncartaDatabase,
      Media,
      MediaData,
      $MediaFilterComposer,
      $MediaOrderingComposer,
      $MediaAnnotationComposer,
      $MediaCreateCompanionBuilder,
      $MediaUpdateCompanionBuilder,
      (MediaData, BaseReferences<_$EncartaDatabase, Media, MediaData>),
      MediaData,
      PrefetchHooks Function()
    >;
typedef $MediaFileCreateCompanionBuilder =
    MediaFileCompanion Function({
      required int mediaRefid,
      required String role,
      Value<String?> baggageId,
      Value<String?> ext,
      Value<int> rowid,
    });
typedef $MediaFileUpdateCompanionBuilder =
    MediaFileCompanion Function({
      Value<int> mediaRefid,
      Value<String> role,
      Value<String?> baggageId,
      Value<String?> ext,
      Value<int> rowid,
    });

class $MediaFileFilterComposer extends Composer<_$EncartaDatabase, MediaFile> {
  $MediaFileFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get mediaRefid => $composableBuilder(
    column: $table.mediaRefid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baggageId => $composableBuilder(
    column: $table.baggageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnFilters(column),
  );
}

class $MediaFileOrderingComposer
    extends Composer<_$EncartaDatabase, MediaFile> {
  $MediaFileOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get mediaRefid => $composableBuilder(
    column: $table.mediaRefid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baggageId => $composableBuilder(
    column: $table.baggageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ext => $composableBuilder(
    column: $table.ext,
    builder: (column) => ColumnOrderings(column),
  );
}

class $MediaFileAnnotationComposer
    extends Composer<_$EncartaDatabase, MediaFile> {
  $MediaFileAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get mediaRefid => $composableBuilder(
    column: $table.mediaRefid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get baggageId =>
      $composableBuilder(column: $table.baggageId, builder: (column) => column);

  GeneratedColumn<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => column);
}

class $MediaFileTableManager
    extends
        RootTableManager<
          _$EncartaDatabase,
          MediaFile,
          MediaFileData,
          $MediaFileFilterComposer,
          $MediaFileOrderingComposer,
          $MediaFileAnnotationComposer,
          $MediaFileCreateCompanionBuilder,
          $MediaFileUpdateCompanionBuilder,
          (
            MediaFileData,
            BaseReferences<_$EncartaDatabase, MediaFile, MediaFileData>,
          ),
          MediaFileData,
          PrefetchHooks Function()
        > {
  $MediaFileTableManager(_$EncartaDatabase db, MediaFile table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $MediaFileFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $MediaFileOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $MediaFileAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> mediaRefid = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> baggageId = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaFileCompanion(
                mediaRefid: mediaRefid,
                role: role,
                baggageId: baggageId,
                ext: ext,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int mediaRefid,
                required String role,
                Value<String?> baggageId = const Value.absent(),
                Value<String?> ext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaFileCompanion.insert(
                mediaRefid: mediaRefid,
                role: role,
                baggageId: baggageId,
                ext: ext,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $MediaFileProcessedTableManager =
    ProcessedTableManager<
      _$EncartaDatabase,
      MediaFile,
      MediaFileData,
      $MediaFileFilterComposer,
      $MediaFileOrderingComposer,
      $MediaFileAnnotationComposer,
      $MediaFileCreateCompanionBuilder,
      $MediaFileUpdateCompanionBuilder,
      (
        MediaFileData,
        BaseReferences<_$EncartaDatabase, MediaFile, MediaFileData>,
      ),
      MediaFileData,
      PrefetchHooks Function()
    >;
typedef $ArticleMediaCreateCompanionBuilder =
    ArticleMediaCompanion Function({
      required int articleRefid,
      required int mediaRefid,
      Value<int> rowid,
    });
typedef $ArticleMediaUpdateCompanionBuilder =
    ArticleMediaCompanion Function({
      Value<int> articleRefid,
      Value<int> mediaRefid,
      Value<int> rowid,
    });

class $ArticleMediaFilterComposer
    extends Composer<_$EncartaDatabase, ArticleMedia> {
  $ArticleMediaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get articleRefid => $composableBuilder(
    column: $table.articleRefid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaRefid => $composableBuilder(
    column: $table.mediaRefid,
    builder: (column) => ColumnFilters(column),
  );
}

class $ArticleMediaOrderingComposer
    extends Composer<_$EncartaDatabase, ArticleMedia> {
  $ArticleMediaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get articleRefid => $composableBuilder(
    column: $table.articleRefid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaRefid => $composableBuilder(
    column: $table.mediaRefid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ArticleMediaAnnotationComposer
    extends Composer<_$EncartaDatabase, ArticleMedia> {
  $ArticleMediaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get articleRefid => $composableBuilder(
    column: $table.articleRefid,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mediaRefid => $composableBuilder(
    column: $table.mediaRefid,
    builder: (column) => column,
  );
}

class $ArticleMediaTableManager
    extends
        RootTableManager<
          _$EncartaDatabase,
          ArticleMedia,
          ArticleMediaData,
          $ArticleMediaFilterComposer,
          $ArticleMediaOrderingComposer,
          $ArticleMediaAnnotationComposer,
          $ArticleMediaCreateCompanionBuilder,
          $ArticleMediaUpdateCompanionBuilder,
          (
            ArticleMediaData,
            BaseReferences<_$EncartaDatabase, ArticleMedia, ArticleMediaData>,
          ),
          ArticleMediaData,
          PrefetchHooks Function()
        > {
  $ArticleMediaTableManager(_$EncartaDatabase db, ArticleMedia table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ArticleMediaFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ArticleMediaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ArticleMediaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> articleRefid = const Value.absent(),
                Value<int> mediaRefid = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticleMediaCompanion(
                articleRefid: articleRefid,
                mediaRefid: mediaRefid,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int articleRefid,
                required int mediaRefid,
                Value<int> rowid = const Value.absent(),
              }) => ArticleMediaCompanion.insert(
                articleRefid: articleRefid,
                mediaRefid: mediaRefid,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ArticleMediaProcessedTableManager =
    ProcessedTableManager<
      _$EncartaDatabase,
      ArticleMedia,
      ArticleMediaData,
      $ArticleMediaFilterComposer,
      $ArticleMediaOrderingComposer,
      $ArticleMediaAnnotationComposer,
      $ArticleMediaCreateCompanionBuilder,
      $ArticleMediaUpdateCompanionBuilder,
      (
        ArticleMediaData,
        BaseReferences<_$EncartaDatabase, ArticleMedia, ArticleMediaData>,
      ),
      ArticleMediaData,
      PrefetchHooks Function()
    >;
typedef $XrefCreateCompanionBuilder =
    XrefCompanion Function({
      required int refid,
      required int targetRefid,
      Value<int> rowid,
    });
typedef $XrefUpdateCompanionBuilder =
    XrefCompanion Function({
      Value<int> refid,
      Value<int> targetRefid,
      Value<int> rowid,
    });

class $XrefFilterComposer extends Composer<_$EncartaDatabase, Xref> {
  $XrefFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get refid => $composableBuilder(
    column: $table.refid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetRefid => $composableBuilder(
    column: $table.targetRefid,
    builder: (column) => ColumnFilters(column),
  );
}

class $XrefOrderingComposer extends Composer<_$EncartaDatabase, Xref> {
  $XrefOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get refid => $composableBuilder(
    column: $table.refid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetRefid => $composableBuilder(
    column: $table.targetRefid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $XrefAnnotationComposer extends Composer<_$EncartaDatabase, Xref> {
  $XrefAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get refid =>
      $composableBuilder(column: $table.refid, builder: (column) => column);

  GeneratedColumn<int> get targetRefid => $composableBuilder(
    column: $table.targetRefid,
    builder: (column) => column,
  );
}

class $XrefTableManager
    extends
        RootTableManager<
          _$EncartaDatabase,
          Xref,
          XrefData,
          $XrefFilterComposer,
          $XrefOrderingComposer,
          $XrefAnnotationComposer,
          $XrefCreateCompanionBuilder,
          $XrefUpdateCompanionBuilder,
          (XrefData, BaseReferences<_$EncartaDatabase, Xref, XrefData>),
          XrefData,
          PrefetchHooks Function()
        > {
  $XrefTableManager(_$EncartaDatabase db, Xref table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $XrefFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $XrefOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $XrefAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> refid = const Value.absent(),
                Value<int> targetRefid = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => XrefCompanion(
                refid: refid,
                targetRefid: targetRefid,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int refid,
                required int targetRefid,
                Value<int> rowid = const Value.absent(),
              }) => XrefCompanion.insert(
                refid: refid,
                targetRefid: targetRefid,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $XrefProcessedTableManager =
    ProcessedTableManager<
      _$EncartaDatabase,
      Xref,
      XrefData,
      $XrefFilterComposer,
      $XrefOrderingComposer,
      $XrefAnnotationComposer,
      $XrefCreateCompanionBuilder,
      $XrefUpdateCompanionBuilder,
      (XrefData, BaseReferences<_$EncartaDatabase, Xref, XrefData>),
      XrefData,
      PrefetchHooks Function()
    >;
typedef $ArticleFtsCreateCompanionBuilder =
    ArticleFtsCompanion Function({required String body, Value<int> rowid});
typedef $ArticleFtsUpdateCompanionBuilder =
    ArticleFtsCompanion Function({Value<String> body, Value<int> rowid});

class $ArticleFtsFilterComposer
    extends Composer<_$EncartaDatabase, ArticleFts> {
  $ArticleFtsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );
}

class $ArticleFtsOrderingComposer
    extends Composer<_$EncartaDatabase, ArticleFts> {
  $ArticleFtsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );
}

class $ArticleFtsAnnotationComposer
    extends Composer<_$EncartaDatabase, ArticleFts> {
  $ArticleFtsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);
}

class $ArticleFtsTableManager
    extends
        RootTableManager<
          _$EncartaDatabase,
          ArticleFts,
          ArticleFt,
          $ArticleFtsFilterComposer,
          $ArticleFtsOrderingComposer,
          $ArticleFtsAnnotationComposer,
          $ArticleFtsCreateCompanionBuilder,
          $ArticleFtsUpdateCompanionBuilder,
          (ArticleFt, BaseReferences<_$EncartaDatabase, ArticleFts, ArticleFt>),
          ArticleFt,
          PrefetchHooks Function()
        > {
  $ArticleFtsTableManager(_$EncartaDatabase db, ArticleFts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ArticleFtsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ArticleFtsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ArticleFtsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> body = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticleFtsCompanion(body: body, rowid: rowid),
          createCompanionCallback:
              ({
                required String body,
                Value<int> rowid = const Value.absent(),
              }) => ArticleFtsCompanion.insert(body: body, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ArticleFtsProcessedTableManager =
    ProcessedTableManager<
      _$EncartaDatabase,
      ArticleFts,
      ArticleFt,
      $ArticleFtsFilterComposer,
      $ArticleFtsOrderingComposer,
      $ArticleFtsAnnotationComposer,
      $ArticleFtsCreateCompanionBuilder,
      $ArticleFtsUpdateCompanionBuilder,
      (ArticleFt, BaseReferences<_$EncartaDatabase, ArticleFts, ArticleFt>),
      ArticleFt,
      PrefetchHooks Function()
    >;

class $EncartaDatabaseManager {
  final _$EncartaDatabase _db;
  $EncartaDatabaseManager(this._db);
  $ArticleTableManager get article => $ArticleTableManager(_db, _db.article);
  $AssetTableManager get asset => $AssetTableManager(_db, _db.asset);
  $MediaTableManager get media => $MediaTableManager(_db, _db.media);
  $MediaFileTableManager get mediaFile =>
      $MediaFileTableManager(_db, _db.mediaFile);
  $ArticleMediaTableManager get articleMedia =>
      $ArticleMediaTableManager(_db, _db.articleMedia);
  $XrefTableManager get xref => $XrefTableManager(_db, _db.xref);
  $ArticleFtsTableManager get articleFts =>
      $ArticleFtsTableManager(_db, _db.articleFts);
}

class FtsSeedArticleResult {
  final String? refid;
  final String? xml;
  FtsSeedArticleResult({this.refid, this.xml});
}

class GetArticleByRefidResult {
  final String? refid;
  final String? title;
  final String? source;
  final String? xml;
  GetArticleByRefidResult({this.refid, this.title, this.source, this.xml});
}

class SearchArticlesResult {
  final String? refid;
  final String? title;
  final double rank;
  SearchArticlesResult({this.refid, this.title, required this.rank});
}

class MediaForArticleResult {
  final String? mediaRefid;
  final String? role;
  final String? mgroup;
  final String? title;
  final String? caption;
  final String? credit;
  final String? assetPath;
  final String? ext;
  final String? kind;
  MediaForArticleResult({
    this.mediaRefid,
    this.role,
    this.mgroup,
    this.title,
    this.caption,
    this.credit,
    this.assetPath,
    this.ext,
    this.kind,
  });
}

class AssetByBaggageIdResult {
  final String? baggageId;
  final String? hash;
  final String? kind;
  final String? ext;
  final String? path;
  AssetByBaggageIdResult({
    this.baggageId,
    this.hash,
    this.kind,
    this.ext,
    this.path,
  });
}

class TitlesIndexResult {
  final String? refid;
  final String? title;
  TitlesIndexResult({this.refid, this.title});
}

class OutboundXrefsResult {
  final String? targetRefid;
  final String? title;
  OutboundXrefsResult({this.targetRefid, this.title});
}

class RandomArticleInRangeResult {
  final String? refid;
  final String? title;
  final String? source;
  final String? xml;
  RandomArticleInRangeResult({this.refid, this.title, this.source, this.xml});
}

class RandomArticleFallbackResult {
  final String? refid;
  final String? title;
  final String? source;
  final String? xml;
  RandomArticleFallbackResult({this.refid, this.title, this.source, this.xml});
}

class FeaturedHomeArticlesResult {
  final String? refid;
  final String? title;
  FeaturedHomeArticlesResult({this.refid, this.title});
}

class FeaturedByMediaCountResult {
  final String? refid;
  final String? title;
  FeaturedByMediaCountResult({this.refid, this.title});
}
