// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ClassRoomsTable extends ClassRooms
    with TableInfo<$ClassRoomsTable, ClassRoomRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClassRoomsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'class_rooms';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClassRoomRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClassRoomRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClassRoomRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
    );
  }

  @override
  $ClassRoomsTable createAlias(String alias) {
    return $ClassRoomsTable(attachedDatabase, alias);
  }
}

class ClassRoomRow extends DataClass implements Insertable<ClassRoomRow> {
  final int id;
  final String name;
  final String? description;
  const ClassRoomRow({required this.id, required this.name, this.description});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  ClassRoomsCompanion toCompanion(bool nullToAbsent) {
    return ClassRoomsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory ClassRoomRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClassRoomRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
    };
  }

  ClassRoomRow copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
  }) => ClassRoomRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
  );
  ClassRoomRow copyWithCompanion(ClassRoomsCompanion data) {
    return ClassRoomRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClassRoomRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassRoomRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description);
}

class ClassRoomsCompanion extends UpdateCompanion<ClassRoomRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  const ClassRoomsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
  });
  ClassRoomsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ClassRoomRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  ClassRoomsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
  }) {
    return ClassRoomsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClassRoomsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $StudentsTable extends Students
    with TableInfo<$StudentsTable, StudentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _classIdMeta = const VerificationMeta(
    'classId',
  );
  @override
  late final GeneratedColumn<int> classId = GeneratedColumn<int>(
    'class_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES class_rooms (id)',
    ),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fullNameMeta = const VerificationMeta(
    'fullName',
  );
  @override
  late final GeneratedColumn<String> fullName = GeneratedColumn<String>(
    'full_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, classId, code, fullName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'students';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('class_id')) {
      context.handle(
        _classIdMeta,
        classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta),
      );
    } else if (isInserting) {
      context.missing(_classIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('full_name')) {
      context.handle(
        _fullNameMeta,
        fullName.isAcceptableOrUnknown(data['full_name']!, _fullNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fullNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      classId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}class_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      fullName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}full_name'],
      )!,
    );
  }

  @override
  $StudentsTable createAlias(String alias) {
    return $StudentsTable(attachedDatabase, alias);
  }
}

class StudentRow extends DataClass implements Insertable<StudentRow> {
  final int id;
  final int classId;
  final String code;
  final String fullName;
  const StudentRow({
    required this.id,
    required this.classId,
    required this.code,
    required this.fullName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['class_id'] = Variable<int>(classId);
    map['code'] = Variable<String>(code);
    map['full_name'] = Variable<String>(fullName);
    return map;
  }

  StudentsCompanion toCompanion(bool nullToAbsent) {
    return StudentsCompanion(
      id: Value(id),
      classId: Value(classId),
      code: Value(code),
      fullName: Value(fullName),
    );
  }

  factory StudentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudentRow(
      id: serializer.fromJson<int>(json['id']),
      classId: serializer.fromJson<int>(json['classId']),
      code: serializer.fromJson<String>(json['code']),
      fullName: serializer.fromJson<String>(json['fullName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'classId': serializer.toJson<int>(classId),
      'code': serializer.toJson<String>(code),
      'fullName': serializer.toJson<String>(fullName),
    };
  }

  StudentRow copyWith({
    int? id,
    int? classId,
    String? code,
    String? fullName,
  }) => StudentRow(
    id: id ?? this.id,
    classId: classId ?? this.classId,
    code: code ?? this.code,
    fullName: fullName ?? this.fullName,
  );
  StudentRow copyWithCompanion(StudentsCompanion data) {
    return StudentRow(
      id: data.id.present ? data.id.value : this.id,
      classId: data.classId.present ? data.classId.value : this.classId,
      code: data.code.present ? data.code.value : this.code,
      fullName: data.fullName.present ? data.fullName.value : this.fullName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudentRow(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('code: $code, ')
          ..write('fullName: $fullName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, classId, code, fullName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudentRow &&
          other.id == this.id &&
          other.classId == this.classId &&
          other.code == this.code &&
          other.fullName == this.fullName);
}

class StudentsCompanion extends UpdateCompanion<StudentRow> {
  final Value<int> id;
  final Value<int> classId;
  final Value<String> code;
  final Value<String> fullName;
  const StudentsCompanion({
    this.id = const Value.absent(),
    this.classId = const Value.absent(),
    this.code = const Value.absent(),
    this.fullName = const Value.absent(),
  });
  StudentsCompanion.insert({
    this.id = const Value.absent(),
    required int classId,
    required String code,
    required String fullName,
  }) : classId = Value(classId),
       code = Value(code),
       fullName = Value(fullName);
  static Insertable<StudentRow> custom({
    Expression<int>? id,
    Expression<int>? classId,
    Expression<String>? code,
    Expression<String>? fullName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (classId != null) 'class_id': classId,
      if (code != null) 'code': code,
      if (fullName != null) 'full_name': fullName,
    });
  }

  StudentsCompanion copyWith({
    Value<int>? id,
    Value<int>? classId,
    Value<String>? code,
    Value<String>? fullName,
  }) {
    return StudentsCompanion(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      code: code ?? this.code,
      fullName: fullName ?? this.fullName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<int>(classId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (fullName.present) {
      map['full_name'] = Variable<String>(fullName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudentsCompanion(')
          ..write('id: $id, ')
          ..write('classId: $classId, ')
          ..write('code: $code, ')
          ..write('fullName: $fullName')
          ..write(')'))
        .toString();
  }
}

class $ContestsTable extends Contests
    with TableInfo<$ContestsTable, ContestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _examDateMeta = const VerificationMeta(
    'examDate',
  );
  @override
  late final GeneratedColumn<DateTime> examDate = GeneratedColumn<DateTime>(
    'exam_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _classIdMeta = const VerificationMeta(
    'classId',
  );
  @override
  late final GeneratedColumn<int> classId = GeneratedColumn<int>(
    'class_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES class_rooms (id)',
    ),
  );
  static const VerificationMeta _questionCountMeta = const VerificationMeta(
    'questionCount',
  );
  @override
  late final GeneratedColumn<int> questionCount = GeneratedColumn<int>(
    'question_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(40),
  );
  static const VerificationMeta _answerChoicesMeta = const VerificationMeta(
    'answerChoices',
  );
  @override
  late final GeneratedColumn<int> answerChoices = GeneratedColumn<int>(
    'answer_choices',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _maxScoreMeta = const VerificationMeta(
    'maxScore',
  );
  @override
  late final GeneratedColumn<double> maxScore = GeneratedColumn<double>(
    'max_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(10.0),
  );
  static const VerificationMeta _formTypeMeta = const VerificationMeta(
    'formType',
  );
  @override
  late final GeneratedColumn<int> formType = GeneratedColumn<int>(
    'form_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _orientationMeta = const VerificationMeta(
    'orientation',
  );
  @override
  late final GeneratedColumn<int> orientation = GeneratedColumn<int>(
    'orientation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _partOneCountMeta = const VerificationMeta(
    'partOneCount',
  );
  @override
  late final GeneratedColumn<int> partOneCount = GeneratedColumn<int>(
    'part_one_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partTwoCountMeta = const VerificationMeta(
    'partTwoCount',
  );
  @override
  late final GeneratedColumn<int> partTwoCount = GeneratedColumn<int>(
    'part_two_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partThreeCountMeta = const VerificationMeta(
    'partThreeCount',
  );
  @override
  late final GeneratedColumn<int> partThreeCount = GeneratedColumn<int>(
    'part_three_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partOneWeightMeta = const VerificationMeta(
    'partOneWeight',
  );
  @override
  late final GeneratedColumn<double> partOneWeight = GeneratedColumn<double>(
    'part_one_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partTwoWeightMeta = const VerificationMeta(
    'partTwoWeight',
  );
  @override
  late final GeneratedColumn<double> partTwoWeight = GeneratedColumn<double>(
    'part_two_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partThreeWeightMeta = const VerificationMeta(
    'partThreeWeight',
  );
  @override
  late final GeneratedColumn<double> partThreeWeight = GeneratedColumn<double>(
    'part_three_weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    examDate,
    classId,
    questionCount,
    answerChoices,
    maxScore,
    formType,
    orientation,
    partOneCount,
    partTwoCount,
    partThreeCount,
    partOneWeight,
    partTwoWeight,
    partThreeWeight,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contests';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('exam_date')) {
      context.handle(
        _examDateMeta,
        examDate.isAcceptableOrUnknown(data['exam_date']!, _examDateMeta),
      );
    } else if (isInserting) {
      context.missing(_examDateMeta);
    }
    if (data.containsKey('class_id')) {
      context.handle(
        _classIdMeta,
        classId.isAcceptableOrUnknown(data['class_id']!, _classIdMeta),
      );
    }
    if (data.containsKey('question_count')) {
      context.handle(
        _questionCountMeta,
        questionCount.isAcceptableOrUnknown(
          data['question_count']!,
          _questionCountMeta,
        ),
      );
    }
    if (data.containsKey('answer_choices')) {
      context.handle(
        _answerChoicesMeta,
        answerChoices.isAcceptableOrUnknown(
          data['answer_choices']!,
          _answerChoicesMeta,
        ),
      );
    }
    if (data.containsKey('max_score')) {
      context.handle(
        _maxScoreMeta,
        maxScore.isAcceptableOrUnknown(data['max_score']!, _maxScoreMeta),
      );
    }
    if (data.containsKey('form_type')) {
      context.handle(
        _formTypeMeta,
        formType.isAcceptableOrUnknown(data['form_type']!, _formTypeMeta),
      );
    }
    if (data.containsKey('orientation')) {
      context.handle(
        _orientationMeta,
        orientation.isAcceptableOrUnknown(
          data['orientation']!,
          _orientationMeta,
        ),
      );
    }
    if (data.containsKey('part_one_count')) {
      context.handle(
        _partOneCountMeta,
        partOneCount.isAcceptableOrUnknown(
          data['part_one_count']!,
          _partOneCountMeta,
        ),
      );
    }
    if (data.containsKey('part_two_count')) {
      context.handle(
        _partTwoCountMeta,
        partTwoCount.isAcceptableOrUnknown(
          data['part_two_count']!,
          _partTwoCountMeta,
        ),
      );
    }
    if (data.containsKey('part_three_count')) {
      context.handle(
        _partThreeCountMeta,
        partThreeCount.isAcceptableOrUnknown(
          data['part_three_count']!,
          _partThreeCountMeta,
        ),
      );
    }
    if (data.containsKey('part_one_weight')) {
      context.handle(
        _partOneWeightMeta,
        partOneWeight.isAcceptableOrUnknown(
          data['part_one_weight']!,
          _partOneWeightMeta,
        ),
      );
    }
    if (data.containsKey('part_two_weight')) {
      context.handle(
        _partTwoWeightMeta,
        partTwoWeight.isAcceptableOrUnknown(
          data['part_two_weight']!,
          _partTwoWeightMeta,
        ),
      );
    }
    if (data.containsKey('part_three_weight')) {
      context.handle(
        _partThreeWeightMeta,
        partThreeWeight.isAcceptableOrUnknown(
          data['part_three_weight']!,
          _partThreeWeightMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContestRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      examDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}exam_date'],
      )!,
      classId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}class_id'],
      ),
      questionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}question_count'],
      )!,
      answerChoices: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}answer_choices'],
      )!,
      maxScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_score'],
      )!,
      formType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}form_type'],
      )!,
      orientation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orientation'],
      )!,
      partOneCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}part_one_count'],
      ),
      partTwoCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}part_two_count'],
      ),
      partThreeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}part_three_count'],
      ),
      partOneWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}part_one_weight'],
      ),
      partTwoWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}part_two_weight'],
      ),
      partThreeWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}part_three_weight'],
      ),
    );
  }

  @override
  $ContestsTable createAlias(String alias) {
    return $ContestsTable(attachedDatabase, alias);
  }
}

