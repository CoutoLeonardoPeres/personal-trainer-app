// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MuscleGroupsTable extends MuscleGroups
    with TableInfo<$MuscleGroupsTable, MuscleGroupEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MuscleGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'muscle_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<MuscleGroupEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MuscleGroupEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MuscleGroupEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MuscleGroupsTable createAlias(String alias) {
    return $MuscleGroupsTable(attachedDatabase, alias);
  }
}

class MuscleGroupEntity extends DataClass
    implements Insertable<MuscleGroupEntity> {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MuscleGroupEntity({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MuscleGroupsCompanion toCompanion(bool nullToAbsent) {
    return MuscleGroupsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MuscleGroupEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MuscleGroupEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MuscleGroupEntity copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MuscleGroupEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MuscleGroupEntity copyWithCompanion(MuscleGroupsCompanion data) {
    return MuscleGroupEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MuscleGroupEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MuscleGroupEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MuscleGroupsCompanion extends UpdateCompanion<MuscleGroupEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MuscleGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MuscleGroupsCompanion.insert({
    required String id,
    required String name,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<MuscleGroupEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MuscleGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MuscleGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MuscleGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, ExerciseEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _muscleGroupIdMeta = const VerificationMeta(
    'muscleGroupId',
  );
  @override
  late final GeneratedColumn<String> muscleGroupId = GeneratedColumn<String>(
    'muscle_group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES muscle_groups (id)',
    ),
  );
  static const VerificationMeta _videoUrlMeta = const VerificationMeta(
    'videoUrl',
  );
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
    'video_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alternativeNoteMeta = const VerificationMeta(
    'alternativeNote',
  );
  @override
  late final GeneratedColumn<String> alternativeNote = GeneratedColumn<String>(
    'alternative_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alternativeVideoUrlMeta =
      const VerificationMeta('alternativeVideoUrl');
  @override
  late final GeneratedColumn<String> alternativeVideoUrl =
      GeneratedColumn<String>(
        'alternative_video_url',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    muscleGroupId,
    videoUrl,
    alternativeNote,
    alternativeVideoUrl,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('muscle_group_id')) {
      context.handle(
        _muscleGroupIdMeta,
        muscleGroupId.isAcceptableOrUnknown(
          data['muscle_group_id']!,
          _muscleGroupIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_muscleGroupIdMeta);
    }
    if (data.containsKey('video_url')) {
      context.handle(
        _videoUrlMeta,
        videoUrl.isAcceptableOrUnknown(data['video_url']!, _videoUrlMeta),
      );
    }
    if (data.containsKey('alternative_note')) {
      context.handle(
        _alternativeNoteMeta,
        alternativeNote.isAcceptableOrUnknown(
          data['alternative_note']!,
          _alternativeNoteMeta,
        ),
      );
    }
    if (data.containsKey('alternative_video_url')) {
      context.handle(
        _alternativeVideoUrlMeta,
        alternativeVideoUrl.isAcceptableOrUnknown(
          data['alternative_video_url']!,
          _alternativeVideoUrlMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      muscleGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}muscle_group_id'],
      )!,
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_url'],
      ),
      alternativeNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternative_note'],
      ),
      alternativeVideoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alternative_video_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class ExerciseEntity extends DataClass implements Insertable<ExerciseEntity> {
  final String id;
  final String name;
  final String muscleGroupId;
  final String? videoUrl;
  final String? alternativeNote;
  final String? alternativeVideoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ExerciseEntity({
    required this.id,
    required this.name,
    required this.muscleGroupId,
    this.videoUrl,
    this.alternativeNote,
    this.alternativeVideoUrl,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['muscle_group_id'] = Variable<String>(muscleGroupId);
    if (!nullToAbsent || videoUrl != null) {
      map['video_url'] = Variable<String>(videoUrl);
    }
    if (!nullToAbsent || alternativeNote != null) {
      map['alternative_note'] = Variable<String>(alternativeNote);
    }
    if (!nullToAbsent || alternativeVideoUrl != null) {
      map['alternative_video_url'] = Variable<String>(alternativeVideoUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      muscleGroupId: Value(muscleGroupId),
      videoUrl: videoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(videoUrl),
      alternativeNote: alternativeNote == null && nullToAbsent
          ? const Value.absent()
          : Value(alternativeNote),
      alternativeVideoUrl: alternativeVideoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(alternativeVideoUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ExerciseEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      muscleGroupId: serializer.fromJson<String>(json['muscleGroupId']),
      videoUrl: serializer.fromJson<String?>(json['videoUrl']),
      alternativeNote: serializer.fromJson<String?>(json['alternativeNote']),
      alternativeVideoUrl: serializer.fromJson<String?>(
        json['alternativeVideoUrl'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'muscleGroupId': serializer.toJson<String>(muscleGroupId),
      'videoUrl': serializer.toJson<String?>(videoUrl),
      'alternativeNote': serializer.toJson<String?>(alternativeNote),
      'alternativeVideoUrl': serializer.toJson<String?>(alternativeVideoUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ExerciseEntity copyWith({
    String? id,
    String? name,
    String? muscleGroupId,
    Value<String?> videoUrl = const Value.absent(),
    Value<String?> alternativeNote = const Value.absent(),
    Value<String?> alternativeVideoUrl = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ExerciseEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    muscleGroupId: muscleGroupId ?? this.muscleGroupId,
    videoUrl: videoUrl.present ? videoUrl.value : this.videoUrl,
    alternativeNote: alternativeNote.present
        ? alternativeNote.value
        : this.alternativeNote,
    alternativeVideoUrl: alternativeVideoUrl.present
        ? alternativeVideoUrl.value
        : this.alternativeVideoUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ExerciseEntity copyWithCompanion(ExercisesCompanion data) {
    return ExerciseEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      muscleGroupId: data.muscleGroupId.present
          ? data.muscleGroupId.value
          : this.muscleGroupId,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
      alternativeNote: data.alternativeNote.present
          ? data.alternativeNote.value
          : this.alternativeNote,
      alternativeVideoUrl: data.alternativeVideoUrl.present
          ? data.alternativeVideoUrl.value
          : this.alternativeVideoUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('muscleGroupId: $muscleGroupId, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('alternativeNote: $alternativeNote, ')
          ..write('alternativeVideoUrl: $alternativeVideoUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    muscleGroupId,
    videoUrl,
    alternativeNote,
    alternativeVideoUrl,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.muscleGroupId == this.muscleGroupId &&
          other.videoUrl == this.videoUrl &&
          other.alternativeNote == this.alternativeNote &&
          other.alternativeVideoUrl == this.alternativeVideoUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ExercisesCompanion extends UpdateCompanion<ExerciseEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> muscleGroupId;
  final Value<String?> videoUrl;
  final Value<String?> alternativeNote;
  final Value<String?> alternativeVideoUrl;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.muscleGroupId = const Value.absent(),
    this.videoUrl = const Value.absent(),
    this.alternativeNote = const Value.absent(),
    this.alternativeVideoUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExercisesCompanion.insert({
    required String id,
    required String name,
    required String muscleGroupId,
    this.videoUrl = const Value.absent(),
    this.alternativeNote = const Value.absent(),
    this.alternativeVideoUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       muscleGroupId = Value(muscleGroupId);
  static Insertable<ExerciseEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? muscleGroupId,
    Expression<String>? videoUrl,
    Expression<String>? alternativeNote,
    Expression<String>? alternativeVideoUrl,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (muscleGroupId != null) 'muscle_group_id': muscleGroupId,
      if (videoUrl != null) 'video_url': videoUrl,
      if (alternativeNote != null) 'alternative_note': alternativeNote,
      if (alternativeVideoUrl != null)
        'alternative_video_url': alternativeVideoUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? muscleGroupId,
    Value<String?>? videoUrl,
    Value<String?>? alternativeNote,
    Value<String?>? alternativeVideoUrl,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroupId: muscleGroupId ?? this.muscleGroupId,
      videoUrl: videoUrl ?? this.videoUrl,
      alternativeNote: alternativeNote ?? this.alternativeNote,
      alternativeVideoUrl: alternativeVideoUrl ?? this.alternativeVideoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (muscleGroupId.present) {
      map['muscle_group_id'] = Variable<String>(muscleGroupId.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    if (alternativeNote.present) {
      map['alternative_note'] = Variable<String>(alternativeNote.value);
    }
    if (alternativeVideoUrl.present) {
      map['alternative_video_url'] = Variable<String>(
        alternativeVideoUrl.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('muscleGroupId: $muscleGroupId, ')
          ..write('videoUrl: $videoUrl, ')
          ..write('alternativeNote: $alternativeNote, ')
          ..write('alternativeVideoUrl: $alternativeVideoUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GymsTable extends Gyms with TableInfo<$GymsTable, GymEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GymsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cnpjMeta = const VerificationMeta('cnpj');
  @override
  late final GeneratedColumn<String> cnpj = GeneratedColumn<String>(
    'cnpj',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streetMeta = const VerificationMeta('street');
  @override
  late final GeneratedColumn<String> street = GeneratedColumn<String>(
    'street',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _complementMeta = const VerificationMeta(
    'complement',
  );
  @override
  late final GeneratedColumn<String> complement = GeneratedColumn<String>(
    'complement',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _districtMeta = const VerificationMeta(
    'district',
  );
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
    'district',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateUfMeta = const VerificationMeta(
    'stateUf',
  );
  @override
  late final GeneratedColumn<String> stateUf = GeneratedColumn<String>(
    'state_uf',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cepMeta = const VerificationMeta('cep');
  @override
  late final GeneratedColumn<String> cep = GeneratedColumn<String>(
    'cep',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    cnpj,
    street,
    number,
    complement,
    district,
    city,
    stateUf,
    cep,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gyms';
  @override
  VerificationContext validateIntegrity(
    Insertable<GymEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cnpj')) {
      context.handle(
        _cnpjMeta,
        cnpj.isAcceptableOrUnknown(data['cnpj']!, _cnpjMeta),
      );
    } else if (isInserting) {
      context.missing(_cnpjMeta);
    }
    if (data.containsKey('street')) {
      context.handle(
        _streetMeta,
        street.isAcceptableOrUnknown(data['street']!, _streetMeta),
      );
    } else if (isInserting) {
      context.missing(_streetMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('complement')) {
      context.handle(
        _complementMeta,
        complement.isAcceptableOrUnknown(data['complement']!, _complementMeta),
      );
    }
    if (data.containsKey('district')) {
      context.handle(
        _districtMeta,
        district.isAcceptableOrUnknown(data['district']!, _districtMeta),
      );
    } else if (isInserting) {
      context.missing(_districtMeta);
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('state_uf')) {
      context.handle(
        _stateUfMeta,
        stateUf.isAcceptableOrUnknown(data['state_uf']!, _stateUfMeta),
      );
    } else if (isInserting) {
      context.missing(_stateUfMeta);
    }
    if (data.containsKey('cep')) {
      context.handle(
        _cepMeta,
        cep.isAcceptableOrUnknown(data['cep']!, _cepMeta),
      );
    } else if (isInserting) {
      context.missing(_cepMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GymEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GymEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cnpj: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cnpj'],
      )!,
      street: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}street'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      )!,
      complement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}complement'],
      ),
      district: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district'],
      )!,
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      stateUf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_uf'],
      )!,
      cep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cep'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GymsTable createAlias(String alias) {
    return $GymsTable(attachedDatabase, alias);
  }
}

class GymEntity extends DataClass implements Insertable<GymEntity> {
  final String id;
  final String name;
  final String cnpj;
  final String street;
  final String number;
  final String? complement;
  final String district;
  final String city;
  final String stateUf;
  final String cep;
  final DateTime createdAt;
  final DateTime updatedAt;
  const GymEntity({
    required this.id,
    required this.name,
    required this.cnpj,
    required this.street,
    required this.number,
    this.complement,
    required this.district,
    required this.city,
    required this.stateUf,
    required this.cep,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['cnpj'] = Variable<String>(cnpj);
    map['street'] = Variable<String>(street);
    map['number'] = Variable<String>(number);
    if (!nullToAbsent || complement != null) {
      map['complement'] = Variable<String>(complement);
    }
    map['district'] = Variable<String>(district);
    map['city'] = Variable<String>(city);
    map['state_uf'] = Variable<String>(stateUf);
    map['cep'] = Variable<String>(cep);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GymsCompanion toCompanion(bool nullToAbsent) {
    return GymsCompanion(
      id: Value(id),
      name: Value(name),
      cnpj: Value(cnpj),
      street: Value(street),
      number: Value(number),
      complement: complement == null && nullToAbsent
          ? const Value.absent()
          : Value(complement),
      district: Value(district),
      city: Value(city),
      stateUf: Value(stateUf),
      cep: Value(cep),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory GymEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GymEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      cnpj: serializer.fromJson<String>(json['cnpj']),
      street: serializer.fromJson<String>(json['street']),
      number: serializer.fromJson<String>(json['number']),
      complement: serializer.fromJson<String?>(json['complement']),
      district: serializer.fromJson<String>(json['district']),
      city: serializer.fromJson<String>(json['city']),
      stateUf: serializer.fromJson<String>(json['stateUf']),
      cep: serializer.fromJson<String>(json['cep']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'cnpj': serializer.toJson<String>(cnpj),
      'street': serializer.toJson<String>(street),
      'number': serializer.toJson<String>(number),
      'complement': serializer.toJson<String?>(complement),
      'district': serializer.toJson<String>(district),
      'city': serializer.toJson<String>(city),
      'stateUf': serializer.toJson<String>(stateUf),
      'cep': serializer.toJson<String>(cep),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GymEntity copyWith({
    String? id,
    String? name,
    String? cnpj,
    String? street,
    String? number,
    Value<String?> complement = const Value.absent(),
    String? district,
    String? city,
    String? stateUf,
    String? cep,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => GymEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    cnpj: cnpj ?? this.cnpj,
    street: street ?? this.street,
    number: number ?? this.number,
    complement: complement.present ? complement.value : this.complement,
    district: district ?? this.district,
    city: city ?? this.city,
    stateUf: stateUf ?? this.stateUf,
    cep: cep ?? this.cep,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GymEntity copyWithCompanion(GymsCompanion data) {
    return GymEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      cnpj: data.cnpj.present ? data.cnpj.value : this.cnpj,
      street: data.street.present ? data.street.value : this.street,
      number: data.number.present ? data.number.value : this.number,
      complement: data.complement.present
          ? data.complement.value
          : this.complement,
      district: data.district.present ? data.district.value : this.district,
      city: data.city.present ? data.city.value : this.city,
      stateUf: data.stateUf.present ? data.stateUf.value : this.stateUf,
      cep: data.cep.present ? data.cep.value : this.cep,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GymEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cnpj: $cnpj, ')
          ..write('street: $street, ')
          ..write('number: $number, ')
          ..write('complement: $complement, ')
          ..write('district: $district, ')
          ..write('city: $city, ')
          ..write('stateUf: $stateUf, ')
          ..write('cep: $cep, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    cnpj,
    street,
    number,
    complement,
    district,
    city,
    stateUf,
    cep,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.cnpj == this.cnpj &&
          other.street == this.street &&
          other.number == this.number &&
          other.complement == this.complement &&
          other.district == this.district &&
          other.city == this.city &&
          other.stateUf == this.stateUf &&
          other.cep == this.cep &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GymsCompanion extends UpdateCompanion<GymEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> cnpj;
  final Value<String> street;
  final Value<String> number;
  final Value<String?> complement;
  final Value<String> district;
  final Value<String> city;
  final Value<String> stateUf;
  final Value<String> cep;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GymsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.cnpj = const Value.absent(),
    this.street = const Value.absent(),
    this.number = const Value.absent(),
    this.complement = const Value.absent(),
    this.district = const Value.absent(),
    this.city = const Value.absent(),
    this.stateUf = const Value.absent(),
    this.cep = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GymsCompanion.insert({
    required String id,
    required String name,
    required String cnpj,
    required String street,
    required String number,
    this.complement = const Value.absent(),
    required String district,
    required String city,
    required String stateUf,
    required String cep,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       cnpj = Value(cnpj),
       street = Value(street),
       number = Value(number),
       district = Value(district),
       city = Value(city),
       stateUf = Value(stateUf),
       cep = Value(cep);
  static Insertable<GymEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? cnpj,
    Expression<String>? street,
    Expression<String>? number,
    Expression<String>? complement,
    Expression<String>? district,
    Expression<String>? city,
    Expression<String>? stateUf,
    Expression<String>? cep,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (cnpj != null) 'cnpj': cnpj,
      if (street != null) 'street': street,
      if (number != null) 'number': number,
      if (complement != null) 'complement': complement,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (stateUf != null) 'state_uf': stateUf,
      if (cep != null) 'cep': cep,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GymsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? cnpj,
    Value<String>? street,
    Value<String>? number,
    Value<String?>? complement,
    Value<String>? district,
    Value<String>? city,
    Value<String>? stateUf,
    Value<String>? cep,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GymsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      cnpj: cnpj ?? this.cnpj,
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      district: district ?? this.district,
      city: city ?? this.city,
      stateUf: stateUf ?? this.stateUf,
      cep: cep ?? this.cep,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cnpj.present) {
      map['cnpj'] = Variable<String>(cnpj.value);
    }
    if (street.present) {
      map['street'] = Variable<String>(street.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (complement.present) {
      map['complement'] = Variable<String>(complement.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (stateUf.present) {
      map['state_uf'] = Variable<String>(stateUf.value);
    }
    if (cep.present) {
      map['cep'] = Variable<String>(cep.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GymsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cnpj: $cnpj, ')
          ..write('street: $street, ')
          ..write('number: $number, ')
          ..write('complement: $complement, ')
          ..write('district: $district, ')
          ..write('city: $city, ')
          ..write('stateUf: $stateUf, ')
          ..write('cep: $cep, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PersonalsTable extends Personals
    with TableInfo<$PersonalsTable, PersonalEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cpfMeta = const VerificationMeta('cpf');
  @override
  late final GeneratedColumn<String> cpf = GeneratedColumn<String>(
    'cpf',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _professionalRegistryMeta =
      const VerificationMeta('professionalRegistry');
  @override
  late final GeneratedColumn<String> professionalRegistry =
      GeneratedColumn<String>(
        'professional_registry',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _streetMeta = const VerificationMeta('street');
  @override
  late final GeneratedColumn<String> street = GeneratedColumn<String>(
    'street',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _complementMeta = const VerificationMeta(
    'complement',
  );
  @override
  late final GeneratedColumn<String> complement = GeneratedColumn<String>(
    'complement',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateUfMeta = const VerificationMeta(
    'stateUf',
  );
  @override
  late final GeneratedColumn<String> stateUf = GeneratedColumn<String>(
    'state_uf',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cepMeta = const VerificationMeta('cep');
  @override
  late final GeneratedColumn<String> cep = GeneratedColumn<String>(
    'cep',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneCommercialMeta = const VerificationMeta(
    'phoneCommercial',
  );
  @override
  late final GeneratedColumn<String> phoneCommercial = GeneratedColumn<String>(
    'phone_commercial',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMobileMeta = const VerificationMeta(
    'phoneMobile',
  );
  @override
  late final GeneratedColumn<String> phoneMobile = GeneratedColumn<String>(
    'phone_mobile',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mustChangePasswordMeta =
      const VerificationMeta('mustChangePassword');
  @override
  late final GeneratedColumn<bool> mustChangePassword = GeneratedColumn<bool>(
    'must_change_password',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("must_change_password" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAdminMeta = const VerificationMeta(
    'isAdmin',
  );
  @override
  late final GeneratedColumn<bool> isAdmin = GeneratedColumn<bool>(
    'is_admin',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_admin" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    cpf,
    professionalRegistry,
    street,
    number,
    complement,
    city,
    stateUf,
    cep,
    email,
    phoneCommercial,
    phoneMobile,
    mustChangePassword,
    passwordHash,
    isAdmin,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'personals';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonalEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cpf')) {
      context.handle(
        _cpfMeta,
        cpf.isAcceptableOrUnknown(data['cpf']!, _cpfMeta),
      );
    } else if (isInserting) {
      context.missing(_cpfMeta);
    }
    if (data.containsKey('professional_registry')) {
      context.handle(
        _professionalRegistryMeta,
        professionalRegistry.isAcceptableOrUnknown(
          data['professional_registry']!,
          _professionalRegistryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_professionalRegistryMeta);
    }
    if (data.containsKey('street')) {
      context.handle(
        _streetMeta,
        street.isAcceptableOrUnknown(data['street']!, _streetMeta),
      );
    } else if (isInserting) {
      context.missing(_streetMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('complement')) {
      context.handle(
        _complementMeta,
        complement.isAcceptableOrUnknown(data['complement']!, _complementMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    } else if (isInserting) {
      context.missing(_cityMeta);
    }
    if (data.containsKey('state_uf')) {
      context.handle(
        _stateUfMeta,
        stateUf.isAcceptableOrUnknown(data['state_uf']!, _stateUfMeta),
      );
    } else if (isInserting) {
      context.missing(_stateUfMeta);
    }
    if (data.containsKey('cep')) {
      context.handle(
        _cepMeta,
        cep.isAcceptableOrUnknown(data['cep']!, _cepMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('phone_commercial')) {
      context.handle(
        _phoneCommercialMeta,
        phoneCommercial.isAcceptableOrUnknown(
          data['phone_commercial']!,
          _phoneCommercialMeta,
        ),
      );
    }
    if (data.containsKey('phone_mobile')) {
      context.handle(
        _phoneMobileMeta,
        phoneMobile.isAcceptableOrUnknown(
          data['phone_mobile']!,
          _phoneMobileMeta,
        ),
      );
    }
    if (data.containsKey('must_change_password')) {
      context.handle(
        _mustChangePasswordMeta,
        mustChangePassword.isAcceptableOrUnknown(
          data['must_change_password']!,
          _mustChangePasswordMeta,
        ),
      );
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    }
    if (data.containsKey('is_admin')) {
      context.handle(
        _isAdminMeta,
        isAdmin.isAcceptableOrUnknown(data['is_admin']!, _isAdminMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonalEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonalEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cpf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cpf'],
      )!,
      professionalRegistry: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}professional_registry'],
      )!,
      street: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}street'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      )!,
      complement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}complement'],
      ),
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      )!,
      stateUf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_uf'],
      )!,
      cep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cep'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      phoneCommercial: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_commercial'],
      ),
      phoneMobile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_mobile'],
      ),
      mustChangePassword: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}must_change_password'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      ),
      isAdmin: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_admin'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PersonalsTable createAlias(String alias) {
    return $PersonalsTable(attachedDatabase, alias);
  }
}

class PersonalEntity extends DataClass implements Insertable<PersonalEntity> {
  final String id;
  final String name;
  final String cpf;
  final String professionalRegistry;
  final String street;
  final String number;
  final String? complement;
  final String city;
  final String stateUf;
  final String? cep;
  final String email;
  final String? phoneCommercial;
  final String? phoneMobile;
  final bool mustChangePassword;
  final String? passwordHash;

  /// Acesso total aos dados de todos os alunos (calendário, planejamento, cadastro).
  final bool isAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PersonalEntity({
    required this.id,
    required this.name,
    required this.cpf,
    required this.professionalRegistry,
    required this.street,
    required this.number,
    this.complement,
    required this.city,
    required this.stateUf,
    this.cep,
    required this.email,
    this.phoneCommercial,
    this.phoneMobile,
    required this.mustChangePassword,
    this.passwordHash,
    required this.isAdmin,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['cpf'] = Variable<String>(cpf);
    map['professional_registry'] = Variable<String>(professionalRegistry);
    map['street'] = Variable<String>(street);
    map['number'] = Variable<String>(number);
    if (!nullToAbsent || complement != null) {
      map['complement'] = Variable<String>(complement);
    }
    map['city'] = Variable<String>(city);
    map['state_uf'] = Variable<String>(stateUf);
    if (!nullToAbsent || cep != null) {
      map['cep'] = Variable<String>(cep);
    }
    map['email'] = Variable<String>(email);
    if (!nullToAbsent || phoneCommercial != null) {
      map['phone_commercial'] = Variable<String>(phoneCommercial);
    }
    if (!nullToAbsent || phoneMobile != null) {
      map['phone_mobile'] = Variable<String>(phoneMobile);
    }
    map['must_change_password'] = Variable<bool>(mustChangePassword);
    if (!nullToAbsent || passwordHash != null) {
      map['password_hash'] = Variable<String>(passwordHash);
    }
    map['is_admin'] = Variable<bool>(isAdmin);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PersonalsCompanion toCompanion(bool nullToAbsent) {
    return PersonalsCompanion(
      id: Value(id),
      name: Value(name),
      cpf: Value(cpf),
      professionalRegistry: Value(professionalRegistry),
      street: Value(street),
      number: Value(number),
      complement: complement == null && nullToAbsent
          ? const Value.absent()
          : Value(complement),
      city: Value(city),
      stateUf: Value(stateUf),
      cep: cep == null && nullToAbsent ? const Value.absent() : Value(cep),
      email: Value(email),
      phoneCommercial: phoneCommercial == null && nullToAbsent
          ? const Value.absent()
          : Value(phoneCommercial),
      phoneMobile: phoneMobile == null && nullToAbsent
          ? const Value.absent()
          : Value(phoneMobile),
      mustChangePassword: Value(mustChangePassword),
      passwordHash: passwordHash == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordHash),
      isAdmin: Value(isAdmin),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PersonalEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonalEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      cpf: serializer.fromJson<String>(json['cpf']),
      professionalRegistry: serializer.fromJson<String>(
        json['professionalRegistry'],
      ),
      street: serializer.fromJson<String>(json['street']),
      number: serializer.fromJson<String>(json['number']),
      complement: serializer.fromJson<String?>(json['complement']),
      city: serializer.fromJson<String>(json['city']),
      stateUf: serializer.fromJson<String>(json['stateUf']),
      cep: serializer.fromJson<String?>(json['cep']),
      email: serializer.fromJson<String>(json['email']),
      phoneCommercial: serializer.fromJson<String?>(json['phoneCommercial']),
      phoneMobile: serializer.fromJson<String?>(json['phoneMobile']),
      mustChangePassword: serializer.fromJson<bool>(json['mustChangePassword']),
      passwordHash: serializer.fromJson<String?>(json['passwordHash']),
      isAdmin: serializer.fromJson<bool>(json['isAdmin']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'cpf': serializer.toJson<String>(cpf),
      'professionalRegistry': serializer.toJson<String>(professionalRegistry),
      'street': serializer.toJson<String>(street),
      'number': serializer.toJson<String>(number),
      'complement': serializer.toJson<String?>(complement),
      'city': serializer.toJson<String>(city),
      'stateUf': serializer.toJson<String>(stateUf),
      'cep': serializer.toJson<String?>(cep),
      'email': serializer.toJson<String>(email),
      'phoneCommercial': serializer.toJson<String?>(phoneCommercial),
      'phoneMobile': serializer.toJson<String?>(phoneMobile),
      'mustChangePassword': serializer.toJson<bool>(mustChangePassword),
      'passwordHash': serializer.toJson<String?>(passwordHash),
      'isAdmin': serializer.toJson<bool>(isAdmin),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PersonalEntity copyWith({
    String? id,
    String? name,
    String? cpf,
    String? professionalRegistry,
    String? street,
    String? number,
    Value<String?> complement = const Value.absent(),
    String? city,
    String? stateUf,
    Value<String?> cep = const Value.absent(),
    String? email,
    Value<String?> phoneCommercial = const Value.absent(),
    Value<String?> phoneMobile = const Value.absent(),
    bool? mustChangePassword,
    Value<String?> passwordHash = const Value.absent(),
    bool? isAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PersonalEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    cpf: cpf ?? this.cpf,
    professionalRegistry: professionalRegistry ?? this.professionalRegistry,
    street: street ?? this.street,
    number: number ?? this.number,
    complement: complement.present ? complement.value : this.complement,
    city: city ?? this.city,
    stateUf: stateUf ?? this.stateUf,
    cep: cep.present ? cep.value : this.cep,
    email: email ?? this.email,
    phoneCommercial: phoneCommercial.present
        ? phoneCommercial.value
        : this.phoneCommercial,
    phoneMobile: phoneMobile.present ? phoneMobile.value : this.phoneMobile,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    passwordHash: passwordHash.present ? passwordHash.value : this.passwordHash,
    isAdmin: isAdmin ?? this.isAdmin,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PersonalEntity copyWithCompanion(PersonalsCompanion data) {
    return PersonalEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      cpf: data.cpf.present ? data.cpf.value : this.cpf,
      professionalRegistry: data.professionalRegistry.present
          ? data.professionalRegistry.value
          : this.professionalRegistry,
      street: data.street.present ? data.street.value : this.street,
      number: data.number.present ? data.number.value : this.number,
      complement: data.complement.present
          ? data.complement.value
          : this.complement,
      city: data.city.present ? data.city.value : this.city,
      stateUf: data.stateUf.present ? data.stateUf.value : this.stateUf,
      cep: data.cep.present ? data.cep.value : this.cep,
      email: data.email.present ? data.email.value : this.email,
      phoneCommercial: data.phoneCommercial.present
          ? data.phoneCommercial.value
          : this.phoneCommercial,
      phoneMobile: data.phoneMobile.present
          ? data.phoneMobile.value
          : this.phoneMobile,
      mustChangePassword: data.mustChangePassword.present
          ? data.mustChangePassword.value
          : this.mustChangePassword,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      isAdmin: data.isAdmin.present ? data.isAdmin.value : this.isAdmin,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonalEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cpf: $cpf, ')
          ..write('professionalRegistry: $professionalRegistry, ')
          ..write('street: $street, ')
          ..write('number: $number, ')
          ..write('complement: $complement, ')
          ..write('city: $city, ')
          ..write('stateUf: $stateUf, ')
          ..write('cep: $cep, ')
          ..write('email: $email, ')
          ..write('phoneCommercial: $phoneCommercial, ')
          ..write('phoneMobile: $phoneMobile, ')
          ..write('mustChangePassword: $mustChangePassword, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('isAdmin: $isAdmin, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    cpf,
    professionalRegistry,
    street,
    number,
    complement,
    city,
    stateUf,
    cep,
    email,
    phoneCommercial,
    phoneMobile,
    mustChangePassword,
    passwordHash,
    isAdmin,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonalEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.cpf == this.cpf &&
          other.professionalRegistry == this.professionalRegistry &&
          other.street == this.street &&
          other.number == this.number &&
          other.complement == this.complement &&
          other.city == this.city &&
          other.stateUf == this.stateUf &&
          other.cep == this.cep &&
          other.email == this.email &&
          other.phoneCommercial == this.phoneCommercial &&
          other.phoneMobile == this.phoneMobile &&
          other.mustChangePassword == this.mustChangePassword &&
          other.passwordHash == this.passwordHash &&
          other.isAdmin == this.isAdmin &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PersonalsCompanion extends UpdateCompanion<PersonalEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> cpf;
  final Value<String> professionalRegistry;
  final Value<String> street;
  final Value<String> number;
  final Value<String?> complement;
  final Value<String> city;
  final Value<String> stateUf;
  final Value<String?> cep;
  final Value<String> email;
  final Value<String?> phoneCommercial;
  final Value<String?> phoneMobile;
  final Value<bool> mustChangePassword;
  final Value<String?> passwordHash;
  final Value<bool> isAdmin;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PersonalsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.cpf = const Value.absent(),
    this.professionalRegistry = const Value.absent(),
    this.street = const Value.absent(),
    this.number = const Value.absent(),
    this.complement = const Value.absent(),
    this.city = const Value.absent(),
    this.stateUf = const Value.absent(),
    this.cep = const Value.absent(),
    this.email = const Value.absent(),
    this.phoneCommercial = const Value.absent(),
    this.phoneMobile = const Value.absent(),
    this.mustChangePassword = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.isAdmin = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonalsCompanion.insert({
    required String id,
    required String name,
    required String cpf,
    required String professionalRegistry,
    required String street,
    required String number,
    this.complement = const Value.absent(),
    required String city,
    required String stateUf,
    this.cep = const Value.absent(),
    required String email,
    this.phoneCommercial = const Value.absent(),
    this.phoneMobile = const Value.absent(),
    this.mustChangePassword = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.isAdmin = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       cpf = Value(cpf),
       professionalRegistry = Value(professionalRegistry),
       street = Value(street),
       number = Value(number),
       city = Value(city),
       stateUf = Value(stateUf),
       email = Value(email);
  static Insertable<PersonalEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? cpf,
    Expression<String>? professionalRegistry,
    Expression<String>? street,
    Expression<String>? number,
    Expression<String>? complement,
    Expression<String>? city,
    Expression<String>? stateUf,
    Expression<String>? cep,
    Expression<String>? email,
    Expression<String>? phoneCommercial,
    Expression<String>? phoneMobile,
    Expression<bool>? mustChangePassword,
    Expression<String>? passwordHash,
    Expression<bool>? isAdmin,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (cpf != null) 'cpf': cpf,
      if (professionalRegistry != null)
        'professional_registry': professionalRegistry,
      if (street != null) 'street': street,
      if (number != null) 'number': number,
      if (complement != null) 'complement': complement,
      if (city != null) 'city': city,
      if (stateUf != null) 'state_uf': stateUf,
      if (cep != null) 'cep': cep,
      if (email != null) 'email': email,
      if (phoneCommercial != null) 'phone_commercial': phoneCommercial,
      if (phoneMobile != null) 'phone_mobile': phoneMobile,
      if (mustChangePassword != null)
        'must_change_password': mustChangePassword,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (isAdmin != null) 'is_admin': isAdmin,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonalsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? cpf,
    Value<String>? professionalRegistry,
    Value<String>? street,
    Value<String>? number,
    Value<String?>? complement,
    Value<String>? city,
    Value<String>? stateUf,
    Value<String?>? cep,
    Value<String>? email,
    Value<String?>? phoneCommercial,
    Value<String?>? phoneMobile,
    Value<bool>? mustChangePassword,
    Value<String?>? passwordHash,
    Value<bool>? isAdmin,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PersonalsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      cpf: cpf ?? this.cpf,
      professionalRegistry: professionalRegistry ?? this.professionalRegistry,
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      city: city ?? this.city,
      stateUf: stateUf ?? this.stateUf,
      cep: cep ?? this.cep,
      email: email ?? this.email,
      phoneCommercial: phoneCommercial ?? this.phoneCommercial,
      phoneMobile: phoneMobile ?? this.phoneMobile,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      passwordHash: passwordHash ?? this.passwordHash,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cpf.present) {
      map['cpf'] = Variable<String>(cpf.value);
    }
    if (professionalRegistry.present) {
      map['professional_registry'] = Variable<String>(
        professionalRegistry.value,
      );
    }
    if (street.present) {
      map['street'] = Variable<String>(street.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (complement.present) {
      map['complement'] = Variable<String>(complement.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (stateUf.present) {
      map['state_uf'] = Variable<String>(stateUf.value);
    }
    if (cep.present) {
      map['cep'] = Variable<String>(cep.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (phoneCommercial.present) {
      map['phone_commercial'] = Variable<String>(phoneCommercial.value);
    }
    if (phoneMobile.present) {
      map['phone_mobile'] = Variable<String>(phoneMobile.value);
    }
    if (mustChangePassword.present) {
      map['must_change_password'] = Variable<bool>(mustChangePassword.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (isAdmin.present) {
      map['is_admin'] = Variable<bool>(isAdmin.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonalsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('cpf: $cpf, ')
          ..write('professionalRegistry: $professionalRegistry, ')
          ..write('street: $street, ')
          ..write('number: $number, ')
          ..write('complement: $complement, ')
          ..write('city: $city, ')
          ..write('stateUf: $stateUf, ')
          ..write('cep: $cep, ')
          ..write('email: $email, ')
          ..write('phoneCommercial: $phoneCommercial, ')
          ..write('phoneMobile: $phoneMobile, ')
          ..write('mustChangePassword: $mustChangePassword, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('isAdmin: $isAdmin, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudentsTable extends Students
    with TableInfo<$StudentsTable, StudentEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<String> goal = GeneratedColumn<String>(
    'goal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cpfMeta = const VerificationMeta('cpf');
  @override
  late final GeneratedColumn<String> cpf = GeneratedColumn<String>(
    'cpf',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streetMeta = const VerificationMeta('street');
  @override
  late final GeneratedColumn<String> street = GeneratedColumn<String>(
    'street',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String> number = GeneratedColumn<String>(
    'number',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _complementMeta = const VerificationMeta(
    'complement',
  );
  @override
  late final GeneratedColumn<String> complement = GeneratedColumn<String>(
    'complement',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _districtMeta = const VerificationMeta(
    'district',
  );
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
    'district',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cityMeta = const VerificationMeta('city');
  @override
  late final GeneratedColumn<String> city = GeneratedColumn<String>(
    'city',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateUfMeta = const VerificationMeta(
    'stateUf',
  );
  @override
  late final GeneratedColumn<String> stateUf = GeneratedColumn<String>(
    'state_uf',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cepMeta = const VerificationMeta('cep');
  @override
  late final GeneratedColumn<String> cep = GeneratedColumn<String>(
    'cep',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneCommercialMeta = const VerificationMeta(
    'phoneCommercial',
  );
  @override
  late final GeneratedColumn<String> phoneCommercial = GeneratedColumn<String>(
    'phone_commercial',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMobileMeta = const VerificationMeta(
    'phoneMobile',
  );
  @override
  late final GeneratedColumn<String> phoneMobile = GeneratedColumn<String>(
    'phone_mobile',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mustChangePasswordMeta =
      const VerificationMeta('mustChangePassword');
  @override
  late final GeneratedColumn<bool> mustChangePassword = GeneratedColumn<bool>(
    'must_change_password',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("must_change_password" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByPersonalIdMeta =
      const VerificationMeta('createdByPersonalId');
  @override
  late final GeneratedColumn<String> createdByPersonalId =
      GeneratedColumn<String>(
        'created_by_personal_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES personals (id)',
        ),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    email,
    goal,
    cpf,
    birthDate,
    street,
    number,
    complement,
    district,
    city,
    stateUf,
    cep,
    phoneCommercial,
    phoneMobile,
    mustChangePassword,
    passwordHash,
    createdByPersonalId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'students';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudentEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('goal')) {
      context.handle(
        _goalMeta,
        goal.isAcceptableOrUnknown(data['goal']!, _goalMeta),
      );
    }
    if (data.containsKey('cpf')) {
      context.handle(
        _cpfMeta,
        cpf.isAcceptableOrUnknown(data['cpf']!, _cpfMeta),
      );
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('street')) {
      context.handle(
        _streetMeta,
        street.isAcceptableOrUnknown(data['street']!, _streetMeta),
      );
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('complement')) {
      context.handle(
        _complementMeta,
        complement.isAcceptableOrUnknown(data['complement']!, _complementMeta),
      );
    }
    if (data.containsKey('district')) {
      context.handle(
        _districtMeta,
        district.isAcceptableOrUnknown(data['district']!, _districtMeta),
      );
    }
    if (data.containsKey('city')) {
      context.handle(
        _cityMeta,
        city.isAcceptableOrUnknown(data['city']!, _cityMeta),
      );
    }
    if (data.containsKey('state_uf')) {
      context.handle(
        _stateUfMeta,
        stateUf.isAcceptableOrUnknown(data['state_uf']!, _stateUfMeta),
      );
    }
    if (data.containsKey('cep')) {
      context.handle(
        _cepMeta,
        cep.isAcceptableOrUnknown(data['cep']!, _cepMeta),
      );
    }
    if (data.containsKey('phone_commercial')) {
      context.handle(
        _phoneCommercialMeta,
        phoneCommercial.isAcceptableOrUnknown(
          data['phone_commercial']!,
          _phoneCommercialMeta,
        ),
      );
    }
    if (data.containsKey('phone_mobile')) {
      context.handle(
        _phoneMobileMeta,
        phoneMobile.isAcceptableOrUnknown(
          data['phone_mobile']!,
          _phoneMobileMeta,
        ),
      );
    }
    if (data.containsKey('must_change_password')) {
      context.handle(
        _mustChangePasswordMeta,
        mustChangePassword.isAcceptableOrUnknown(
          data['must_change_password']!,
          _mustChangePasswordMeta,
        ),
      );
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    }
    if (data.containsKey('created_by_personal_id')) {
      context.handle(
        _createdByPersonalIdMeta,
        createdByPersonalId.isAcceptableOrUnknown(
          data['created_by_personal_id']!,
          _createdByPersonalIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudentEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudentEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      goal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal'],
      ),
      cpf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cpf'],
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      ),
      street: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}street'],
      ),
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}number'],
      ),
      complement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}complement'],
      ),
      district: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}district'],
      ),
      city: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}city'],
      ),
      stateUf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_uf'],
      ),
      cep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cep'],
      ),
      phoneCommercial: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_commercial'],
      ),
      phoneMobile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone_mobile'],
      ),
      mustChangePassword: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}must_change_password'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      ),
      createdByPersonalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_personal_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StudentsTable createAlias(String alias) {
    return $StudentsTable(attachedDatabase, alias);
  }
}

class StudentEntity extends DataClass implements Insertable<StudentEntity> {
  final String id;
  final String name;
  final String? email;
  final String? goal;
  final String? cpf;
  final DateTime? birthDate;
  final String? street;
  final String? number;
  final String? complement;
  final String? district;
  final String? city;
  final String? stateUf;
  final String? cep;
  final String? phoneCommercial;
  final String? phoneMobile;

  /// Quando true, o app exige troca de senha no próximo acesso.
  final bool mustChangePassword;
  final String? passwordHash;

  /// Personal que cadastrou o aluno — visibilidade dos dados (com admin e o próprio aluno).
  final String? createdByPersonalId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StudentEntity({
    required this.id,
    required this.name,
    this.email,
    this.goal,
    this.cpf,
    this.birthDate,
    this.street,
    this.number,
    this.complement,
    this.district,
    this.city,
    this.stateUf,
    this.cep,
    this.phoneCommercial,
    this.phoneMobile,
    required this.mustChangePassword,
    this.passwordHash,
    this.createdByPersonalId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || goal != null) {
      map['goal'] = Variable<String>(goal);
    }
    if (!nullToAbsent || cpf != null) {
      map['cpf'] = Variable<String>(cpf);
    }
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<DateTime>(birthDate);
    }
    if (!nullToAbsent || street != null) {
      map['street'] = Variable<String>(street);
    }
    if (!nullToAbsent || number != null) {
      map['number'] = Variable<String>(number);
    }
    if (!nullToAbsent || complement != null) {
      map['complement'] = Variable<String>(complement);
    }
    if (!nullToAbsent || district != null) {
      map['district'] = Variable<String>(district);
    }
    if (!nullToAbsent || city != null) {
      map['city'] = Variable<String>(city);
    }
    if (!nullToAbsent || stateUf != null) {
      map['state_uf'] = Variable<String>(stateUf);
    }
    if (!nullToAbsent || cep != null) {
      map['cep'] = Variable<String>(cep);
    }
    if (!nullToAbsent || phoneCommercial != null) {
      map['phone_commercial'] = Variable<String>(phoneCommercial);
    }
    if (!nullToAbsent || phoneMobile != null) {
      map['phone_mobile'] = Variable<String>(phoneMobile);
    }
    map['must_change_password'] = Variable<bool>(mustChangePassword);
    if (!nullToAbsent || passwordHash != null) {
      map['password_hash'] = Variable<String>(passwordHash);
    }
    if (!nullToAbsent || createdByPersonalId != null) {
      map['created_by_personal_id'] = Variable<String>(createdByPersonalId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  StudentsCompanion toCompanion(bool nullToAbsent) {
    return StudentsCompanion(
      id: Value(id),
      name: Value(name),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      goal: goal == null && nullToAbsent ? const Value.absent() : Value(goal),
      cpf: cpf == null && nullToAbsent ? const Value.absent() : Value(cpf),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      street: street == null && nullToAbsent
          ? const Value.absent()
          : Value(street),
      number: number == null && nullToAbsent
          ? const Value.absent()
          : Value(number),
      complement: complement == null && nullToAbsent
          ? const Value.absent()
          : Value(complement),
      district: district == null && nullToAbsent
          ? const Value.absent()
          : Value(district),
      city: city == null && nullToAbsent ? const Value.absent() : Value(city),
      stateUf: stateUf == null && nullToAbsent
          ? const Value.absent()
          : Value(stateUf),
      cep: cep == null && nullToAbsent ? const Value.absent() : Value(cep),
      phoneCommercial: phoneCommercial == null && nullToAbsent
          ? const Value.absent()
          : Value(phoneCommercial),
      phoneMobile: phoneMobile == null && nullToAbsent
          ? const Value.absent()
          : Value(phoneMobile),
      mustChangePassword: Value(mustChangePassword),
      passwordHash: passwordHash == null && nullToAbsent
          ? const Value.absent()
          : Value(passwordHash),
      createdByPersonalId: createdByPersonalId == null && nullToAbsent
          ? const Value.absent()
          : Value(createdByPersonalId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StudentEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudentEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String?>(json['email']),
      goal: serializer.fromJson<String?>(json['goal']),
      cpf: serializer.fromJson<String?>(json['cpf']),
      birthDate: serializer.fromJson<DateTime?>(json['birthDate']),
      street: serializer.fromJson<String?>(json['street']),
      number: serializer.fromJson<String?>(json['number']),
      complement: serializer.fromJson<String?>(json['complement']),
      district: serializer.fromJson<String?>(json['district']),
      city: serializer.fromJson<String?>(json['city']),
      stateUf: serializer.fromJson<String?>(json['stateUf']),
      cep: serializer.fromJson<String?>(json['cep']),
      phoneCommercial: serializer.fromJson<String?>(json['phoneCommercial']),
      phoneMobile: serializer.fromJson<String?>(json['phoneMobile']),
      mustChangePassword: serializer.fromJson<bool>(json['mustChangePassword']),
      passwordHash: serializer.fromJson<String?>(json['passwordHash']),
      createdByPersonalId: serializer.fromJson<String?>(
        json['createdByPersonalId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String?>(email),
      'goal': serializer.toJson<String?>(goal),
      'cpf': serializer.toJson<String?>(cpf),
      'birthDate': serializer.toJson<DateTime?>(birthDate),
      'street': serializer.toJson<String?>(street),
      'number': serializer.toJson<String?>(number),
      'complement': serializer.toJson<String?>(complement),
      'district': serializer.toJson<String?>(district),
      'city': serializer.toJson<String?>(city),
      'stateUf': serializer.toJson<String?>(stateUf),
      'cep': serializer.toJson<String?>(cep),
      'phoneCommercial': serializer.toJson<String?>(phoneCommercial),
      'phoneMobile': serializer.toJson<String?>(phoneMobile),
      'mustChangePassword': serializer.toJson<bool>(mustChangePassword),
      'passwordHash': serializer.toJson<String?>(passwordHash),
      'createdByPersonalId': serializer.toJson<String?>(createdByPersonalId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StudentEntity copyWith({
    String? id,
    String? name,
    Value<String?> email = const Value.absent(),
    Value<String?> goal = const Value.absent(),
    Value<String?> cpf = const Value.absent(),
    Value<DateTime?> birthDate = const Value.absent(),
    Value<String?> street = const Value.absent(),
    Value<String?> number = const Value.absent(),
    Value<String?> complement = const Value.absent(),
    Value<String?> district = const Value.absent(),
    Value<String?> city = const Value.absent(),
    Value<String?> stateUf = const Value.absent(),
    Value<String?> cep = const Value.absent(),
    Value<String?> phoneCommercial = const Value.absent(),
    Value<String?> phoneMobile = const Value.absent(),
    bool? mustChangePassword,
    Value<String?> passwordHash = const Value.absent(),
    Value<String?> createdByPersonalId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StudentEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email.present ? email.value : this.email,
    goal: goal.present ? goal.value : this.goal,
    cpf: cpf.present ? cpf.value : this.cpf,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    street: street.present ? street.value : this.street,
    number: number.present ? number.value : this.number,
    complement: complement.present ? complement.value : this.complement,
    district: district.present ? district.value : this.district,
    city: city.present ? city.value : this.city,
    stateUf: stateUf.present ? stateUf.value : this.stateUf,
    cep: cep.present ? cep.value : this.cep,
    phoneCommercial: phoneCommercial.present
        ? phoneCommercial.value
        : this.phoneCommercial,
    phoneMobile: phoneMobile.present ? phoneMobile.value : this.phoneMobile,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    passwordHash: passwordHash.present ? passwordHash.value : this.passwordHash,
    createdByPersonalId: createdByPersonalId.present
        ? createdByPersonalId.value
        : this.createdByPersonalId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StudentEntity copyWithCompanion(StudentsCompanion data) {
    return StudentEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      goal: data.goal.present ? data.goal.value : this.goal,
      cpf: data.cpf.present ? data.cpf.value : this.cpf,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      street: data.street.present ? data.street.value : this.street,
      number: data.number.present ? data.number.value : this.number,
      complement: data.complement.present
          ? data.complement.value
          : this.complement,
      district: data.district.present ? data.district.value : this.district,
      city: data.city.present ? data.city.value : this.city,
      stateUf: data.stateUf.present ? data.stateUf.value : this.stateUf,
      cep: data.cep.present ? data.cep.value : this.cep,
      phoneCommercial: data.phoneCommercial.present
          ? data.phoneCommercial.value
          : this.phoneCommercial,
      phoneMobile: data.phoneMobile.present
          ? data.phoneMobile.value
          : this.phoneMobile,
      mustChangePassword: data.mustChangePassword.present
          ? data.mustChangePassword.value
          : this.mustChangePassword,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      createdByPersonalId: data.createdByPersonalId.present
          ? data.createdByPersonalId.value
          : this.createdByPersonalId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudentEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('goal: $goal, ')
          ..write('cpf: $cpf, ')
          ..write('birthDate: $birthDate, ')
          ..write('street: $street, ')
          ..write('number: $number, ')
          ..write('complement: $complement, ')
          ..write('district: $district, ')
          ..write('city: $city, ')
          ..write('stateUf: $stateUf, ')
          ..write('cep: $cep, ')
          ..write('phoneCommercial: $phoneCommercial, ')
          ..write('phoneMobile: $phoneMobile, ')
          ..write('mustChangePassword: $mustChangePassword, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('createdByPersonalId: $createdByPersonalId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    email,
    goal,
    cpf,
    birthDate,
    street,
    number,
    complement,
    district,
    city,
    stateUf,
    cep,
    phoneCommercial,
    phoneMobile,
    mustChangePassword,
    passwordHash,
    createdByPersonalId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudentEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.email == this.email &&
          other.goal == this.goal &&
          other.cpf == this.cpf &&
          other.birthDate == this.birthDate &&
          other.street == this.street &&
          other.number == this.number &&
          other.complement == this.complement &&
          other.district == this.district &&
          other.city == this.city &&
          other.stateUf == this.stateUf &&
          other.cep == this.cep &&
          other.phoneCommercial == this.phoneCommercial &&
          other.phoneMobile == this.phoneMobile &&
          other.mustChangePassword == this.mustChangePassword &&
          other.passwordHash == this.passwordHash &&
          other.createdByPersonalId == this.createdByPersonalId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class StudentsCompanion extends UpdateCompanion<StudentEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> email;
  final Value<String?> goal;
  final Value<String?> cpf;
  final Value<DateTime?> birthDate;
  final Value<String?> street;
  final Value<String?> number;
  final Value<String?> complement;
  final Value<String?> district;
  final Value<String?> city;
  final Value<String?> stateUf;
  final Value<String?> cep;
  final Value<String?> phoneCommercial;
  final Value<String?> phoneMobile;
  final Value<bool> mustChangePassword;
  final Value<String?> passwordHash;
  final Value<String?> createdByPersonalId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const StudentsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.goal = const Value.absent(),
    this.cpf = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.street = const Value.absent(),
    this.number = const Value.absent(),
    this.complement = const Value.absent(),
    this.district = const Value.absent(),
    this.city = const Value.absent(),
    this.stateUf = const Value.absent(),
    this.cep = const Value.absent(),
    this.phoneCommercial = const Value.absent(),
    this.phoneMobile = const Value.absent(),
    this.mustChangePassword = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.createdByPersonalId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudentsCompanion.insert({
    required String id,
    required String name,
    this.email = const Value.absent(),
    this.goal = const Value.absent(),
    this.cpf = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.street = const Value.absent(),
    this.number = const Value.absent(),
    this.complement = const Value.absent(),
    this.district = const Value.absent(),
    this.city = const Value.absent(),
    this.stateUf = const Value.absent(),
    this.cep = const Value.absent(),
    this.phoneCommercial = const Value.absent(),
    this.phoneMobile = const Value.absent(),
    this.mustChangePassword = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.createdByPersonalId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<StudentEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? email,
    Expression<String>? goal,
    Expression<String>? cpf,
    Expression<DateTime>? birthDate,
    Expression<String>? street,
    Expression<String>? number,
    Expression<String>? complement,
    Expression<String>? district,
    Expression<String>? city,
    Expression<String>? stateUf,
    Expression<String>? cep,
    Expression<String>? phoneCommercial,
    Expression<String>? phoneMobile,
    Expression<bool>? mustChangePassword,
    Expression<String>? passwordHash,
    Expression<String>? createdByPersonalId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (goal != null) 'goal': goal,
      if (cpf != null) 'cpf': cpf,
      if (birthDate != null) 'birth_date': birthDate,
      if (street != null) 'street': street,
      if (number != null) 'number': number,
      if (complement != null) 'complement': complement,
      if (district != null) 'district': district,
      if (city != null) 'city': city,
      if (stateUf != null) 'state_uf': stateUf,
      if (cep != null) 'cep': cep,
      if (phoneCommercial != null) 'phone_commercial': phoneCommercial,
      if (phoneMobile != null) 'phone_mobile': phoneMobile,
      if (mustChangePassword != null)
        'must_change_password': mustChangePassword,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (createdByPersonalId != null)
        'created_by_personal_id': createdByPersonalId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudentsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? email,
    Value<String?>? goal,
    Value<String?>? cpf,
    Value<DateTime?>? birthDate,
    Value<String?>? street,
    Value<String?>? number,
    Value<String?>? complement,
    Value<String?>? district,
    Value<String?>? city,
    Value<String?>? stateUf,
    Value<String?>? cep,
    Value<String?>? phoneCommercial,
    Value<String?>? phoneMobile,
    Value<bool>? mustChangePassword,
    Value<String?>? passwordHash,
    Value<String?>? createdByPersonalId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return StudentsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      goal: goal ?? this.goal,
      cpf: cpf ?? this.cpf,
      birthDate: birthDate ?? this.birthDate,
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      district: district ?? this.district,
      city: city ?? this.city,
      stateUf: stateUf ?? this.stateUf,
      cep: cep ?? this.cep,
      phoneCommercial: phoneCommercial ?? this.phoneCommercial,
      phoneMobile: phoneMobile ?? this.phoneMobile,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      passwordHash: passwordHash ?? this.passwordHash,
      createdByPersonalId: createdByPersonalId ?? this.createdByPersonalId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (goal.present) {
      map['goal'] = Variable<String>(goal.value);
    }
    if (cpf.present) {
      map['cpf'] = Variable<String>(cpf.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (street.present) {
      map['street'] = Variable<String>(street.value);
    }
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (complement.present) {
      map['complement'] = Variable<String>(complement.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (city.present) {
      map['city'] = Variable<String>(city.value);
    }
    if (stateUf.present) {
      map['state_uf'] = Variable<String>(stateUf.value);
    }
    if (cep.present) {
      map['cep'] = Variable<String>(cep.value);
    }
    if (phoneCommercial.present) {
      map['phone_commercial'] = Variable<String>(phoneCommercial.value);
    }
    if (phoneMobile.present) {
      map['phone_mobile'] = Variable<String>(phoneMobile.value);
    }
    if (mustChangePassword.present) {
      map['must_change_password'] = Variable<bool>(mustChangePassword.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (createdByPersonalId.present) {
      map['created_by_personal_id'] = Variable<String>(
        createdByPersonalId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('goal: $goal, ')
          ..write('cpf: $cpf, ')
          ..write('birthDate: $birthDate, ')
          ..write('street: $street, ')
          ..write('number: $number, ')
          ..write('complement: $complement, ')
          ..write('district: $district, ')
          ..write('city: $city, ')
          ..write('stateUf: $stateUf, ')
          ..write('cep: $cep, ')
          ..write('phoneCommercial: $phoneCommercial, ')
          ..write('phoneMobile: $phoneMobile, ')
          ..write('mustChangePassword: $mustChangePassword, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('createdByPersonalId: $createdByPersonalId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudentGymsTable extends StudentGyms
    with TableInfo<$StudentGymsTable, StudentGymEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentGymsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES students (id)',
    ),
  );
  static const VerificationMeta _gymIdMeta = const VerificationMeta('gymId');
  @override
  late final GeneratedColumn<String> gymId = GeneratedColumn<String>(
    'gym_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES gyms (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [studentId, gymId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'student_gyms';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudentGymEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('gym_id')) {
      context.handle(
        _gymIdMeta,
        gymId.isAcceptableOrUnknown(data['gym_id']!, _gymIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gymIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {studentId, gymId};
  @override
  StudentGymEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudentGymEntity(
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      gymId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gym_id'],
      )!,
    );
  }

  @override
  $StudentGymsTable createAlias(String alias) {
    return $StudentGymsTable(attachedDatabase, alias);
  }
}

class StudentGymEntity extends DataClass
    implements Insertable<StudentGymEntity> {
  final String studentId;
  final String gymId;
  const StudentGymEntity({required this.studentId, required this.gymId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['student_id'] = Variable<String>(studentId);
    map['gym_id'] = Variable<String>(gymId);
    return map;
  }

  StudentGymsCompanion toCompanion(bool nullToAbsent) {
    return StudentGymsCompanion(
      studentId: Value(studentId),
      gymId: Value(gymId),
    );
  }

  factory StudentGymEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudentGymEntity(
      studentId: serializer.fromJson<String>(json['studentId']),
      gymId: serializer.fromJson<String>(json['gymId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'studentId': serializer.toJson<String>(studentId),
      'gymId': serializer.toJson<String>(gymId),
    };
  }

  StudentGymEntity copyWith({String? studentId, String? gymId}) =>
      StudentGymEntity(
        studentId: studentId ?? this.studentId,
        gymId: gymId ?? this.gymId,
      );
  StudentGymEntity copyWithCompanion(StudentGymsCompanion data) {
    return StudentGymEntity(
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      gymId: data.gymId.present ? data.gymId.value : this.gymId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudentGymEntity(')
          ..write('studentId: $studentId, ')
          ..write('gymId: $gymId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(studentId, gymId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudentGymEntity &&
          other.studentId == this.studentId &&
          other.gymId == this.gymId);
}

class StudentGymsCompanion extends UpdateCompanion<StudentGymEntity> {
  final Value<String> studentId;
  final Value<String> gymId;
  final Value<int> rowid;
  const StudentGymsCompanion({
    this.studentId = const Value.absent(),
    this.gymId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudentGymsCompanion.insert({
    required String studentId,
    required String gymId,
    this.rowid = const Value.absent(),
  }) : studentId = Value(studentId),
       gymId = Value(gymId);
  static Insertable<StudentGymEntity> custom({
    Expression<String>? studentId,
    Expression<String>? gymId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (studentId != null) 'student_id': studentId,
      if (gymId != null) 'gym_id': gymId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudentGymsCompanion copyWith({
    Value<String>? studentId,
    Value<String>? gymId,
    Value<int>? rowid,
  }) {
    return StudentGymsCompanion(
      studentId: studentId ?? this.studentId,
      gymId: gymId ?? this.gymId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (gymId.present) {
      map['gym_id'] = Variable<String>(gymId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentGymsCompanion(')
          ..write('studentId: $studentId, ')
          ..write('gymId: $gymId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingMethodsTable extends TrainingMethods
    with TableInfo<$TrainingMethodsTable, TrainingMethodEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingMethodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    method,
    description,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_methods';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainingMethodEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('method')) {
      context.handle(
        _methodMeta,
        method.isAcceptableOrUnknown(data['method']!, _methodMeta),
      );
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainingMethodEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingMethodEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TrainingMethodsTable createAlias(String alias) {
    return $TrainingMethodsTable(attachedDatabase, alias);
  }
}

class TrainingMethodEntity extends DataClass
    implements Insertable<TrainingMethodEntity> {
  final String id;
  final String method;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TrainingMethodEntity({
    required this.id,
    required this.method,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['method'] = Variable<String>(method);
    map['description'] = Variable<String>(description);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TrainingMethodsCompanion toCompanion(bool nullToAbsent) {
    return TrainingMethodsCompanion(
      id: Value(id),
      method: Value(method),
      description: Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrainingMethodEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingMethodEntity(
      id: serializer.fromJson<String>(json['id']),
      method: serializer.fromJson<String>(json['method']),
      description: serializer.fromJson<String>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'method': serializer.toJson<String>(method),
      'description': serializer.toJson<String>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TrainingMethodEntity copyWith({
    String? id,
    String? method,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TrainingMethodEntity(
    id: id ?? this.id,
    method: method ?? this.method,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TrainingMethodEntity copyWithCompanion(TrainingMethodsCompanion data) {
    return TrainingMethodEntity(
      id: data.id.present ? data.id.value : this.id,
      method: data.method.present ? data.method.value : this.method,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingMethodEntity(')
          ..write('id: $id, ')
          ..write('method: $method, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, method, description, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingMethodEntity &&
          other.id == this.id &&
          other.method == this.method &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TrainingMethodsCompanion extends UpdateCompanion<TrainingMethodEntity> {
  final Value<String> id;
  final Value<String> method;
  final Value<String> description;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TrainingMethodsCompanion({
    this.id = const Value.absent(),
    this.method = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingMethodsCompanion.insert({
    required String id,
    required String method,
    required String description,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       method = Value(method),
       description = Value(description);
  static Insertable<TrainingMethodEntity> custom({
    Expression<String>? id,
    Expression<String>? method,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (method != null) 'method': method,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingMethodsCompanion copyWith({
    Value<String>? id,
    Value<String>? method,
    Value<String>? description,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TrainingMethodsCompanion(
      id: id ?? this.id,
      method: method ?? this.method,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingMethodsCompanion(')
          ..write('id: $id, ')
          ..write('method: $method, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutGroupsTable extends WorkoutGroups
    with TableInfo<$WorkoutGroupsTable, WorkoutGroupEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutGroupEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutGroupEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutGroupEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WorkoutGroupsTable createAlias(String alias) {
    return $WorkoutGroupsTable(attachedDatabase, alias);
  }
}

class WorkoutGroupEntity extends DataClass
    implements Insertable<WorkoutGroupEntity> {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WorkoutGroupEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WorkoutGroupsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutGroupsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WorkoutGroupEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutGroupEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WorkoutGroupEntity copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WorkoutGroupEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WorkoutGroupEntity copyWithCompanion(WorkoutGroupsCompanion data) {
    return WorkoutGroupEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutGroupEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutGroupEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WorkoutGroupsCompanion extends UpdateCompanion<WorkoutGroupEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WorkoutGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutGroupsCompanion.insert({
    required String id,
    required String name,
    required String description,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       description = Value(description);
  static Insertable<WorkoutGroupEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WorkoutGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutGroupExercisesTable extends WorkoutGroupExercises
    with TableInfo<$WorkoutGroupExercisesTable, WorkoutGroupExerciseEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutGroupExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutGroupIdMeta = const VerificationMeta(
    'workoutGroupId',
  );
  @override
  late final GeneratedColumn<String> workoutGroupId = GeneratedColumn<String>(
    'workout_group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_groups (id)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastLoadKgMeta = const VerificationMeta(
    'lastLoadKg',
  );
  @override
  late final GeneratedColumn<double> lastLoadKg = GeneratedColumn<double>(
    'last_load_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastRepsMeta = const VerificationMeta(
    'lastReps',
  );
  @override
  late final GeneratedColumn<int> lastReps = GeneratedColumn<int>(
    'last_reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastRepsTextMeta = const VerificationMeta(
    'lastRepsText',
  );
  @override
  late final GeneratedColumn<String> lastRepsText = GeneratedColumn<String>(
    'last_reps_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSetsMeta = const VerificationMeta(
    'lastSets',
  );
  @override
  late final GeneratedColumn<int> lastSets = GeneratedColumn<int>(
    'last_sets',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restBetweenSetsSecMeta =
      const VerificationMeta('restBetweenSetsSec');
  @override
  late final GeneratedColumn<int> restBetweenSetsSec = GeneratedColumn<int>(
    'rest_between_sets_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _trainingMethodIdMeta = const VerificationMeta(
    'trainingMethodId',
  );
  @override
  late final GeneratedColumn<String> trainingMethodId = GeneratedColumn<String>(
    'training_method_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES training_methods (id)',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _comboIdMeta = const VerificationMeta(
    'comboId',
  );
  @override
  late final GeneratedColumn<String> comboId = GeneratedColumn<String>(
    'combo_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutGroupId,
    exerciseId,
    sortOrder,
    lastLoadKg,
    lastReps,
    lastRepsText,
    lastSets,
    restBetweenSetsSec,
    trainingMethodId,
    updatedAt,
    comboId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_group_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutGroupExerciseEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('workout_group_id')) {
      context.handle(
        _workoutGroupIdMeta,
        workoutGroupId.isAcceptableOrUnknown(
          data['workout_group_id']!,
          _workoutGroupIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workoutGroupIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('last_load_kg')) {
      context.handle(
        _lastLoadKgMeta,
        lastLoadKg.isAcceptableOrUnknown(
          data['last_load_kg']!,
          _lastLoadKgMeta,
        ),
      );
    }
    if (data.containsKey('last_reps')) {
      context.handle(
        _lastRepsMeta,
        lastReps.isAcceptableOrUnknown(data['last_reps']!, _lastRepsMeta),
      );
    }
    if (data.containsKey('last_reps_text')) {
      context.handle(
        _lastRepsTextMeta,
        lastRepsText.isAcceptableOrUnknown(
          data['last_reps_text']!,
          _lastRepsTextMeta,
        ),
      );
    }
    if (data.containsKey('last_sets')) {
      context.handle(
        _lastSetsMeta,
        lastSets.isAcceptableOrUnknown(data['last_sets']!, _lastSetsMeta),
      );
    }
    if (data.containsKey('rest_between_sets_sec')) {
      context.handle(
        _restBetweenSetsSecMeta,
        restBetweenSetsSec.isAcceptableOrUnknown(
          data['rest_between_sets_sec']!,
          _restBetweenSetsSecMeta,
        ),
      );
    }
    if (data.containsKey('training_method_id')) {
      context.handle(
        _trainingMethodIdMeta,
        trainingMethodId.isAcceptableOrUnknown(
          data['training_method_id']!,
          _trainingMethodIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('combo_id')) {
      context.handle(
        _comboIdMeta,
        comboId.isAcceptableOrUnknown(data['combo_id']!, _comboIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutGroupExerciseEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutGroupExerciseEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      workoutGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_group_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      lastLoadKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_load_kg'],
      ),
      lastReps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_reps'],
      ),
      lastRepsText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_reps_text'],
      ),
      lastSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sets'],
      ),
      restBetweenSetsSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_between_sets_sec'],
      )!,
      trainingMethodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_method_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      comboId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}combo_id'],
      ),
    );
  }

  @override
  $WorkoutGroupExercisesTable createAlias(String alias) {
    return $WorkoutGroupExercisesTable(attachedDatabase, alias);
  }
}

class WorkoutGroupExerciseEntity extends DataClass
    implements Insertable<WorkoutGroupExerciseEntity> {
  final String id;
  final String workoutGroupId;
  final String exerciseId;
  final int sortOrder;
  final double? lastLoadKg;

  /// Legado (número inteiro); preferir [lastRepsText] para faixas como «12-15».
  final int? lastReps;
  final String? lastRepsText;
  final int? lastSets;

  /// Descanso prescrito entre séries deste exercício no modelo (segundos).
  final int restBetweenSetsSec;

  /// Método de treino associado a esta linha (opcional).
  final String? trainingMethodId;

  /// Para importação admin (LWW) alinhada ao Supabase.
  final DateTime updatedAt;

  /// Exercícios consecutivos com o mesmo id formam um bloco (superserie); descanso só após a última linha do bloco.
  final String? comboId;
  const WorkoutGroupExerciseEntity({
    required this.id,
    required this.workoutGroupId,
    required this.exerciseId,
    required this.sortOrder,
    this.lastLoadKg,
    this.lastReps,
    this.lastRepsText,
    this.lastSets,
    required this.restBetweenSetsSec,
    this.trainingMethodId,
    required this.updatedAt,
    this.comboId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['workout_group_id'] = Variable<String>(workoutGroupId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || lastLoadKg != null) {
      map['last_load_kg'] = Variable<double>(lastLoadKg);
    }
    if (!nullToAbsent || lastReps != null) {
      map['last_reps'] = Variable<int>(lastReps);
    }
    if (!nullToAbsent || lastRepsText != null) {
      map['last_reps_text'] = Variable<String>(lastRepsText);
    }
    if (!nullToAbsent || lastSets != null) {
      map['last_sets'] = Variable<int>(lastSets);
    }
    map['rest_between_sets_sec'] = Variable<int>(restBetweenSetsSec);
    if (!nullToAbsent || trainingMethodId != null) {
      map['training_method_id'] = Variable<String>(trainingMethodId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || comboId != null) {
      map['combo_id'] = Variable<String>(comboId);
    }
    return map;
  }

  WorkoutGroupExercisesCompanion toCompanion(bool nullToAbsent) {
    return WorkoutGroupExercisesCompanion(
      id: Value(id),
      workoutGroupId: Value(workoutGroupId),
      exerciseId: Value(exerciseId),
      sortOrder: Value(sortOrder),
      lastLoadKg: lastLoadKg == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLoadKg),
      lastReps: lastReps == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReps),
      lastRepsText: lastRepsText == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRepsText),
      lastSets: lastSets == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSets),
      restBetweenSetsSec: Value(restBetweenSetsSec),
      trainingMethodId: trainingMethodId == null && nullToAbsent
          ? const Value.absent()
          : Value(trainingMethodId),
      updatedAt: Value(updatedAt),
      comboId: comboId == null && nullToAbsent
          ? const Value.absent()
          : Value(comboId),
    );
  }

  factory WorkoutGroupExerciseEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutGroupExerciseEntity(
      id: serializer.fromJson<String>(json['id']),
      workoutGroupId: serializer.fromJson<String>(json['workoutGroupId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      lastLoadKg: serializer.fromJson<double?>(json['lastLoadKg']),
      lastReps: serializer.fromJson<int?>(json['lastReps']),
      lastRepsText: serializer.fromJson<String?>(json['lastRepsText']),
      lastSets: serializer.fromJson<int?>(json['lastSets']),
      restBetweenSetsSec: serializer.fromJson<int>(json['restBetweenSetsSec']),
      trainingMethodId: serializer.fromJson<String?>(json['trainingMethodId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      comboId: serializer.fromJson<String?>(json['comboId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'workoutGroupId': serializer.toJson<String>(workoutGroupId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'lastLoadKg': serializer.toJson<double?>(lastLoadKg),
      'lastReps': serializer.toJson<int?>(lastReps),
      'lastRepsText': serializer.toJson<String?>(lastRepsText),
      'lastSets': serializer.toJson<int?>(lastSets),
      'restBetweenSetsSec': serializer.toJson<int>(restBetweenSetsSec),
      'trainingMethodId': serializer.toJson<String?>(trainingMethodId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'comboId': serializer.toJson<String?>(comboId),
    };
  }

  WorkoutGroupExerciseEntity copyWith({
    String? id,
    String? workoutGroupId,
    String? exerciseId,
    int? sortOrder,
    Value<double?> lastLoadKg = const Value.absent(),
    Value<int?> lastReps = const Value.absent(),
    Value<String?> lastRepsText = const Value.absent(),
    Value<int?> lastSets = const Value.absent(),
    int? restBetweenSetsSec,
    Value<String?> trainingMethodId = const Value.absent(),
    DateTime? updatedAt,
    Value<String?> comboId = const Value.absent(),
  }) => WorkoutGroupExerciseEntity(
    id: id ?? this.id,
    workoutGroupId: workoutGroupId ?? this.workoutGroupId,
    exerciseId: exerciseId ?? this.exerciseId,
    sortOrder: sortOrder ?? this.sortOrder,
    lastLoadKg: lastLoadKg.present ? lastLoadKg.value : this.lastLoadKg,
    lastReps: lastReps.present ? lastReps.value : this.lastReps,
    lastRepsText: lastRepsText.present ? lastRepsText.value : this.lastRepsText,
    lastSets: lastSets.present ? lastSets.value : this.lastSets,
    restBetweenSetsSec: restBetweenSetsSec ?? this.restBetweenSetsSec,
    trainingMethodId: trainingMethodId.present
        ? trainingMethodId.value
        : this.trainingMethodId,
    updatedAt: updatedAt ?? this.updatedAt,
    comboId: comboId.present ? comboId.value : this.comboId,
  );
  WorkoutGroupExerciseEntity copyWithCompanion(
    WorkoutGroupExercisesCompanion data,
  ) {
    return WorkoutGroupExerciseEntity(
      id: data.id.present ? data.id.value : this.id,
      workoutGroupId: data.workoutGroupId.present
          ? data.workoutGroupId.value
          : this.workoutGroupId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      lastLoadKg: data.lastLoadKg.present
          ? data.lastLoadKg.value
          : this.lastLoadKg,
      lastReps: data.lastReps.present ? data.lastReps.value : this.lastReps,
      lastRepsText: data.lastRepsText.present
          ? data.lastRepsText.value
          : this.lastRepsText,
      lastSets: data.lastSets.present ? data.lastSets.value : this.lastSets,
      restBetweenSetsSec: data.restBetweenSetsSec.present
          ? data.restBetweenSetsSec.value
          : this.restBetweenSetsSec,
      trainingMethodId: data.trainingMethodId.present
          ? data.trainingMethodId.value
          : this.trainingMethodId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      comboId: data.comboId.present ? data.comboId.value : this.comboId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutGroupExerciseEntity(')
          ..write('id: $id, ')
          ..write('workoutGroupId: $workoutGroupId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('lastLoadKg: $lastLoadKg, ')
          ..write('lastReps: $lastReps, ')
          ..write('lastRepsText: $lastRepsText, ')
          ..write('lastSets: $lastSets, ')
          ..write('restBetweenSetsSec: $restBetweenSetsSec, ')
          ..write('trainingMethodId: $trainingMethodId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('comboId: $comboId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutGroupId,
    exerciseId,
    sortOrder,
    lastLoadKg,
    lastReps,
    lastRepsText,
    lastSets,
    restBetweenSetsSec,
    trainingMethodId,
    updatedAt,
    comboId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutGroupExerciseEntity &&
          other.id == this.id &&
          other.workoutGroupId == this.workoutGroupId &&
          other.exerciseId == this.exerciseId &&
          other.sortOrder == this.sortOrder &&
          other.lastLoadKg == this.lastLoadKg &&
          other.lastReps == this.lastReps &&
          other.lastRepsText == this.lastRepsText &&
          other.lastSets == this.lastSets &&
          other.restBetweenSetsSec == this.restBetweenSetsSec &&
          other.trainingMethodId == this.trainingMethodId &&
          other.updatedAt == this.updatedAt &&
          other.comboId == this.comboId);
}

class WorkoutGroupExercisesCompanion
    extends UpdateCompanion<WorkoutGroupExerciseEntity> {
  final Value<String> id;
  final Value<String> workoutGroupId;
  final Value<String> exerciseId;
  final Value<int> sortOrder;
  final Value<double?> lastLoadKg;
  final Value<int?> lastReps;
  final Value<String?> lastRepsText;
  final Value<int?> lastSets;
  final Value<int> restBetweenSetsSec;
  final Value<String?> trainingMethodId;
  final Value<DateTime> updatedAt;
  final Value<String?> comboId;
  final Value<int> rowid;
  const WorkoutGroupExercisesCompanion({
    this.id = const Value.absent(),
    this.workoutGroupId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.lastLoadKg = const Value.absent(),
    this.lastReps = const Value.absent(),
    this.lastRepsText = const Value.absent(),
    this.lastSets = const Value.absent(),
    this.restBetweenSetsSec = const Value.absent(),
    this.trainingMethodId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.comboId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutGroupExercisesCompanion.insert({
    required String id,
    required String workoutGroupId,
    required String exerciseId,
    this.sortOrder = const Value.absent(),
    this.lastLoadKg = const Value.absent(),
    this.lastReps = const Value.absent(),
    this.lastRepsText = const Value.absent(),
    this.lastSets = const Value.absent(),
    this.restBetweenSetsSec = const Value.absent(),
    this.trainingMethodId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.comboId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       workoutGroupId = Value(workoutGroupId),
       exerciseId = Value(exerciseId);
  static Insertable<WorkoutGroupExerciseEntity> custom({
    Expression<String>? id,
    Expression<String>? workoutGroupId,
    Expression<String>? exerciseId,
    Expression<int>? sortOrder,
    Expression<double>? lastLoadKg,
    Expression<int>? lastReps,
    Expression<String>? lastRepsText,
    Expression<int>? lastSets,
    Expression<int>? restBetweenSetsSec,
    Expression<String>? trainingMethodId,
    Expression<DateTime>? updatedAt,
    Expression<String>? comboId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutGroupId != null) 'workout_group_id': workoutGroupId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (lastLoadKg != null) 'last_load_kg': lastLoadKg,
      if (lastReps != null) 'last_reps': lastReps,
      if (lastRepsText != null) 'last_reps_text': lastRepsText,
      if (lastSets != null) 'last_sets': lastSets,
      if (restBetweenSetsSec != null)
        'rest_between_sets_sec': restBetweenSetsSec,
      if (trainingMethodId != null) 'training_method_id': trainingMethodId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (comboId != null) 'combo_id': comboId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutGroupExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? workoutGroupId,
    Value<String>? exerciseId,
    Value<int>? sortOrder,
    Value<double?>? lastLoadKg,
    Value<int?>? lastReps,
    Value<String?>? lastRepsText,
    Value<int?>? lastSets,
    Value<int>? restBetweenSetsSec,
    Value<String?>? trainingMethodId,
    Value<DateTime>? updatedAt,
    Value<String?>? comboId,
    Value<int>? rowid,
  }) {
    return WorkoutGroupExercisesCompanion(
      id: id ?? this.id,
      workoutGroupId: workoutGroupId ?? this.workoutGroupId,
      exerciseId: exerciseId ?? this.exerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      lastLoadKg: lastLoadKg ?? this.lastLoadKg,
      lastReps: lastReps ?? this.lastReps,
      lastRepsText: lastRepsText ?? this.lastRepsText,
      lastSets: lastSets ?? this.lastSets,
      restBetweenSetsSec: restBetweenSetsSec ?? this.restBetweenSetsSec,
      trainingMethodId: trainingMethodId ?? this.trainingMethodId,
      updatedAt: updatedAt ?? this.updatedAt,
      comboId: comboId ?? this.comboId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (workoutGroupId.present) {
      map['workout_group_id'] = Variable<String>(workoutGroupId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (lastLoadKg.present) {
      map['last_load_kg'] = Variable<double>(lastLoadKg.value);
    }
    if (lastReps.present) {
      map['last_reps'] = Variable<int>(lastReps.value);
    }
    if (lastRepsText.present) {
      map['last_reps_text'] = Variable<String>(lastRepsText.value);
    }
    if (lastSets.present) {
      map['last_sets'] = Variable<int>(lastSets.value);
    }
    if (restBetweenSetsSec.present) {
      map['rest_between_sets_sec'] = Variable<int>(restBetweenSetsSec.value);
    }
    if (trainingMethodId.present) {
      map['training_method_id'] = Variable<String>(trainingMethodId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (comboId.present) {
      map['combo_id'] = Variable<String>(comboId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutGroupExercisesCompanion(')
          ..write('id: $id, ')
          ..write('workoutGroupId: $workoutGroupId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('lastLoadKg: $lastLoadKg, ')
          ..write('lastReps: $lastReps, ')
          ..write('lastRepsText: $lastRepsText, ')
          ..write('lastSets: $lastSets, ')
          ..write('restBetweenSetsSec: $restBetweenSetsSec, ')
          ..write('trainingMethodId: $trainingMethodId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('comboId: $comboId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeekScheduleBlocksTable extends WeekScheduleBlocks
    with TableInfo<$WeekScheduleBlocksTable, WeekScheduleBlockEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeekScheduleBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES students (id)',
    ),
  );
  static const VerificationMeta _weekStartMondayMeta = const VerificationMeta(
    'weekStartMonday',
  );
  @override
  late final GeneratedColumn<DateTime> weekStartMonday =
      GeneratedColumn<DateTime>(
        'week_start_monday',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    studentId,
    weekStartMonday,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'week_schedule_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeekScheduleBlockEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('week_start_monday')) {
      context.handle(
        _weekStartMondayMeta,
        weekStartMonday.isAcceptableOrUnknown(
          data['week_start_monday']!,
          _weekStartMondayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weekStartMondayMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeekScheduleBlockEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeekScheduleBlockEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      weekStartMonday: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}week_start_monday'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $WeekScheduleBlocksTable createAlias(String alias) {
    return $WeekScheduleBlocksTable(attachedDatabase, alias);
  }
}

class WeekScheduleBlockEntity extends DataClass
    implements Insertable<WeekScheduleBlockEntity> {
  final String id;
  final String studentId;
  final DateTime weekStartMonday;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WeekScheduleBlockEntity({
    required this.id,
    required this.studentId,
    required this.weekStartMonday,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['student_id'] = Variable<String>(studentId);
    map['week_start_monday'] = Variable<DateTime>(weekStartMonday);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WeekScheduleBlocksCompanion toCompanion(bool nullToAbsent) {
    return WeekScheduleBlocksCompanion(
      id: Value(id),
      studentId: Value(studentId),
      weekStartMonday: Value(weekStartMonday),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WeekScheduleBlockEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeekScheduleBlockEntity(
      id: serializer.fromJson<String>(json['id']),
      studentId: serializer.fromJson<String>(json['studentId']),
      weekStartMonday: serializer.fromJson<DateTime>(json['weekStartMonday']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studentId': serializer.toJson<String>(studentId),
      'weekStartMonday': serializer.toJson<DateTime>(weekStartMonday),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WeekScheduleBlockEntity copyWith({
    String? id,
    String? studentId,
    DateTime? weekStartMonday,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WeekScheduleBlockEntity(
    id: id ?? this.id,
    studentId: studentId ?? this.studentId,
    weekStartMonday: weekStartMonday ?? this.weekStartMonday,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WeekScheduleBlockEntity copyWithCompanion(WeekScheduleBlocksCompanion data) {
    return WeekScheduleBlockEntity(
      id: data.id.present ? data.id.value : this.id,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      weekStartMonday: data.weekStartMonday.present
          ? data.weekStartMonday.value
          : this.weekStartMonday,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeekScheduleBlockEntity(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('weekStartMonday: $weekStartMonday, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, studentId, weekStartMonday, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeekScheduleBlockEntity &&
          other.id == this.id &&
          other.studentId == this.studentId &&
          other.weekStartMonday == this.weekStartMonday &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WeekScheduleBlocksCompanion
    extends UpdateCompanion<WeekScheduleBlockEntity> {
  final Value<String> id;
  final Value<String> studentId;
  final Value<DateTime> weekStartMonday;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WeekScheduleBlocksCompanion({
    this.id = const Value.absent(),
    this.studentId = const Value.absent(),
    this.weekStartMonday = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeekScheduleBlocksCompanion.insert({
    required String id,
    required String studentId,
    required DateTime weekStartMonday,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studentId = Value(studentId),
       weekStartMonday = Value(weekStartMonday);
  static Insertable<WeekScheduleBlockEntity> custom({
    Expression<String>? id,
    Expression<String>? studentId,
    Expression<DateTime>? weekStartMonday,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studentId != null) 'student_id': studentId,
      if (weekStartMonday != null) 'week_start_monday': weekStartMonday,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeekScheduleBlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? studentId,
    Value<DateTime>? weekStartMonday,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WeekScheduleBlocksCompanion(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      weekStartMonday: weekStartMonday ?? this.weekStartMonday,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (weekStartMonday.present) {
      map['week_start_monday'] = Variable<DateTime>(weekStartMonday.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeekScheduleBlocksCompanion(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('weekStartMonday: $weekStartMonday, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeekScheduleItemsTable extends WeekScheduleItems
    with TableInfo<$WeekScheduleItemsTable, WeekScheduleItemEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeekScheduleItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blockIdMeta = const VerificationMeta(
    'blockId',
  );
  @override
  late final GeneratedColumn<String> blockId = GeneratedColumn<String>(
    'block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES week_schedule_blocks (id)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _sourceWorkoutGroupIdMeta =
      const VerificationMeta('sourceWorkoutGroupId');
  @override
  late final GeneratedColumn<String> sourceWorkoutGroupId =
      GeneratedColumn<String>(
        'source_workout_group_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _setsMeta = const VerificationMeta('sets');
  @override
  late final GeneratedColumn<int> sets = GeneratedColumn<int>(
    'sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repsTextMeta = const VerificationMeta(
    'repsText',
  );
  @override
  late final GeneratedColumn<String> repsText = GeneratedColumn<String>(
    'reps_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loadKgMeta = const VerificationMeta('loadKg');
  @override
  late final GeneratedColumn<double> loadKg = GeneratedColumn<double>(
    'load_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _needsDetailMeta = const VerificationMeta(
    'needsDetail',
  );
  @override
  late final GeneratedColumn<bool> needsDetail = GeneratedColumn<bool>(
    'needs_detail',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_detail" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _restBetweenSetsSecMeta =
      const VerificationMeta('restBetweenSetsSec');
  @override
  late final GeneratedColumn<int> restBetweenSetsSec = GeneratedColumn<int>(
    'rest_between_sets_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _trainingMethodIdMeta = const VerificationMeta(
    'trainingMethodId',
  );
  @override
  late final GeneratedColumn<String> trainingMethodId = GeneratedColumn<String>(
    'training_method_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES training_methods (id)',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _comboIdMeta = const VerificationMeta(
    'comboId',
  );
  @override
  late final GeneratedColumn<String> comboId = GeneratedColumn<String>(
    'combo_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    blockId,
    exerciseId,
    sourceWorkoutGroupId,
    sortOrder,
    sets,
    reps,
    repsText,
    loadKg,
    needsDetail,
    restBetweenSetsSec,
    trainingMethodId,
    updatedAt,
    comboId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'week_schedule_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeekScheduleItemEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('block_id')) {
      context.handle(
        _blockIdMeta,
        blockId.isAcceptableOrUnknown(data['block_id']!, _blockIdMeta),
      );
    } else if (isInserting) {
      context.missing(_blockIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('source_workout_group_id')) {
      context.handle(
        _sourceWorkoutGroupIdMeta,
        sourceWorkoutGroupId.isAcceptableOrUnknown(
          data['source_workout_group_id']!,
          _sourceWorkoutGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sets')) {
      context.handle(
        _setsMeta,
        sets.isAcceptableOrUnknown(data['sets']!, _setsMeta),
      );
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('reps_text')) {
      context.handle(
        _repsTextMeta,
        repsText.isAcceptableOrUnknown(data['reps_text']!, _repsTextMeta),
      );
    }
    if (data.containsKey('load_kg')) {
      context.handle(
        _loadKgMeta,
        loadKg.isAcceptableOrUnknown(data['load_kg']!, _loadKgMeta),
      );
    }
    if (data.containsKey('needs_detail')) {
      context.handle(
        _needsDetailMeta,
        needsDetail.isAcceptableOrUnknown(
          data['needs_detail']!,
          _needsDetailMeta,
        ),
      );
    }
    if (data.containsKey('rest_between_sets_sec')) {
      context.handle(
        _restBetweenSetsSecMeta,
        restBetweenSetsSec.isAcceptableOrUnknown(
          data['rest_between_sets_sec']!,
          _restBetweenSetsSecMeta,
        ),
      );
    }
    if (data.containsKey('training_method_id')) {
      context.handle(
        _trainingMethodIdMeta,
        trainingMethodId.isAcceptableOrUnknown(
          data['training_method_id']!,
          _trainingMethodIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('combo_id')) {
      context.handle(
        _comboIdMeta,
        comboId.isAcceptableOrUnknown(data['combo_id']!, _comboIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeekScheduleItemEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeekScheduleItemEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      blockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}block_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      sourceWorkoutGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_workout_group_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      sets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sets'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      repsText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reps_text'],
      ),
      loadKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}load_kg'],
      ),
      needsDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_detail'],
      )!,
      restBetweenSetsSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_between_sets_sec'],
      )!,
      trainingMethodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_method_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      comboId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}combo_id'],
      ),
    );
  }

  @override
  $WeekScheduleItemsTable createAlias(String alias) {
    return $WeekScheduleItemsTable(attachedDatabase, alias);
  }
}

class WeekScheduleItemEntity extends DataClass
    implements Insertable<WeekScheduleItemEntity> {
  final String id;
  final String blockId;
  final String exerciseId;
  final String? sourceWorkoutGroupId;
  final int sortOrder;
  final int sets;
  final int reps;

  /// Faixa livre (ex.: «12-15»); quando preenchido, tem precedência na UI sobre [reps].
  final String? repsText;
  final double? loadKg;
  final bool needsDetail;

  /// Descanso entre séries (s); copiado do grupo ou ajustado no planejamento.
  final int restBetweenSetsSec;
  final String? trainingMethodId;

  /// Para importação admin (LWW) alinhada ao Supabase.
  final DateTime updatedAt;
  final String? comboId;
  const WeekScheduleItemEntity({
    required this.id,
    required this.blockId,
    required this.exerciseId,
    this.sourceWorkoutGroupId,
    required this.sortOrder,
    required this.sets,
    required this.reps,
    this.repsText,
    this.loadKg,
    required this.needsDetail,
    required this.restBetweenSetsSec,
    this.trainingMethodId,
    required this.updatedAt,
    this.comboId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['block_id'] = Variable<String>(blockId);
    map['exercise_id'] = Variable<String>(exerciseId);
    if (!nullToAbsent || sourceWorkoutGroupId != null) {
      map['source_workout_group_id'] = Variable<String>(sourceWorkoutGroupId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['sets'] = Variable<int>(sets);
    map['reps'] = Variable<int>(reps);
    if (!nullToAbsent || repsText != null) {
      map['reps_text'] = Variable<String>(repsText);
    }
    if (!nullToAbsent || loadKg != null) {
      map['load_kg'] = Variable<double>(loadKg);
    }
    map['needs_detail'] = Variable<bool>(needsDetail);
    map['rest_between_sets_sec'] = Variable<int>(restBetweenSetsSec);
    if (!nullToAbsent || trainingMethodId != null) {
      map['training_method_id'] = Variable<String>(trainingMethodId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || comboId != null) {
      map['combo_id'] = Variable<String>(comboId);
    }
    return map;
  }

  WeekScheduleItemsCompanion toCompanion(bool nullToAbsent) {
    return WeekScheduleItemsCompanion(
      id: Value(id),
      blockId: Value(blockId),
      exerciseId: Value(exerciseId),
      sourceWorkoutGroupId: sourceWorkoutGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceWorkoutGroupId),
      sortOrder: Value(sortOrder),
      sets: Value(sets),
      reps: Value(reps),
      repsText: repsText == null && nullToAbsent
          ? const Value.absent()
          : Value(repsText),
      loadKg: loadKg == null && nullToAbsent
          ? const Value.absent()
          : Value(loadKg),
      needsDetail: Value(needsDetail),
      restBetweenSetsSec: Value(restBetweenSetsSec),
      trainingMethodId: trainingMethodId == null && nullToAbsent
          ? const Value.absent()
          : Value(trainingMethodId),
      updatedAt: Value(updatedAt),
      comboId: comboId == null && nullToAbsent
          ? const Value.absent()
          : Value(comboId),
    );
  }

  factory WeekScheduleItemEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeekScheduleItemEntity(
      id: serializer.fromJson<String>(json['id']),
      blockId: serializer.fromJson<String>(json['blockId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      sourceWorkoutGroupId: serializer.fromJson<String?>(
        json['sourceWorkoutGroupId'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      sets: serializer.fromJson<int>(json['sets']),
      reps: serializer.fromJson<int>(json['reps']),
      repsText: serializer.fromJson<String?>(json['repsText']),
      loadKg: serializer.fromJson<double?>(json['loadKg']),
      needsDetail: serializer.fromJson<bool>(json['needsDetail']),
      restBetweenSetsSec: serializer.fromJson<int>(json['restBetweenSetsSec']),
      trainingMethodId: serializer.fromJson<String?>(json['trainingMethodId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      comboId: serializer.fromJson<String?>(json['comboId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'blockId': serializer.toJson<String>(blockId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'sourceWorkoutGroupId': serializer.toJson<String?>(sourceWorkoutGroupId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'sets': serializer.toJson<int>(sets),
      'reps': serializer.toJson<int>(reps),
      'repsText': serializer.toJson<String?>(repsText),
      'loadKg': serializer.toJson<double?>(loadKg),
      'needsDetail': serializer.toJson<bool>(needsDetail),
      'restBetweenSetsSec': serializer.toJson<int>(restBetweenSetsSec),
      'trainingMethodId': serializer.toJson<String?>(trainingMethodId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'comboId': serializer.toJson<String?>(comboId),
    };
  }

  WeekScheduleItemEntity copyWith({
    String? id,
    String? blockId,
    String? exerciseId,
    Value<String?> sourceWorkoutGroupId = const Value.absent(),
    int? sortOrder,
    int? sets,
    int? reps,
    Value<String?> repsText = const Value.absent(),
    Value<double?> loadKg = const Value.absent(),
    bool? needsDetail,
    int? restBetweenSetsSec,
    Value<String?> trainingMethodId = const Value.absent(),
    DateTime? updatedAt,
    Value<String?> comboId = const Value.absent(),
  }) => WeekScheduleItemEntity(
    id: id ?? this.id,
    blockId: blockId ?? this.blockId,
    exerciseId: exerciseId ?? this.exerciseId,
    sourceWorkoutGroupId: sourceWorkoutGroupId.present
        ? sourceWorkoutGroupId.value
        : this.sourceWorkoutGroupId,
    sortOrder: sortOrder ?? this.sortOrder,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    repsText: repsText.present ? repsText.value : this.repsText,
    loadKg: loadKg.present ? loadKg.value : this.loadKg,
    needsDetail: needsDetail ?? this.needsDetail,
    restBetweenSetsSec: restBetweenSetsSec ?? this.restBetweenSetsSec,
    trainingMethodId: trainingMethodId.present
        ? trainingMethodId.value
        : this.trainingMethodId,
    updatedAt: updatedAt ?? this.updatedAt,
    comboId: comboId.present ? comboId.value : this.comboId,
  );
  WeekScheduleItemEntity copyWithCompanion(WeekScheduleItemsCompanion data) {
    return WeekScheduleItemEntity(
      id: data.id.present ? data.id.value : this.id,
      blockId: data.blockId.present ? data.blockId.value : this.blockId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      sourceWorkoutGroupId: data.sourceWorkoutGroupId.present
          ? data.sourceWorkoutGroupId.value
          : this.sourceWorkoutGroupId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      sets: data.sets.present ? data.sets.value : this.sets,
      reps: data.reps.present ? data.reps.value : this.reps,
      repsText: data.repsText.present ? data.repsText.value : this.repsText,
      loadKg: data.loadKg.present ? data.loadKg.value : this.loadKg,
      needsDetail: data.needsDetail.present
          ? data.needsDetail.value
          : this.needsDetail,
      restBetweenSetsSec: data.restBetweenSetsSec.present
          ? data.restBetweenSetsSec.value
          : this.restBetweenSetsSec,
      trainingMethodId: data.trainingMethodId.present
          ? data.trainingMethodId.value
          : this.trainingMethodId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      comboId: data.comboId.present ? data.comboId.value : this.comboId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeekScheduleItemEntity(')
          ..write('id: $id, ')
          ..write('blockId: $blockId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sourceWorkoutGroupId: $sourceWorkoutGroupId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sets: $sets, ')
          ..write('reps: $reps, ')
          ..write('repsText: $repsText, ')
          ..write('loadKg: $loadKg, ')
          ..write('needsDetail: $needsDetail, ')
          ..write('restBetweenSetsSec: $restBetweenSetsSec, ')
          ..write('trainingMethodId: $trainingMethodId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('comboId: $comboId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    blockId,
    exerciseId,
    sourceWorkoutGroupId,
    sortOrder,
    sets,
    reps,
    repsText,
    loadKg,
    needsDetail,
    restBetweenSetsSec,
    trainingMethodId,
    updatedAt,
    comboId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeekScheduleItemEntity &&
          other.id == this.id &&
          other.blockId == this.blockId &&
          other.exerciseId == this.exerciseId &&
          other.sourceWorkoutGroupId == this.sourceWorkoutGroupId &&
          other.sortOrder == this.sortOrder &&
          other.sets == this.sets &&
          other.reps == this.reps &&
          other.repsText == this.repsText &&
          other.loadKg == this.loadKg &&
          other.needsDetail == this.needsDetail &&
          other.restBetweenSetsSec == this.restBetweenSetsSec &&
          other.trainingMethodId == this.trainingMethodId &&
          other.updatedAt == this.updatedAt &&
          other.comboId == this.comboId);
}

class WeekScheduleItemsCompanion
    extends UpdateCompanion<WeekScheduleItemEntity> {
  final Value<String> id;
  final Value<String> blockId;
  final Value<String> exerciseId;
  final Value<String?> sourceWorkoutGroupId;
  final Value<int> sortOrder;
  final Value<int> sets;
  final Value<int> reps;
  final Value<String?> repsText;
  final Value<double?> loadKg;
  final Value<bool> needsDetail;
  final Value<int> restBetweenSetsSec;
  final Value<String?> trainingMethodId;
  final Value<DateTime> updatedAt;
  final Value<String?> comboId;
  final Value<int> rowid;
  const WeekScheduleItemsCompanion({
    this.id = const Value.absent(),
    this.blockId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.sourceWorkoutGroupId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sets = const Value.absent(),
    this.reps = const Value.absent(),
    this.repsText = const Value.absent(),
    this.loadKg = const Value.absent(),
    this.needsDetail = const Value.absent(),
    this.restBetweenSetsSec = const Value.absent(),
    this.trainingMethodId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.comboId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeekScheduleItemsCompanion.insert({
    required String id,
    required String blockId,
    required String exerciseId,
    this.sourceWorkoutGroupId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sets = const Value.absent(),
    this.reps = const Value.absent(),
    this.repsText = const Value.absent(),
    this.loadKg = const Value.absent(),
    this.needsDetail = const Value.absent(),
    this.restBetweenSetsSec = const Value.absent(),
    this.trainingMethodId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.comboId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       blockId = Value(blockId),
       exerciseId = Value(exerciseId);
  static Insertable<WeekScheduleItemEntity> custom({
    Expression<String>? id,
    Expression<String>? blockId,
    Expression<String>? exerciseId,
    Expression<String>? sourceWorkoutGroupId,
    Expression<int>? sortOrder,
    Expression<int>? sets,
    Expression<int>? reps,
    Expression<String>? repsText,
    Expression<double>? loadKg,
    Expression<bool>? needsDetail,
    Expression<int>? restBetweenSetsSec,
    Expression<String>? trainingMethodId,
    Expression<DateTime>? updatedAt,
    Expression<String>? comboId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (blockId != null) 'block_id': blockId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (sourceWorkoutGroupId != null)
        'source_workout_group_id': sourceWorkoutGroupId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (repsText != null) 'reps_text': repsText,
      if (loadKg != null) 'load_kg': loadKg,
      if (needsDetail != null) 'needs_detail': needsDetail,
      if (restBetweenSetsSec != null)
        'rest_between_sets_sec': restBetweenSetsSec,
      if (trainingMethodId != null) 'training_method_id': trainingMethodId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (comboId != null) 'combo_id': comboId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeekScheduleItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? blockId,
    Value<String>? exerciseId,
    Value<String?>? sourceWorkoutGroupId,
    Value<int>? sortOrder,
    Value<int>? sets,
    Value<int>? reps,
    Value<String?>? repsText,
    Value<double?>? loadKg,
    Value<bool>? needsDetail,
    Value<int>? restBetweenSetsSec,
    Value<String?>? trainingMethodId,
    Value<DateTime>? updatedAt,
    Value<String?>? comboId,
    Value<int>? rowid,
  }) {
    return WeekScheduleItemsCompanion(
      id: id ?? this.id,
      blockId: blockId ?? this.blockId,
      exerciseId: exerciseId ?? this.exerciseId,
      sourceWorkoutGroupId: sourceWorkoutGroupId ?? this.sourceWorkoutGroupId,
      sortOrder: sortOrder ?? this.sortOrder,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      repsText: repsText ?? this.repsText,
      loadKg: loadKg ?? this.loadKg,
      needsDetail: needsDetail ?? this.needsDetail,
      restBetweenSetsSec: restBetweenSetsSec ?? this.restBetweenSetsSec,
      trainingMethodId: trainingMethodId ?? this.trainingMethodId,
      updatedAt: updatedAt ?? this.updatedAt,
      comboId: comboId ?? this.comboId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (blockId.present) {
      map['block_id'] = Variable<String>(blockId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (sourceWorkoutGroupId.present) {
      map['source_workout_group_id'] = Variable<String>(
        sourceWorkoutGroupId.value,
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (sets.present) {
      map['sets'] = Variable<int>(sets.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (repsText.present) {
      map['reps_text'] = Variable<String>(repsText.value);
    }
    if (loadKg.present) {
      map['load_kg'] = Variable<double>(loadKg.value);
    }
    if (needsDetail.present) {
      map['needs_detail'] = Variable<bool>(needsDetail.value);
    }
    if (restBetweenSetsSec.present) {
      map['rest_between_sets_sec'] = Variable<int>(restBetweenSetsSec.value);
    }
    if (trainingMethodId.present) {
      map['training_method_id'] = Variable<String>(trainingMethodId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (comboId.present) {
      map['combo_id'] = Variable<String>(comboId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeekScheduleItemsCompanion(')
          ..write('id: $id, ')
          ..write('blockId: $blockId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sourceWorkoutGroupId: $sourceWorkoutGroupId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sets: $sets, ')
          ..write('reps: $reps, ')
          ..write('repsText: $repsText, ')
          ..write('loadKg: $loadKg, ')
          ..write('needsDetail: $needsDetail, ')
          ..write('restBetweenSetsSec: $restBetweenSetsSec, ')
          ..write('trainingMethodId: $trainingMethodId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('comboId: $comboId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayWorkoutsTable extends DayWorkouts
    with TableInfo<$DayWorkoutsTable, DayWorkoutEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayWorkoutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<String> studentId = GeneratedColumn<String>(
    'student_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES students (id)',
    ),
  );
  static const VerificationMeta _dayDateMeta = const VerificationMeta(
    'dayDate',
  );
  @override
  late final GeneratedColumn<DateTime> dayDate = GeneratedColumn<DateTime>(
    'day_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekItemIdMeta = const VerificationMeta(
    'weekItemId',
  );
  @override
  late final GeneratedColumn<String> weekItemId = GeneratedColumn<String>(
    'week_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeDurationSecondsMeta =
      const VerificationMeta('activeDurationSeconds');
  @override
  late final GeneratedColumn<int> activeDurationSeconds = GeneratedColumn<int>(
    'active_duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _workoutScoreMeta = const VerificationMeta(
    'workoutScore',
  );
  @override
  late final GeneratedColumn<double> workoutScore = GeneratedColumn<double>(
    'workout_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timerResumeAtMeta = const VerificationMeta(
    'timerResumeAt',
  );
  @override
  late final GeneratedColumn<DateTime> timerResumeAt =
      GeneratedColumn<DateTime>(
        'timer_resume_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _sourceWorkoutGroupIdMeta =
      const VerificationMeta('sourceWorkoutGroupId');
  @override
  late final GeneratedColumn<String> sourceWorkoutGroupId =
      GeneratedColumn<String>(
        'source_workout_group_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _watchCaloriesKcalMeta = const VerificationMeta(
    'watchCaloriesKcal',
  );
  @override
  late final GeneratedColumn<double> watchCaloriesKcal =
      GeneratedColumn<double>(
        'watch_calories_kcal',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _watchAvgHeartRateBpmMeta =
      const VerificationMeta('watchAvgHeartRateBpm');
  @override
  late final GeneratedColumn<int> watchAvgHeartRateBpm = GeneratedColumn<int>(
    'watch_avg_heart_rate_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    studentId,
    dayDate,
    status,
    weekItemId,
    activeDurationSeconds,
    workoutScore,
    startedAt,
    completedAt,
    timerResumeAt,
    createdAt,
    updatedAt,
    sourceWorkoutGroupId,
    watchCaloriesKcal,
    watchAvgHeartRateBpm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_workouts';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayWorkoutEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_studentIdMeta);
    }
    if (data.containsKey('day_date')) {
      context.handle(
        _dayDateMeta,
        dayDate.isAcceptableOrUnknown(data['day_date']!, _dayDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dayDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('week_item_id')) {
      context.handle(
        _weekItemIdMeta,
        weekItemId.isAcceptableOrUnknown(
          data['week_item_id']!,
          _weekItemIdMeta,
        ),
      );
    }
    if (data.containsKey('active_duration_seconds')) {
      context.handle(
        _activeDurationSecondsMeta,
        activeDurationSeconds.isAcceptableOrUnknown(
          data['active_duration_seconds']!,
          _activeDurationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('workout_score')) {
      context.handle(
        _workoutScoreMeta,
        workoutScore.isAcceptableOrUnknown(
          data['workout_score']!,
          _workoutScoreMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('timer_resume_at')) {
      context.handle(
        _timerResumeAtMeta,
        timerResumeAt.isAcceptableOrUnknown(
          data['timer_resume_at']!,
          _timerResumeAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('source_workout_group_id')) {
      context.handle(
        _sourceWorkoutGroupIdMeta,
        sourceWorkoutGroupId.isAcceptableOrUnknown(
          data['source_workout_group_id']!,
          _sourceWorkoutGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('watch_calories_kcal')) {
      context.handle(
        _watchCaloriesKcalMeta,
        watchCaloriesKcal.isAcceptableOrUnknown(
          data['watch_calories_kcal']!,
          _watchCaloriesKcalMeta,
        ),
      );
    }
    if (data.containsKey('watch_avg_heart_rate_bpm')) {
      context.handle(
        _watchAvgHeartRateBpmMeta,
        watchAvgHeartRateBpm.isAcceptableOrUnknown(
          data['watch_avg_heart_rate_bpm']!,
          _watchAvgHeartRateBpmMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayWorkoutEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayWorkoutEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_id'],
      )!,
      dayDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}day_date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      weekItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}week_item_id'],
      ),
      activeDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_duration_seconds'],
      )!,
      workoutScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}workout_score'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      timerResumeAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timer_resume_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      sourceWorkoutGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_workout_group_id'],
      ),
      watchCaloriesKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}watch_calories_kcal'],
      ),
      watchAvgHeartRateBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}watch_avg_heart_rate_bpm'],
      ),
    );
  }

  @override
  $DayWorkoutsTable createAlias(String alias) {
    return $DayWorkoutsTable(attachedDatabase, alias);
  }
}

class DayWorkoutEntity extends DataClass
    implements Insertable<DayWorkoutEntity> {
  final String id;
  final String studentId;
  final DateTime dayDate;

  /// scheduled | programmed | started | completed | cancelled (cancelado = permanece no BD)
  final String status;
  final String? weekItemId;
  final int activeDurationSeconds;
  final double? workoutScore;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Quando não nulo, o cronômetro está correndo desde este instante (tempo ativo acumulado em [activeDurationSeconds]).
  final DateTime? timerResumeAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Quando veio de um grupo ao programar no calendário — exibe o nome do grupo na folha.
  final String? sourceWorkoutGroupId;

  /// Calorias (kcal) opcionais do relógio/smartphone após o treino.
  final double? watchCaloriesKcal;

  /// Frequência cardíaca média (bpm) opcional, ex.: Apple Watch / Garmin.
  final int? watchAvgHeartRateBpm;
  const DayWorkoutEntity({
    required this.id,
    required this.studentId,
    required this.dayDate,
    required this.status,
    this.weekItemId,
    required this.activeDurationSeconds,
    this.workoutScore,
    this.startedAt,
    this.completedAt,
    this.timerResumeAt,
    required this.createdAt,
    required this.updatedAt,
    this.sourceWorkoutGroupId,
    this.watchCaloriesKcal,
    this.watchAvgHeartRateBpm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['student_id'] = Variable<String>(studentId);
    map['day_date'] = Variable<DateTime>(dayDate);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || weekItemId != null) {
      map['week_item_id'] = Variable<String>(weekItemId);
    }
    map['active_duration_seconds'] = Variable<int>(activeDurationSeconds);
    if (!nullToAbsent || workoutScore != null) {
      map['workout_score'] = Variable<double>(workoutScore);
    }
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    if (!nullToAbsent || timerResumeAt != null) {
      map['timer_resume_at'] = Variable<DateTime>(timerResumeAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || sourceWorkoutGroupId != null) {
      map['source_workout_group_id'] = Variable<String>(sourceWorkoutGroupId);
    }
    if (!nullToAbsent || watchCaloriesKcal != null) {
      map['watch_calories_kcal'] = Variable<double>(watchCaloriesKcal);
    }
    if (!nullToAbsent || watchAvgHeartRateBpm != null) {
      map['watch_avg_heart_rate_bpm'] = Variable<int>(watchAvgHeartRateBpm);
    }
    return map;
  }

  DayWorkoutsCompanion toCompanion(bool nullToAbsent) {
    return DayWorkoutsCompanion(
      id: Value(id),
      studentId: Value(studentId),
      dayDate: Value(dayDate),
      status: Value(status),
      weekItemId: weekItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(weekItemId),
      activeDurationSeconds: Value(activeDurationSeconds),
      workoutScore: workoutScore == null && nullToAbsent
          ? const Value.absent()
          : Value(workoutScore),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      timerResumeAt: timerResumeAt == null && nullToAbsent
          ? const Value.absent()
          : Value(timerResumeAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      sourceWorkoutGroupId: sourceWorkoutGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceWorkoutGroupId),
      watchCaloriesKcal: watchCaloriesKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(watchCaloriesKcal),
      watchAvgHeartRateBpm: watchAvgHeartRateBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(watchAvgHeartRateBpm),
    );
  }

  factory DayWorkoutEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayWorkoutEntity(
      id: serializer.fromJson<String>(json['id']),
      studentId: serializer.fromJson<String>(json['studentId']),
      dayDate: serializer.fromJson<DateTime>(json['dayDate']),
      status: serializer.fromJson<String>(json['status']),
      weekItemId: serializer.fromJson<String?>(json['weekItemId']),
      activeDurationSeconds: serializer.fromJson<int>(
        json['activeDurationSeconds'],
      ),
      workoutScore: serializer.fromJson<double?>(json['workoutScore']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      timerResumeAt: serializer.fromJson<DateTime?>(json['timerResumeAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      sourceWorkoutGroupId: serializer.fromJson<String?>(
        json['sourceWorkoutGroupId'],
      ),
      watchCaloriesKcal: serializer.fromJson<double?>(
        json['watchCaloriesKcal'],
      ),
      watchAvgHeartRateBpm: serializer.fromJson<int?>(
        json['watchAvgHeartRateBpm'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'studentId': serializer.toJson<String>(studentId),
      'dayDate': serializer.toJson<DateTime>(dayDate),
      'status': serializer.toJson<String>(status),
      'weekItemId': serializer.toJson<String?>(weekItemId),
      'activeDurationSeconds': serializer.toJson<int>(activeDurationSeconds),
      'workoutScore': serializer.toJson<double?>(workoutScore),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'timerResumeAt': serializer.toJson<DateTime?>(timerResumeAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'sourceWorkoutGroupId': serializer.toJson<String?>(sourceWorkoutGroupId),
      'watchCaloriesKcal': serializer.toJson<double?>(watchCaloriesKcal),
      'watchAvgHeartRateBpm': serializer.toJson<int?>(watchAvgHeartRateBpm),
    };
  }

  DayWorkoutEntity copyWith({
    String? id,
    String? studentId,
    DateTime? dayDate,
    String? status,
    Value<String?> weekItemId = const Value.absent(),
    int? activeDurationSeconds,
    Value<double?> workoutScore = const Value.absent(),
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> completedAt = const Value.absent(),
    Value<DateTime?> timerResumeAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> sourceWorkoutGroupId = const Value.absent(),
    Value<double?> watchCaloriesKcal = const Value.absent(),
    Value<int?> watchAvgHeartRateBpm = const Value.absent(),
  }) => DayWorkoutEntity(
    id: id ?? this.id,
    studentId: studentId ?? this.studentId,
    dayDate: dayDate ?? this.dayDate,
    status: status ?? this.status,
    weekItemId: weekItemId.present ? weekItemId.value : this.weekItemId,
    activeDurationSeconds: activeDurationSeconds ?? this.activeDurationSeconds,
    workoutScore: workoutScore.present ? workoutScore.value : this.workoutScore,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    timerResumeAt: timerResumeAt.present
        ? timerResumeAt.value
        : this.timerResumeAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    sourceWorkoutGroupId: sourceWorkoutGroupId.present
        ? sourceWorkoutGroupId.value
        : this.sourceWorkoutGroupId,
    watchCaloriesKcal: watchCaloriesKcal.present
        ? watchCaloriesKcal.value
        : this.watchCaloriesKcal,
    watchAvgHeartRateBpm: watchAvgHeartRateBpm.present
        ? watchAvgHeartRateBpm.value
        : this.watchAvgHeartRateBpm,
  );
  DayWorkoutEntity copyWithCompanion(DayWorkoutsCompanion data) {
    return DayWorkoutEntity(
      id: data.id.present ? data.id.value : this.id,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      dayDate: data.dayDate.present ? data.dayDate.value : this.dayDate,
      status: data.status.present ? data.status.value : this.status,
      weekItemId: data.weekItemId.present
          ? data.weekItemId.value
          : this.weekItemId,
      activeDurationSeconds: data.activeDurationSeconds.present
          ? data.activeDurationSeconds.value
          : this.activeDurationSeconds,
      workoutScore: data.workoutScore.present
          ? data.workoutScore.value
          : this.workoutScore,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      timerResumeAt: data.timerResumeAt.present
          ? data.timerResumeAt.value
          : this.timerResumeAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sourceWorkoutGroupId: data.sourceWorkoutGroupId.present
          ? data.sourceWorkoutGroupId.value
          : this.sourceWorkoutGroupId,
      watchCaloriesKcal: data.watchCaloriesKcal.present
          ? data.watchCaloriesKcal.value
          : this.watchCaloriesKcal,
      watchAvgHeartRateBpm: data.watchAvgHeartRateBpm.present
          ? data.watchAvgHeartRateBpm.value
          : this.watchAvgHeartRateBpm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayWorkoutEntity(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('dayDate: $dayDate, ')
          ..write('status: $status, ')
          ..write('weekItemId: $weekItemId, ')
          ..write('activeDurationSeconds: $activeDurationSeconds, ')
          ..write('workoutScore: $workoutScore, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('timerResumeAt: $timerResumeAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sourceWorkoutGroupId: $sourceWorkoutGroupId, ')
          ..write('watchCaloriesKcal: $watchCaloriesKcal, ')
          ..write('watchAvgHeartRateBpm: $watchAvgHeartRateBpm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    studentId,
    dayDate,
    status,
    weekItemId,
    activeDurationSeconds,
    workoutScore,
    startedAt,
    completedAt,
    timerResumeAt,
    createdAt,
    updatedAt,
    sourceWorkoutGroupId,
    watchCaloriesKcal,
    watchAvgHeartRateBpm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayWorkoutEntity &&
          other.id == this.id &&
          other.studentId == this.studentId &&
          other.dayDate == this.dayDate &&
          other.status == this.status &&
          other.weekItemId == this.weekItemId &&
          other.activeDurationSeconds == this.activeDurationSeconds &&
          other.workoutScore == this.workoutScore &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.timerResumeAt == this.timerResumeAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.sourceWorkoutGroupId == this.sourceWorkoutGroupId &&
          other.watchCaloriesKcal == this.watchCaloriesKcal &&
          other.watchAvgHeartRateBpm == this.watchAvgHeartRateBpm);
}

class DayWorkoutsCompanion extends UpdateCompanion<DayWorkoutEntity> {
  final Value<String> id;
  final Value<String> studentId;
  final Value<DateTime> dayDate;
  final Value<String> status;
  final Value<String?> weekItemId;
  final Value<int> activeDurationSeconds;
  final Value<double?> workoutScore;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> completedAt;
  final Value<DateTime?> timerResumeAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> sourceWorkoutGroupId;
  final Value<double?> watchCaloriesKcal;
  final Value<int?> watchAvgHeartRateBpm;
  final Value<int> rowid;
  const DayWorkoutsCompanion({
    this.id = const Value.absent(),
    this.studentId = const Value.absent(),
    this.dayDate = const Value.absent(),
    this.status = const Value.absent(),
    this.weekItemId = const Value.absent(),
    this.activeDurationSeconds = const Value.absent(),
    this.workoutScore = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.timerResumeAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sourceWorkoutGroupId = const Value.absent(),
    this.watchCaloriesKcal = const Value.absent(),
    this.watchAvgHeartRateBpm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayWorkoutsCompanion.insert({
    required String id,
    required String studentId,
    required DateTime dayDate,
    required String status,
    this.weekItemId = const Value.absent(),
    this.activeDurationSeconds = const Value.absent(),
    this.workoutScore = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.timerResumeAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sourceWorkoutGroupId = const Value.absent(),
    this.watchCaloriesKcal = const Value.absent(),
    this.watchAvgHeartRateBpm = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       studentId = Value(studentId),
       dayDate = Value(dayDate),
       status = Value(status);
  static Insertable<DayWorkoutEntity> custom({
    Expression<String>? id,
    Expression<String>? studentId,
    Expression<DateTime>? dayDate,
    Expression<String>? status,
    Expression<String>? weekItemId,
    Expression<int>? activeDurationSeconds,
    Expression<double>? workoutScore,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? timerResumeAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? sourceWorkoutGroupId,
    Expression<double>? watchCaloriesKcal,
    Expression<int>? watchAvgHeartRateBpm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (studentId != null) 'student_id': studentId,
      if (dayDate != null) 'day_date': dayDate,
      if (status != null) 'status': status,
      if (weekItemId != null) 'week_item_id': weekItemId,
      if (activeDurationSeconds != null)
        'active_duration_seconds': activeDurationSeconds,
      if (workoutScore != null) 'workout_score': workoutScore,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (timerResumeAt != null) 'timer_resume_at': timerResumeAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sourceWorkoutGroupId != null)
        'source_workout_group_id': sourceWorkoutGroupId,
      if (watchCaloriesKcal != null) 'watch_calories_kcal': watchCaloriesKcal,
      if (watchAvgHeartRateBpm != null)
        'watch_avg_heart_rate_bpm': watchAvgHeartRateBpm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayWorkoutsCompanion copyWith({
    Value<String>? id,
    Value<String>? studentId,
    Value<DateTime>? dayDate,
    Value<String>? status,
    Value<String?>? weekItemId,
    Value<int>? activeDurationSeconds,
    Value<double?>? workoutScore,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? completedAt,
    Value<DateTime?>? timerResumeAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? sourceWorkoutGroupId,
    Value<double?>? watchCaloriesKcal,
    Value<int?>? watchAvgHeartRateBpm,
    Value<int>? rowid,
  }) {
    return DayWorkoutsCompanion(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      dayDate: dayDate ?? this.dayDate,
      status: status ?? this.status,
      weekItemId: weekItemId ?? this.weekItemId,
      activeDurationSeconds:
          activeDurationSeconds ?? this.activeDurationSeconds,
      workoutScore: workoutScore ?? this.workoutScore,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      timerResumeAt: timerResumeAt ?? this.timerResumeAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceWorkoutGroupId: sourceWorkoutGroupId ?? this.sourceWorkoutGroupId,
      watchCaloriesKcal: watchCaloriesKcal ?? this.watchCaloriesKcal,
      watchAvgHeartRateBpm: watchAvgHeartRateBpm ?? this.watchAvgHeartRateBpm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<String>(studentId.value);
    }
    if (dayDate.present) {
      map['day_date'] = Variable<DateTime>(dayDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (weekItemId.present) {
      map['week_item_id'] = Variable<String>(weekItemId.value);
    }
    if (activeDurationSeconds.present) {
      map['active_duration_seconds'] = Variable<int>(
        activeDurationSeconds.value,
      );
    }
    if (workoutScore.present) {
      map['workout_score'] = Variable<double>(workoutScore.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (timerResumeAt.present) {
      map['timer_resume_at'] = Variable<DateTime>(timerResumeAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (sourceWorkoutGroupId.present) {
      map['source_workout_group_id'] = Variable<String>(
        sourceWorkoutGroupId.value,
      );
    }
    if (watchCaloriesKcal.present) {
      map['watch_calories_kcal'] = Variable<double>(watchCaloriesKcal.value);
    }
    if (watchAvgHeartRateBpm.present) {
      map['watch_avg_heart_rate_bpm'] = Variable<int>(
        watchAvgHeartRateBpm.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayWorkoutsCompanion(')
          ..write('id: $id, ')
          ..write('studentId: $studentId, ')
          ..write('dayDate: $dayDate, ')
          ..write('status: $status, ')
          ..write('weekItemId: $weekItemId, ')
          ..write('activeDurationSeconds: $activeDurationSeconds, ')
          ..write('workoutScore: $workoutScore, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('timerResumeAt: $timerResumeAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sourceWorkoutGroupId: $sourceWorkoutGroupId, ')
          ..write('watchCaloriesKcal: $watchCaloriesKcal, ')
          ..write('watchAvgHeartRateBpm: $watchAvgHeartRateBpm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DayWorkoutExercisesTable extends DayWorkoutExercises
    with TableInfo<$DayWorkoutExercisesTable, DayWorkoutExerciseEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DayWorkoutExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayWorkoutIdMeta = const VerificationMeta(
    'dayWorkoutId',
  );
  @override
  late final GeneratedColumn<String> dayWorkoutId = GeneratedColumn<String>(
    'day_workout_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES day_workouts (id)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<String> exerciseId = GeneratedColumn<String>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _setsMeta = const VerificationMeta('sets');
  @override
  late final GeneratedColumn<int> sets = GeneratedColumn<int>(
    'sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsTextMeta = const VerificationMeta(
    'repsText',
  );
  @override
  late final GeneratedColumn<String> repsText = GeneratedColumn<String>(
    'reps_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loadKgMeta = const VerificationMeta('loadKg');
  @override
  late final GeneratedColumn<double> loadKg = GeneratedColumn<double>(
    'load_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exerciseScoreMeta = const VerificationMeta(
    'exerciseScore',
  );
  @override
  late final GeneratedColumn<double> exerciseScore = GeneratedColumn<double>(
    'exercise_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _performedSetsJsonMeta = const VerificationMeta(
    'performedSetsJson',
  );
  @override
  late final GeneratedColumn<String> performedSetsJson =
      GeneratedColumn<String>(
        'performed_sets_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _restBetweenSetsSecMeta =
      const VerificationMeta('restBetweenSetsSec');
  @override
  late final GeneratedColumn<int> restBetweenSetsSec = GeneratedColumn<int>(
    'rest_between_sets_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _trainingMethodIdMeta = const VerificationMeta(
    'trainingMethodId',
  );
  @override
  late final GeneratedColumn<String> trainingMethodId = GeneratedColumn<String>(
    'training_method_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES training_methods (id)',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _comboIdMeta = const VerificationMeta(
    'comboId',
  );
  @override
  late final GeneratedColumn<String> comboId = GeneratedColumn<String>(
    'combo_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dayWorkoutId,
    exerciseId,
    sortOrder,
    sets,
    reps,
    repsText,
    loadKg,
    exerciseScore,
    performedSetsJson,
    restBetweenSetsSec,
    trainingMethodId,
    updatedAt,
    comboId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'day_workout_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<DayWorkoutExerciseEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('day_workout_id')) {
      context.handle(
        _dayWorkoutIdMeta,
        dayWorkoutId.isAcceptableOrUnknown(
          data['day_workout_id']!,
          _dayWorkoutIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dayWorkoutIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('sets')) {
      context.handle(
        _setsMeta,
        sets.isAcceptableOrUnknown(data['sets']!, _setsMeta),
      );
    } else if (isInserting) {
      context.missing(_setsMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('reps_text')) {
      context.handle(
        _repsTextMeta,
        repsText.isAcceptableOrUnknown(data['reps_text']!, _repsTextMeta),
      );
    }
    if (data.containsKey('load_kg')) {
      context.handle(
        _loadKgMeta,
        loadKg.isAcceptableOrUnknown(data['load_kg']!, _loadKgMeta),
      );
    }
    if (data.containsKey('exercise_score')) {
      context.handle(
        _exerciseScoreMeta,
        exerciseScore.isAcceptableOrUnknown(
          data['exercise_score']!,
          _exerciseScoreMeta,
        ),
      );
    }
    if (data.containsKey('performed_sets_json')) {
      context.handle(
        _performedSetsJsonMeta,
        performedSetsJson.isAcceptableOrUnknown(
          data['performed_sets_json']!,
          _performedSetsJsonMeta,
        ),
      );
    }
    if (data.containsKey('rest_between_sets_sec')) {
      context.handle(
        _restBetweenSetsSecMeta,
        restBetweenSetsSec.isAcceptableOrUnknown(
          data['rest_between_sets_sec']!,
          _restBetweenSetsSecMeta,
        ),
      );
    }
    if (data.containsKey('training_method_id')) {
      context.handle(
        _trainingMethodIdMeta,
        trainingMethodId.isAcceptableOrUnknown(
          data['training_method_id']!,
          _trainingMethodIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('combo_id')) {
      context.handle(
        _comboIdMeta,
        comboId.isAcceptableOrUnknown(data['combo_id']!, _comboIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DayWorkoutExerciseEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DayWorkoutExerciseEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dayWorkoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_workout_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      sets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sets'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      repsText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reps_text'],
      ),
      loadKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}load_kg'],
      ),
      exerciseScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}exercise_score'],
      ),
      performedSetsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}performed_sets_json'],
      ),
      restBetweenSetsSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_between_sets_sec'],
      )!,
      trainingMethodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_method_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      comboId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}combo_id'],
      ),
    );
  }

  @override
  $DayWorkoutExercisesTable createAlias(String alias) {
    return $DayWorkoutExercisesTable(attachedDatabase, alias);
  }
}

class DayWorkoutExerciseEntity extends DataClass
    implements Insertable<DayWorkoutExerciseEntity> {
  final String id;
  final String dayWorkoutId;
  final String exerciseId;
  final int sortOrder;
  final int sets;
  final int reps;
  final String? repsText;
  final double? loadKg;
  final double? exerciseScore;

  /// JSON: lista `[{ "loadKg": 20.0, "reps": 15 }, ...]` — séries executadas (modal Adicionar série).
  final String? performedSetsJson;

  /// Descanso prescrito entre séries neste dia (s); vindo do planejamento / grupo.
  final int restBetweenSetsSec;
  final String? trainingMethodId;

  /// Para importação admin (LWW) alinhada ao Supabase.
  final DateTime updatedAt;
  final String? comboId;
  const DayWorkoutExerciseEntity({
    required this.id,
    required this.dayWorkoutId,
    required this.exerciseId,
    required this.sortOrder,
    required this.sets,
    required this.reps,
    this.repsText,
    this.loadKg,
    this.exerciseScore,
    this.performedSetsJson,
    required this.restBetweenSetsSec,
    this.trainingMethodId,
    required this.updatedAt,
    this.comboId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['day_workout_id'] = Variable<String>(dayWorkoutId);
    map['exercise_id'] = Variable<String>(exerciseId);
    map['sort_order'] = Variable<int>(sortOrder);
    map['sets'] = Variable<int>(sets);
    map['reps'] = Variable<int>(reps);
    if (!nullToAbsent || repsText != null) {
      map['reps_text'] = Variable<String>(repsText);
    }
    if (!nullToAbsent || loadKg != null) {
      map['load_kg'] = Variable<double>(loadKg);
    }
    if (!nullToAbsent || exerciseScore != null) {
      map['exercise_score'] = Variable<double>(exerciseScore);
    }
    if (!nullToAbsent || performedSetsJson != null) {
      map['performed_sets_json'] = Variable<String>(performedSetsJson);
    }
    map['rest_between_sets_sec'] = Variable<int>(restBetweenSetsSec);
    if (!nullToAbsent || trainingMethodId != null) {
      map['training_method_id'] = Variable<String>(trainingMethodId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || comboId != null) {
      map['combo_id'] = Variable<String>(comboId);
    }
    return map;
  }

  DayWorkoutExercisesCompanion toCompanion(bool nullToAbsent) {
    return DayWorkoutExercisesCompanion(
      id: Value(id),
      dayWorkoutId: Value(dayWorkoutId),
      exerciseId: Value(exerciseId),
      sortOrder: Value(sortOrder),
      sets: Value(sets),
      reps: Value(reps),
      repsText: repsText == null && nullToAbsent
          ? const Value.absent()
          : Value(repsText),
      loadKg: loadKg == null && nullToAbsent
          ? const Value.absent()
          : Value(loadKg),
      exerciseScore: exerciseScore == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseScore),
      performedSetsJson: performedSetsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(performedSetsJson),
      restBetweenSetsSec: Value(restBetweenSetsSec),
      trainingMethodId: trainingMethodId == null && nullToAbsent
          ? const Value.absent()
          : Value(trainingMethodId),
      updatedAt: Value(updatedAt),
      comboId: comboId == null && nullToAbsent
          ? const Value.absent()
          : Value(comboId),
    );
  }

  factory DayWorkoutExerciseEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DayWorkoutExerciseEntity(
      id: serializer.fromJson<String>(json['id']),
      dayWorkoutId: serializer.fromJson<String>(json['dayWorkoutId']),
      exerciseId: serializer.fromJson<String>(json['exerciseId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      sets: serializer.fromJson<int>(json['sets']),
      reps: serializer.fromJson<int>(json['reps']),
      repsText: serializer.fromJson<String?>(json['repsText']),
      loadKg: serializer.fromJson<double?>(json['loadKg']),
      exerciseScore: serializer.fromJson<double?>(json['exerciseScore']),
      performedSetsJson: serializer.fromJson<String?>(
        json['performedSetsJson'],
      ),
      restBetweenSetsSec: serializer.fromJson<int>(json['restBetweenSetsSec']),
      trainingMethodId: serializer.fromJson<String?>(json['trainingMethodId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      comboId: serializer.fromJson<String?>(json['comboId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dayWorkoutId': serializer.toJson<String>(dayWorkoutId),
      'exerciseId': serializer.toJson<String>(exerciseId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'sets': serializer.toJson<int>(sets),
      'reps': serializer.toJson<int>(reps),
      'repsText': serializer.toJson<String?>(repsText),
      'loadKg': serializer.toJson<double?>(loadKg),
      'exerciseScore': serializer.toJson<double?>(exerciseScore),
      'performedSetsJson': serializer.toJson<String?>(performedSetsJson),
      'restBetweenSetsSec': serializer.toJson<int>(restBetweenSetsSec),
      'trainingMethodId': serializer.toJson<String?>(trainingMethodId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'comboId': serializer.toJson<String?>(comboId),
    };
  }

  DayWorkoutExerciseEntity copyWith({
    String? id,
    String? dayWorkoutId,
    String? exerciseId,
    int? sortOrder,
    int? sets,
    int? reps,
    Value<String?> repsText = const Value.absent(),
    Value<double?> loadKg = const Value.absent(),
    Value<double?> exerciseScore = const Value.absent(),
    Value<String?> performedSetsJson = const Value.absent(),
    int? restBetweenSetsSec,
    Value<String?> trainingMethodId = const Value.absent(),
    DateTime? updatedAt,
    Value<String?> comboId = const Value.absent(),
  }) => DayWorkoutExerciseEntity(
    id: id ?? this.id,
    dayWorkoutId: dayWorkoutId ?? this.dayWorkoutId,
    exerciseId: exerciseId ?? this.exerciseId,
    sortOrder: sortOrder ?? this.sortOrder,
    sets: sets ?? this.sets,
    reps: reps ?? this.reps,
    repsText: repsText.present ? repsText.value : this.repsText,
    loadKg: loadKg.present ? loadKg.value : this.loadKg,
    exerciseScore: exerciseScore.present
        ? exerciseScore.value
        : this.exerciseScore,
    performedSetsJson: performedSetsJson.present
        ? performedSetsJson.value
        : this.performedSetsJson,
    restBetweenSetsSec: restBetweenSetsSec ?? this.restBetweenSetsSec,
    trainingMethodId: trainingMethodId.present
        ? trainingMethodId.value
        : this.trainingMethodId,
    updatedAt: updatedAt ?? this.updatedAt,
    comboId: comboId.present ? comboId.value : this.comboId,
  );
  DayWorkoutExerciseEntity copyWithCompanion(
    DayWorkoutExercisesCompanion data,
  ) {
    return DayWorkoutExerciseEntity(
      id: data.id.present ? data.id.value : this.id,
      dayWorkoutId: data.dayWorkoutId.present
          ? data.dayWorkoutId.value
          : this.dayWorkoutId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      sets: data.sets.present ? data.sets.value : this.sets,
      reps: data.reps.present ? data.reps.value : this.reps,
      repsText: data.repsText.present ? data.repsText.value : this.repsText,
      loadKg: data.loadKg.present ? data.loadKg.value : this.loadKg,
      exerciseScore: data.exerciseScore.present
          ? data.exerciseScore.value
          : this.exerciseScore,
      performedSetsJson: data.performedSetsJson.present
          ? data.performedSetsJson.value
          : this.performedSetsJson,
      restBetweenSetsSec: data.restBetweenSetsSec.present
          ? data.restBetweenSetsSec.value
          : this.restBetweenSetsSec,
      trainingMethodId: data.trainingMethodId.present
          ? data.trainingMethodId.value
          : this.trainingMethodId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      comboId: data.comboId.present ? data.comboId.value : this.comboId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DayWorkoutExerciseEntity(')
          ..write('id: $id, ')
          ..write('dayWorkoutId: $dayWorkoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sets: $sets, ')
          ..write('reps: $reps, ')
          ..write('repsText: $repsText, ')
          ..write('loadKg: $loadKg, ')
          ..write('exerciseScore: $exerciseScore, ')
          ..write('performedSetsJson: $performedSetsJson, ')
          ..write('restBetweenSetsSec: $restBetweenSetsSec, ')
          ..write('trainingMethodId: $trainingMethodId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('comboId: $comboId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dayWorkoutId,
    exerciseId,
    sortOrder,
    sets,
    reps,
    repsText,
    loadKg,
    exerciseScore,
    performedSetsJson,
    restBetweenSetsSec,
    trainingMethodId,
    updatedAt,
    comboId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DayWorkoutExerciseEntity &&
          other.id == this.id &&
          other.dayWorkoutId == this.dayWorkoutId &&
          other.exerciseId == this.exerciseId &&
          other.sortOrder == this.sortOrder &&
          other.sets == this.sets &&
          other.reps == this.reps &&
          other.repsText == this.repsText &&
          other.loadKg == this.loadKg &&
          other.exerciseScore == this.exerciseScore &&
          other.performedSetsJson == this.performedSetsJson &&
          other.restBetweenSetsSec == this.restBetweenSetsSec &&
          other.trainingMethodId == this.trainingMethodId &&
          other.updatedAt == this.updatedAt &&
          other.comboId == this.comboId);
}

class DayWorkoutExercisesCompanion
    extends UpdateCompanion<DayWorkoutExerciseEntity> {
  final Value<String> id;
  final Value<String> dayWorkoutId;
  final Value<String> exerciseId;
  final Value<int> sortOrder;
  final Value<int> sets;
  final Value<int> reps;
  final Value<String?> repsText;
  final Value<double?> loadKg;
  final Value<double?> exerciseScore;
  final Value<String?> performedSetsJson;
  final Value<int> restBetweenSetsSec;
  final Value<String?> trainingMethodId;
  final Value<DateTime> updatedAt;
  final Value<String?> comboId;
  final Value<int> rowid;
  const DayWorkoutExercisesCompanion({
    this.id = const Value.absent(),
    this.dayWorkoutId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sets = const Value.absent(),
    this.reps = const Value.absent(),
    this.repsText = const Value.absent(),
    this.loadKg = const Value.absent(),
    this.exerciseScore = const Value.absent(),
    this.performedSetsJson = const Value.absent(),
    this.restBetweenSetsSec = const Value.absent(),
    this.trainingMethodId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.comboId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DayWorkoutExercisesCompanion.insert({
    required String id,
    required String dayWorkoutId,
    required String exerciseId,
    this.sortOrder = const Value.absent(),
    required int sets,
    required int reps,
    this.repsText = const Value.absent(),
    this.loadKg = const Value.absent(),
    this.exerciseScore = const Value.absent(),
    this.performedSetsJson = const Value.absent(),
    this.restBetweenSetsSec = const Value.absent(),
    this.trainingMethodId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.comboId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dayWorkoutId = Value(dayWorkoutId),
       exerciseId = Value(exerciseId),
       sets = Value(sets),
       reps = Value(reps);
  static Insertable<DayWorkoutExerciseEntity> custom({
    Expression<String>? id,
    Expression<String>? dayWorkoutId,
    Expression<String>? exerciseId,
    Expression<int>? sortOrder,
    Expression<int>? sets,
    Expression<int>? reps,
    Expression<String>? repsText,
    Expression<double>? loadKg,
    Expression<double>? exerciseScore,
    Expression<String>? performedSetsJson,
    Expression<int>? restBetweenSetsSec,
    Expression<String>? trainingMethodId,
    Expression<DateTime>? updatedAt,
    Expression<String>? comboId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayWorkoutId != null) 'day_workout_id': dayWorkoutId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (repsText != null) 'reps_text': repsText,
      if (loadKg != null) 'load_kg': loadKg,
      if (exerciseScore != null) 'exercise_score': exerciseScore,
      if (performedSetsJson != null) 'performed_sets_json': performedSetsJson,
      if (restBetweenSetsSec != null)
        'rest_between_sets_sec': restBetweenSetsSec,
      if (trainingMethodId != null) 'training_method_id': trainingMethodId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (comboId != null) 'combo_id': comboId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DayWorkoutExercisesCompanion copyWith({
    Value<String>? id,
    Value<String>? dayWorkoutId,
    Value<String>? exerciseId,
    Value<int>? sortOrder,
    Value<int>? sets,
    Value<int>? reps,
    Value<String?>? repsText,
    Value<double?>? loadKg,
    Value<double?>? exerciseScore,
    Value<String?>? performedSetsJson,
    Value<int>? restBetweenSetsSec,
    Value<String?>? trainingMethodId,
    Value<DateTime>? updatedAt,
    Value<String?>? comboId,
    Value<int>? rowid,
  }) {
    return DayWorkoutExercisesCompanion(
      id: id ?? this.id,
      dayWorkoutId: dayWorkoutId ?? this.dayWorkoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      repsText: repsText ?? this.repsText,
      loadKg: loadKg ?? this.loadKg,
      exerciseScore: exerciseScore ?? this.exerciseScore,
      performedSetsJson: performedSetsJson ?? this.performedSetsJson,
      restBetweenSetsSec: restBetweenSetsSec ?? this.restBetweenSetsSec,
      trainingMethodId: trainingMethodId ?? this.trainingMethodId,
      updatedAt: updatedAt ?? this.updatedAt,
      comboId: comboId ?? this.comboId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dayWorkoutId.present) {
      map['day_workout_id'] = Variable<String>(dayWorkoutId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<String>(exerciseId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (sets.present) {
      map['sets'] = Variable<int>(sets.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (repsText.present) {
      map['reps_text'] = Variable<String>(repsText.value);
    }
    if (loadKg.present) {
      map['load_kg'] = Variable<double>(loadKg.value);
    }
    if (exerciseScore.present) {
      map['exercise_score'] = Variable<double>(exerciseScore.value);
    }
    if (performedSetsJson.present) {
      map['performed_sets_json'] = Variable<String>(performedSetsJson.value);
    }
    if (restBetweenSetsSec.present) {
      map['rest_between_sets_sec'] = Variable<int>(restBetweenSetsSec.value);
    }
    if (trainingMethodId.present) {
      map['training_method_id'] = Variable<String>(trainingMethodId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (comboId.present) {
      map['combo_id'] = Variable<String>(comboId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DayWorkoutExercisesCompanion(')
          ..write('id: $id, ')
          ..write('dayWorkoutId: $dayWorkoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sets: $sets, ')
          ..write('reps: $reps, ')
          ..write('repsText: $repsText, ')
          ..write('loadKg: $loadKg, ')
          ..write('exerciseScore: $exerciseScore, ')
          ..write('performedSetsJson: $performedSetsJson, ')
          ..write('restBetweenSetsSec: $restBetweenSetsSec, ')
          ..write('trainingMethodId: $trainingMethodId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('comboId: $comboId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLogEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    action,
    entityType,
    entityId,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLogEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLogEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLogEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLogEntity extends DataClass implements Insertable<AuditLogEntity> {
  final String id;
  final DateTime at;
  final String action;
  final String entityType;
  final String? entityId;
  final String? payloadJson;
  const AuditLogEntity({
    required this.id,
    required this.at,
    required this.action,
    required this.entityType,
    this.entityId,
    this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['at'] = Variable<DateTime>(at);
    map['action'] = Variable<String>(action);
    map['entity_type'] = Variable<String>(entityType);
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      at: Value(at),
      action: Value(action),
      entityType: Value(entityType),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
    );
  }

  factory AuditLogEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLogEntity(
      id: serializer.fromJson<String>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      action: serializer.fromJson<String>(json['action']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String?>(json['entityId']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'at': serializer.toJson<DateTime>(at),
      'action': serializer.toJson<String>(action),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String?>(entityId),
      'payloadJson': serializer.toJson<String?>(payloadJson),
    };
  }

  AuditLogEntity copyWith({
    String? id,
    DateTime? at,
    String? action,
    String? entityType,
    Value<String?> entityId = const Value.absent(),
    Value<String?> payloadJson = const Value.absent(),
  }) => AuditLogEntity(
    id: id ?? this.id,
    at: at ?? this.at,
    action: action ?? this.action,
    entityType: entityType ?? this.entityType,
    entityId: entityId.present ? entityId.value : this.entityId,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
  );
  AuditLogEntity copyWithCompanion(AuditLogsCompanion data) {
    return AuditLogEntity(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      action: data.action.present ? data.action.value : this.action,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogEntity(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, at, action, entityType, entityId, payloadJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLogEntity &&
          other.id == this.id &&
          other.at == this.at &&
          other.action == this.action &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payloadJson == this.payloadJson);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLogEntity> {
  final Value<String> id;
  final Value<DateTime> at;
  final Value<String> action;
  final Value<String> entityType;
  final Value<String?> entityId;
  final Value<String?> payloadJson;
  final Value<int> rowid;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.action = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    required String id,
    this.at = const Value.absent(),
    required String action,
    required String entityType,
    this.entityId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       action = Value(action),
       entityType = Value(entityType);
  static Insertable<AuditLogEntity> custom({
    Expression<String>? id,
    Expression<DateTime>? at,
    Expression<String>? action,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (action != null) 'action': action,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AuditLogsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? at,
    Value<String>? action,
    Value<String>? entityType,
    Value<String?>? entityId,
    Value<String?>? payloadJson,
    Value<int>? rowid,
  }) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('action: $action, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MuscleGroupsTable muscleGroups = $MuscleGroupsTable(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $GymsTable gyms = $GymsTable(this);
  late final $PersonalsTable personals = $PersonalsTable(this);
  late final $StudentsTable students = $StudentsTable(this);
  late final $StudentGymsTable studentGyms = $StudentGymsTable(this);
  late final $TrainingMethodsTable trainingMethods = $TrainingMethodsTable(
    this,
  );
  late final $WorkoutGroupsTable workoutGroups = $WorkoutGroupsTable(this);
  late final $WorkoutGroupExercisesTable workoutGroupExercises =
      $WorkoutGroupExercisesTable(this);
  late final $WeekScheduleBlocksTable weekScheduleBlocks =
      $WeekScheduleBlocksTable(this);
  late final $WeekScheduleItemsTable weekScheduleItems =
      $WeekScheduleItemsTable(this);
  late final $DayWorkoutsTable dayWorkouts = $DayWorkoutsTable(this);
  late final $DayWorkoutExercisesTable dayWorkoutExercises =
      $DayWorkoutExercisesTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    muscleGroups,
    exercises,
    gyms,
    personals,
    students,
    studentGyms,
    trainingMethods,
    workoutGroups,
    workoutGroupExercises,
    weekScheduleBlocks,
    weekScheduleItems,
    dayWorkouts,
    dayWorkoutExercises,
    auditLogs,
  ];
}

typedef $$MuscleGroupsTableCreateCompanionBuilder =
    MuscleGroupsCompanion Function({
      required String id,
      required String name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$MuscleGroupsTableUpdateCompanionBuilder =
    MuscleGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$MuscleGroupsTableReferences
    extends
        BaseReferences<_$AppDatabase, $MuscleGroupsTable, MuscleGroupEntity> {
  $$MuscleGroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ExercisesTable, List<ExerciseEntity>>
  _exercisesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.exercises,
    aliasName: $_aliasNameGenerator(
      db.muscleGroups.id,
      db.exercises.muscleGroupId,
    ),
  );

  $$ExercisesTableProcessedTableManager get exercisesRefs {
    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.muscleGroupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_exercisesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MuscleGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $MuscleGroupsTable> {
  $$MuscleGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> exercisesRefs(
    Expression<bool> Function($$ExercisesTableFilterComposer f) f,
  ) {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.muscleGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MuscleGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $MuscleGroupsTable> {
  $$MuscleGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MuscleGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MuscleGroupsTable> {
  $$MuscleGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> exercisesRefs<T extends Object>(
    Expression<T> Function($$ExercisesTableAnnotationComposer a) f,
  ) {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.muscleGroupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MuscleGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MuscleGroupsTable,
          MuscleGroupEntity,
          $$MuscleGroupsTableFilterComposer,
          $$MuscleGroupsTableOrderingComposer,
          $$MuscleGroupsTableAnnotationComposer,
          $$MuscleGroupsTableCreateCompanionBuilder,
          $$MuscleGroupsTableUpdateCompanionBuilder,
          (MuscleGroupEntity, $$MuscleGroupsTableReferences),
          MuscleGroupEntity,
          PrefetchHooks Function({bool exercisesRefs})
        > {
  $$MuscleGroupsTableTableManager(_$AppDatabase db, $MuscleGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MuscleGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MuscleGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MuscleGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MuscleGroupsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MuscleGroupsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MuscleGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({exercisesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (exercisesRefs) db.exercises],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (exercisesRefs)
                    await $_getPrefetchedData<
                      MuscleGroupEntity,
                      $MuscleGroupsTable,
                      ExerciseEntity
                    >(
                      currentTable: table,
                      referencedTable: $$MuscleGroupsTableReferences
                          ._exercisesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MuscleGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).exercisesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.muscleGroupId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MuscleGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MuscleGroupsTable,
      MuscleGroupEntity,
      $$MuscleGroupsTableFilterComposer,
      $$MuscleGroupsTableOrderingComposer,
      $$MuscleGroupsTableAnnotationComposer,
      $$MuscleGroupsTableCreateCompanionBuilder,
      $$MuscleGroupsTableUpdateCompanionBuilder,
      (MuscleGroupEntity, $$MuscleGroupsTableReferences),
      MuscleGroupEntity,
      PrefetchHooks Function({bool exercisesRefs})
    >;
typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      required String id,
      required String name,
      required String muscleGroupId,
      Value<String?> videoUrl,
      Value<String?> alternativeNote,
      Value<String?> alternativeVideoUrl,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> muscleGroupId,
      Value<String?> videoUrl,
      Value<String?> alternativeNote,
      Value<String?> alternativeVideoUrl,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$ExercisesTableReferences
    extends BaseReferences<_$AppDatabase, $ExercisesTable, ExerciseEntity> {
  $$ExercisesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MuscleGroupsTable _muscleGroupIdTable(_$AppDatabase db) =>
      db.muscleGroups.createAlias(
        $_aliasNameGenerator(db.exercises.muscleGroupId, db.muscleGroups.id),
      );

  $$MuscleGroupsTableProcessedTableManager get muscleGroupId {
    final $_column = $_itemColumn<String>('muscle_group_id')!;

    final manager = $$MuscleGroupsTableTableManager(
      $_db,
      $_db.muscleGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_muscleGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $WorkoutGroupExercisesTable,
    List<WorkoutGroupExerciseEntity>
  >
  _workoutGroupExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutGroupExercises,
        aliasName: $_aliasNameGenerator(
          db.exercises.id,
          db.workoutGroupExercises.exerciseId,
        ),
      );

  $$WorkoutGroupExercisesTableProcessedTableManager
  get workoutGroupExercisesRefs {
    final manager = $$WorkoutGroupExercisesTableTableManager(
      $_db,
      $_db.workoutGroupExercises,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutGroupExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WeekScheduleItemsTable,
    List<WeekScheduleItemEntity>
  >
  _weekScheduleItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.weekScheduleItems,
        aliasName: $_aliasNameGenerator(
          db.exercises.id,
          db.weekScheduleItems.exerciseId,
        ),
      );

  $$WeekScheduleItemsTableProcessedTableManager get weekScheduleItemsRefs {
    final manager = $$WeekScheduleItemsTableTableManager(
      $_db,
      $_db.weekScheduleItems,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _weekScheduleItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $DayWorkoutExercisesTable,
    List<DayWorkoutExerciseEntity>
  >
  _dayWorkoutExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dayWorkoutExercises,
        aliasName: $_aliasNameGenerator(
          db.exercises.id,
          db.dayWorkoutExercises.exerciseId,
        ),
      );

  $$DayWorkoutExercisesTableProcessedTableManager get dayWorkoutExercisesRefs {
    final manager = $$DayWorkoutExercisesTableTableManager(
      $_db,
      $_db.dayWorkoutExercises,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dayWorkoutExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternativeNote => $composableBuilder(
    column: $table.alternativeNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alternativeVideoUrl => $composableBuilder(
    column: $table.alternativeVideoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MuscleGroupsTableFilterComposer get muscleGroupId {
    final $$MuscleGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.muscleGroupId,
      referencedTable: $db.muscleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MuscleGroupsTableFilterComposer(
            $db: $db,
            $table: $db.muscleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutGroupExercisesRefs(
    Expression<bool> Function($$WorkoutGroupExercisesTableFilterComposer f) f,
  ) {
    final $$WorkoutGroupExercisesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutGroupExercises,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutGroupExercisesTableFilterComposer(
                $db: $db,
                $table: $db.workoutGroupExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> weekScheduleItemsRefs(
    Expression<bool> Function($$WeekScheduleItemsTableFilterComposer f) f,
  ) {
    final $$WeekScheduleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.weekScheduleItems,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeekScheduleItemsTableFilterComposer(
            $db: $db,
            $table: $db.weekScheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dayWorkoutExercisesRefs(
    Expression<bool> Function($$DayWorkoutExercisesTableFilterComposer f) f,
  ) {
    final $$DayWorkoutExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayWorkoutExercises,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayWorkoutExercisesTableFilterComposer(
            $db: $db,
            $table: $db.dayWorkoutExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternativeNote => $composableBuilder(
    column: $table.alternativeNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alternativeVideoUrl => $composableBuilder(
    column: $table.alternativeVideoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MuscleGroupsTableOrderingComposer get muscleGroupId {
    final $$MuscleGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.muscleGroupId,
      referencedTable: $db.muscleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MuscleGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.muscleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  GeneratedColumn<String> get alternativeNote => $composableBuilder(
    column: $table.alternativeNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alternativeVideoUrl => $composableBuilder(
    column: $table.alternativeVideoUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MuscleGroupsTableAnnotationComposer get muscleGroupId {
    final $$MuscleGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.muscleGroupId,
      referencedTable: $db.muscleGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MuscleGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.muscleGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutGroupExercisesRefs<T extends Object>(
    Expression<T> Function($$WorkoutGroupExercisesTableAnnotationComposer a) f,
  ) {
    final $$WorkoutGroupExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutGroupExercises,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutGroupExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutGroupExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> weekScheduleItemsRefs<T extends Object>(
    Expression<T> Function($$WeekScheduleItemsTableAnnotationComposer a) f,
  ) {
    final $$WeekScheduleItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.weekScheduleItems,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WeekScheduleItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.weekScheduleItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> dayWorkoutExercisesRefs<T extends Object>(
    Expression<T> Function($$DayWorkoutExercisesTableAnnotationComposer a) f,
  ) {
    final $$DayWorkoutExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.dayWorkoutExercises,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DayWorkoutExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.dayWorkoutExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          ExerciseEntity,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (ExerciseEntity, $$ExercisesTableReferences),
          ExerciseEntity,
          PrefetchHooks Function({
            bool muscleGroupId,
            bool workoutGroupExercisesRefs,
            bool weekScheduleItemsRefs,
            bool dayWorkoutExercisesRefs,
          })
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> muscleGroupId = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
                Value<String?> alternativeNote = const Value.absent(),
                Value<String?> alternativeVideoUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                muscleGroupId: muscleGroupId,
                videoUrl: videoUrl,
                alternativeNote: alternativeNote,
                alternativeVideoUrl: alternativeVideoUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String muscleGroupId,
                Value<String?> videoUrl = const Value.absent(),
                Value<String?> alternativeNote = const Value.absent(),
                Value<String?> alternativeVideoUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                muscleGroupId: muscleGroupId,
                videoUrl: videoUrl,
                alternativeNote: alternativeNote,
                alternativeVideoUrl: alternativeVideoUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                muscleGroupId = false,
                workoutGroupExercisesRefs = false,
                weekScheduleItemsRefs = false,
                dayWorkoutExercisesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutGroupExercisesRefs) db.workoutGroupExercises,
                    if (weekScheduleItemsRefs) db.weekScheduleItems,
                    if (dayWorkoutExercisesRefs) db.dayWorkoutExercises,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (muscleGroupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.muscleGroupId,
                                    referencedTable: $$ExercisesTableReferences
                                        ._muscleGroupIdTable(db),
                                    referencedColumn: $$ExercisesTableReferences
                                        ._muscleGroupIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutGroupExercisesRefs)
                        await $_getPrefetchedData<
                          ExerciseEntity,
                          $ExercisesTable,
                          WorkoutGroupExerciseEntity
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences
                              ._workoutGroupExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutGroupExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (weekScheduleItemsRefs)
                        await $_getPrefetchedData<
                          ExerciseEntity,
                          $ExercisesTable,
                          WeekScheduleItemEntity
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences
                              ._weekScheduleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).weekScheduleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dayWorkoutExercisesRefs)
                        await $_getPrefetchedData<
                          ExerciseEntity,
                          $ExercisesTable,
                          DayWorkoutExerciseEntity
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences
                              ._dayWorkoutExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).dayWorkoutExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      ExerciseEntity,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (ExerciseEntity, $$ExercisesTableReferences),
      ExerciseEntity,
      PrefetchHooks Function({
        bool muscleGroupId,
        bool workoutGroupExercisesRefs,
        bool weekScheduleItemsRefs,
        bool dayWorkoutExercisesRefs,
      })
    >;
typedef $$GymsTableCreateCompanionBuilder =
    GymsCompanion Function({
      required String id,
      required String name,
      required String cnpj,
      required String street,
      required String number,
      Value<String?> complement,
      required String district,
      required String city,
      required String stateUf,
      required String cep,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$GymsTableUpdateCompanionBuilder =
    GymsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> cnpj,
      Value<String> street,
      Value<String> number,
      Value<String?> complement,
      Value<String> district,
      Value<String> city,
      Value<String> stateUf,
      Value<String> cep,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$GymsTableReferences
    extends BaseReferences<_$AppDatabase, $GymsTable, GymEntity> {
  $$GymsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StudentGymsTable, List<StudentGymEntity>>
  _studentGymsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.studentGyms,
    aliasName: $_aliasNameGenerator(db.gyms.id, db.studentGyms.gymId),
  );

  $$StudentGymsTableProcessedTableManager get studentGymsRefs {
    final manager = $$StudentGymsTableTableManager(
      $_db,
      $_db.studentGyms,
    ).filter((f) => f.gymId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_studentGymsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GymsTableFilterComposer extends Composer<_$AppDatabase, $GymsTable> {
  $$GymsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cnpj => $composableBuilder(
    column: $table.cnpj,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get street => $composableBuilder(
    column: $table.street,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateUf => $composableBuilder(
    column: $table.stateUf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cep => $composableBuilder(
    column: $table.cep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> studentGymsRefs(
    Expression<bool> Function($$StudentGymsTableFilterComposer f) f,
  ) {
    final $$StudentGymsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studentGyms,
      getReferencedColumn: (t) => t.gymId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentGymsTableFilterComposer(
            $db: $db,
            $table: $db.studentGyms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GymsTableOrderingComposer extends Composer<_$AppDatabase, $GymsTable> {
  $$GymsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cnpj => $composableBuilder(
    column: $table.cnpj,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get street => $composableBuilder(
    column: $table.street,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateUf => $composableBuilder(
    column: $table.stateUf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cep => $composableBuilder(
    column: $table.cep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GymsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GymsTable> {
  $$GymsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cnpj =>
      $composableBuilder(column: $table.cnpj, builder: (column) => column);

  GeneratedColumn<String> get street =>
      $composableBuilder(column: $table.street, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => column,
  );

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get stateUf =>
      $composableBuilder(column: $table.stateUf, builder: (column) => column);

  GeneratedColumn<String> get cep =>
      $composableBuilder(column: $table.cep, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> studentGymsRefs<T extends Object>(
    Expression<T> Function($$StudentGymsTableAnnotationComposer a) f,
  ) {
    final $$StudentGymsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studentGyms,
      getReferencedColumn: (t) => t.gymId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentGymsTableAnnotationComposer(
            $db: $db,
            $table: $db.studentGyms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GymsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GymsTable,
          GymEntity,
          $$GymsTableFilterComposer,
          $$GymsTableOrderingComposer,
          $$GymsTableAnnotationComposer,
          $$GymsTableCreateCompanionBuilder,
          $$GymsTableUpdateCompanionBuilder,
          (GymEntity, $$GymsTableReferences),
          GymEntity,
          PrefetchHooks Function({bool studentGymsRefs})
        > {
  $$GymsTableTableManager(_$AppDatabase db, $GymsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GymsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GymsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GymsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> cnpj = const Value.absent(),
                Value<String> street = const Value.absent(),
                Value<String> number = const Value.absent(),
                Value<String?> complement = const Value.absent(),
                Value<String> district = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> stateUf = const Value.absent(),
                Value<String> cep = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymsCompanion(
                id: id,
                name: name,
                cnpj: cnpj,
                street: street,
                number: number,
                complement: complement,
                district: district,
                city: city,
                stateUf: stateUf,
                cep: cep,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String cnpj,
                required String street,
                required String number,
                Value<String?> complement = const Value.absent(),
                required String district,
                required String city,
                required String stateUf,
                required String cep,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymsCompanion.insert(
                id: id,
                name: name,
                cnpj: cnpj,
                street: street,
                number: number,
                complement: complement,
                district: district,
                city: city,
                stateUf: stateUf,
                cep: cep,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GymsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({studentGymsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (studentGymsRefs) db.studentGyms],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (studentGymsRefs)
                    await $_getPrefetchedData<
                      GymEntity,
                      $GymsTable,
                      StudentGymEntity
                    >(
                      currentTable: table,
                      referencedTable: $$GymsTableReferences
                          ._studentGymsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$GymsTableReferences(db, table, p0).studentGymsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.gymId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$GymsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GymsTable,
      GymEntity,
      $$GymsTableFilterComposer,
      $$GymsTableOrderingComposer,
      $$GymsTableAnnotationComposer,
      $$GymsTableCreateCompanionBuilder,
      $$GymsTableUpdateCompanionBuilder,
      (GymEntity, $$GymsTableReferences),
      GymEntity,
      PrefetchHooks Function({bool studentGymsRefs})
    >;
typedef $$PersonalsTableCreateCompanionBuilder =
    PersonalsCompanion Function({
      required String id,
      required String name,
      required String cpf,
      required String professionalRegistry,
      required String street,
      required String number,
      Value<String?> complement,
      required String city,
      required String stateUf,
      Value<String?> cep,
      required String email,
      Value<String?> phoneCommercial,
      Value<String?> phoneMobile,
      Value<bool> mustChangePassword,
      Value<String?> passwordHash,
      Value<bool> isAdmin,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PersonalsTableUpdateCompanionBuilder =
    PersonalsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> cpf,
      Value<String> professionalRegistry,
      Value<String> street,
      Value<String> number,
      Value<String?> complement,
      Value<String> city,
      Value<String> stateUf,
      Value<String?> cep,
      Value<String> email,
      Value<String?> phoneCommercial,
      Value<String?> phoneMobile,
      Value<bool> mustChangePassword,
      Value<String?> passwordHash,
      Value<bool> isAdmin,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PersonalsTableReferences
    extends BaseReferences<_$AppDatabase, $PersonalsTable, PersonalEntity> {
  $$PersonalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StudentsTable, List<StudentEntity>>
  _studentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.students,
    aliasName: $_aliasNameGenerator(
      db.personals.id,
      db.students.createdByPersonalId,
    ),
  );

  $$StudentsTableProcessedTableManager get studentsRefs {
    final manager = $$StudentsTableTableManager($_db, $_db.students).filter(
      (f) => f.createdByPersonalId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_studentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PersonalsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonalsTable> {
  $$PersonalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cpf => $composableBuilder(
    column: $table.cpf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get professionalRegistry => $composableBuilder(
    column: $table.professionalRegistry,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get street => $composableBuilder(
    column: $table.street,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateUf => $composableBuilder(
    column: $table.stateUf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cep => $composableBuilder(
    column: $table.cep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneCommercial => $composableBuilder(
    column: $table.phoneCommercial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneMobile => $composableBuilder(
    column: $table.phoneMobile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mustChangePassword => $composableBuilder(
    column: $table.mustChangePassword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAdmin => $composableBuilder(
    column: $table.isAdmin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> studentsRefs(
    Expression<bool> Function($$StudentsTableFilterComposer f) f,
  ) {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.createdByPersonalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableFilterComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PersonalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonalsTable> {
  $$PersonalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cpf => $composableBuilder(
    column: $table.cpf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get professionalRegistry => $composableBuilder(
    column: $table.professionalRegistry,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get street => $composableBuilder(
    column: $table.street,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateUf => $composableBuilder(
    column: $table.stateUf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cep => $composableBuilder(
    column: $table.cep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneCommercial => $composableBuilder(
    column: $table.phoneCommercial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneMobile => $composableBuilder(
    column: $table.phoneMobile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mustChangePassword => $composableBuilder(
    column: $table.mustChangePassword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAdmin => $composableBuilder(
    column: $table.isAdmin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonalsTable> {
  $$PersonalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get cpf =>
      $composableBuilder(column: $table.cpf, builder: (column) => column);

  GeneratedColumn<String> get professionalRegistry => $composableBuilder(
    column: $table.professionalRegistry,
    builder: (column) => column,
  );

  GeneratedColumn<String> get street =>
      $composableBuilder(column: $table.street, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => column,
  );

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get stateUf =>
      $composableBuilder(column: $table.stateUf, builder: (column) => column);

  GeneratedColumn<String> get cep =>
      $composableBuilder(column: $table.cep, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get phoneCommercial => $composableBuilder(
    column: $table.phoneCommercial,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phoneMobile => $composableBuilder(
    column: $table.phoneMobile,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get mustChangePassword => $composableBuilder(
    column: $table.mustChangePassword,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAdmin =>
      $composableBuilder(column: $table.isAdmin, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> studentsRefs<T extends Object>(
    Expression<T> Function($$StudentsTableAnnotationComposer a) f,
  ) {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.createdByPersonalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableAnnotationComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PersonalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonalsTable,
          PersonalEntity,
          $$PersonalsTableFilterComposer,
          $$PersonalsTableOrderingComposer,
          $$PersonalsTableAnnotationComposer,
          $$PersonalsTableCreateCompanionBuilder,
          $$PersonalsTableUpdateCompanionBuilder,
          (PersonalEntity, $$PersonalsTableReferences),
          PersonalEntity,
          PrefetchHooks Function({bool studentsRefs})
        > {
  $$PersonalsTableTableManager(_$AppDatabase db, $PersonalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> cpf = const Value.absent(),
                Value<String> professionalRegistry = const Value.absent(),
                Value<String> street = const Value.absent(),
                Value<String> number = const Value.absent(),
                Value<String?> complement = const Value.absent(),
                Value<String> city = const Value.absent(),
                Value<String> stateUf = const Value.absent(),
                Value<String?> cep = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String?> phoneCommercial = const Value.absent(),
                Value<String?> phoneMobile = const Value.absent(),
                Value<bool> mustChangePassword = const Value.absent(),
                Value<String?> passwordHash = const Value.absent(),
                Value<bool> isAdmin = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalsCompanion(
                id: id,
                name: name,
                cpf: cpf,
                professionalRegistry: professionalRegistry,
                street: street,
                number: number,
                complement: complement,
                city: city,
                stateUf: stateUf,
                cep: cep,
                email: email,
                phoneCommercial: phoneCommercial,
                phoneMobile: phoneMobile,
                mustChangePassword: mustChangePassword,
                passwordHash: passwordHash,
                isAdmin: isAdmin,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String cpf,
                required String professionalRegistry,
                required String street,
                required String number,
                Value<String?> complement = const Value.absent(),
                required String city,
                required String stateUf,
                Value<String?> cep = const Value.absent(),
                required String email,
                Value<String?> phoneCommercial = const Value.absent(),
                Value<String?> phoneMobile = const Value.absent(),
                Value<bool> mustChangePassword = const Value.absent(),
                Value<String?> passwordHash = const Value.absent(),
                Value<bool> isAdmin = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonalsCompanion.insert(
                id: id,
                name: name,
                cpf: cpf,
                professionalRegistry: professionalRegistry,
                street: street,
                number: number,
                complement: complement,
                city: city,
                stateUf: stateUf,
                cep: cep,
                email: email,
                phoneCommercial: phoneCommercial,
                phoneMobile: phoneMobile,
                mustChangePassword: mustChangePassword,
                passwordHash: passwordHash,
                isAdmin: isAdmin,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PersonalsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({studentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (studentsRefs) db.students],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (studentsRefs)
                    await $_getPrefetchedData<
                      PersonalEntity,
                      $PersonalsTable,
                      StudentEntity
                    >(
                      currentTable: table,
                      referencedTable: $$PersonalsTableReferences
                          ._studentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PersonalsTableReferences(
                            db,
                            table,
                            p0,
                          ).studentsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.createdByPersonalId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PersonalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonalsTable,
      PersonalEntity,
      $$PersonalsTableFilterComposer,
      $$PersonalsTableOrderingComposer,
      $$PersonalsTableAnnotationComposer,
      $$PersonalsTableCreateCompanionBuilder,
      $$PersonalsTableUpdateCompanionBuilder,
      (PersonalEntity, $$PersonalsTableReferences),
      PersonalEntity,
      PrefetchHooks Function({bool studentsRefs})
    >;
typedef $$StudentsTableCreateCompanionBuilder =
    StudentsCompanion Function({
      required String id,
      required String name,
      Value<String?> email,
      Value<String?> goal,
      Value<String?> cpf,
      Value<DateTime?> birthDate,
      Value<String?> street,
      Value<String?> number,
      Value<String?> complement,
      Value<String?> district,
      Value<String?> city,
      Value<String?> stateUf,
      Value<String?> cep,
      Value<String?> phoneCommercial,
      Value<String?> phoneMobile,
      Value<bool> mustChangePassword,
      Value<String?> passwordHash,
      Value<String?> createdByPersonalId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$StudentsTableUpdateCompanionBuilder =
    StudentsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> email,
      Value<String?> goal,
      Value<String?> cpf,
      Value<DateTime?> birthDate,
      Value<String?> street,
      Value<String?> number,
      Value<String?> complement,
      Value<String?> district,
      Value<String?> city,
      Value<String?> stateUf,
      Value<String?> cep,
      Value<String?> phoneCommercial,
      Value<String?> phoneMobile,
      Value<bool> mustChangePassword,
      Value<String?> passwordHash,
      Value<String?> createdByPersonalId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$StudentsTableReferences
    extends BaseReferences<_$AppDatabase, $StudentsTable, StudentEntity> {
  $$StudentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PersonalsTable _createdByPersonalIdTable(_$AppDatabase db) =>
      db.personals.createAlias(
        $_aliasNameGenerator(db.students.createdByPersonalId, db.personals.id),
      );

  $$PersonalsTableProcessedTableManager? get createdByPersonalId {
    final $_column = $_itemColumn<String>('created_by_personal_id');
    if ($_column == null) return null;
    final manager = $$PersonalsTableTableManager(
      $_db,
      $_db.personals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_createdByPersonalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StudentGymsTable, List<StudentGymEntity>>
  _studentGymsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.studentGyms,
    aliasName: $_aliasNameGenerator(db.students.id, db.studentGyms.studentId),
  );

  $$StudentGymsTableProcessedTableManager get studentGymsRefs {
    final manager = $$StudentGymsTableTableManager(
      $_db,
      $_db.studentGyms,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_studentGymsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WeekScheduleBlocksTable,
    List<WeekScheduleBlockEntity>
  >
  _weekScheduleBlocksRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.weekScheduleBlocks,
        aliasName: $_aliasNameGenerator(
          db.students.id,
          db.weekScheduleBlocks.studentId,
        ),
      );

  $$WeekScheduleBlocksTableProcessedTableManager get weekScheduleBlocksRefs {
    final manager = $$WeekScheduleBlocksTableTableManager(
      $_db,
      $_db.weekScheduleBlocks,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _weekScheduleBlocksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DayWorkoutsTable, List<DayWorkoutEntity>>
  _dayWorkoutsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dayWorkouts,
    aliasName: $_aliasNameGenerator(db.students.id, db.dayWorkouts.studentId),
  );

  $$DayWorkoutsTableProcessedTableManager get dayWorkoutsRefs {
    final manager = $$DayWorkoutsTableTableManager(
      $_db,
      $_db.dayWorkouts,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dayWorkoutsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StudentsTableFilterComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cpf => $composableBuilder(
    column: $table.cpf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get street => $composableBuilder(
    column: $table.street,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateUf => $composableBuilder(
    column: $table.stateUf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cep => $composableBuilder(
    column: $table.cep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneCommercial => $composableBuilder(
    column: $table.phoneCommercial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phoneMobile => $composableBuilder(
    column: $table.phoneMobile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get mustChangePassword => $composableBuilder(
    column: $table.mustChangePassword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PersonalsTableFilterComposer get createdByPersonalId {
    final $$PersonalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByPersonalId,
      referencedTable: $db.personals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonalsTableFilterComposer(
            $db: $db,
            $table: $db.personals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> studentGymsRefs(
    Expression<bool> Function($$StudentGymsTableFilterComposer f) f,
  ) {
    final $$StudentGymsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studentGyms,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentGymsTableFilterComposer(
            $db: $db,
            $table: $db.studentGyms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> weekScheduleBlocksRefs(
    Expression<bool> Function($$WeekScheduleBlocksTableFilterComposer f) f,
  ) {
    final $$WeekScheduleBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.weekScheduleBlocks,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeekScheduleBlocksTableFilterComposer(
            $db: $db,
            $table: $db.weekScheduleBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dayWorkoutsRefs(
    Expression<bool> Function($$DayWorkoutsTableFilterComposer f) f,
  ) {
    final $$DayWorkoutsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayWorkouts,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayWorkoutsTableFilterComposer(
            $db: $db,
            $table: $db.dayWorkouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudentsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cpf => $composableBuilder(
    column: $table.cpf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get street => $composableBuilder(
    column: $table.street,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get district => $composableBuilder(
    column: $table.district,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get city => $composableBuilder(
    column: $table.city,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateUf => $composableBuilder(
    column: $table.stateUf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cep => $composableBuilder(
    column: $table.cep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneCommercial => $composableBuilder(
    column: $table.phoneCommercial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phoneMobile => $composableBuilder(
    column: $table.phoneMobile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get mustChangePassword => $composableBuilder(
    column: $table.mustChangePassword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PersonalsTableOrderingComposer get createdByPersonalId {
    final $$PersonalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByPersonalId,
      referencedTable: $db.personals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonalsTableOrderingComposer(
            $db: $db,
            $table: $db.personals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentsTable> {
  $$StudentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<String> get cpf =>
      $composableBuilder(column: $table.cpf, builder: (column) => column);

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<String> get street =>
      $composableBuilder(column: $table.street, builder: (column) => column);

  GeneratedColumn<String> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get complement => $composableBuilder(
    column: $table.complement,
    builder: (column) => column,
  );

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<String> get city =>
      $composableBuilder(column: $table.city, builder: (column) => column);

  GeneratedColumn<String> get stateUf =>
      $composableBuilder(column: $table.stateUf, builder: (column) => column);

  GeneratedColumn<String> get cep =>
      $composableBuilder(column: $table.cep, builder: (column) => column);

  GeneratedColumn<String> get phoneCommercial => $composableBuilder(
    column: $table.phoneCommercial,
    builder: (column) => column,
  );

  GeneratedColumn<String> get phoneMobile => $composableBuilder(
    column: $table.phoneMobile,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get mustChangePassword => $composableBuilder(
    column: $table.mustChangePassword,
    builder: (column) => column,
  );

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PersonalsTableAnnotationComposer get createdByPersonalId {
    final $$PersonalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.createdByPersonalId,
      referencedTable: $db.personals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PersonalsTableAnnotationComposer(
            $db: $db,
            $table: $db.personals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> studentGymsRefs<T extends Object>(
    Expression<T> Function($$StudentGymsTableAnnotationComposer a) f,
  ) {
    final $$StudentGymsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.studentGyms,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentGymsTableAnnotationComposer(
            $db: $db,
            $table: $db.studentGyms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> weekScheduleBlocksRefs<T extends Object>(
    Expression<T> Function($$WeekScheduleBlocksTableAnnotationComposer a) f,
  ) {
    final $$WeekScheduleBlocksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.weekScheduleBlocks,
          getReferencedColumn: (t) => t.studentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WeekScheduleBlocksTableAnnotationComposer(
                $db: $db,
                $table: $db.weekScheduleBlocks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> dayWorkoutsRefs<T extends Object>(
    Expression<T> Function($$DayWorkoutsTableAnnotationComposer a) f,
  ) {
    final $$DayWorkoutsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayWorkouts,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayWorkoutsTableAnnotationComposer(
            $db: $db,
            $table: $db.dayWorkouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudentsTable,
          StudentEntity,
          $$StudentsTableFilterComposer,
          $$StudentsTableOrderingComposer,
          $$StudentsTableAnnotationComposer,
          $$StudentsTableCreateCompanionBuilder,
          $$StudentsTableUpdateCompanionBuilder,
          (StudentEntity, $$StudentsTableReferences),
          StudentEntity,
          PrefetchHooks Function({
            bool createdByPersonalId,
            bool studentGymsRefs,
            bool weekScheduleBlocksRefs,
            bool dayWorkoutsRefs,
          })
        > {
  $$StudentsTableTableManager(_$AppDatabase db, $StudentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> goal = const Value.absent(),
                Value<String?> cpf = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<String?> street = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<String?> complement = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> stateUf = const Value.absent(),
                Value<String?> cep = const Value.absent(),
                Value<String?> phoneCommercial = const Value.absent(),
                Value<String?> phoneMobile = const Value.absent(),
                Value<bool> mustChangePassword = const Value.absent(),
                Value<String?> passwordHash = const Value.absent(),
                Value<String?> createdByPersonalId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentsCompanion(
                id: id,
                name: name,
                email: email,
                goal: goal,
                cpf: cpf,
                birthDate: birthDate,
                street: street,
                number: number,
                complement: complement,
                district: district,
                city: city,
                stateUf: stateUf,
                cep: cep,
                phoneCommercial: phoneCommercial,
                phoneMobile: phoneMobile,
                mustChangePassword: mustChangePassword,
                passwordHash: passwordHash,
                createdByPersonalId: createdByPersonalId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> email = const Value.absent(),
                Value<String?> goal = const Value.absent(),
                Value<String?> cpf = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<String?> street = const Value.absent(),
                Value<String?> number = const Value.absent(),
                Value<String?> complement = const Value.absent(),
                Value<String?> district = const Value.absent(),
                Value<String?> city = const Value.absent(),
                Value<String?> stateUf = const Value.absent(),
                Value<String?> cep = const Value.absent(),
                Value<String?> phoneCommercial = const Value.absent(),
                Value<String?> phoneMobile = const Value.absent(),
                Value<bool> mustChangePassword = const Value.absent(),
                Value<String?> passwordHash = const Value.absent(),
                Value<String?> createdByPersonalId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentsCompanion.insert(
                id: id,
                name: name,
                email: email,
                goal: goal,
                cpf: cpf,
                birthDate: birthDate,
                street: street,
                number: number,
                complement: complement,
                district: district,
                city: city,
                stateUf: stateUf,
                cep: cep,
                phoneCommercial: phoneCommercial,
                phoneMobile: phoneMobile,
                mustChangePassword: mustChangePassword,
                passwordHash: passwordHash,
                createdByPersonalId: createdByPersonalId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StudentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                createdByPersonalId = false,
                studentGymsRefs = false,
                weekScheduleBlocksRefs = false,
                dayWorkoutsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (studentGymsRefs) db.studentGyms,
                    if (weekScheduleBlocksRefs) db.weekScheduleBlocks,
                    if (dayWorkoutsRefs) db.dayWorkouts,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (createdByPersonalId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.createdByPersonalId,
                                    referencedTable: $$StudentsTableReferences
                                        ._createdByPersonalIdTable(db),
                                    referencedColumn: $$StudentsTableReferences
                                        ._createdByPersonalIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (studentGymsRefs)
                        await $_getPrefetchedData<
                          StudentEntity,
                          $StudentsTable,
                          StudentGymEntity
                        >(
                          currentTable: table,
                          referencedTable: $$StudentsTableReferences
                              ._studentGymsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudentsTableReferences(
                                db,
                                table,
                                p0,
                              ).studentGymsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (weekScheduleBlocksRefs)
                        await $_getPrefetchedData<
                          StudentEntity,
                          $StudentsTable,
                          WeekScheduleBlockEntity
                        >(
                          currentTable: table,
                          referencedTable: $$StudentsTableReferences
                              ._weekScheduleBlocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudentsTableReferences(
                                db,
                                table,
                                p0,
                              ).weekScheduleBlocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dayWorkoutsRefs)
                        await $_getPrefetchedData<
                          StudentEntity,
                          $StudentsTable,
                          DayWorkoutEntity
                        >(
                          currentTable: table,
                          referencedTable: $$StudentsTableReferences
                              ._dayWorkoutsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudentsTableReferences(
                                db,
                                table,
                                p0,
                              ).dayWorkoutsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.studentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StudentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudentsTable,
      StudentEntity,
      $$StudentsTableFilterComposer,
      $$StudentsTableOrderingComposer,
      $$StudentsTableAnnotationComposer,
      $$StudentsTableCreateCompanionBuilder,
      $$StudentsTableUpdateCompanionBuilder,
      (StudentEntity, $$StudentsTableReferences),
      StudentEntity,
      PrefetchHooks Function({
        bool createdByPersonalId,
        bool studentGymsRefs,
        bool weekScheduleBlocksRefs,
        bool dayWorkoutsRefs,
      })
    >;
typedef $$StudentGymsTableCreateCompanionBuilder =
    StudentGymsCompanion Function({
      required String studentId,
      required String gymId,
      Value<int> rowid,
    });
typedef $$StudentGymsTableUpdateCompanionBuilder =
    StudentGymsCompanion Function({
      Value<String> studentId,
      Value<String> gymId,
      Value<int> rowid,
    });

final class $$StudentGymsTableReferences
    extends BaseReferences<_$AppDatabase, $StudentGymsTable, StudentGymEntity> {
  $$StudentGymsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StudentsTable _studentIdTable(_$AppDatabase db) =>
      db.students.createAlias(
        $_aliasNameGenerator(db.studentGyms.studentId, db.students.id),
      );

  $$StudentsTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<String>('student_id')!;

    final manager = $$StudentsTableTableManager(
      $_db,
      $_db.students,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GymsTable _gymIdTable(_$AppDatabase db) => db.gyms.createAlias(
    $_aliasNameGenerator(db.studentGyms.gymId, db.gyms.id),
  );

  $$GymsTableProcessedTableManager get gymId {
    final $_column = $_itemColumn<String>('gym_id')!;

    final manager = $$GymsTableTableManager(
      $_db,
      $_db.gyms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gymIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StudentGymsTableFilterComposer
    extends Composer<_$AppDatabase, $StudentGymsTable> {
  $$StudentGymsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$StudentsTableFilterComposer get studentId {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableFilterComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GymsTableFilterComposer get gymId {
    final $$GymsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gymId,
      referencedTable: $db.gyms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GymsTableFilterComposer(
            $db: $db,
            $table: $db.gyms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudentGymsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudentGymsTable> {
  $$StudentGymsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$StudentsTableOrderingComposer get studentId {
    final $$StudentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableOrderingComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GymsTableOrderingComposer get gymId {
    final $$GymsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gymId,
      referencedTable: $db.gyms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GymsTableOrderingComposer(
            $db: $db,
            $table: $db.gyms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudentGymsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudentGymsTable> {
  $$StudentGymsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$StudentsTableAnnotationComposer get studentId {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableAnnotationComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GymsTableAnnotationComposer get gymId {
    final $$GymsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gymId,
      referencedTable: $db.gyms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GymsTableAnnotationComposer(
            $db: $db,
            $table: $db.gyms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StudentGymsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudentGymsTable,
          StudentGymEntity,
          $$StudentGymsTableFilterComposer,
          $$StudentGymsTableOrderingComposer,
          $$StudentGymsTableAnnotationComposer,
          $$StudentGymsTableCreateCompanionBuilder,
          $$StudentGymsTableUpdateCompanionBuilder,
          (StudentGymEntity, $$StudentGymsTableReferences),
          StudentGymEntity,
          PrefetchHooks Function({bool studentId, bool gymId})
        > {
  $$StudentGymsTableTableManager(_$AppDatabase db, $StudentGymsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudentGymsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudentGymsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudentGymsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> studentId = const Value.absent(),
                Value<String> gymId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudentGymsCompanion(
                studentId: studentId,
                gymId: gymId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String studentId,
                required String gymId,
                Value<int> rowid = const Value.absent(),
              }) => StudentGymsCompanion.insert(
                studentId: studentId,
                gymId: gymId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StudentGymsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({studentId = false, gymId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (studentId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.studentId,
                                referencedTable: $$StudentGymsTableReferences
                                    ._studentIdTable(db),
                                referencedColumn: $$StudentGymsTableReferences
                                    ._studentIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (gymId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.gymId,
                                referencedTable: $$StudentGymsTableReferences
                                    ._gymIdTable(db),
                                referencedColumn: $$StudentGymsTableReferences
                                    ._gymIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StudentGymsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudentGymsTable,
      StudentGymEntity,
      $$StudentGymsTableFilterComposer,
      $$StudentGymsTableOrderingComposer,
      $$StudentGymsTableAnnotationComposer,
      $$StudentGymsTableCreateCompanionBuilder,
      $$StudentGymsTableUpdateCompanionBuilder,
      (StudentGymEntity, $$StudentGymsTableReferences),
      StudentGymEntity,
      PrefetchHooks Function({bool studentId, bool gymId})
    >;
typedef $$TrainingMethodsTableCreateCompanionBuilder =
    TrainingMethodsCompanion Function({
      required String id,
      required String method,
      required String description,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$TrainingMethodsTableUpdateCompanionBuilder =
    TrainingMethodsCompanion Function({
      Value<String> id,
      Value<String> method,
      Value<String> description,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TrainingMethodsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TrainingMethodsTable,
          TrainingMethodEntity
        > {
  $$TrainingMethodsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $WorkoutGroupExercisesTable,
    List<WorkoutGroupExerciseEntity>
  >
  _workoutGroupExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutGroupExercises,
        aliasName: $_aliasNameGenerator(
          db.trainingMethods.id,
          db.workoutGroupExercises.trainingMethodId,
        ),
      );

  $$WorkoutGroupExercisesTableProcessedTableManager
  get workoutGroupExercisesRefs {
    final manager =
        $$WorkoutGroupExercisesTableTableManager(
          $_db,
          $_db.workoutGroupExercises,
        ).filter(
          (f) => f.trainingMethodId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _workoutGroupExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WeekScheduleItemsTable,
    List<WeekScheduleItemEntity>
  >
  _weekScheduleItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.weekScheduleItems,
        aliasName: $_aliasNameGenerator(
          db.trainingMethods.id,
          db.weekScheduleItems.trainingMethodId,
        ),
      );

  $$WeekScheduleItemsTableProcessedTableManager get weekScheduleItemsRefs {
    final manager =
        $$WeekScheduleItemsTableTableManager(
          $_db,
          $_db.weekScheduleItems,
        ).filter(
          (f) => f.trainingMethodId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _weekScheduleItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $DayWorkoutExercisesTable,
    List<DayWorkoutExerciseEntity>
  >
  _dayWorkoutExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dayWorkoutExercises,
        aliasName: $_aliasNameGenerator(
          db.trainingMethods.id,
          db.dayWorkoutExercises.trainingMethodId,
        ),
      );

  $$DayWorkoutExercisesTableProcessedTableManager get dayWorkoutExercisesRefs {
    final manager =
        $$DayWorkoutExercisesTableTableManager(
          $_db,
          $_db.dayWorkoutExercises,
        ).filter(
          (f) => f.trainingMethodId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _dayWorkoutExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TrainingMethodsTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingMethodsTable> {
  $$TrainingMethodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutGroupExercisesRefs(
    Expression<bool> Function($$WorkoutGroupExercisesTableFilterComposer f) f,
  ) {
    final $$WorkoutGroupExercisesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutGroupExercises,
          getReferencedColumn: (t) => t.trainingMethodId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutGroupExercisesTableFilterComposer(
                $db: $db,
                $table: $db.workoutGroupExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> weekScheduleItemsRefs(
    Expression<bool> Function($$WeekScheduleItemsTableFilterComposer f) f,
  ) {
    final $$WeekScheduleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.weekScheduleItems,
      getReferencedColumn: (t) => t.trainingMethodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeekScheduleItemsTableFilterComposer(
            $db: $db,
            $table: $db.weekScheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dayWorkoutExercisesRefs(
    Expression<bool> Function($$DayWorkoutExercisesTableFilterComposer f) f,
  ) {
    final $$DayWorkoutExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayWorkoutExercises,
      getReferencedColumn: (t) => t.trainingMethodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayWorkoutExercisesTableFilterComposer(
            $db: $db,
            $table: $db.dayWorkoutExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrainingMethodsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingMethodsTable> {
  $$TrainingMethodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get method => $composableBuilder(
    column: $table.method,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrainingMethodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingMethodsTable> {
  $$TrainingMethodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> workoutGroupExercisesRefs<T extends Object>(
    Expression<T> Function($$WorkoutGroupExercisesTableAnnotationComposer a) f,
  ) {
    final $$WorkoutGroupExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutGroupExercises,
          getReferencedColumn: (t) => t.trainingMethodId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutGroupExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutGroupExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> weekScheduleItemsRefs<T extends Object>(
    Expression<T> Function($$WeekScheduleItemsTableAnnotationComposer a) f,
  ) {
    final $$WeekScheduleItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.weekScheduleItems,
          getReferencedColumn: (t) => t.trainingMethodId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WeekScheduleItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.weekScheduleItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> dayWorkoutExercisesRefs<T extends Object>(
    Expression<T> Function($$DayWorkoutExercisesTableAnnotationComposer a) f,
  ) {
    final $$DayWorkoutExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.dayWorkoutExercises,
          getReferencedColumn: (t) => t.trainingMethodId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DayWorkoutExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.dayWorkoutExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TrainingMethodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainingMethodsTable,
          TrainingMethodEntity,
          $$TrainingMethodsTableFilterComposer,
          $$TrainingMethodsTableOrderingComposer,
          $$TrainingMethodsTableAnnotationComposer,
          $$TrainingMethodsTableCreateCompanionBuilder,
          $$TrainingMethodsTableUpdateCompanionBuilder,
          (TrainingMethodEntity, $$TrainingMethodsTableReferences),
          TrainingMethodEntity,
          PrefetchHooks Function({
            bool workoutGroupExercisesRefs,
            bool weekScheduleItemsRefs,
            bool dayWorkoutExercisesRefs,
          })
        > {
  $$TrainingMethodsTableTableManager(
    _$AppDatabase db,
    $TrainingMethodsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingMethodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingMethodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingMethodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingMethodsCompanion(
                id: id,
                method: method,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String method,
                required String description,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingMethodsCompanion.insert(
                id: id,
                method: method,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrainingMethodsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                workoutGroupExercisesRefs = false,
                weekScheduleItemsRefs = false,
                dayWorkoutExercisesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutGroupExercisesRefs) db.workoutGroupExercises,
                    if (weekScheduleItemsRefs) db.weekScheduleItems,
                    if (dayWorkoutExercisesRefs) db.dayWorkoutExercises,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutGroupExercisesRefs)
                        await $_getPrefetchedData<
                          TrainingMethodEntity,
                          $TrainingMethodsTable,
                          WorkoutGroupExerciseEntity
                        >(
                          currentTable: table,
                          referencedTable: $$TrainingMethodsTableReferences
                              ._workoutGroupExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrainingMethodsTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutGroupExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trainingMethodId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (weekScheduleItemsRefs)
                        await $_getPrefetchedData<
                          TrainingMethodEntity,
                          $TrainingMethodsTable,
                          WeekScheduleItemEntity
                        >(
                          currentTable: table,
                          referencedTable: $$TrainingMethodsTableReferences
                              ._weekScheduleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrainingMethodsTableReferences(
                                db,
                                table,
                                p0,
                              ).weekScheduleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trainingMethodId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (dayWorkoutExercisesRefs)
                        await $_getPrefetchedData<
                          TrainingMethodEntity,
                          $TrainingMethodsTable,
                          DayWorkoutExerciseEntity
                        >(
                          currentTable: table,
                          referencedTable: $$TrainingMethodsTableReferences
                              ._dayWorkoutExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrainingMethodsTableReferences(
                                db,
                                table,
                                p0,
                              ).dayWorkoutExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trainingMethodId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TrainingMethodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainingMethodsTable,
      TrainingMethodEntity,
      $$TrainingMethodsTableFilterComposer,
      $$TrainingMethodsTableOrderingComposer,
      $$TrainingMethodsTableAnnotationComposer,
      $$TrainingMethodsTableCreateCompanionBuilder,
      $$TrainingMethodsTableUpdateCompanionBuilder,
      (TrainingMethodEntity, $$TrainingMethodsTableReferences),
      TrainingMethodEntity,
      PrefetchHooks Function({
        bool workoutGroupExercisesRefs,
        bool weekScheduleItemsRefs,
        bool dayWorkoutExercisesRefs,
      })
    >;
typedef $$WorkoutGroupsTableCreateCompanionBuilder =
    WorkoutGroupsCompanion Function({
      required String id,
      required String name,
      required String description,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$WorkoutGroupsTableUpdateCompanionBuilder =
    WorkoutGroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> description,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WorkoutGroupsTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkoutGroupsTable, WorkoutGroupEntity> {
  $$WorkoutGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $WorkoutGroupExercisesTable,
    List<WorkoutGroupExerciseEntity>
  >
  _workoutGroupExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutGroupExercises,
        aliasName: $_aliasNameGenerator(
          db.workoutGroups.id,
          db.workoutGroupExercises.workoutGroupId,
        ),
      );

  $$WorkoutGroupExercisesTableProcessedTableManager
  get workoutGroupExercisesRefs {
    final manager = $$WorkoutGroupExercisesTableTableManager(
      $_db,
      $_db.workoutGroupExercises,
    ).filter((f) => f.workoutGroupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutGroupExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutGroupsTable> {
  $$WorkoutGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutGroupExercisesRefs(
    Expression<bool> Function($$WorkoutGroupExercisesTableFilterComposer f) f,
  ) {
    final $$WorkoutGroupExercisesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutGroupExercises,
          getReferencedColumn: (t) => t.workoutGroupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutGroupExercisesTableFilterComposer(
                $db: $db,
                $table: $db.workoutGroupExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutGroupsTable> {
  $$WorkoutGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutGroupsTable> {
  $$WorkoutGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> workoutGroupExercisesRefs<T extends Object>(
    Expression<T> Function($$WorkoutGroupExercisesTableAnnotationComposer a) f,
  ) {
    final $$WorkoutGroupExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutGroupExercises,
          getReferencedColumn: (t) => t.workoutGroupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutGroupExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutGroupExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutGroupsTable,
          WorkoutGroupEntity,
          $$WorkoutGroupsTableFilterComposer,
          $$WorkoutGroupsTableOrderingComposer,
          $$WorkoutGroupsTableAnnotationComposer,
          $$WorkoutGroupsTableCreateCompanionBuilder,
          $$WorkoutGroupsTableUpdateCompanionBuilder,
          (WorkoutGroupEntity, $$WorkoutGroupsTableReferences),
          WorkoutGroupEntity,
          PrefetchHooks Function({bool workoutGroupExercisesRefs})
        > {
  $$WorkoutGroupsTableTableManager(_$AppDatabase db, $WorkoutGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutGroupsCompanion(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String description,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutGroupsCompanion.insert(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workoutGroupExercisesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (workoutGroupExercisesRefs) db.workoutGroupExercises,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutGroupExercisesRefs)
                    await $_getPrefetchedData<
                      WorkoutGroupEntity,
                      $WorkoutGroupsTable,
                      WorkoutGroupExerciseEntity
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutGroupsTableReferences
                          ._workoutGroupExercisesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$WorkoutGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).workoutGroupExercisesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.workoutGroupId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutGroupsTable,
      WorkoutGroupEntity,
      $$WorkoutGroupsTableFilterComposer,
      $$WorkoutGroupsTableOrderingComposer,
      $$WorkoutGroupsTableAnnotationComposer,
      $$WorkoutGroupsTableCreateCompanionBuilder,
      $$WorkoutGroupsTableUpdateCompanionBuilder,
      (WorkoutGroupEntity, $$WorkoutGroupsTableReferences),
      WorkoutGroupEntity,
      PrefetchHooks Function({bool workoutGroupExercisesRefs})
    >;
typedef $$WorkoutGroupExercisesTableCreateCompanionBuilder =
    WorkoutGroupExercisesCompanion Function({
      required String id,
      required String workoutGroupId,
      required String exerciseId,
      Value<int> sortOrder,
      Value<double?> lastLoadKg,
      Value<int?> lastReps,
      Value<String?> lastRepsText,
      Value<int?> lastSets,
      Value<int> restBetweenSetsSec,
      Value<String?> trainingMethodId,
      Value<DateTime> updatedAt,
      Value<String?> comboId,
      Value<int> rowid,
    });
typedef $$WorkoutGroupExercisesTableUpdateCompanionBuilder =
    WorkoutGroupExercisesCompanion Function({
      Value<String> id,
      Value<String> workoutGroupId,
      Value<String> exerciseId,
      Value<int> sortOrder,
      Value<double?> lastLoadKg,
      Value<int?> lastReps,
      Value<String?> lastRepsText,
      Value<int?> lastSets,
      Value<int> restBetweenSetsSec,
      Value<String?> trainingMethodId,
      Value<DateTime> updatedAt,
      Value<String?> comboId,
      Value<int> rowid,
    });

final class $$WorkoutGroupExercisesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkoutGroupExercisesTable,
          WorkoutGroupExerciseEntity
        > {
  $$WorkoutGroupExercisesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkoutGroupsTable _workoutGroupIdTable(_$AppDatabase db) =>
      db.workoutGroups.createAlias(
        $_aliasNameGenerator(
          db.workoutGroupExercises.workoutGroupId,
          db.workoutGroups.id,
        ),
      );

  $$WorkoutGroupsTableProcessedTableManager get workoutGroupId {
    final $_column = $_itemColumn<String>('workout_group_id')!;

    final manager = $$WorkoutGroupsTableTableManager(
      $_db,
      $_db.workoutGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutGroupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias(
        $_aliasNameGenerator(
          db.workoutGroupExercises.exerciseId,
          db.exercises.id,
        ),
      );

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TrainingMethodsTable _trainingMethodIdTable(_$AppDatabase db) =>
      db.trainingMethods.createAlias(
        $_aliasNameGenerator(
          db.workoutGroupExercises.trainingMethodId,
          db.trainingMethods.id,
        ),
      );

  $$TrainingMethodsTableProcessedTableManager? get trainingMethodId {
    final $_column = $_itemColumn<String>('training_method_id');
    if ($_column == null) return null;
    final manager = $$TrainingMethodsTableTableManager(
      $_db,
      $_db.trainingMethods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trainingMethodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkoutGroupExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutGroupExercisesTable> {
  $$WorkoutGroupExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastLoadKg => $composableBuilder(
    column: $table.lastLoadKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastReps => $composableBuilder(
    column: $table.lastReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastRepsText => $composableBuilder(
    column: $table.lastRepsText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSets => $composableBuilder(
    column: $table.lastSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comboId => $composableBuilder(
    column: $table.comboId,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutGroupsTableFilterComposer get workoutGroupId {
    final $$WorkoutGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutGroupId,
      referencedTable: $db.workoutGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutGroupsTableFilterComposer(
            $db: $db,
            $table: $db.workoutGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableFilterComposer get trainingMethodId {
    final $$TrainingMethodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableFilterComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutGroupExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutGroupExercisesTable> {
  $$WorkoutGroupExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastLoadKg => $composableBuilder(
    column: $table.lastLoadKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastReps => $composableBuilder(
    column: $table.lastReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastRepsText => $composableBuilder(
    column: $table.lastRepsText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSets => $composableBuilder(
    column: $table.lastSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comboId => $composableBuilder(
    column: $table.comboId,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutGroupsTableOrderingComposer get workoutGroupId {
    final $$WorkoutGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutGroupId,
      referencedTable: $db.workoutGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.workoutGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableOrderingComposer get trainingMethodId {
    final $$TrainingMethodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableOrderingComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutGroupExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutGroupExercisesTable> {
  $$WorkoutGroupExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<double> get lastLoadKg => $composableBuilder(
    column: $table.lastLoadKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastReps =>
      $composableBuilder(column: $table.lastReps, builder: (column) => column);

  GeneratedColumn<String> get lastRepsText => $composableBuilder(
    column: $table.lastRepsText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSets =>
      $composableBuilder(column: $table.lastSets, builder: (column) => column);

  GeneratedColumn<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get comboId =>
      $composableBuilder(column: $table.comboId, builder: (column) => column);

  $$WorkoutGroupsTableAnnotationComposer get workoutGroupId {
    final $$WorkoutGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutGroupId,
      referencedTable: $db.workoutGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableAnnotationComposer get trainingMethodId {
    final $$TrainingMethodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutGroupExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutGroupExercisesTable,
          WorkoutGroupExerciseEntity,
          $$WorkoutGroupExercisesTableFilterComposer,
          $$WorkoutGroupExercisesTableOrderingComposer,
          $$WorkoutGroupExercisesTableAnnotationComposer,
          $$WorkoutGroupExercisesTableCreateCompanionBuilder,
          $$WorkoutGroupExercisesTableUpdateCompanionBuilder,
          (WorkoutGroupExerciseEntity, $$WorkoutGroupExercisesTableReferences),
          WorkoutGroupExerciseEntity,
          PrefetchHooks Function({
            bool workoutGroupId,
            bool exerciseId,
            bool trainingMethodId,
          })
        > {
  $$WorkoutGroupExercisesTableTableManager(
    _$AppDatabase db,
    $WorkoutGroupExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutGroupExercisesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WorkoutGroupExercisesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WorkoutGroupExercisesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> workoutGroupId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<double?> lastLoadKg = const Value.absent(),
                Value<int?> lastReps = const Value.absent(),
                Value<String?> lastRepsText = const Value.absent(),
                Value<int?> lastSets = const Value.absent(),
                Value<int> restBetweenSetsSec = const Value.absent(),
                Value<String?> trainingMethodId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> comboId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutGroupExercisesCompanion(
                id: id,
                workoutGroupId: workoutGroupId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                lastLoadKg: lastLoadKg,
                lastReps: lastReps,
                lastRepsText: lastRepsText,
                lastSets: lastSets,
                restBetweenSetsSec: restBetweenSetsSec,
                trainingMethodId: trainingMethodId,
                updatedAt: updatedAt,
                comboId: comboId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String workoutGroupId,
                required String exerciseId,
                Value<int> sortOrder = const Value.absent(),
                Value<double?> lastLoadKg = const Value.absent(),
                Value<int?> lastReps = const Value.absent(),
                Value<String?> lastRepsText = const Value.absent(),
                Value<int?> lastSets = const Value.absent(),
                Value<int> restBetweenSetsSec = const Value.absent(),
                Value<String?> trainingMethodId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> comboId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutGroupExercisesCompanion.insert(
                id: id,
                workoutGroupId: workoutGroupId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                lastLoadKg: lastLoadKg,
                lastReps: lastReps,
                lastRepsText: lastRepsText,
                lastSets: lastSets,
                restBetweenSetsSec: restBetweenSetsSec,
                trainingMethodId: trainingMethodId,
                updatedAt: updatedAt,
                comboId: comboId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutGroupExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                workoutGroupId = false,
                exerciseId = false,
                trainingMethodId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (workoutGroupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.workoutGroupId,
                                    referencedTable:
                                        $$WorkoutGroupExercisesTableReferences
                                            ._workoutGroupIdTable(db),
                                    referencedColumn:
                                        $$WorkoutGroupExercisesTableReferences
                                            ._workoutGroupIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (exerciseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.exerciseId,
                                    referencedTable:
                                        $$WorkoutGroupExercisesTableReferences
                                            ._exerciseIdTable(db),
                                    referencedColumn:
                                        $$WorkoutGroupExercisesTableReferences
                                            ._exerciseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (trainingMethodId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.trainingMethodId,
                                    referencedTable:
                                        $$WorkoutGroupExercisesTableReferences
                                            ._trainingMethodIdTable(db),
                                    referencedColumn:
                                        $$WorkoutGroupExercisesTableReferences
                                            ._trainingMethodIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$WorkoutGroupExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutGroupExercisesTable,
      WorkoutGroupExerciseEntity,
      $$WorkoutGroupExercisesTableFilterComposer,
      $$WorkoutGroupExercisesTableOrderingComposer,
      $$WorkoutGroupExercisesTableAnnotationComposer,
      $$WorkoutGroupExercisesTableCreateCompanionBuilder,
      $$WorkoutGroupExercisesTableUpdateCompanionBuilder,
      (WorkoutGroupExerciseEntity, $$WorkoutGroupExercisesTableReferences),
      WorkoutGroupExerciseEntity,
      PrefetchHooks Function({
        bool workoutGroupId,
        bool exerciseId,
        bool trainingMethodId,
      })
    >;
typedef $$WeekScheduleBlocksTableCreateCompanionBuilder =
    WeekScheduleBlocksCompanion Function({
      required String id,
      required String studentId,
      required DateTime weekStartMonday,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$WeekScheduleBlocksTableUpdateCompanionBuilder =
    WeekScheduleBlocksCompanion Function({
      Value<String> id,
      Value<String> studentId,
      Value<DateTime> weekStartMonday,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WeekScheduleBlocksTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WeekScheduleBlocksTable,
          WeekScheduleBlockEntity
        > {
  $$WeekScheduleBlocksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StudentsTable _studentIdTable(_$AppDatabase db) =>
      db.students.createAlias(
        $_aliasNameGenerator(db.weekScheduleBlocks.studentId, db.students.id),
      );

  $$StudentsTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<String>('student_id')!;

    final manager = $$StudentsTableTableManager(
      $_db,
      $_db.students,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $WeekScheduleItemsTable,
    List<WeekScheduleItemEntity>
  >
  _weekScheduleItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.weekScheduleItems,
        aliasName: $_aliasNameGenerator(
          db.weekScheduleBlocks.id,
          db.weekScheduleItems.blockId,
        ),
      );

  $$WeekScheduleItemsTableProcessedTableManager get weekScheduleItemsRefs {
    final manager = $$WeekScheduleItemsTableTableManager(
      $_db,
      $_db.weekScheduleItems,
    ).filter((f) => f.blockId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _weekScheduleItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WeekScheduleBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $WeekScheduleBlocksTable> {
  $$WeekScheduleBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get weekStartMonday => $composableBuilder(
    column: $table.weekStartMonday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StudentsTableFilterComposer get studentId {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableFilterComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> weekScheduleItemsRefs(
    Expression<bool> Function($$WeekScheduleItemsTableFilterComposer f) f,
  ) {
    final $$WeekScheduleItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.weekScheduleItems,
      getReferencedColumn: (t) => t.blockId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeekScheduleItemsTableFilterComposer(
            $db: $db,
            $table: $db.weekScheduleItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WeekScheduleBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $WeekScheduleBlocksTable> {
  $$WeekScheduleBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get weekStartMonday => $composableBuilder(
    column: $table.weekStartMonday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StudentsTableOrderingComposer get studentId {
    final $$StudentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableOrderingComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeekScheduleBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeekScheduleBlocksTable> {
  $$WeekScheduleBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get weekStartMonday => $composableBuilder(
    column: $table.weekStartMonday,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StudentsTableAnnotationComposer get studentId {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableAnnotationComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> weekScheduleItemsRefs<T extends Object>(
    Expression<T> Function($$WeekScheduleItemsTableAnnotationComposer a) f,
  ) {
    final $$WeekScheduleItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.weekScheduleItems,
          getReferencedColumn: (t) => t.blockId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WeekScheduleItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.weekScheduleItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WeekScheduleBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeekScheduleBlocksTable,
          WeekScheduleBlockEntity,
          $$WeekScheduleBlocksTableFilterComposer,
          $$WeekScheduleBlocksTableOrderingComposer,
          $$WeekScheduleBlocksTableAnnotationComposer,
          $$WeekScheduleBlocksTableCreateCompanionBuilder,
          $$WeekScheduleBlocksTableUpdateCompanionBuilder,
          (WeekScheduleBlockEntity, $$WeekScheduleBlocksTableReferences),
          WeekScheduleBlockEntity,
          PrefetchHooks Function({bool studentId, bool weekScheduleItemsRefs})
        > {
  $$WeekScheduleBlocksTableTableManager(
    _$AppDatabase db,
    $WeekScheduleBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeekScheduleBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeekScheduleBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeekScheduleBlocksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<DateTime> weekStartMonday = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeekScheduleBlocksCompanion(
                id: id,
                studentId: studentId,
                weekStartMonday: weekStartMonday,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studentId,
                required DateTime weekStartMonday,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeekScheduleBlocksCompanion.insert(
                id: id,
                studentId: studentId,
                weekStartMonday: weekStartMonday,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WeekScheduleBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({studentId = false, weekScheduleItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (weekScheduleItemsRefs) db.weekScheduleItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (studentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.studentId,
                                    referencedTable:
                                        $$WeekScheduleBlocksTableReferences
                                            ._studentIdTable(db),
                                    referencedColumn:
                                        $$WeekScheduleBlocksTableReferences
                                            ._studentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (weekScheduleItemsRefs)
                        await $_getPrefetchedData<
                          WeekScheduleBlockEntity,
                          $WeekScheduleBlocksTable,
                          WeekScheduleItemEntity
                        >(
                          currentTable: table,
                          referencedTable: $$WeekScheduleBlocksTableReferences
                              ._weekScheduleItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WeekScheduleBlocksTableReferences(
                                db,
                                table,
                                p0,
                              ).weekScheduleItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.blockId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WeekScheduleBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeekScheduleBlocksTable,
      WeekScheduleBlockEntity,
      $$WeekScheduleBlocksTableFilterComposer,
      $$WeekScheduleBlocksTableOrderingComposer,
      $$WeekScheduleBlocksTableAnnotationComposer,
      $$WeekScheduleBlocksTableCreateCompanionBuilder,
      $$WeekScheduleBlocksTableUpdateCompanionBuilder,
      (WeekScheduleBlockEntity, $$WeekScheduleBlocksTableReferences),
      WeekScheduleBlockEntity,
      PrefetchHooks Function({bool studentId, bool weekScheduleItemsRefs})
    >;
typedef $$WeekScheduleItemsTableCreateCompanionBuilder =
    WeekScheduleItemsCompanion Function({
      required String id,
      required String blockId,
      required String exerciseId,
      Value<String?> sourceWorkoutGroupId,
      Value<int> sortOrder,
      Value<int> sets,
      Value<int> reps,
      Value<String?> repsText,
      Value<double?> loadKg,
      Value<bool> needsDetail,
      Value<int> restBetweenSetsSec,
      Value<String?> trainingMethodId,
      Value<DateTime> updatedAt,
      Value<String?> comboId,
      Value<int> rowid,
    });
typedef $$WeekScheduleItemsTableUpdateCompanionBuilder =
    WeekScheduleItemsCompanion Function({
      Value<String> id,
      Value<String> blockId,
      Value<String> exerciseId,
      Value<String?> sourceWorkoutGroupId,
      Value<int> sortOrder,
      Value<int> sets,
      Value<int> reps,
      Value<String?> repsText,
      Value<double?> loadKg,
      Value<bool> needsDetail,
      Value<int> restBetweenSetsSec,
      Value<String?> trainingMethodId,
      Value<DateTime> updatedAt,
      Value<String?> comboId,
      Value<int> rowid,
    });

final class $$WeekScheduleItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WeekScheduleItemsTable,
          WeekScheduleItemEntity
        > {
  $$WeekScheduleItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WeekScheduleBlocksTable _blockIdTable(_$AppDatabase db) =>
      db.weekScheduleBlocks.createAlias(
        $_aliasNameGenerator(
          db.weekScheduleItems.blockId,
          db.weekScheduleBlocks.id,
        ),
      );

  $$WeekScheduleBlocksTableProcessedTableManager get blockId {
    final $_column = $_itemColumn<String>('block_id')!;

    final manager = $$WeekScheduleBlocksTableTableManager(
      $_db,
      $_db.weekScheduleBlocks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_blockIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias(
        $_aliasNameGenerator(db.weekScheduleItems.exerciseId, db.exercises.id),
      );

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TrainingMethodsTable _trainingMethodIdTable(_$AppDatabase db) =>
      db.trainingMethods.createAlias(
        $_aliasNameGenerator(
          db.weekScheduleItems.trainingMethodId,
          db.trainingMethods.id,
        ),
      );

  $$TrainingMethodsTableProcessedTableManager? get trainingMethodId {
    final $_column = $_itemColumn<String>('training_method_id');
    if ($_column == null) return null;
    final manager = $$TrainingMethodsTableTableManager(
      $_db,
      $_db.trainingMethods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trainingMethodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WeekScheduleItemsTableFilterComposer
    extends Composer<_$AppDatabase, $WeekScheduleItemsTable> {
  $$WeekScheduleItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceWorkoutGroupId => $composableBuilder(
    column: $table.sourceWorkoutGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sets => $composableBuilder(
    column: $table.sets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repsText => $composableBuilder(
    column: $table.repsText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get loadKg => $composableBuilder(
    column: $table.loadKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsDetail => $composableBuilder(
    column: $table.needsDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comboId => $composableBuilder(
    column: $table.comboId,
    builder: (column) => ColumnFilters(column),
  );

  $$WeekScheduleBlocksTableFilterComposer get blockId {
    final $$WeekScheduleBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.blockId,
      referencedTable: $db.weekScheduleBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeekScheduleBlocksTableFilterComposer(
            $db: $db,
            $table: $db.weekScheduleBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableFilterComposer get trainingMethodId {
    final $$TrainingMethodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableFilterComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeekScheduleItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeekScheduleItemsTable> {
  $$WeekScheduleItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceWorkoutGroupId => $composableBuilder(
    column: $table.sourceWorkoutGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sets => $composableBuilder(
    column: $table.sets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repsText => $composableBuilder(
    column: $table.repsText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get loadKg => $composableBuilder(
    column: $table.loadKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsDetail => $composableBuilder(
    column: $table.needsDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comboId => $composableBuilder(
    column: $table.comboId,
    builder: (column) => ColumnOrderings(column),
  );

  $$WeekScheduleBlocksTableOrderingComposer get blockId {
    final $$WeekScheduleBlocksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.blockId,
      referencedTable: $db.weekScheduleBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeekScheduleBlocksTableOrderingComposer(
            $db: $db,
            $table: $db.weekScheduleBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableOrderingComposer get trainingMethodId {
    final $$TrainingMethodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableOrderingComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeekScheduleItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeekScheduleItemsTable> {
  $$WeekScheduleItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceWorkoutGroupId => $composableBuilder(
    column: $table.sourceWorkoutGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get sets =>
      $composableBuilder(column: $table.sets, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<String> get repsText =>
      $composableBuilder(column: $table.repsText, builder: (column) => column);

  GeneratedColumn<double> get loadKg =>
      $composableBuilder(column: $table.loadKg, builder: (column) => column);

  GeneratedColumn<bool> get needsDetail => $composableBuilder(
    column: $table.needsDetail,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get comboId =>
      $composableBuilder(column: $table.comboId, builder: (column) => column);

  $$WeekScheduleBlocksTableAnnotationComposer get blockId {
    final $$WeekScheduleBlocksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.blockId,
          referencedTable: $db.weekScheduleBlocks,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WeekScheduleBlocksTableAnnotationComposer(
                $db: $db,
                $table: $db.weekScheduleBlocks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableAnnotationComposer get trainingMethodId {
    final $$TrainingMethodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeekScheduleItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeekScheduleItemsTable,
          WeekScheduleItemEntity,
          $$WeekScheduleItemsTableFilterComposer,
          $$WeekScheduleItemsTableOrderingComposer,
          $$WeekScheduleItemsTableAnnotationComposer,
          $$WeekScheduleItemsTableCreateCompanionBuilder,
          $$WeekScheduleItemsTableUpdateCompanionBuilder,
          (WeekScheduleItemEntity, $$WeekScheduleItemsTableReferences),
          WeekScheduleItemEntity,
          PrefetchHooks Function({
            bool blockId,
            bool exerciseId,
            bool trainingMethodId,
          })
        > {
  $$WeekScheduleItemsTableTableManager(
    _$AppDatabase db,
    $WeekScheduleItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeekScheduleItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeekScheduleItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeekScheduleItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> blockId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<String?> sourceWorkoutGroupId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> sets = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<String?> repsText = const Value.absent(),
                Value<double?> loadKg = const Value.absent(),
                Value<bool> needsDetail = const Value.absent(),
                Value<int> restBetweenSetsSec = const Value.absent(),
                Value<String?> trainingMethodId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> comboId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeekScheduleItemsCompanion(
                id: id,
                blockId: blockId,
                exerciseId: exerciseId,
                sourceWorkoutGroupId: sourceWorkoutGroupId,
                sortOrder: sortOrder,
                sets: sets,
                reps: reps,
                repsText: repsText,
                loadKg: loadKg,
                needsDetail: needsDetail,
                restBetweenSetsSec: restBetweenSetsSec,
                trainingMethodId: trainingMethodId,
                updatedAt: updatedAt,
                comboId: comboId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String blockId,
                required String exerciseId,
                Value<String?> sourceWorkoutGroupId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> sets = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<String?> repsText = const Value.absent(),
                Value<double?> loadKg = const Value.absent(),
                Value<bool> needsDetail = const Value.absent(),
                Value<int> restBetweenSetsSec = const Value.absent(),
                Value<String?> trainingMethodId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> comboId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeekScheduleItemsCompanion.insert(
                id: id,
                blockId: blockId,
                exerciseId: exerciseId,
                sourceWorkoutGroupId: sourceWorkoutGroupId,
                sortOrder: sortOrder,
                sets: sets,
                reps: reps,
                repsText: repsText,
                loadKg: loadKg,
                needsDetail: needsDetail,
                restBetweenSetsSec: restBetweenSetsSec,
                trainingMethodId: trainingMethodId,
                updatedAt: updatedAt,
                comboId: comboId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WeekScheduleItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                blockId = false,
                exerciseId = false,
                trainingMethodId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (blockId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.blockId,
                                    referencedTable:
                                        $$WeekScheduleItemsTableReferences
                                            ._blockIdTable(db),
                                    referencedColumn:
                                        $$WeekScheduleItemsTableReferences
                                            ._blockIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (exerciseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.exerciseId,
                                    referencedTable:
                                        $$WeekScheduleItemsTableReferences
                                            ._exerciseIdTable(db),
                                    referencedColumn:
                                        $$WeekScheduleItemsTableReferences
                                            ._exerciseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (trainingMethodId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.trainingMethodId,
                                    referencedTable:
                                        $$WeekScheduleItemsTableReferences
                                            ._trainingMethodIdTable(db),
                                    referencedColumn:
                                        $$WeekScheduleItemsTableReferences
                                            ._trainingMethodIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$WeekScheduleItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeekScheduleItemsTable,
      WeekScheduleItemEntity,
      $$WeekScheduleItemsTableFilterComposer,
      $$WeekScheduleItemsTableOrderingComposer,
      $$WeekScheduleItemsTableAnnotationComposer,
      $$WeekScheduleItemsTableCreateCompanionBuilder,
      $$WeekScheduleItemsTableUpdateCompanionBuilder,
      (WeekScheduleItemEntity, $$WeekScheduleItemsTableReferences),
      WeekScheduleItemEntity,
      PrefetchHooks Function({
        bool blockId,
        bool exerciseId,
        bool trainingMethodId,
      })
    >;
typedef $$DayWorkoutsTableCreateCompanionBuilder =
    DayWorkoutsCompanion Function({
      required String id,
      required String studentId,
      required DateTime dayDate,
      required String status,
      Value<String?> weekItemId,
      Value<int> activeDurationSeconds,
      Value<double?> workoutScore,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> timerResumeAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> sourceWorkoutGroupId,
      Value<double?> watchCaloriesKcal,
      Value<int?> watchAvgHeartRateBpm,
      Value<int> rowid,
    });
typedef $$DayWorkoutsTableUpdateCompanionBuilder =
    DayWorkoutsCompanion Function({
      Value<String> id,
      Value<String> studentId,
      Value<DateTime> dayDate,
      Value<String> status,
      Value<String?> weekItemId,
      Value<int> activeDurationSeconds,
      Value<double?> workoutScore,
      Value<DateTime?> startedAt,
      Value<DateTime?> completedAt,
      Value<DateTime?> timerResumeAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> sourceWorkoutGroupId,
      Value<double?> watchCaloriesKcal,
      Value<int?> watchAvgHeartRateBpm,
      Value<int> rowid,
    });

final class $$DayWorkoutsTableReferences
    extends BaseReferences<_$AppDatabase, $DayWorkoutsTable, DayWorkoutEntity> {
  $$DayWorkoutsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StudentsTable _studentIdTable(_$AppDatabase db) =>
      db.students.createAlias(
        $_aliasNameGenerator(db.dayWorkouts.studentId, db.students.id),
      );

  $$StudentsTableProcessedTableManager get studentId {
    final $_column = $_itemColumn<String>('student_id')!;

    final manager = $$StudentsTableTableManager(
      $_db,
      $_db.students,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_studentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $DayWorkoutExercisesTable,
    List<DayWorkoutExerciseEntity>
  >
  _dayWorkoutExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dayWorkoutExercises,
        aliasName: $_aliasNameGenerator(
          db.dayWorkouts.id,
          db.dayWorkoutExercises.dayWorkoutId,
        ),
      );

  $$DayWorkoutExercisesTableProcessedTableManager get dayWorkoutExercisesRefs {
    final manager = $$DayWorkoutExercisesTableTableManager(
      $_db,
      $_db.dayWorkoutExercises,
    ).filter((f) => f.dayWorkoutId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dayWorkoutExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DayWorkoutsTableFilterComposer
    extends Composer<_$AppDatabase, $DayWorkoutsTable> {
  $$DayWorkoutsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dayDate => $composableBuilder(
    column: $table.dayDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weekItemId => $composableBuilder(
    column: $table.weekItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeDurationSeconds => $composableBuilder(
    column: $table.activeDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get workoutScore => $composableBuilder(
    column: $table.workoutScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timerResumeAt => $composableBuilder(
    column: $table.timerResumeAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceWorkoutGroupId => $composableBuilder(
    column: $table.sourceWorkoutGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get watchCaloriesKcal => $composableBuilder(
    column: $table.watchCaloriesKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get watchAvgHeartRateBpm => $composableBuilder(
    column: $table.watchAvgHeartRateBpm,
    builder: (column) => ColumnFilters(column),
  );

  $$StudentsTableFilterComposer get studentId {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableFilterComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> dayWorkoutExercisesRefs(
    Expression<bool> Function($$DayWorkoutExercisesTableFilterComposer f) f,
  ) {
    final $$DayWorkoutExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dayWorkoutExercises,
      getReferencedColumn: (t) => t.dayWorkoutId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayWorkoutExercisesTableFilterComposer(
            $db: $db,
            $table: $db.dayWorkoutExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DayWorkoutsTableOrderingComposer
    extends Composer<_$AppDatabase, $DayWorkoutsTable> {
  $$DayWorkoutsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dayDate => $composableBuilder(
    column: $table.dayDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weekItemId => $composableBuilder(
    column: $table.weekItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeDurationSeconds => $composableBuilder(
    column: $table.activeDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get workoutScore => $composableBuilder(
    column: $table.workoutScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timerResumeAt => $composableBuilder(
    column: $table.timerResumeAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceWorkoutGroupId => $composableBuilder(
    column: $table.sourceWorkoutGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get watchCaloriesKcal => $composableBuilder(
    column: $table.watchCaloriesKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get watchAvgHeartRateBpm => $composableBuilder(
    column: $table.watchAvgHeartRateBpm,
    builder: (column) => ColumnOrderings(column),
  );

  $$StudentsTableOrderingComposer get studentId {
    final $$StudentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableOrderingComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayWorkoutsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayWorkoutsTable> {
  $$DayWorkoutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get dayDate =>
      $composableBuilder(column: $table.dayDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get weekItemId => $composableBuilder(
    column: $table.weekItemId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get activeDurationSeconds => $composableBuilder(
    column: $table.activeDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get workoutScore => $composableBuilder(
    column: $table.workoutScore,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timerResumeAt => $composableBuilder(
    column: $table.timerResumeAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceWorkoutGroupId => $composableBuilder(
    column: $table.sourceWorkoutGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get watchCaloriesKcal => $composableBuilder(
    column: $table.watchCaloriesKcal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get watchAvgHeartRateBpm => $composableBuilder(
    column: $table.watchAvgHeartRateBpm,
    builder: (column) => column,
  );

  $$StudentsTableAnnotationComposer get studentId {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.studentId,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudentsTableAnnotationComposer(
            $db: $db,
            $table: $db.students,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> dayWorkoutExercisesRefs<T extends Object>(
    Expression<T> Function($$DayWorkoutExercisesTableAnnotationComposer a) f,
  ) {
    final $$DayWorkoutExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.dayWorkoutExercises,
          getReferencedColumn: (t) => t.dayWorkoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DayWorkoutExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.dayWorkoutExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DayWorkoutsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayWorkoutsTable,
          DayWorkoutEntity,
          $$DayWorkoutsTableFilterComposer,
          $$DayWorkoutsTableOrderingComposer,
          $$DayWorkoutsTableAnnotationComposer,
          $$DayWorkoutsTableCreateCompanionBuilder,
          $$DayWorkoutsTableUpdateCompanionBuilder,
          (DayWorkoutEntity, $$DayWorkoutsTableReferences),
          DayWorkoutEntity,
          PrefetchHooks Function({bool studentId, bool dayWorkoutExercisesRefs})
        > {
  $$DayWorkoutsTableTableManager(_$AppDatabase db, $DayWorkoutsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayWorkoutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayWorkoutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DayWorkoutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> studentId = const Value.absent(),
                Value<DateTime> dayDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> weekItemId = const Value.absent(),
                Value<int> activeDurationSeconds = const Value.absent(),
                Value<double?> workoutScore = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> timerResumeAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> sourceWorkoutGroupId = const Value.absent(),
                Value<double?> watchCaloriesKcal = const Value.absent(),
                Value<int?> watchAvgHeartRateBpm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayWorkoutsCompanion(
                id: id,
                studentId: studentId,
                dayDate: dayDate,
                status: status,
                weekItemId: weekItemId,
                activeDurationSeconds: activeDurationSeconds,
                workoutScore: workoutScore,
                startedAt: startedAt,
                completedAt: completedAt,
                timerResumeAt: timerResumeAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                sourceWorkoutGroupId: sourceWorkoutGroupId,
                watchCaloriesKcal: watchCaloriesKcal,
                watchAvgHeartRateBpm: watchAvgHeartRateBpm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String studentId,
                required DateTime dayDate,
                required String status,
                Value<String?> weekItemId = const Value.absent(),
                Value<int> activeDurationSeconds = const Value.absent(),
                Value<double?> workoutScore = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime?> timerResumeAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> sourceWorkoutGroupId = const Value.absent(),
                Value<double?> watchCaloriesKcal = const Value.absent(),
                Value<int?> watchAvgHeartRateBpm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayWorkoutsCompanion.insert(
                id: id,
                studentId: studentId,
                dayDate: dayDate,
                status: status,
                weekItemId: weekItemId,
                activeDurationSeconds: activeDurationSeconds,
                workoutScore: workoutScore,
                startedAt: startedAt,
                completedAt: completedAt,
                timerResumeAt: timerResumeAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                sourceWorkoutGroupId: sourceWorkoutGroupId,
                watchCaloriesKcal: watchCaloriesKcal,
                watchAvgHeartRateBpm: watchAvgHeartRateBpm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DayWorkoutsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({studentId = false, dayWorkoutExercisesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (dayWorkoutExercisesRefs) db.dayWorkoutExercises,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (studentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.studentId,
                                    referencedTable:
                                        $$DayWorkoutsTableReferences
                                            ._studentIdTable(db),
                                    referencedColumn:
                                        $$DayWorkoutsTableReferences
                                            ._studentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (dayWorkoutExercisesRefs)
                        await $_getPrefetchedData<
                          DayWorkoutEntity,
                          $DayWorkoutsTable,
                          DayWorkoutExerciseEntity
                        >(
                          currentTable: table,
                          referencedTable: $$DayWorkoutsTableReferences
                              ._dayWorkoutExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DayWorkoutsTableReferences(
                                db,
                                table,
                                p0,
                              ).dayWorkoutExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.dayWorkoutId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DayWorkoutsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayWorkoutsTable,
      DayWorkoutEntity,
      $$DayWorkoutsTableFilterComposer,
      $$DayWorkoutsTableOrderingComposer,
      $$DayWorkoutsTableAnnotationComposer,
      $$DayWorkoutsTableCreateCompanionBuilder,
      $$DayWorkoutsTableUpdateCompanionBuilder,
      (DayWorkoutEntity, $$DayWorkoutsTableReferences),
      DayWorkoutEntity,
      PrefetchHooks Function({bool studentId, bool dayWorkoutExercisesRefs})
    >;
typedef $$DayWorkoutExercisesTableCreateCompanionBuilder =
    DayWorkoutExercisesCompanion Function({
      required String id,
      required String dayWorkoutId,
      required String exerciseId,
      Value<int> sortOrder,
      required int sets,
      required int reps,
      Value<String?> repsText,
      Value<double?> loadKg,
      Value<double?> exerciseScore,
      Value<String?> performedSetsJson,
      Value<int> restBetweenSetsSec,
      Value<String?> trainingMethodId,
      Value<DateTime> updatedAt,
      Value<String?> comboId,
      Value<int> rowid,
    });
typedef $$DayWorkoutExercisesTableUpdateCompanionBuilder =
    DayWorkoutExercisesCompanion Function({
      Value<String> id,
      Value<String> dayWorkoutId,
      Value<String> exerciseId,
      Value<int> sortOrder,
      Value<int> sets,
      Value<int> reps,
      Value<String?> repsText,
      Value<double?> loadKg,
      Value<double?> exerciseScore,
      Value<String?> performedSetsJson,
      Value<int> restBetweenSetsSec,
      Value<String?> trainingMethodId,
      Value<DateTime> updatedAt,
      Value<String?> comboId,
      Value<int> rowid,
    });

final class $$DayWorkoutExercisesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DayWorkoutExercisesTable,
          DayWorkoutExerciseEntity
        > {
  $$DayWorkoutExercisesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DayWorkoutsTable _dayWorkoutIdTable(_$AppDatabase db) =>
      db.dayWorkouts.createAlias(
        $_aliasNameGenerator(
          db.dayWorkoutExercises.dayWorkoutId,
          db.dayWorkouts.id,
        ),
      );

  $$DayWorkoutsTableProcessedTableManager get dayWorkoutId {
    final $_column = $_itemColumn<String>('day_workout_id')!;

    final manager = $$DayWorkoutsTableTableManager(
      $_db,
      $_db.dayWorkouts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dayWorkoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias(
        $_aliasNameGenerator(
          db.dayWorkoutExercises.exerciseId,
          db.exercises.id,
        ),
      );

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<String>('exercise_id')!;

    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TrainingMethodsTable _trainingMethodIdTable(_$AppDatabase db) =>
      db.trainingMethods.createAlias(
        $_aliasNameGenerator(
          db.dayWorkoutExercises.trainingMethodId,
          db.trainingMethods.id,
        ),
      );

  $$TrainingMethodsTableProcessedTableManager? get trainingMethodId {
    final $_column = $_itemColumn<String>('training_method_id');
    if ($_column == null) return null;
    final manager = $$TrainingMethodsTableTableManager(
      $_db,
      $_db.trainingMethods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trainingMethodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DayWorkoutExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $DayWorkoutExercisesTable> {
  $$DayWorkoutExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sets => $composableBuilder(
    column: $table.sets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repsText => $composableBuilder(
    column: $table.repsText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get loadKg => $composableBuilder(
    column: $table.loadKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get exerciseScore => $composableBuilder(
    column: $table.exerciseScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get performedSetsJson => $composableBuilder(
    column: $table.performedSetsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comboId => $composableBuilder(
    column: $table.comboId,
    builder: (column) => ColumnFilters(column),
  );

  $$DayWorkoutsTableFilterComposer get dayWorkoutId {
    final $$DayWorkoutsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayWorkoutId,
      referencedTable: $db.dayWorkouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayWorkoutsTableFilterComposer(
            $db: $db,
            $table: $db.dayWorkouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableFilterComposer get trainingMethodId {
    final $$TrainingMethodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableFilterComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayWorkoutExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $DayWorkoutExercisesTable> {
  $$DayWorkoutExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sets => $composableBuilder(
    column: $table.sets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repsText => $composableBuilder(
    column: $table.repsText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get loadKg => $composableBuilder(
    column: $table.loadKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get exerciseScore => $composableBuilder(
    column: $table.exerciseScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get performedSetsJson => $composableBuilder(
    column: $table.performedSetsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comboId => $composableBuilder(
    column: $table.comboId,
    builder: (column) => ColumnOrderings(column),
  );

  $$DayWorkoutsTableOrderingComposer get dayWorkoutId {
    final $$DayWorkoutsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayWorkoutId,
      referencedTable: $db.dayWorkouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayWorkoutsTableOrderingComposer(
            $db: $db,
            $table: $db.dayWorkouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableOrderingComposer get trainingMethodId {
    final $$TrainingMethodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableOrderingComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayWorkoutExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DayWorkoutExercisesTable> {
  $$DayWorkoutExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get sets =>
      $composableBuilder(column: $table.sets, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<String> get repsText =>
      $composableBuilder(column: $table.repsText, builder: (column) => column);

  GeneratedColumn<double> get loadKg =>
      $composableBuilder(column: $table.loadKg, builder: (column) => column);

  GeneratedColumn<double> get exerciseScore => $composableBuilder(
    column: $table.exerciseScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get performedSetsJson => $composableBuilder(
    column: $table.performedSetsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restBetweenSetsSec => $composableBuilder(
    column: $table.restBetweenSetsSec,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get comboId =>
      $composableBuilder(column: $table.comboId, builder: (column) => column);

  $$DayWorkoutsTableAnnotationComposer get dayWorkoutId {
    final $$DayWorkoutsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.dayWorkoutId,
      referencedTable: $db.dayWorkouts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DayWorkoutsTableAnnotationComposer(
            $db: $db,
            $table: $db.dayWorkouts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TrainingMethodsTableAnnotationComposer get trainingMethodId {
    final $$TrainingMethodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingMethodId,
      referencedTable: $db.trainingMethods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingMethodsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingMethods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DayWorkoutExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DayWorkoutExercisesTable,
          DayWorkoutExerciseEntity,
          $$DayWorkoutExercisesTableFilterComposer,
          $$DayWorkoutExercisesTableOrderingComposer,
          $$DayWorkoutExercisesTableAnnotationComposer,
          $$DayWorkoutExercisesTableCreateCompanionBuilder,
          $$DayWorkoutExercisesTableUpdateCompanionBuilder,
          (DayWorkoutExerciseEntity, $$DayWorkoutExercisesTableReferences),
          DayWorkoutExerciseEntity,
          PrefetchHooks Function({
            bool dayWorkoutId,
            bool exerciseId,
            bool trainingMethodId,
          })
        > {
  $$DayWorkoutExercisesTableTableManager(
    _$AppDatabase db,
    $DayWorkoutExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DayWorkoutExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DayWorkoutExercisesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DayWorkoutExercisesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> dayWorkoutId = const Value.absent(),
                Value<String> exerciseId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> sets = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<String?> repsText = const Value.absent(),
                Value<double?> loadKg = const Value.absent(),
                Value<double?> exerciseScore = const Value.absent(),
                Value<String?> performedSetsJson = const Value.absent(),
                Value<int> restBetweenSetsSec = const Value.absent(),
                Value<String?> trainingMethodId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> comboId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayWorkoutExercisesCompanion(
                id: id,
                dayWorkoutId: dayWorkoutId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                sets: sets,
                reps: reps,
                repsText: repsText,
                loadKg: loadKg,
                exerciseScore: exerciseScore,
                performedSetsJson: performedSetsJson,
                restBetweenSetsSec: restBetweenSetsSec,
                trainingMethodId: trainingMethodId,
                updatedAt: updatedAt,
                comboId: comboId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String dayWorkoutId,
                required String exerciseId,
                Value<int> sortOrder = const Value.absent(),
                required int sets,
                required int reps,
                Value<String?> repsText = const Value.absent(),
                Value<double?> loadKg = const Value.absent(),
                Value<double?> exerciseScore = const Value.absent(),
                Value<String?> performedSetsJson = const Value.absent(),
                Value<int> restBetweenSetsSec = const Value.absent(),
                Value<String?> trainingMethodId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> comboId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DayWorkoutExercisesCompanion.insert(
                id: id,
                dayWorkoutId: dayWorkoutId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                sets: sets,
                reps: reps,
                repsText: repsText,
                loadKg: loadKg,
                exerciseScore: exerciseScore,
                performedSetsJson: performedSetsJson,
                restBetweenSetsSec: restBetweenSetsSec,
                trainingMethodId: trainingMethodId,
                updatedAt: updatedAt,
                comboId: comboId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DayWorkoutExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                dayWorkoutId = false,
                exerciseId = false,
                trainingMethodId = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (dayWorkoutId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.dayWorkoutId,
                                    referencedTable:
                                        $$DayWorkoutExercisesTableReferences
                                            ._dayWorkoutIdTable(db),
                                    referencedColumn:
                                        $$DayWorkoutExercisesTableReferences
                                            ._dayWorkoutIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (exerciseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.exerciseId,
                                    referencedTable:
                                        $$DayWorkoutExercisesTableReferences
                                            ._exerciseIdTable(db),
                                    referencedColumn:
                                        $$DayWorkoutExercisesTableReferences
                                            ._exerciseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (trainingMethodId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.trainingMethodId,
                                    referencedTable:
                                        $$DayWorkoutExercisesTableReferences
                                            ._trainingMethodIdTable(db),
                                    referencedColumn:
                                        $$DayWorkoutExercisesTableReferences
                                            ._trainingMethodIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$DayWorkoutExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DayWorkoutExercisesTable,
      DayWorkoutExerciseEntity,
      $$DayWorkoutExercisesTableFilterComposer,
      $$DayWorkoutExercisesTableOrderingComposer,
      $$DayWorkoutExercisesTableAnnotationComposer,
      $$DayWorkoutExercisesTableCreateCompanionBuilder,
      $$DayWorkoutExercisesTableUpdateCompanionBuilder,
      (DayWorkoutExerciseEntity, $$DayWorkoutExercisesTableReferences),
      DayWorkoutExerciseEntity,
      PrefetchHooks Function({
        bool dayWorkoutId,
        bool exerciseId,
        bool trainingMethodId,
      })
    >;
typedef $$AuditLogsTableCreateCompanionBuilder =
    AuditLogsCompanion Function({
      required String id,
      Value<DateTime> at,
      required String action,
      required String entityType,
      Value<String?> entityId,
      Value<String?> payloadJson,
      Value<int> rowid,
    });
typedef $$AuditLogsTableUpdateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<String> id,
      Value<DateTime> at,
      Value<String> action,
      Value<String> entityType,
      Value<String?> entityId,
      Value<String?> payloadJson,
      Value<int> rowid,
    });

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$AuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogsTable,
          AuditLogEntity,
          $$AuditLogsTableFilterComposer,
          $$AuditLogsTableOrderingComposer,
          $$AuditLogsTableAnnotationComposer,
          $$AuditLogsTableCreateCompanionBuilder,
          $$AuditLogsTableUpdateCompanionBuilder,
          (
            AuditLogEntity,
            BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLogEntity>,
          ),
          AuditLogEntity,
          PrefetchHooks Function()
        > {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String?> entityId = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion(
                id: id,
                at: at,
                action: action,
                entityType: entityType,
                entityId: entityId,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<DateTime> at = const Value.absent(),
                required String action,
                required String entityType,
                Value<String?> entityId = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AuditLogsCompanion.insert(
                id: id,
                at: at,
                action: action,
                entityType: entityType,
                entityId: entityId,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogsTable,
      AuditLogEntity,
      $$AuditLogsTableFilterComposer,
      $$AuditLogsTableOrderingComposer,
      $$AuditLogsTableAnnotationComposer,
      $$AuditLogsTableCreateCompanionBuilder,
      $$AuditLogsTableUpdateCompanionBuilder,
      (
        AuditLogEntity,
        BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLogEntity>,
      ),
      AuditLogEntity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MuscleGroupsTableTableManager get muscleGroups =>
      $$MuscleGroupsTableTableManager(_db, _db.muscleGroups);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$GymsTableTableManager get gyms => $$GymsTableTableManager(_db, _db.gyms);
  $$PersonalsTableTableManager get personals =>
      $$PersonalsTableTableManager(_db, _db.personals);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db, _db.students);
  $$StudentGymsTableTableManager get studentGyms =>
      $$StudentGymsTableTableManager(_db, _db.studentGyms);
  $$TrainingMethodsTableTableManager get trainingMethods =>
      $$TrainingMethodsTableTableManager(_db, _db.trainingMethods);
  $$WorkoutGroupsTableTableManager get workoutGroups =>
      $$WorkoutGroupsTableTableManager(_db, _db.workoutGroups);
  $$WorkoutGroupExercisesTableTableManager get workoutGroupExercises =>
      $$WorkoutGroupExercisesTableTableManager(_db, _db.workoutGroupExercises);
  $$WeekScheduleBlocksTableTableManager get weekScheduleBlocks =>
      $$WeekScheduleBlocksTableTableManager(_db, _db.weekScheduleBlocks);
  $$WeekScheduleItemsTableTableManager get weekScheduleItems =>
      $$WeekScheduleItemsTableTableManager(_db, _db.weekScheduleItems);
  $$DayWorkoutsTableTableManager get dayWorkouts =>
      $$DayWorkoutsTableTableManager(_db, _db.dayWorkouts);
  $$DayWorkoutExercisesTableTableManager get dayWorkoutExercises =>
      $$DayWorkoutExercisesTableTableManager(_db, _db.dayWorkoutExercises);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
}
