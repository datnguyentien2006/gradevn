/// Trường học / lớp học — repository pattern: entity thuần Dart, không phụ thuộc UI/DB.
class ClassRoom {
  const ClassRoom({
    required this.id,
    required this.name,
    this.description,
  });

  final int id;
  final String name;
  final String? description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClassRoom && other.id == id && other.name == name && other.description == description);

  @override
  int get hashCode => Object.hash(id, name, description);

  @override
  String toString() => 'ClassRoom#$id($name)';
}

/// Học sinh thuộc một lớp; `code` là mã số tương ứng ô "số báo danh" trên phiếu.
class Student {
  const Student({
    required this.id,
    required this.classId,
    required this.code,
    required this.fullName,
  });

  final int id;
  final int classId;
  final String code;
  final String fullName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Student &&
          other.id == id &&
          other.classId == classId &&
          other.code == code &&
          other.fullName == fullName);

  @override
  int get hashCode => Object.hash(id, classId, code, fullName);

  @override
  String toString() => 'Student#$id($code $fullName)';
}