class ContestRow extends DataClass implements Insertable<ContestRow> {
  final int id;
  final String name;
  final DateTime examDate;
  final int? classId;
  final int questionCount;
  final int answerChoices;
  final double maxScore;
  final int formType;
  final int orientation;
  final int? partOneCount;
  final int? partTwoCount;
  final int? partThreeCount;
  final double? partOneWeight;
  final double? partTwoWeight;
  final double? partThreeWeight;
  const ContestRow({
    required this.id,
    required this.name,
    required this.examDate,
    this.classId,
    required this.questionCount,
    required this.answerChoices,
    required this.maxScore,
    required this.formType,
    required this.orientation,
    this.partOneCount,
    this.partTwoCount,
    this.partThreeCount,
    this.partOneWeight,
    this.partTwoWeight,
    this.partThreeWeight,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['exam_date'] = Variable<DateTime>(examDate);
    if (!nullToAbsent || classId != null) {
      map['class_id'] = Variable<int>(classId);
    }
    map['question_count'] = Variable<int>(questionCount);
    map['answer_choices'] = Variable<int>(answerChoices);
    map['max_score'] = Variable<double>(maxScore);
    map['form_type'] = Variable<int>(formType);
    map['orientation'] = Variable<int>(orientation);
    if (!nullToAbsent || partOneCount != null) {
      map['part_one_count'] = Variable<int>(partOneCount);
    }
    if (!nullToAbsent || partTwoCount != null) {
      map['part_two_count'] = Variable<int>(partTwoCount);
    }
    if (!nullToAbsent || partThreeCount != null) {
      map['part_three_count'] = Variable<int>(partThreeCount);
    }
    if (!nullToAbsent || partOneWeight != null) {
      map['part_one_weight'] = Variable<double>(partOneWeight);
    }
    if (!nullToAbsent || partTwoWeight != null) {
      map['part_two_weight'] = Variable<double>(partTwoWeight);
    }
    if (!nullToAbsent || partThreeWeight != null) {
      map['part_three_weight'] = Variable<double>(partThreeWeight);
    }
    return map;
  }

  ContestsCompanion toCompanion(bool nullToAbsent) {
    return ContestsCompanion(
      id: Value(id),
      name: Value(name),
      examDate: Value(examDate),
      classId: classId == null && nullToAbsent
          ? const Value.absent()
          : Value(classId),
      questionCount: Value(questionCount),
      answerChoices: Value(answerChoices),
      maxScore: Value(maxScore),
      formType: Value(formType),
      orientation: Value(orientation),
      partOneCount: partOneCount == null && nullToAbsent
          ? const Value.absent()
          : Value(partOneCount),
      partTwoCount: partTwoCount == null && nullToAbsent
          ? const Value.absent()
          : Value(partTwoCount),
      partThreeCount: partThreeCount == null && nullToAbsent
          ? const Value.absent()
          : Value(partThreeCount),
      partOneWeight: partOneWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(partOneWeight),
      partTwoWeight: partTwoWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(partTwoWeight),
      partThreeWeight: partThreeWeight == null && nullToAbsent
          ? const Value.absent()
          : Value(partThreeWeight),
    );
  }

  factory ContestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContestRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      examDate: serializer.fromJson<DateTime>(json['examDate']),
      classId: serializer.fromJson<int?>(json['classId']),
      questionCount: serializer.fromJson<int>(json['questionCount']),
      answerChoices: serializer.fromJson<int>(json['answerChoices']),
      maxScore: serializer.fromJson<double>(json['maxScore']),
      formType: serializer.fromJson<int>(json['formType']),
      orientation: serializer.fromJson<int>(json['orientation']),
      partOneCount: serializer.fromJson<int?>(json['partOneCount']),
      partTwoCount: serializer.fromJson<int?>(json['partTwoCount']),
      partThreeCount: serializer.fromJson<int?>(json['partThreeCount']),
      partOneWeight: serializer.fromJson<double?>(json['partOneWeight']),
      partTwoWeight: serializer.fromJson<double?>(json['partTwoWeight']),
      partThreeWeight: serializer.fromJson<double?>(json['partThreeWeight']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'examDate': serializer.toJson<DateTime>(examDate),
      'classId': serializer.toJson<int?>(classId),
      'questionCount': serializer.toJson<int>(questionCount),
      'answerChoices': serializer.toJson<int>(answerChoices),
      'maxScore': serializer.toJson<double>(maxScore),
      'formType': serializer.toJson<int>(formType),
      'orientation': serializer.toJson<int>(orientation),
      'partOneCount': serializer.toJson<int?>(partOneCount),
      'partTwoCount': serializer.toJson<int?>(partTwoCount),
      'partThreeCount': serializer.toJson<int?>(partThreeCount),
      'partOneWeight': serializer.toJson<double?>(partOneWeight),
      'partTwoWeight': serializer.toJson<double?>(partTwoWeight),
      'partThreeWeight': serializer.toJson<double?>(partThreeWeight),
    };
  }

  ContestRow copyWith({
    int? id,
    String? name,
    DateTime? examDate,
    Value<int?> classId = const Value.absent(),
    int? questionCount,
    int? answerChoices,
    double? maxScore,
    int? formType,
    int? orientation,
    Value<int?> partOneCount = const Value.absent(),
    Value<int?> partTwoCount = const Value.absent(),
    Value<int?> partThreeCount = const Value.absent(),
    Value<double?> partOneWeight = const Value.absent(),
    Value<double?> partTwoWeight = const Value.absent(),
    Value<double?> partThreeWeight = const Value.absent(),
  }) => ContestRow(
    id: id ?? this.id,
    name: name ?? this.name,
    examDate: examDate ?? this.examDate,
    classId: classId.present ? classId.value : this.classId,
    questionCount: questionCount ?? this.questionCount,
    answerChoices: answerChoices ?? this.answerChoices,
    maxScore: maxScore ?? this.maxScore,
    formType: formType ?? this.formType,
    orientation: orientation ?? this.orientation,
    partOneCount: partOneCount.present ? partOneCount.value : this.partOneCount,
    partTwoCount: partTwoCount.present ? partTwoCount.value : this.partTwoCount,
    partThreeCount: partThreeCount.present
        ? partThreeCount.value
        : this.partThreeCount,
    partOneWeight: partOneWeight.present
        ? partOneWeight.value
        : this.partOneWeight,
    partTwoWeight: partTwoWeight.present
        ? partTwoWeight.value
        : this.partTwoWeight,
    partThreeWeight: partThreeWeight.present
        ? partThreeWeight.value
        : this.partThreeWeight,
  );
  ContestRow copyWithCompanion(ContestsCompanion data) {
    return ContestRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      examDate: data.examDate.present ? data.examDate.value : this.examDate,
      classId: data.classId.present ? data.classId.value : this.classId,
      questionCount: data.questionCount.present
          ? data.questionCount.value
          : this.questionCount,
      answerChoices: data.answerChoices.present
          ? data.answerChoices.value
          : this.answerChoices,
      maxScore: data.maxScore.present ? data.maxScore.value : this.maxScore,
      formType: data.formType.present ? data.formType.value : this.formType,
      orientation: data.orientation.present
          ? data.orientation.value
          : this.orientation,
      partOneCount: data.partOneCount.present
          ? data.partOneCount.value
          : this.partOneCount,
      partTwoCount: data.partTwoCount.present
          ? data.partTwoCount.value
          : this.partTwoCount,
      partThreeCount: data.partThreeCount.present
          ? data.partThreeCount.value
          : this.partThreeCount,
      partOneWeight: data.partOneWeight.present
          ? data.partOneWeight.value
          : this.partOneWeight,
      partTwoWeight: data.partTwoWeight.present
          ? data.partTwoWeight.value
          : this.partTwoWeight,
      partThreeWeight: data.partThreeWeight.present
          ? data.partThreeWeight.value
          : this.partThreeWeight,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContestRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('examDate: $examDate, ')
          ..write('classId: $classId, ')
          ..write('questionCount: $questionCount, ')
          ..write('answerChoices: $answerChoices, ')
          ..write('maxScore: $maxScore, ')
          ..write('formType: $formType, ')
          ..write('orientation: $orientation, ')
          ..write('partOneCount: $partOneCount, ')
          ..write('partTwoCount: $partTwoCount, ')
          ..write('partThreeCount: $partThreeCount, ')
          ..write('partOneWeight: $partOneWeight, ')
          ..write('partTwoWeight: $partTwoWeight, ')
          ..write('partThreeWeight: $partThreeWeight')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    examDate,
    classId,
    questionCount,
    answerChoices,
    maxScore,
    formType,
    orientation,
    partOneCount,
    partTwoCount,
    partThreeCount,
    partOneWeight,
    partTwoWeight,
    partThreeWeight,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContestRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.examDate == this.examDate &&
          other.classId == this.classId &&
          other.questionCount == this.questionCount &&
          other.answerChoices == this.answerChoices &&
          other.maxScore == this.maxScore &&
          other.formType == this.formType &&
          other.orientation == this.orientation &&
          other.partOneCount == this.partOneCount &&
          other.partTwoCount == this.partTwoCount &&
          other.partThreeCount == this.partThreeCount &&
          other.partOneWeight == this.partOneWeight &&
          other.partTwoWeight == this.partTwoWeight &&
          other.partThreeWeight == this.partThreeWeight);
}

