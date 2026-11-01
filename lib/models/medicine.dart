import 'package:hive/hive.dart';
part 'medicine.g.dart';

/// Legacy schema retained only to migrate existing Hive records.
@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String? note;

  @HiveField(3)
  List<int> intakeDays;

  @HiveField(4)
  List<String> intakeTimes;

  @HiveField(5)
  RepeatCycle repeatCycle;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  int? remainingCount;

  @HiveField(8)
  bool? isActive;

  @HiveField(9)
  bool? isUnlimited;

  @HiveField(10)
  int? totalCount;

  Medicine({
    required this.id,
    required this.name,
    this.note,
    required this.intakeDays,
    required this.intakeTimes,
    required this.repeatCycle,
    required this.createdAt,
    this.remainingCount,
    this.isActive = true,
    this.isUnlimited = false,
    this.totalCount,
  });
}

@HiveType(typeId: 1)
enum RepeatCycle {
  @HiveField(0)
  daily,

  @HiveField(1)
  weekly,

  @HiveField(2)
  monthly,
}
