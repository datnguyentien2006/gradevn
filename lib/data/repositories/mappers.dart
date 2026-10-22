import 'package:drift/drift.dart' show Value;

import '../db/app_database.dart';
import '../../domain/entities/class_room.dart' as entities;
import '../../domain/entities/contest.dart' as entities;
import '../../domain/entities/graded_sheet.dart' as entities;
import '../../domain/entities/sheet_spec.dart';

/// Mapper hàng DB ↔ entity thuần Dart.
/// (ClassRoomRow/…Companion sinh ra trong thư viện app_database.dart —
/// import trực tiếp thư viện đó để dùng được cả part nói trên.)

extension ClassRoomRowX on ClassRoomRow {
  entities.ClassRoom toEntity() =>
      entities.ClassRoom(id: id, name: name, description: description);
}

extension ClassRoomX on entities.ClassRoom {
  ClassRoomsCompanion toCompanion({bool includeId = false}) => ClassRoomsCompanion(
        name: Value(name),
        description: description == null ? const Value.absent() : Value(description!),
        id: includeId ? Value(id) : const Value.absent(),
      );
}

extension StudentRowX on StudentRow {
  entities.Student toEntity() =>
      entities.Student(id: id, classId: classId, code: code, fullName: fullName);
}

extension StudentX on entities.Student {
  StudentsCompanion toCompanion({bool includeId = false}) => StudentsCompanion.insert(
        classId: classId,
        code: code,
        fullName: fullName,
        id: includeId ? Value(id) : const Value.absent(),
      );
}

extension ContestRowX on ContestRow {
  entities.Contest toEntity() => entities.Contest(
        id: id,
        name: name,
        examDate: examDate,
        classRoomId: classId,
        questionCount: questionCount,
        answerChoices: answerChoices,
        maxScore: maxScore,
        formType: SheetFormType.values[formType.clamp(0, SheetFormType.values.length - 1)],
        orientation:
            SheetOrientation.values[orientation.clamp(0, SheetOrientation.values.length - 1)],
        partOneCount: partOneCount,
        partTwoCount: partTwoCount,
        partThreeCount: partThreeCount,
        partOneWeight: partOneWeight,
        partTwoWeight: partTwoWeight,
        partThreeWeight: partThreeWeight,
      );
}

extension ContestX on entities.Contest {
  ContestsCompanion toCompanion({bool includeId = false}) => ContestsCompanion(
        name: Value(name),
        examDate: Value(examDate),
        classId: classRoomId == null ? const Value.absent() : Value(classRoomId),
        questionCount: Value(questionCount),
        answerChoices: Value(answerChoices),
        maxScore: Value(maxScore),
        formType: Value(formType.index),
        orientation: Value(orientation.index),
        partOneCount: partOneCount == null ? const Value.absent() : Value(partOneCount),
        partTwoCount: partTwoCount == null ? const Value.absent() : Value(partTwoCount),
        partThreeCount: partThreeCount == null ? const Value.absent() : Value(partThreeCount),
        partOneWeight: partOneWeight == null ? const Value.absent() : Value(partOneWeight),
        partTwoWeight: partTwoWeight == null ? const Value.absent() : Value(partTwoWeight),
        partThreeWeight: partThreeWeight == null ? const Value.absent() : Value(partThreeWeight),
        id: includeId ? Value(id) : const Value.absent(),
      );
}

extension AnswerKeyRowX on AnswerKeyRow {
  entities.AnswerKey toEntity() => entities.AnswerKey(
        id: id,
        contestId: contestId,
        examCode: examCode,
        answerSequence: answerSequence,
        createdAt: createdAt,
      );
}

extension AnswerKeyX on entities.AnswerKey {
  AnswerKeysCompanion toCompanion({bool includeId = false}) => AnswerKeysCompanion(
        contestId: Value(contestId),
        examCode: Value(examCode),
        answerSequence: Value(answerSequence),
        createdAt: createdAt == null ? const Value.absent() : Value(createdAt!),
        id: includeId ? Value(id) : const Value.absent(),
      );
}

const _emptyMark = '-';

extension GradedSheetRowX on GradedSheetRow {
  entities.GradedSheet toEntity() {
    final chosenList = <String?>[];
    for (final c in chosen.split('')) {
      chosenList.add(c == _emptyMark ? null : c);
    }
    final flags = <bool?>[];
    for (final c in correctFlags.split('')) {
      flags.add(c == '1' ? true : c == '0' ? false : null);
    }
    return entities.GradedSheet(
      id: id,
      contestId: contestId,
      keyId: keyId,
      studentId: studentId,
      examCode: examCode,
      studentCode: studentCode,
      chosen: List<String?>.unmodifiable(chosenList),
      correctFlags: List<bool?>.unmodifiable(flags),
      score: score,
      partScores: <String, double>{
        '1': partOneScore ?? 0,
        '2': partTwoScore ?? 0,
        '3': partThreeScore ?? 0,
      },
      originalImagePath: originalImagePath,
      markedImagePath: markedImagePath,
      infoImagePath: infoImagePath,
      gradedAt: gradedAt,
    );
  }
}

extension GradedSheetX on entities.GradedSheet {
  GradedSheetsCompanion toCompanion() => GradedSheetsCompanion(
        contestId: Value(contestId),
        keyId: keyId == null ? const Value.absent() : Value(keyId),
        studentId: studentId == null ? const Value.absent() : Value(studentId),
        examCode: Value(examCode),
        studentCode: Value(studentCode),
        chosen: Value(chosen.map((c) => c ?? _emptyMark).join()),
        correctFlags: Value(correctFlags
            .map((f) {
              if (f == true) return '1';
              if (f == false) return '0';
              return '?';
            })
            .join()),
        score: Value(score),
        partOneScore: partScores['1'] == null ? const Value.absent() : Value(partScores['1']),
        partTwoScore: partScores['2'] == null ? const Value.absent() : Value(partScores['2']),
        partThreeScore: partScores['3'] == null ? const Value.absent() : Value(partScores['3']),
        originalImagePath:
            originalImagePath == null ? const Value.absent() : Value(originalImagePath!),
        markedImagePath: markedImagePath == null ? const Value.absent() : Value(markedImagePath!),
        infoImagePath: infoImagePath == null ? const Value.absent() : Value(infoImagePath!),
        gradedAt: gradedAt == null ? const Value.absent() : Value(gradedAt!),
      );
}