class ContestsCompanion extends UpdateCompanion<ContestRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> examDate;
  final Value<int?> classId;
  final Value<int> questionCount;
  final Value<int> answerChoices;
  final Value<double> maxScore;
  final Value<int> formType;
  final Value<int> orientation;
  final Value<int?> partOneCount;
  final Value<int?> partTwoCount;
  final Value<int?> partThreeCount;
  final Value<double?> partOneWeight;
  final Value<double?> partTwoWeight;
  final Value<double?> partThreeWeight;
  const ContestsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.examDate = const Value.absent(),
    this.classId = const Value.absent(),
    this.questionCount = const Value.absent(),
    this.answerChoices = const Value.absent(),
    this.maxScore = const Value.absent(),
    this.formType = const Value.absent(),
    this.orientation = const Value.absent(),
    this.partOneCount = const Value.absent(),
    this.partTwoCount = const Value.absent(),
    this.partThreeCount = const Value.absent(),
    this.partOneWeight = const Value.absent(),
    this.partTwoWeight = const Value.absent(),
    this.partThreeWeight = const Value.absent(),
  });
  ContestsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime examDate,
    this.classId = const Value.absent(),
    this.questionCount = const Value.absent(),
    this.answerChoices = const Value.absent(),
    this.maxScore = const Value.absent(),
    this.formType = const Value.absent(),
    this.orientation = const Value.absent(),
    this.partOneCount = const Value.absent(),
    this.partTwoCount = const Value.absent(),
    this.partThreeCount = const Value.absent(),
    this.partOneWeight = const Value.absent(),
    this.partTwoWeight = const Value.absent(),
    this.partThreeWeight = const Value.absent(),
  }) : name = Value(name),
       examDate = Value(examDate);
  static Insertable<ContestRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? examDate,
    Expression<int>? classId,
    Expression<int>? questionCount,
    Expression<int>? answerChoices,
    Expression<double>? maxScore,
    Expression<int>? formType,
    Expression<int>? orientation,
    Expression<int>? partOneCount,
    Expression<int>? partTwoCount,
    Expression<int>? partThreeCount,
    Expression<double>? partOneWeight,
    Expression<double>? partTwoWeight,
    Expression<double>? partThreeWeight,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (examDate != null) 'exam_date': examDate,
      if (classId != null) 'class_id': classId,
      if (questionCount != null) 'question_count': questionCount,
      if (answerChoices != null) 'answer_choices': answerChoices,
      if (maxScore != null) 'max_score': maxScore,
      if (formType != null) 'form_type': formType,
      if (orientation != null) 'orientation': orientation,
      if (partOneCount != null) 'part_one_count': partOneCount,
      if (partTwoCount != null) 'part_two_count': partTwoCount,
      if (partThreeCount != null) 'part_three_count': partThreeCount,
      if (partOneWeight != null) 'part_one_weight': partOneWeight,
      if (partTwoWeight != null) 'part_two_weight': partTwoWeight,
      if (partThreeWeight != null) 'part_three_weight': partThreeWeight,
    });
  }

  ContestsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? examDate,
    Value<int?>? classId,
    Value<int>? questionCount,
    Value<int>? answerChoices,
    Value<double>? maxScore,
    Value<int>? formType,
    Value<int>? orientation,
    Value<int?>? partOneCount,
    Value<int?>? partTwoCount,
    Value<int?>? partThreeCount,
    Value<double?>? partOneWeight,
    Value<double?>? partTwoWeight,
    Value<double?>? partThreeWeight,
  }) {
    return ContestsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      examDate: examDate ?? this.examDate,
      classId: classId ?? this.classId,
      questionCount: questionCount ?? this.questionCount,
      answerChoices: answerChoices ?? this.answerChoices,
      maxScore: maxScore ?? this.maxScore,
      formType: formType ?? this.formType,
      orientation: orientation ?? this.orientation,
      partOneCount: partOneCount ?? this.partOneCount,
      partTwoCount: partTwoCount ?? this.partTwoCount,
      partThreeCount: partThreeCount ?? this.partThreeCount,
      partOneWeight: partOneWeight ?? this.partOneWeight,
      partTwoWeight: partTwoWeight ?? this.partTwoWeight,
      partThreeWeight: partThreeWeight ?? this.partThreeWeight,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (examDate.present) {
      map['exam_date'] = Variable<DateTime>(examDate.value);
    }
    if (classId.present) {
      map['class_id'] = Variable<int>(classId.value);
    }
    if (questionCount.present) {
      map['question_count'] = Variable<int>(questionCount.value);
    }
    if (answerChoices.present) {
      map['answer_choices'] = Variable<int>(answerChoices.value);
    }
    if (maxScore.present) {
      map['max_score'] = Variable<double>(maxScore.value);
    }
    if (formType.present) {
      map['form_type'] = Variable<int>(formType.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<int>(orientation.value);
    }
    if (partOneCount.present) {
      map['part_one_count'] = Variable<int>(partOneCount.value);
    }
    if (partTwoCount.present) {
      map['part_two_count'] = Variable<int>(partTwoCount.value);
    }
    if (partThreeCount.present) {
      map['part_three_count'] = Variable<int>(partThreeCount.value);
    }
    if (partOneWeight.present) {
      map['part_one_weight'] = Variable<double>(partOneWeight.value);
    }
    if (partTwoWeight.present) {
      map['part_two_weight'] = Variable<double>(partTwoWeight.value);
    }
    if (partThreeWeight.present) {
      map['part_three_weight'] = Variable<double>(partThreeWeight.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContestsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('examDate: $examDate, ')
          ..write('classId: $classId, ')
          ..write('questionCount: $questionCount, ')
          ..write('answerChoices: $answerChoices, ')
          ..write('maxScore: $maxScore, ')
          ..write('formType: $formType, ')
          ..write('orientation: $orientation, ')
          ..write('partOneCount: $partOneCount, ')
          ..write('partTwoCount: $partTwoCount, ')
          ..write('partThreeCount: $partThreeCount, ')
          ..write('partOneWeight: $partOneWeight, ')
          ..write('partTwoWeight: $partTwoWeight, ')
          ..write('partThreeWeight: $partThreeWeight')
          ..write(')'))
        .toString();
  }
}

class $AnswerKeysTable extends AnswerKeys
    with TableInfo<$AnswerKeysTable, AnswerKeyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnswerKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contestIdMeta = const VerificationMeta(
    'contestId',
  );
  @override
  late final GeneratedColumn<int> contestId = GeneratedColumn<int>(
    'contest_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES contests (id)',
    ),
  );
  static const VerificationMeta _examCodeMeta = const VerificationMeta(
    'examCode',
  );
  @override
  late final GeneratedColumn<String> examCode = GeneratedColumn<String>(
    'exam_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerSequenceMeta = const VerificationMeta(
    'answerSequence',
  );
  @override
  late final GeneratedColumn<String> answerSequence = GeneratedColumn<String>(
    'answer_sequence',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contestId,
    examCode,
    answerSequence,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'answer_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnswerKeyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('contest_id')) {
      context.handle(
        _contestIdMeta,
        contestId.isAcceptableOrUnknown(data['contest_id']!, _contestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contestIdMeta);
    }
    if (data.containsKey('exam_code')) {
      context.handle(
        _examCodeMeta,
        examCode.isAcceptableOrUnknown(data['exam_code']!, _examCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_examCodeMeta);
    }
    if (data.containsKey('answer_sequence')) {
      context.handle(
        _answerSequenceMeta,
        answerSequence.isAcceptableOrUnknown(
          data['answer_sequence']!,
          _answerSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_answerSequenceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {contestId, examCode},
  ];
  @override
  AnswerKeyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnswerKeyRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      contestId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}contest_id'],
      )!,
      examCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_code'],
      )!,
      answerSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_sequence'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AnswerKeysTable createAlias(String alias) {
    return $AnswerKeysTable(attachedDatabase, alias);
  }
}

class AnswerKeyRow extends DataClass implements Insertable<AnswerKeyRow> {
  final int id;
  final int contestId;
  final String examCode;
  final String answerSequence;
  final DateTime createdAt;
  const AnswerKeyRow({
    required this.id,
    required this.contestId,
    required this.examCode,
    required this.answerSequence,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['contest_id'] = Variable<int>(contestId);
    map['exam_code'] = Variable<String>(examCode);
    map['answer_sequence'] = Variable<String>(answerSequence);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnswerKeysCompanion toCompanion(bool nullToAbsent) {
    return AnswerKeysCompanion(
      id: Value(id),
      contestId: Value(contestId),
      examCode: Value(examCode),
      answerSequence: Value(answerSequence),
      createdAt: Value(createdAt),
    );
  }

  factory AnswerKeyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnswerKeyRow(
      id: serializer.fromJson<int>(json['id']),
      contestId: serializer.fromJson<int>(json['contestId']),
      examCode: serializer.fromJson<String>(json['examCode']),
      answerSequence: serializer.fromJson<String>(json['answerSequence']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contestId': serializer.toJson<int>(contestId),
      'examCode': serializer.toJson<String>(examCode),
      'answerSequence': serializer.toJson<String>(answerSequence),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AnswerKeyRow copyWith({
    int? id,
    int? contestId,
    String? examCode,
    String? answerSequence,
    DateTime? createdAt,
  }) => AnswerKeyRow(
    id: id ?? this.id,
    contestId: contestId ?? this.contestId,
    examCode: examCode ?? this.examCode,
    answerSequence: answerSequence ?? this.answerSequence,
    createdAt: createdAt ?? this.createdAt,
  );
  AnswerKeyRow copyWithCompanion(AnswerKeysCompanion data) {
    return AnswerKeyRow(
      id: data.id.present ? data.id.value : this.id,
      contestId: data.contestId.present ? data.contestId.value : this.contestId,
      examCode: data.examCode.present ? data.examCode.value : this.examCode,
      answerSequence: data.answerSequence.present
          ? data.answerSequence.value
          : this.answerSequence,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnswerKeyRow(')
          ..write('id: $id, ')
          ..write('contestId: $contestId, ')
          ..write('examCode: $examCode, ')
          ..write('answerSequence: $answerSequence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, contestId, examCode, answerSequence, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnswerKeyRow &&
          other.id == this.id &&
          other.contestId == this.contestId &&
          other.examCode == this.examCode &&
          other.answerSequence == this.answerSequence &&
          other.createdAt == this.createdAt);
}

class AnswerKeysCompanion extends UpdateCompanion<AnswerKeyRow> {
  final Value<int> id;
  final Value<int> contestId;
  final Value<String> examCode;
  final Value<String> answerSequence;
  final Value<DateTime> createdAt;
  const AnswerKeysCompanion({
    this.id = const Value.absent(),
    this.contestId = const Value.absent(),
    this.examCode = const Value.absent(),
    this.answerSequence = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AnswerKeysCompanion.insert({
    this.id = const Value.absent(),
    required int contestId,
    required String examCode,
    required String answerSequence,
    this.createdAt = const Value.absent(),
  }) : contestId = Value(contestId),
       examCode = Value(examCode),
       answerSequence = Value(answerSequence);
  static Insertable<AnswerKeyRow> custom({
    Expression<int>? id,
    Expression<int>? contestId,
    Expression<String>? examCode,
    Expression<String>? answerSequence,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contestId != null) 'contest_id': contestId,
      if (examCode != null) 'exam_code': examCode,
      if (answerSequence != null) 'answer_sequence': answerSequence,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AnswerKeysCompanion copyWith({
    Value<int>? id,
    Value<int>? contestId,
    Value<String>? examCode,
    Value<String>? answerSequence,
    Value<DateTime>? createdAt,
  }) {
    return AnswerKeysCompanion(
      id: id ?? this.id,
      contestId: contestId ?? this.contestId,
      examCode: examCode ?? this.examCode,
      answerSequence: answerSequence ?? this.answerSequence,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contestId.present) {
      map['contest_id'] = Variable<int>(contestId.value);
    }
    if (examCode.present) {
      map['exam_code'] = Variable<String>(examCode.value);
    }
    if (answerSequence.present) {
      map['answer_sequence'] = Variable<String>(answerSequence.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnswerKeysCompanion(')
          ..write('id: $id, ')
          ..write('contestId: $contestId, ')
          ..write('examCode: $examCode, ')
          ..write('answerSequence: $answerSequence, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $GradedSheetsTable extends GradedSheets
    with TableInfo<$GradedSheetsTable, GradedSheetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GradedSheetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contestIdMeta = const VerificationMeta(
    'contestId',
  );
  @override
  late final GeneratedColumn<int> contestId = GeneratedColumn<int>(
    'contest_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES contests (id)',
    ),
  );
  static const VerificationMeta _keyIdMeta = const VerificationMeta('keyId');
  @override
  late final GeneratedColumn<int> keyId = GeneratedColumn<int>(
    'key_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES answer_keys (id)',
    ),
  );
  static const VerificationMeta _studentIdMeta = const VerificationMeta(
    'studentId',
  );
  @override
  late final GeneratedColumn<int> studentId = GeneratedColumn<int>(
    'student_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES students (id)',
    ),
  );
  static const VerificationMeta _examCodeMeta = const VerificationMeta(
    'examCode',
  );
  @override
  late final GeneratedColumn<String> examCode = GeneratedColumn<String>(
    'exam_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studentCodeMeta = const VerificationMeta(
    'studentCode',
  );
  @override
  late final GeneratedColumn<String> studentCode = GeneratedColumn<String>(
    'student_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _chosenMeta = const VerificationMeta('chosen');
  @override
  late final GeneratedColumn<String> chosen = GeneratedColumn<String>(
    'chosen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctFlagsMeta = const VerificationMeta(
    'correctFlags',
  );
  @override
  late final GeneratedColumn<String> correctFlags = GeneratedColumn<String>(
    'correct_flags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partOneScoreMeta = const VerificationMeta(
    'partOneScore',
  );
  @override
  late final GeneratedColumn<double> partOneScore = GeneratedColumn<double>(
    'part_one_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partTwoScoreMeta = const VerificationMeta(
    'partTwoScore',
  );
  @override
  late final GeneratedColumn<double> partTwoScore = GeneratedColumn<double>(
    'part_two_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partThreeScoreMeta = const VerificationMeta(
    'partThreeScore',
  );
  @override
  late final GeneratedColumn<double> partThreeScore = GeneratedColumn<double>(
    'part_three_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalImagePathMeta = const VerificationMeta(
    'originalImagePath',
  );
  @override
  late final GeneratedColumn<String> originalImagePath =
      GeneratedColumn<String>(
        'original_image_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _markedImagePathMeta = const VerificationMeta(
    'markedImagePath',
  );
  @override
  late final GeneratedColumn<String> markedImagePath = GeneratedColumn<String>(
    'marked_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _infoImagePathMeta = const VerificationMeta(
    'infoImagePath',
  );
  @override
  late final GeneratedColumn<String> infoImagePath = GeneratedColumn<String>(
    'info_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gradedAtMeta = const VerificationMeta(
    'gradedAt',
  );
  @override
  late final GeneratedColumn<DateTime> gradedAt = GeneratedColumn<DateTime>(
    'graded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contestId,
    keyId,
    studentId,
    examCode,
    studentCode,
    chosen,
    correctFlags,
    score,
    partOneScore,
    partTwoScore,
    partThreeScore,
    originalImagePath,
    markedImagePath,
    infoImagePath,
    gradedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'graded_sheets';
  @override
  VerificationContext validateIntegrity(
    Insertable<GradedSheetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('contest_id')) {
      context.handle(
        _contestIdMeta,
        contestId.isAcceptableOrUnknown(data['contest_id']!, _contestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contestIdMeta);
    }
    if (data.containsKey('key_id')) {
      context.handle(
        _keyIdMeta,
        keyId.isAcceptableOrUnknown(data['key_id']!, _keyIdMeta),
      );
    }
    if (data.containsKey('student_id')) {
      context.handle(
        _studentIdMeta,
        studentId.isAcceptableOrUnknown(data['student_id']!, _studentIdMeta),
      );
    }
    if (data.containsKey('exam_code')) {
      context.handle(
        _examCodeMeta,
        examCode.isAcceptableOrUnknown(data['exam_code']!, _examCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_examCodeMeta);
    }
    if (data.containsKey('student_code')) {
      context.handle(
        _studentCodeMeta,
        studentCode.isAcceptableOrUnknown(
          data['student_code']!,
          _studentCodeMeta,
        ),
      );
    }
    if (data.containsKey('chosen')) {
      context.handle(
        _chosenMeta,
        chosen.isAcceptableOrUnknown(data['chosen']!, _chosenMeta),
      );
    } else if (isInserting) {
      context.missing(_chosenMeta);
    }
    if (data.containsKey('correct_flags')) {
      context.handle(
        _correctFlagsMeta,
        correctFlags.isAcceptableOrUnknown(
          data['correct_flags']!,
          _correctFlagsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_correctFlagsMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('part_one_score')) {
      context.handle(
        _partOneScoreMeta,
        partOneScore.isAcceptableOrUnknown(
          data['part_one_score']!,
          _partOneScoreMeta,
        ),
      );
    }
    if (data.containsKey('part_two_score')) {
      context.handle(
        _partTwoScoreMeta,
        partTwoScore.isAcceptableOrUnknown(
          data['part_two_score']!,
          _partTwoScoreMeta,
        ),
      );
    }
    if (data.containsKey('part_three_score')) {
      context.handle(
        _partThreeScoreMeta,
        partThreeScore.isAcceptableOrUnknown(
          data['part_three_score']!,
          _partThreeScoreMeta,
        ),
      );
    }
    if (data.containsKey('original_image_path')) {
      context.handle(
        _originalImagePathMeta,
        originalImagePath.isAcceptableOrUnknown(
          data['original_image_path']!,
          _originalImagePathMeta,
        ),
      );
    }
    if (data.containsKey('marked_image_path')) {
      context.handle(
        _markedImagePathMeta,
        markedImagePath.isAcceptableOrUnknown(
          data['marked_image_path']!,
          _markedImagePathMeta,
        ),
      );
    }
    if (data.containsKey('info_image_path')) {
      context.handle(
        _infoImagePathMeta,
        infoImagePath.isAcceptableOrUnknown(
          data['info_image_path']!,
          _infoImagePathMeta,
        ),
      );
    }
    if (data.containsKey('graded_at')) {
      context.handle(
        _gradedAtMeta,
        gradedAt.isAcceptableOrUnknown(data['graded_at']!, _gradedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GradedSheetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GradedSheetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      contestId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}contest_id'],
      )!,
      keyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_id'],
      ),
      studentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}student_id'],
      ),
      examCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exam_code'],
      )!,
      studentCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}student_code'],
      )!,
      chosen: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chosen'],
      )!,
      correctFlags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correct_flags'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      partOneScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}part_one_score'],
      ),
      partTwoScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}part_two_score'],
      ),
      partThreeScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}part_three_score'],
      ),
      originalImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_image_path'],
      ),
      markedImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marked_image_path'],
      ),
      infoImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}info_image_path'],
      ),
      gradedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}graded_at'],
      )!,
    );
  }

  @override
  $GradedSheetsTable createAlias(String alias) {
    return $GradedSheetsTable(attachedDatabase, alias);
  }
}

class GradedSheetRow extends DataClass implements Insertable<GradedSheetRow> {
  final int id;
  final int contestId;
  final int? keyId;
  final int? studentId;
  final String examCode;
  final String studentCode;
  final String chosen;
  final String correctFlags;
  final double score;
  final double? partOneScore;
  final double? partTwoScore;
  final double? partThreeScore;
  final String? originalImagePath;
  final String? markedImagePath;
  final String? infoImagePath;
  final DateTime gradedAt;
  const GradedSheetRow({
    required this.id,
    required this.contestId,
    this.keyId,
    this.studentId,
    required this.examCode,
    required this.studentCode,
    required this.chosen,
    required this.correctFlags,
    required this.score,
    this.partOneScore,
    this.partTwoScore,
    this.partThreeScore,
    this.originalImagePath,
    this.markedImagePath,
    this.infoImagePath,
    required this.gradedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['contest_id'] = Variable<int>(contestId);
    if (!nullToAbsent || keyId != null) {
      map['key_id'] = Variable<int>(keyId);
    }
    if (!nullToAbsent || studentId != null) {
      map['student_id'] = Variable<int>(studentId);
    }
    map['exam_code'] = Variable<String>(examCode);
    map['student_code'] = Variable<String>(studentCode);
    map['chosen'] = Variable<String>(chosen);
    map['correct_flags'] = Variable<String>(correctFlags);
    map['score'] = Variable<double>(score);
    if (!nullToAbsent || partOneScore != null) {
      map['part_one_score'] = Variable<double>(partOneScore);
    }
    if (!nullToAbsent || partTwoScore != null) {
      map['part_two_score'] = Variable<double>(partTwoScore);
    }
    if (!nullToAbsent || partThreeScore != null) {
      map['part_three_score'] = Variable<double>(partThreeScore);
    }
    if (!nullToAbsent || originalImagePath != null) {
      map['original_image_path'] = Variable<String>(originalImagePath);
    }
    if (!nullToAbsent || markedImagePath != null) {
      map['marked_image_path'] = Variable<String>(markedImagePath);
    }
    if (!nullToAbsent || infoImagePath != null) {
      map['info_image_path'] = Variable<String>(infoImagePath);
    }
    map['graded_at'] = Variable<DateTime>(gradedAt);
    return map;
  }

  GradedSheetsCompanion toCompanion(bool nullToAbsent) {
    return GradedSheetsCompanion(
      id: Value(id),
      contestId: Value(contestId),
      keyId: keyId == null && nullToAbsent
          ? const Value.absent()
          : Value(keyId),
      studentId: studentId == null && nullToAbsent
          ? const Value.absent()
          : Value(studentId),
      examCode: Value(examCode),
      studentCode: Value(studentCode),
      chosen: Value(chosen),
      correctFlags: Value(correctFlags),
      score: Value(score),
      partOneScore: partOneScore == null && nullToAbsent
          ? const Value.absent()
          : Value(partOneScore),
      partTwoScore: partTwoScore == null && nullToAbsent
          ? const Value.absent()
          : Value(partTwoScore),
      partThreeScore: partThreeScore == null && nullToAbsent
          ? const Value.absent()
          : Value(partThreeScore),
      originalImagePath: originalImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(originalImagePath),
      markedImagePath: markedImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(markedImagePath),
      infoImagePath: infoImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(infoImagePath),
      gradedAt: Value(gradedAt),
    );
  }

  factory GradedSheetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GradedSheetRow(
      id: serializer.fromJson<int>(json['id']),
      contestId: serializer.fromJson<int>(json['contestId']),
      keyId: serializer.fromJson<int?>(json['keyId']),
      studentId: serializer.fromJson<int?>(json['studentId']),
      examCode: serializer.fromJson<String>(json['examCode']),
      studentCode: serializer.fromJson<String>(json['studentCode']),
      chosen: serializer.fromJson<String>(json['chosen']),
      correctFlags: serializer.fromJson<String>(json['correctFlags']),
      score: serializer.fromJson<double>(json['score']),
      partOneScore: serializer.fromJson<double?>(json['partOneScore']),
      partTwoScore: serializer.fromJson<double?>(json['partTwoScore']),
      partThreeScore: serializer.fromJson<double?>(json['partThreeScore']),
      originalImagePath: serializer.fromJson<String?>(
        json['originalImagePath'],
      ),
      markedImagePath: serializer.fromJson<String?>(json['markedImagePath']),
      infoImagePath: serializer.fromJson<String?>(json['infoImagePath']),
      gradedAt: serializer.fromJson<DateTime>(json['gradedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contestId': serializer.toJson<int>(contestId),
      'keyId': serializer.toJson<int?>(keyId),
      'studentId': serializer.toJson<int?>(studentId),
      'examCode': serializer.toJson<String>(examCode),
      'studentCode': serializer.toJson<String>(studentCode),
      'chosen': serializer.toJson<String>(chosen),
      'correctFlags': serializer.toJson<String>(correctFlags),
      'score': serializer.toJson<double>(score),
      'partOneScore': serializer.toJson<double?>(partOneScore),
      'partTwoScore': serializer.toJson<double?>(partTwoScore),
      'partThreeScore': serializer.toJson<double?>(partThreeScore),
      'originalImagePath': serializer.toJson<String?>(originalImagePath),
      'markedImagePath': serializer.toJson<String?>(markedImagePath),
      'infoImagePath': serializer.toJson<String?>(infoImagePath),
      'gradedAt': serializer.toJson<DateTime>(gradedAt),
    };
  }

  GradedSheetRow copyWith({
    int? id,
    int? contestId,
    Value<int?> keyId = const Value.absent(),
    Value<int?> studentId = const Value.absent(),
    String? examCode,
    String? studentCode,
    String? chosen,
    String? correctFlags,
    double? score,
    Value<double?> partOneScore = const Value.absent(),
    Value<double?> partTwoScore = const Value.absent(),
    Value<double?> partThreeScore = const Value.absent(),
    Value<String?> originalImagePath = const Value.absent(),
    Value<String?> markedImagePath = const Value.absent(),
    Value<String?> infoImagePath = const Value.absent(),
    DateTime? gradedAt,
  }) => GradedSheetRow(
    id: id ?? this.id,
    contestId: contestId ?? this.contestId,
    keyId: keyId.present ? keyId.value : this.keyId,
    studentId: studentId.present ? studentId.value : this.studentId,
    examCode: examCode ?? this.examCode,
    studentCode: studentCode ?? this.studentCode,
    chosen: chosen ?? this.chosen,
    correctFlags: correctFlags ?? this.correctFlags,
    score: score ?? this.score,
    partOneScore: partOneScore.present ? partOneScore.value : this.partOneScore,
    partTwoScore: partTwoScore.present ? partTwoScore.value : this.partTwoScore,
    partThreeScore: partThreeScore.present
        ? partThreeScore.value
        : this.partThreeScore,
    originalImagePath: originalImagePath.present
        ? originalImagePath.value
        : this.originalImagePath,
    markedImagePath: markedImagePath.present
        ? markedImagePath.value
        : this.markedImagePath,
    infoImagePath: infoImagePath.present
        ? infoImagePath.value
        : this.infoImagePath,
    gradedAt: gradedAt ?? this.gradedAt,
  );
  GradedSheetRow copyWithCompanion(GradedSheetsCompanion data) {
    return GradedSheetRow(
      id: data.id.present ? data.id.value : this.id,
      contestId: data.contestId.present ? data.contestId.value : this.contestId,
      keyId: data.keyId.present ? data.keyId.value : this.keyId,
      studentId: data.studentId.present ? data.studentId.value : this.studentId,
      examCode: data.examCode.present ? data.examCode.value : this.examCode,
      studentCode: data.studentCode.present
          ? data.studentCode.value
          : this.studentCode,
      chosen: data.chosen.present ? data.chosen.value : this.chosen,
      correctFlags: data.correctFlags.present
          ? data.correctFlags.value
          : this.correctFlags,
      score: data.score.present ? data.score.value : this.score,
      partOneScore: data.partOneScore.present
          ? data.partOneScore.value
          : this.partOneScore,
      partTwoScore: data.partTwoScore.present
          ? data.partTwoScore.value
          : this.partTwoScore,
      partThreeScore: data.partThreeScore.present
          ? data.partThreeScore.value
          : this.partThreeScore,
      originalImagePath: data.originalImagePath.present
          ? data.originalImagePath.value
          : this.originalImagePath,
      markedImagePath: data.markedImagePath.present
          ? data.markedImagePath.value
          : this.markedImagePath,
      infoImagePath: data.infoImagePath.present
          ? data.infoImagePath.value
          : this.infoImagePath,
      gradedAt: data.gradedAt.present ? data.gradedAt.value : this.gradedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GradedSheetRow(')
          ..write('id: $id, ')
          ..write('contestId: $contestId, ')
          ..write('keyId: $keyId, ')
          ..write('studentId: $studentId, ')
          ..write('examCode: $examCode, ')
          ..write('studentCode: $studentCode, ')
          ..write('chosen: $chosen, ')
          ..write('correctFlags: $correctFlags, ')
          ..write('score: $score, ')
          ..write('partOneScore: $partOneScore, ')
          ..write('partTwoScore: $partTwoScore, ')
          ..write('partThreeScore: $partThreeScore, ')
          ..write('originalImagePath: $originalImagePath, ')
          ..write('markedImagePath: $markedImagePath, ')
          ..write('infoImagePath: $infoImagePath, ')
          ..write('gradedAt: $gradedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    contestId,
    keyId,
    studentId,
    examCode,
    studentCode,
    chosen,
    correctFlags,
    score,
    partOneScore,
    partTwoScore,
    partThreeScore,
    originalImagePath,
    markedImagePath,
    infoImagePath,
    gradedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GradedSheetRow &&
          other.id == this.id &&
          other.contestId == this.contestId &&
          other.keyId == this.keyId &&
          other.studentId == this.studentId &&
          other.examCode == this.examCode &&
          other.studentCode == this.studentCode &&
          other.chosen == this.chosen &&
          other.correctFlags == this.correctFlags &&
          other.score == this.score &&
          other.partOneScore == this.partOneScore &&
          other.partTwoScore == this.partTwoScore &&
          other.partThreeScore == this.partThreeScore &&
          other.originalImagePath == this.originalImagePath &&
          other.markedImagePath == this.markedImagePath &&
          other.infoImagePath == this.infoImagePath &&
          other.gradedAt == this.gradedAt);
}

class GradedSheetsCompanion extends UpdateCompanion<GradedSheetRow> {
  final Value<int> id;
  final Value<int> contestId;
  final Value<int?> keyId;
  final Value<int?> studentId;
  final Value<String> examCode;
  final Value<String> studentCode;
  final Value<String> chosen;
  final Value<String> correctFlags;
  final Value<double> score;
  final Value<double?> partOneScore;
  final Value<double?> partTwoScore;
  final Value<double?> partThreeScore;
  final Value<String?> originalImagePath;
  final Value<String?> markedImagePath;
  final Value<String?> infoImagePath;
  final Value<DateTime> gradedAt;
  const GradedSheetsCompanion({
    this.id = const Value.absent(),
    this.contestId = const Value.absent(),
    this.keyId = const Value.absent(),
    this.studentId = const Value.absent(),
    this.examCode = const Value.absent(),
    this.studentCode = const Value.absent(),
    this.chosen = const Value.absent(),
    this.correctFlags = const Value.absent(),
    this.score = const Value.absent(),
    this.partOneScore = const Value.absent(),
    this.partTwoScore = const Value.absent(),
    this.partThreeScore = const Value.absent(),
    this.originalImagePath = const Value.absent(),
    this.markedImagePath = const Value.absent(),
    this.infoImagePath = const Value.absent(),
    this.gradedAt = const Value.absent(),
  });
  GradedSheetsCompanion.insert({
    this.id = const Value.absent(),
    required int contestId,
    this.keyId = const Value.absent(),
    this.studentId = const Value.absent(),
    required String examCode,
    this.studentCode = const Value.absent(),
    required String chosen,
    required String correctFlags,
    required double score,
    this.partOneScore = const Value.absent(),
    this.partTwoScore = const Value.absent(),
    this.partThreeScore = const Value.absent(),
    this.originalImagePath = const Value.absent(),
    this.markedImagePath = const Value.absent(),
    this.infoImagePath = const Value.absent(),
    this.gradedAt = const Value.absent(),
  }) : contestId = Value(contestId),
       examCode = Value(examCode),
       chosen = Value(chosen),
       correctFlags = Value(correctFlags),
       score = Value(score);
  static Insertable<GradedSheetRow> custom({
    Expression<int>? id,
    Expression<int>? contestId,
    Expression<int>? keyId,
    Expression<int>? studentId,
    Expression<String>? examCode,
    Expression<String>? studentCode,
    Expression<String>? chosen,
    Expression<String>? correctFlags,
    Expression<double>? score,
    Expression<double>? partOneScore,
    Expression<double>? partTwoScore,
    Expression<double>? partThreeScore,
    Expression<String>? originalImagePath,
    Expression<String>? markedImagePath,
    Expression<String>? infoImagePath,
    Expression<DateTime>? gradedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contestId != null) 'contest_id': contestId,
      if (keyId != null) 'key_id': keyId,
      if (studentId != null) 'student_id': studentId,
      if (examCode != null) 'exam_code': examCode,
      if (studentCode != null) 'student_code': studentCode,
      if (chosen != null) 'chosen': chosen,
      if (correctFlags != null) 'correct_flags': correctFlags,
      if (score != null) 'score': score,
      if (partOneScore != null) 'part_one_score': partOneScore,
      if (partTwoScore != null) 'part_two_score': partTwoScore,
      if (partThreeScore != null) 'part_three_score': partThreeScore,
      if (originalImagePath != null) 'original_image_path': originalImagePath,
      if (markedImagePath != null) 'marked_image_path': markedImagePath,
      if (infoImagePath != null) 'info_image_path': infoImagePath,
      if (gradedAt != null) 'graded_at': gradedAt,
    });
  }

  GradedSheetsCompanion copyWith({
    Value<int>? id,
    Value<int>? contestId,
    Value<int?>? keyId,
    Value<int?>? studentId,
    Value<String>? examCode,
    Value<String>? studentCode,
    Value<String>? chosen,
    Value<String>? correctFlags,
    Value<double>? score,
    Value<double?>? partOneScore,
    Value<double?>? partTwoScore,
    Value<double?>? partThreeScore,
    Value<String?>? originalImagePath,
    Value<String?>? markedImagePath,
    Value<String?>? infoImagePath,
    Value<DateTime>? gradedAt,
  }) {
    return GradedSheetsCompanion(
      id: id ?? this.id,
      contestId: contestId ?? this.contestId,
      keyId: keyId ?? this.keyId,
      studentId: studentId ?? this.studentId,
      examCode: examCode ?? this.examCode,
      studentCode: studentCode ?? this.studentCode,
      chosen: chosen ?? this.chosen,
      correctFlags: correctFlags ?? this.correctFlags,
      score: score ?? this.score,
      partOneScore: partOneScore ?? this.partOneScore,
      partTwoScore: partTwoScore ?? this.partTwoScore,
      partThreeScore: partThreeScore ?? this.partThreeScore,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      markedImagePath: markedImagePath ?? this.markedImagePath,
      infoImagePath: infoImagePath ?? this.infoImagePath,
      gradedAt: gradedAt ?? this.gradedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contestId.present) {
      map['contest_id'] = Variable<int>(contestId.value);
    }
    if (keyId.present) {
      map['key_id'] = Variable<int>(keyId.value);
    }
    if (studentId.present) {
      map['student_id'] = Variable<int>(studentId.value);
    }
    if (examCode.present) {
      map['exam_code'] = Variable<String>(examCode.value);
    }
    if (studentCode.present) {
      map['student_code'] = Variable<String>(studentCode.value);
    }
    if (chosen.present) {
      map['chosen'] = Variable<String>(chosen.value);
    }
    if (correctFlags.present) {
      map['correct_flags'] = Variable<String>(correctFlags.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (partOneScore.present) {
      map['part_one_score'] = Variable<double>(partOneScore.value);
    }
    if (partTwoScore.present) {
      map['part_two_score'] = Variable<double>(partTwoScore.value);
    }
    if (partThreeScore.present) {
      map['part_three_score'] = Variable<double>(partThreeScore.value);
    }
    if (originalImagePath.present) {
      map['original_image_path'] = Variable<String>(originalImagePath.value);
    }
    if (markedImagePath.present) {
      map['marked_image_path'] = Variable<String>(markedImagePath.value);
    }
    if (infoImagePath.present) {
      map['info_image_path'] = Variable<String>(infoImagePath.value);
    }
    if (gradedAt.present) {
      map['graded_at'] = Variable<DateTime>(gradedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GradedSheetsCompanion(')
          ..write('id: $id, ')
          ..write('contestId: $contestId, ')
          ..write('keyId: $keyId, ')
          ..write('studentId: $studentId, ')
          ..write('examCode: $examCode, ')
          ..write('studentCode: $studentCode, ')
          ..write('chosen: $chosen, ')
          ..write('correctFlags: $correctFlags, ')
          ..write('score: $score, ')
          ..write('partOneScore: $partOneScore, ')
          ..write('partTwoScore: $partTwoScore, ')
          ..write('partThreeScore: $partThreeScore, ')
          ..write('originalImagePath: $originalImagePath, ')
          ..write('markedImagePath: $markedImagePath, ')
          ..write('infoImagePath: $infoImagePath, ')
          ..write('gradedAt: $gradedAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {key},
  ];
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final int id;
  final String key;
  final String value;
  const SettingRow({required this.id, required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({int? id, String? key, String? value}) => SettingRow(
    id: id ?? this.id,
    key: key ?? this.key,
    value: value ?? this.value,
  );
  SettingRow copyWithCompanion(AppSettingsCompanion data) {
    return SettingRow(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.id == this.id &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<int> id;
  final Value<String> key;
  final Value<String> value;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    required String value,
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? value,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? key,
    Value<String>? value,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ClassRoomsTable classRooms = $ClassRoomsTable(this);
  late final $StudentsTable students = $StudentsTable(this);
  late final $ContestsTable contests = $ContestsTable(this);
  late final $AnswerKeysTable answerKeys = $AnswerKeysTable(this);
  late final $GradedSheetsTable gradedSheets = $GradedSheetsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    classRooms,
    students,
    contests,
    answerKeys,
    gradedSheets,
    appSettings,
  ];
}

typedef $$ClassRoomsTableCreateCompanionBuilder = ClassRoomsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
});
typedef $$ClassRoomsTableUpdateCompanionBuilder = ClassRoomsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
});

final class $$ClassRoomsTableReferences
    extends BaseReferences<_$AppDatabase, $ClassRoomsTable, ClassRoomRow> {
  $$ClassRoomsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$StudentsTable, List<StudentRow>>
  _studentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.students,
    aliasName: 'class_rooms__id__students__class_id',
  );

  $$StudentsTableProcessedTableManager get studentsRefs {
    final manager = $$StudentsTableTableManager(
      $_db,
      $_db.students,
    ).filter((f) => f.classId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_studentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ContestsTable, List<ContestRow>>
  _contestsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.contests,
    aliasName: 'class_rooms__id__contests__class_id',
  );

  $$ContestsTableProcessedTableManager get contestsRefs {
    final manager = $$ContestsTableTableManager(
      $_db,
      $_db.contests,
    ).filter((f) => f.classId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_contestsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ClassRoomsTableFilterComposer
    extends Composer<_$AppDatabase, $ClassRoomsTable> {
  $$ClassRoomsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
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

  Expression<bool> studentsRefs(
    Expression<bool> Function($$StudentsTableFilterComposer f) f,
  ) {
    final $$StudentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.classId,
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

  Expression<bool> contestsRefs(
    Expression<bool> Function($$ContestsTableFilterComposer f) f,
  ) {
    final $$ContestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contests,
      getReferencedColumn: (t) => t.classId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContestsTableFilterComposer(
            $db: $db,
            $table: $db.contests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClassRoomsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClassRoomsTable> {
  $$ClassRoomsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
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
}

class $$ClassRoomsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClassRoomsTable> {
  $$ClassRoomsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  Expression<T> studentsRefs<T extends Object>(
    Expression<T> Function($$StudentsTableAnnotationComposer a) f,
  ) {
    final $$StudentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.students,
      getReferencedColumn: (t) => t.classId,
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

  Expression<T> contestsRefs<T extends Object>(
    Expression<T> Function($$ContestsTableAnnotationComposer a) f,
  ) {
    final $$ContestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contests,
      getReferencedColumn: (t) => t.classId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContestsTableAnnotationComposer(
            $db: $db,
            $table: $db.contests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ClassRoomsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClassRoomsTable,
          ClassRoomRow,
          $$ClassRoomsTableFilterComposer,
          $$ClassRoomsTableOrderingComposer,
          $$ClassRoomsTableAnnotationComposer,
          $$ClassRoomsTableCreateCompanionBuilder,
          $$ClassRoomsTableUpdateCompanionBuilder,
          (ClassRoomRow, $$ClassRoomsTableReferences),
          ClassRoomRow,
          PrefetchHooks Function({bool studentsRefs, bool contestsRefs})
        > {
  $$ClassRoomsTableTableManager(_$AppDatabase db, $ClassRoomsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClassRoomsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClassRoomsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClassRoomsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
              }) => ClassRoomsCompanion(
                id: id,
                name: name,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
              }) => ClassRoomsCompanion.insert(
                id: id,
                name: name,
                description: description,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClassRoomsTable, ClassRoomRow>(table),
                  $$ClassRoomsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({studentsRefs = false, contestsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (studentsRefs) db.students,
                    if (contestsRefs) db.contests,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (studentsRefs)
                        await $_getPrefetchedData<
                          ClassRoomRow,
                          $ClassRoomsTable,
                          StudentRow
                        >(
                          currentTable: table,
                          referencedTable: $$ClassRoomsTableReferences
                              ._studentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClassRoomsTableReferences(
                                db,
                                table,
                                p0,
                              ).studentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.classId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (contestsRefs)
                        await $_getPrefetchedData<
                          ClassRoomRow,
                          $ClassRoomsTable,
                          ContestRow
                        >(
                          currentTable: table,
                          referencedTable: $$ClassRoomsTableReferences
                              ._contestsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ClassRoomsTableReferences(
                                db,
                                table,
                                p0,
                              ).contestsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.classId == item.id,
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

typedef $$ClassRoomsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClassRoomsTable,
      ClassRoomRow,
      $$ClassRoomsTableFilterComposer,
      $$ClassRoomsTableOrderingComposer,
      $$ClassRoomsTableAnnotationComposer,
      $$ClassRoomsTableCreateCompanionBuilder,
      $$ClassRoomsTableUpdateCompanionBuilder,
      (ClassRoomRow, $$ClassRoomsTableReferences),
      ClassRoomRow,
      PrefetchHooks Function({bool studentsRefs, bool contestsRefs})
    >;
typedef $$StudentsTableCreateCompanionBuilder = StudentsCompanion Function({
  Value<int> id,
  required int classId,
  required String code,
  required String fullName,
});
typedef $$StudentsTableUpdateCompanionBuilder = StudentsCompanion Function({
  Value<int> id,
  Value<int> classId,
  Value<String> code,
  Value<String> fullName,
});

final class $$StudentsTableReferences
    extends BaseReferences<_$AppDatabase, $StudentsTable, StudentRow> {
  $$StudentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClassRoomsTable _classIdTable(_$AppDatabase db) =>
      db.classRooms.createAlias('students__class_id__class_rooms__id');

  $$ClassRoomsTableProcessedTableManager get classId {
    final $_column = $_itemColumn<int>('class_id')!;

    final manager = $$ClassRoomsTableTableManager(
      $_db,
      $_db.classRooms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$GradedSheetsTable, List<GradedSheetRow>>
  _gradedSheetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gradedSheets,
    aliasName: 'students__id__graded_sheets__student_id',
  );

  $$GradedSheetsTableProcessedTableManager get gradedSheetsRefs {
    final manager = $$GradedSheetsTableTableManager(
      $_db,
      $_db.gradedSheets,
    ).filter((f) => f.studentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gradedSheetsRefsTable($_db));
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
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnFilters(column),
  );

  $$ClassRoomsTableFilterComposer get classId {
    final $$ClassRoomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.classRooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassRoomsTableFilterComposer(
            $db: $db,
            $table: $db.classRooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> gradedSheetsRefs(
    Expression<bool> Function($$GradedSheetsTableFilterComposer f) f,
  ) {
    final $$GradedSheetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gradedSheets,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GradedSheetsTableFilterComposer(
            $db: $db,
            $table: $db.gradedSheets,
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
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fullName => $composableBuilder(
    column: $table.fullName,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClassRoomsTableOrderingComposer get classId {
    final $$ClassRoomsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.classRooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassRoomsTableOrderingComposer(
            $db: $db,
            $table: $db.classRooms,
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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get fullName =>
      $composableBuilder(column: $table.fullName, builder: (column) => column);

  $$ClassRoomsTableAnnotationComposer get classId {
    final $$ClassRoomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.classRooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassRoomsTableAnnotationComposer(
            $db: $db,
            $table: $db.classRooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> gradedSheetsRefs<T extends Object>(
    Expression<T> Function($$GradedSheetsTableAnnotationComposer a) f,
  ) {
    final $$GradedSheetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gradedSheets,
      getReferencedColumn: (t) => t.studentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GradedSheetsTableAnnotationComposer(
            $db: $db,
            $table: $db.gradedSheets,
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
          StudentRow,
          $$StudentsTableFilterComposer,
          $$StudentsTableOrderingComposer,
          $$StudentsTableAnnotationComposer,
          $$StudentsTableCreateCompanionBuilder,
          $$StudentsTableUpdateCompanionBuilder,
          (StudentRow, $$StudentsTableReferences),
          StudentRow,
          PrefetchHooks Function({bool classId, bool gradedSheetsRefs})
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
                Value<int> id = const Value.absent(),
                Value<int> classId = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> fullName = const Value.absent(),
              }) => StudentsCompanion(
                id: id,
                classId: classId,
                code: code,
                fullName: fullName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int classId,
                required String code,
                required String fullName,
              }) => StudentsCompanion.insert(
                id: id,
                classId: classId,
                code: code,
                fullName: fullName,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudentsTable, StudentRow>(table),
                  $$StudentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({classId = false, gradedSheetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (gradedSheetsRefs) db.gradedSheets],
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
                    if (classId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.classId,
                        referencedTable: $$StudentsTableReferences
                            ._classIdTable(db),
                        referencedColumn: $$StudentsTableReferences
                            ._classIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (gradedSheetsRefs)
                    await $_getPrefetchedData<
                      StudentRow,
                      $StudentsTable,
                      GradedSheetRow
                    >(
                      currentTable: table,
                      referencedTable: $$StudentsTableReferences
                          ._gradedSheetsRefsTable(db),
                      managerFromTypedResult: (p0) => $$StudentsTableReferences(
                        db,
                        table,
                        p0,
                      ).gradedSheetsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.studentId == item.id),
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
      StudentRow,
      $$StudentsTableFilterComposer,
      $$StudentsTableOrderingComposer,
      $$StudentsTableAnnotationComposer,
      $$StudentsTableCreateCompanionBuilder,
      $$StudentsTableUpdateCompanionBuilder,
      (StudentRow, $$StudentsTableReferences),
      StudentRow,
      PrefetchHooks Function({bool classId, bool gradedSheetsRefs})
    >;
typedef $$ContestsTableCreateCompanionBuilder = ContestsCompanion Function({
  Value<int> id,
  required String name,
  required DateTime examDate,
  Value<int?> classId,
  Value<int> questionCount,
  Value<int> answerChoices,
  Value<double> maxScore,
  Value<int> formType,
  Value<int> orientation,
  Value<int?> partOneCount,
  Value<int?> partTwoCount,
  Value<int?> partThreeCount,
  Value<double?> partOneWeight,
  Value<double?> partTwoWeight,
  Value<double?> partThreeWeight,
});
typedef $$ContestsTableUpdateCompanionBuilder = ContestsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> examDate,
  Value<int?> classId,
  Value<int> questionCount,
  Value<int> answerChoices,
  Value<double> maxScore,
  Value<int> formType,
  Value<int> orientation,
  Value<int?> partOneCount,
  Value<int?> partTwoCount,
  Value<int?> partThreeCount,
  Value<double?> partOneWeight,
  Value<double?> partTwoWeight,
  Value<double?> partThreeWeight,
});

final class $$ContestsTableReferences
    extends BaseReferences<_$AppDatabase, $ContestsTable, ContestRow> {
  $$ContestsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ClassRoomsTable _classIdTable(_$AppDatabase db) =>
      db.classRooms.createAlias('contests__class_id__class_rooms__id');

  $$ClassRoomsTableProcessedTableManager? get classId {
    final $_column = $_itemColumn<int>('class_id');
    if ($_column == null) return null;
    final manager = $$ClassRoomsTableTableManager(
      $_db,
      $_db.classRooms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AnswerKeysTable, List<AnswerKeyRow>>
  _answerKeysRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.answerKeys,
    aliasName: 'contests__id__answer_keys__contest_id',
  );

  $$AnswerKeysTableProcessedTableManager get answerKeysRefs {
    final manager = $$AnswerKeysTableTableManager(
      $_db,
      $_db.answerKeys,
    ).filter((f) => f.contestId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_answerKeysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GradedSheetsTable, List<GradedSheetRow>>
  _gradedSheetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gradedSheets,
    aliasName: 'contests__id__graded_sheets__contest_id',
  );

  $$GradedSheetsTableProcessedTableManager get gradedSheetsRefs {
    final manager = $$GradedSheetsTableTableManager(
      $_db,
      $_db.gradedSheets,
    ).filter((f) => f.contestId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gradedSheetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ContestsTableFilterComposer
    extends Composer<_$AppDatabase, $ContestsTable> {
  $$ContestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get examDate => $composableBuilder(
    column: $table.examDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get answerChoices => $composableBuilder(
    column: $table.answerChoices,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxScore => $composableBuilder(
    column: $table.maxScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formType => $composableBuilder(
    column: $table.formType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partOneCount => $composableBuilder(
    column: $table.partOneCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partTwoCount => $composableBuilder(
    column: $table.partTwoCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get partThreeCount => $composableBuilder(
    column: $table.partThreeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get partOneWeight => $composableBuilder(
    column: $table.partOneWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get partTwoWeight => $composableBuilder(
    column: $table.partTwoWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get partThreeWeight => $composableBuilder(
    column: $table.partThreeWeight,
    builder: (column) => ColumnFilters(column),
  );

  $$ClassRoomsTableFilterComposer get classId {
    final $$ClassRoomsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.classRooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassRoomsTableFilterComposer(
            $db: $db,
            $table: $db.classRooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> answerKeysRefs(
    Expression<bool> Function($$AnswerKeysTableFilterComposer f) f,
  ) {
    final $$AnswerKeysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.answerKeys,
      getReferencedColumn: (t) => t.contestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnswerKeysTableFilterComposer(
            $db: $db,
            $table: $db.answerKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> gradedSheetsRefs(
    Expression<bool> Function($$GradedSheetsTableFilterComposer f) f,
  ) {
    final $$GradedSheetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gradedSheets,
      getReferencedColumn: (t) => t.contestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GradedSheetsTableFilterComposer(
            $db: $db,
            $table: $db.gradedSheets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContestsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContestsTable> {
  $$ContestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get examDate => $composableBuilder(
    column: $table.examDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get answerChoices => $composableBuilder(
    column: $table.answerChoices,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxScore => $composableBuilder(
    column: $table.maxScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formType => $composableBuilder(
    column: $table.formType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partOneCount => $composableBuilder(
    column: $table.partOneCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partTwoCount => $composableBuilder(
    column: $table.partTwoCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get partThreeCount => $composableBuilder(
    column: $table.partThreeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get partOneWeight => $composableBuilder(
    column: $table.partOneWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get partTwoWeight => $composableBuilder(
    column: $table.partTwoWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get partThreeWeight => $composableBuilder(
    column: $table.partThreeWeight,
    builder: (column) => ColumnOrderings(column),
  );

  $$ClassRoomsTableOrderingComposer get classId {
    final $$ClassRoomsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.classRooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassRoomsTableOrderingComposer(
            $db: $db,
            $table: $db.classRooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContestsTable> {
  $$ContestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get examDate =>
      $composableBuilder(column: $table.examDate, builder: (column) => column);

  GeneratedColumn<int> get questionCount => $composableBuilder(
    column: $table.questionCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get answerChoices => $composableBuilder(
    column: $table.answerChoices,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxScore =>
      $composableBuilder(column: $table.maxScore, builder: (column) => column);

  GeneratedColumn<int> get formType =>
      $composableBuilder(column: $table.formType, builder: (column) => column);

  GeneratedColumn<int> get orientation => $composableBuilder(
    column: $table.orientation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get partOneCount => $composableBuilder(
    column: $table.partOneCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get partTwoCount => $composableBuilder(
    column: $table.partTwoCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get partThreeCount => $composableBuilder(
    column: $table.partThreeCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get partOneWeight => $composableBuilder(
    column: $table.partOneWeight,
    builder: (column) => column,
  );

  GeneratedColumn<double> get partTwoWeight => $composableBuilder(
    column: $table.partTwoWeight,
    builder: (column) => column,
  );

  GeneratedColumn<double> get partThreeWeight => $composableBuilder(
    column: $table.partThreeWeight,
    builder: (column) => column,
  );

  $$ClassRoomsTableAnnotationComposer get classId {
    final $$ClassRoomsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.classId,
      referencedTable: $db.classRooms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClassRoomsTableAnnotationComposer(
            $db: $db,
            $table: $db.classRooms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> answerKeysRefs<T extends Object>(
    Expression<T> Function($$AnswerKeysTableAnnotationComposer a) f,
  ) {
    final $$AnswerKeysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.answerKeys,
      getReferencedColumn: (t) => t.contestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnswerKeysTableAnnotationComposer(
            $db: $db,
            $table: $db.answerKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> gradedSheetsRefs<T extends Object>(
    Expression<T> Function($$GradedSheetsTableAnnotationComposer a) f,
  ) {
    final $$GradedSheetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gradedSheets,
      getReferencedColumn: (t) => t.contestId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GradedSheetsTableAnnotationComposer(
            $db: $db,
            $table: $db.gradedSheets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContestsTable,
          ContestRow,
          $$ContestsTableFilterComposer,
          $$ContestsTableOrderingComposer,
          $$ContestsTableAnnotationComposer,
          $$ContestsTableCreateCompanionBuilder,
          $$ContestsTableUpdateCompanionBuilder,
          (ContestRow, $$ContestsTableReferences),
          ContestRow,
          PrefetchHooks Function({
            bool classId,
            bool answerKeysRefs,
            bool gradedSheetsRefs,
          })
        > {
  $$ContestsTableTableManager(_$AppDatabase db, $ContestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> examDate = const Value.absent(),
                Value<int?> classId = const Value.absent(),
                Value<int> questionCount = const Value.absent(),
                Value<int> answerChoices = const Value.absent(),
                Value<double> maxScore = const Value.absent(),
                Value<int> formType = const Value.absent(),
                Value<int> orientation = const Value.absent(),
                Value<int?> partOneCount = const Value.absent(),
                Value<int?> partTwoCount = const Value.absent(),
                Value<int?> partThreeCount = const Value.absent(),
                Value<double?> partOneWeight = const Value.absent(),
                Value<double?> partTwoWeight = const Value.absent(),
                Value<double?> partThreeWeight = const Value.absent(),
              }) => ContestsCompanion(
                id: id,
                name: name,
                examDate: examDate,
                classId: classId,
                questionCount: questionCount,
                answerChoices: answerChoices,
                maxScore: maxScore,
                formType: formType,
                orientation: orientation,
                partOneCount: partOneCount,
                partTwoCount: partTwoCount,
                partThreeCount: partThreeCount,
                partOneWeight: partOneWeight,
                partTwoWeight: partTwoWeight,
                partThreeWeight: partThreeWeight,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime examDate,
                Value<int?> classId = const Value.absent(),
                Value<int> questionCount = const Value.absent(),
                Value<int> answerChoices = const Value.absent(),
                Value<double> maxScore = const Value.absent(),
                Value<int> formType = const Value.absent(),
                Value<int> orientation = const Value.absent(),
                Value<int?> partOneCount = const Value.absent(),
                Value<int?> partTwoCount = const Value.absent(),
                Value<int?> partThreeCount = const Value.absent(),
                Value<double?> partOneWeight = const Value.absent(),
                Value<double?> partTwoWeight = const Value.absent(),
                Value<double?> partThreeWeight = const Value.absent(),
              }) => ContestsCompanion.insert(
                id: id,
                name: name,
                examDate: examDate,
                classId: classId,
                questionCount: questionCount,
                answerChoices: answerChoices,
                maxScore: maxScore,
                formType: formType,
                orientation: orientation,
                partOneCount: partOneCount,
                partTwoCount: partTwoCount,
                partThreeCount: partThreeCount,
                partOneWeight: partOneWeight,
                partTwoWeight: partTwoWeight,
                partThreeWeight: partThreeWeight,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContestsTable, ContestRow>(table),
                  $$ContestsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                classId = false,
                answerKeysRefs = false,
                gradedSheetsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (answerKeysRefs) db.answerKeys,
                    if (gradedSheetsRefs) db.gradedSheets,
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
                        if (classId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.classId,
                            referencedTable: $$ContestsTableReferences
                                ._classIdTable(db),
                            referencedColumn: $$ContestsTableReferences
                                ._classIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (answerKeysRefs)
                        await $_getPrefetchedData<
                          ContestRow,
                          $ContestsTable,
                          AnswerKeyRow
                        >(
                          currentTable: table,
                          referencedTable: $$ContestsTableReferences
                              ._answerKeysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ContestsTableReferences(
                                db,
                                table,
                                p0,
                              ).answerKeysRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.contestId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (gradedSheetsRefs)
                        await $_getPrefetchedData<
                          ContestRow,
                          $ContestsTable,
                          GradedSheetRow
                        >(
                          currentTable: table,
                          referencedTable: $$ContestsTableReferences
                              ._gradedSheetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ContestsTableReferences(
                                db,
                                table,
                                p0,
                              ).gradedSheetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.contestId == item.id,
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

typedef $$ContestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContestsTable,
      ContestRow,
      $$ContestsTableFilterComposer,
      $$ContestsTableOrderingComposer,
      $$ContestsTableAnnotationComposer,
      $$ContestsTableCreateCompanionBuilder,
      $$ContestsTableUpdateCompanionBuilder,
      (ContestRow, $$ContestsTableReferences),
      ContestRow,
      PrefetchHooks Function({
        bool classId,
        bool answerKeysRefs,
        bool gradedSheetsRefs,
      })
    >;
typedef $$AnswerKeysTableCreateCompanionBuilder = AnswerKeysCompanion Function({
  Value<int> id,
  required int contestId,
  required String examCode,
  required String answerSequence,
  Value<DateTime> createdAt,
});
typedef $$AnswerKeysTableUpdateCompanionBuilder = AnswerKeysCompanion Function({
  Value<int> id,
  Value<int> contestId,
  Value<String> examCode,
  Value<String> answerSequence,
  Value<DateTime> createdAt,
});

final class $$AnswerKeysTableReferences
    extends BaseReferences<_$AppDatabase, $AnswerKeysTable, AnswerKeyRow> {
  $$AnswerKeysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ContestsTable _contestIdTable(_$AppDatabase db) =>
      db.contests.createAlias('answer_keys__contest_id__contests__id');

  $$ContestsTableProcessedTableManager get contestId {
    final $_column = $_itemColumn<int>('contest_id')!;

    final manager = $$ContestsTableTableManager(
      $_db,
      $_db.contests,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contestIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$GradedSheetsTable, List<GradedSheetRow>>
  _gradedSheetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gradedSheets,
    aliasName: 'answer_keys__id__graded_sheets__key_id',
  );

  $$GradedSheetsTableProcessedTableManager get gradedSheetsRefs {
    final manager = $$GradedSheetsTableTableManager(
      $_db,
      $_db.gradedSheets,
    ).filter((f) => f.keyId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gradedSheetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AnswerKeysTableFilterComposer
    extends Composer<_$AppDatabase, $AnswerKeysTable> {
  $$AnswerKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examCode => $composableBuilder(
    column: $table.examCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerSequence => $composableBuilder(
    column: $table.answerSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ContestsTableFilterComposer get contestId {
    final $$ContestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contestId,
      referencedTable: $db.contests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContestsTableFilterComposer(
            $db: $db,
            $table: $db.contests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> gradedSheetsRefs(
    Expression<bool> Function($$GradedSheetsTableFilterComposer f) f,
  ) {
    final $$GradedSheetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gradedSheets,
      getReferencedColumn: (t) => t.keyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GradedSheetsTableFilterComposer(
            $db: $db,
            $table: $db.gradedSheets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AnswerKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $AnswerKeysTable> {
  $$AnswerKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examCode => $composableBuilder(
    column: $table.examCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerSequence => $composableBuilder(
    column: $table.answerSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContestsTableOrderingComposer get contestId {
    final $$ContestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contestId,
      referencedTable: $db.contests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContestsTableOrderingComposer(
            $db: $db,
            $table: $db.contests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnswerKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnswerKeysTable> {
  $$AnswerKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => column);

  GeneratedColumn<String> get answerSequence => $composableBuilder(
    column: $table.answerSequence,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$ContestsTableAnnotationComposer get contestId {
    final $$ContestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contestId,
      referencedTable: $db.contests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContestsTableAnnotationComposer(
            $db: $db,
            $table: $db.contests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> gradedSheetsRefs<T extends Object>(
    Expression<T> Function($$GradedSheetsTableAnnotationComposer a) f,
  ) {
    final $$GradedSheetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gradedSheets,
      getReferencedColumn: (t) => t.keyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GradedSheetsTableAnnotationComposer(
            $db: $db,
            $table: $db.gradedSheets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AnswerKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnswerKeysTable,
          AnswerKeyRow,
          $$AnswerKeysTableFilterComposer,
          $$AnswerKeysTableOrderingComposer,
          $$AnswerKeysTableAnnotationComposer,
          $$AnswerKeysTableCreateCompanionBuilder,
          $$AnswerKeysTableUpdateCompanionBuilder,
          (AnswerKeyRow, $$AnswerKeysTableReferences),
          AnswerKeyRow,
          PrefetchHooks Function({bool contestId, bool gradedSheetsRefs})
        > {
  $$AnswerKeysTableTableManager(_$AppDatabase db, $AnswerKeysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnswerKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnswerKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnswerKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> contestId = const Value.absent(),
                Value<String> examCode = const Value.absent(),
                Value<String> answerSequence = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AnswerKeysCompanion(
                id: id,
                contestId: contestId,
                examCode: examCode,
                answerSequence: answerSequence,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int contestId,
                required String examCode,
                required String answerSequence,
                Value<DateTime> createdAt = const Value.absent(),
              }) => AnswerKeysCompanion.insert(
                id: id,
                contestId: contestId,
                examCode: examCode,
                answerSequence: answerSequence,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnswerKeysTable, AnswerKeyRow>(table),
                  $$AnswerKeysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({contestId = false, gradedSheetsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (gradedSheetsRefs) db.gradedSheets,
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
                        if (contestId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.contestId,
                            referencedTable: $$AnswerKeysTableReferences
                                ._contestIdTable(db),
                            referencedColumn: $$AnswerKeysTableReferences
                                ._contestIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (gradedSheetsRefs)
                        await $_getPrefetchedData<
                          AnswerKeyRow,
                          $AnswerKeysTable,
                          GradedSheetRow
                        >(
                          currentTable: table,
                          referencedTable: $$AnswerKeysTableReferences
                              ._gradedSheetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AnswerKeysTableReferences(
                                db,
                                table,
                                p0,
                              ).gradedSheetsRefs,
                          referencedItemsForCurrentItem: (
                            item,
                            referencedItems,
                          ) => referencedItems.where((e) => e.keyId == item.id),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AnswerKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnswerKeysTable,
      AnswerKeyRow,
      $$AnswerKeysTableFilterComposer,
      $$AnswerKeysTableOrderingComposer,
      $$AnswerKeysTableAnnotationComposer,
      $$AnswerKeysTableCreateCompanionBuilder,
      $$AnswerKeysTableUpdateCompanionBuilder,
      (AnswerKeyRow, $$AnswerKeysTableReferences),
      AnswerKeyRow,
      PrefetchHooks Function({bool contestId, bool gradedSheetsRefs})
    >;
typedef $$GradedSheetsTableCreateCompanionBuilder =
    GradedSheetsCompanion Function({
      Value<int> id,
      required int contestId,
      Value<int?> keyId,
      Value<int?> studentId,
      required String examCode,
      Value<String> studentCode,
      required String chosen,
      required String correctFlags,
      required double score,
      Value<double?> partOneScore,
      Value<double?> partTwoScore,
      Value<double?> partThreeScore,
      Value<String?> originalImagePath,
      Value<String?> markedImagePath,
      Value<String?> infoImagePath,
      Value<DateTime> gradedAt,
    });
typedef $$GradedSheetsTableUpdateCompanionBuilder =
    GradedSheetsCompanion Function({
      Value<int> id,
      Value<int> contestId,
      Value<int?> keyId,
      Value<int?> studentId,
      Value<String> examCode,
      Value<String> studentCode,
      Value<String> chosen,
      Value<String> correctFlags,
      Value<double> score,
      Value<double?> partOneScore,
      Value<double?> partTwoScore,
      Value<double?> partThreeScore,
      Value<String?> originalImagePath,
      Value<String?> markedImagePath,
      Value<String?> infoImagePath,
      Value<DateTime> gradedAt,
    });

final class $$GradedSheetsTableReferences
    extends BaseReferences<_$AppDatabase, $GradedSheetsTable, GradedSheetRow> {
  $$GradedSheetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ContestsTable _contestIdTable(_$AppDatabase db) =>
      db.contests.createAlias('graded_sheets__contest_id__contests__id');

  $$ContestsTableProcessedTableManager get contestId {
    final $_column = $_itemColumn<int>('contest_id')!;

    final manager = $$ContestsTableTableManager(
      $_db,
      $_db.contests,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contestIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AnswerKeysTable _keyIdTable(_$AppDatabase db) =>
      db.answerKeys.createAlias('graded_sheets__key_id__answer_keys__id');

  $$AnswerKeysTableProcessedTableManager? get keyId {
    final $_column = $_itemColumn<int>('key_id');
    if ($_column == null) return null;
    final manager = $$AnswerKeysTableTableManager(
      $_db,
      $_db.answerKeys,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_keyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StudentsTable _studentIdTable(_$AppDatabase db) =>
      db.students.createAlias('graded_sheets__student_id__students__id');

  $$StudentsTableProcessedTableManager? get studentId {
    final $_column = $_itemColumn<int>('student_id');
    if ($_column == null) return null;
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
}

class $$GradedSheetsTableFilterComposer
    extends Composer<_$AppDatabase, $GradedSheetsTable> {
  $$GradedSheetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get examCode => $composableBuilder(
    column: $table.examCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get studentCode => $composableBuilder(
    column: $table.studentCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chosen => $composableBuilder(
    column: $table.chosen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correctFlags => $composableBuilder(
    column: $table.correctFlags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get partOneScore => $composableBuilder(
    column: $table.partOneScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get partTwoScore => $composableBuilder(
    column: $table.partTwoScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get partThreeScore => $composableBuilder(
    column: $table.partThreeScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalImagePath => $composableBuilder(
    column: $table.originalImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get markedImagePath => $composableBuilder(
    column: $table.markedImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get infoImagePath => $composableBuilder(
    column: $table.infoImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get gradedAt => $composableBuilder(
    column: $table.gradedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ContestsTableFilterComposer get contestId {
    final $$ContestsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contestId,
      referencedTable: $db.contests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContestsTableFilterComposer(
            $db: $db,
            $table: $db.contests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AnswerKeysTableFilterComposer get keyId {
    final $$AnswerKeysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.keyId,
      referencedTable: $db.answerKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnswerKeysTableFilterComposer(
            $db: $db,
            $table: $db.answerKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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
}

class $$GradedSheetsTableOrderingComposer
    extends Composer<_$AppDatabase, $GradedSheetsTable> {
  $$GradedSheetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get examCode => $composableBuilder(
    column: $table.examCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get studentCode => $composableBuilder(
    column: $table.studentCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chosen => $composableBuilder(
    column: $table.chosen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correctFlags => $composableBuilder(
    column: $table.correctFlags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get partOneScore => $composableBuilder(
    column: $table.partOneScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get partTwoScore => $composableBuilder(
    column: $table.partTwoScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get partThreeScore => $composableBuilder(
    column: $table.partThreeScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalImagePath => $composableBuilder(
    column: $table.originalImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get markedImagePath => $composableBuilder(
    column: $table.markedImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get infoImagePath => $composableBuilder(
    column: $table.infoImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get gradedAt => $composableBuilder(
    column: $table.gradedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContestsTableOrderingComposer get contestId {
    final $$ContestsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contestId,
      referencedTable: $db.contests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContestsTableOrderingComposer(
            $db: $db,
            $table: $db.contests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AnswerKeysTableOrderingComposer get keyId {
    final $$AnswerKeysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.keyId,
      referencedTable: $db.answerKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnswerKeysTableOrderingComposer(
            $db: $db,
            $table: $db.answerKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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

class $$GradedSheetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GradedSheetsTable> {
  $$GradedSheetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get examCode =>
      $composableBuilder(column: $table.examCode, builder: (column) => column);

  GeneratedColumn<String> get studentCode => $composableBuilder(
    column: $table.studentCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chosen =>
      $composableBuilder(column: $table.chosen, builder: (column) => column);

  GeneratedColumn<String> get correctFlags => $composableBuilder(
    column: $table.correctFlags,
    builder: (column) => column,
  );

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<double> get partOneScore => $composableBuilder(
    column: $table.partOneScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get partTwoScore => $composableBuilder(
    column: $table.partTwoScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get partThreeScore => $composableBuilder(
    column: $table.partThreeScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalImagePath => $composableBuilder(
    column: $table.originalImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get markedImagePath => $composableBuilder(
    column: $table.markedImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get infoImagePath => $composableBuilder(
    column: $table.infoImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get gradedAt =>
      $composableBuilder(column: $table.gradedAt, builder: (column) => column);

  $$ContestsTableAnnotationComposer get contestId {
    final $$ContestsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contestId,
      referencedTable: $db.contests,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContestsTableAnnotationComposer(
            $db: $db,
            $table: $db.contests,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AnswerKeysTableAnnotationComposer get keyId {
    final $$AnswerKeysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.keyId,
      referencedTable: $db.answerKeys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnswerKeysTableAnnotationComposer(
            $db: $db,
            $table: $db.answerKeys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

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
}

class $$GradedSheetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GradedSheetsTable,
          GradedSheetRow,
          $$GradedSheetsTableFilterComposer,
          $$GradedSheetsTableOrderingComposer,
          $$GradedSheetsTableAnnotationComposer,
          $$GradedSheetsTableCreateCompanionBuilder,
          $$GradedSheetsTableUpdateCompanionBuilder,
          (GradedSheetRow, $$GradedSheetsTableReferences),
          GradedSheetRow,
          PrefetchHooks Function({bool contestId, bool keyId, bool studentId})
        > {
  $$GradedSheetsTableTableManager(_$AppDatabase db, $GradedSheetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GradedSheetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GradedSheetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GradedSheetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> contestId = const Value.absent(),
                Value<int?> keyId = const Value.absent(),
                Value<int?> studentId = const Value.absent(),
                Value<String> examCode = const Value.absent(),
                Value<String> studentCode = const Value.absent(),
                Value<String> chosen = const Value.absent(),
                Value<String> correctFlags = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<double?> partOneScore = const Value.absent(),
                Value<double?> partTwoScore = const Value.absent(),
                Value<double?> partThreeScore = const Value.absent(),
                Value<String?> originalImagePath = const Value.absent(),
                Value<String?> markedImagePath = const Value.absent(),
                Value<String?> infoImagePath = const Value.absent(),
                Value<DateTime> gradedAt = const Value.absent(),
              }) => GradedSheetsCompanion(
                id: id,
                contestId: contestId,
                keyId: keyId,
                studentId: studentId,
                examCode: examCode,
                studentCode: studentCode,
                chosen: chosen,
                correctFlags: correctFlags,
                score: score,
                partOneScore: partOneScore,
                partTwoScore: partTwoScore,
                partThreeScore: partThreeScore,
                originalImagePath: originalImagePath,
                markedImagePath: markedImagePath,
                infoImagePath: infoImagePath,
                gradedAt: gradedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int contestId,
                Value<int?> keyId = const Value.absent(),
                Value<int?> studentId = const Value.absent(),
                required String examCode,
                Value<String> studentCode = const Value.absent(),
                required String chosen,
                required String correctFlags,
                required double score,
                Value<double?> partOneScore = const Value.absent(),
                Value<double?> partTwoScore = const Value.absent(),
                Value<double?> partThreeScore = const Value.absent(),
                Value<String?> originalImagePath = const Value.absent(),
                Value<String?> markedImagePath = const Value.absent(),
                Value<String?> infoImagePath = const Value.absent(),
                Value<DateTime> gradedAt = const Value.absent(),
              }) => GradedSheetsCompanion.insert(
                id: id,
                contestId: contestId,
                keyId: keyId,
                studentId: studentId,
                examCode: examCode,
                studentCode: studentCode,
                chosen: chosen,
                correctFlags: correctFlags,
                score: score,
                partOneScore: partOneScore,
                partTwoScore: partTwoScore,
                partThreeScore: partThreeScore,
                originalImagePath: originalImagePath,
                markedImagePath: markedImagePath,
                infoImagePath: infoImagePath,
                gradedAt: gradedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GradedSheetsTable, GradedSheetRow>(table),
                  $$GradedSheetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({contestId = false, keyId = false, studentId = false}) {
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
                        if (contestId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.contestId,
                            referencedTable: $$GradedSheetsTableReferences
                                ._contestIdTable(db),
                            referencedColumn: $$GradedSheetsTableReferences
                                ._contestIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (keyId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.keyId,
                            referencedTable: $$GradedSheetsTableReferences
                                ._keyIdTable(db),
                            referencedColumn: $$GradedSheetsTableReferences
                                ._keyIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (studentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.studentId,
                            referencedTable: $$GradedSheetsTableReferences
                                ._studentIdTable(db),
                            referencedColumn: $$GradedSheetsTableReferences
                                ._studentIdTable(db)
                                .id,
                          ) as T;
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

typedef $$GradedSheetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GradedSheetsTable,
      GradedSheetRow,
      $$GradedSheetsTableFilterComposer,
      $$GradedSheetsTableOrderingComposer,
      $$GradedSheetsTableAnnotationComposer,
      $$GradedSheetsTableCreateCompanionBuilder,
      $$GradedSheetsTableUpdateCompanionBuilder,
      (GradedSheetRow, $$GradedSheetsTableReferences),
      GradedSheetRow,
      PrefetchHooks Function({bool contestId, bool keyId, bool studentId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      required String key,
      required String value,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<String> key,
      Value<String> value,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          SettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
          }) => AppSettingsCompanion(id: id, key: key, value: value),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String key,
            required String value,
          }) => AppSettingsCompanion.insert(id: id, key: key, value: value),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      SettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ClassRoomsTableTableManager get classRooms =>
      $$ClassRoomsTableTableManager(_db, _db.classRooms);
  $$StudentsTableTableManager get students =>
      $$StudentsTableTableManager(_db, _db.students);
  $$ContestsTableTableManager get contests =>
      $$ContestsTableTableManager(_db, _db.contests);
  $$AnswerKeysTableTableManager get answerKeys =>
      $$AnswerKeysTableTableManager(_db, _db.answerKeys);
  $$GradedSheetsTableTableManager get gradedSheets =>
      $$GradedSheetsTableTableManager(_db, _db.gradedSheets);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
