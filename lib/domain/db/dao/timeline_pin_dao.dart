import 'package:cobble/domain/db/cobble_database.dart';
import 'package:cobble/domain/db/models/next_sync_action.dart';
import 'package:cobble/domain/db/models/timeline_pin.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:uuid_type/uuid_type.dart';

class TimelinePinDao {
  Future<Database> _dbFuture;

  TimelinePinDao(this._dbFuture);

  Future<void> insertOrUpdateTimelinePin(TimelinePin pin) async {
    final db = await _dbFuture;

    db.insert(tableTimelinePins, pin.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<TimelinePin?> getPinById(Uuid id) async {
    final db = await _dbFuture;

    final receivedPins = (await db.query(
      tableTimelinePins,
      where: "itemId = ?",
      whereArgs: [id.toString()],
    ));

    if (receivedPins.isEmpty) {
      return null;
    }

    return TimelinePin.fromMap(receivedPins.first);
  }

  Future<List<TimelinePin>> getAllPins() async {
    final db = await _dbFuture;

    return (await db.query(tableTimelinePins))
        .map((e) => TimelinePin.fromMap(e))
        .toList();
  }

  Future<List<TimelinePin>> getPinsFromParent(Uuid parentId) async {
    final db = await _dbFuture;

    return (await db.query(
      tableTimelinePins,
      where: "parentId = ?",
      whereArgs: [parentId.toString()],
    ))
        .map((e) => TimelinePin.fromMap(e))
        .toList();
  }

  Future<List<TimelinePin>> getAllPinsWithPendingUpload() async {
    final db = await _dbFuture;

    return (await db.query(tableTimelinePins,
            where: "nextSyncAction = \"Upload\"", orderBy: "timestamp ASC"))
        .map((e) => TimelinePin.fromMap(e))
        .toList();
  }

  Future<List<TimelinePin>> getAllPinsWithPendingDelete() async {
    final db = await _dbFuture;

    return (await db.query(tableTimelinePins,
            where:
                "nextSyncAction = \"Delete\" OR nextSyncAction = \"DeleteThenIgnore\""))
        .map((e) => TimelinePin.fromMap(e))
        .toList();
  }

  Future<void> setSyncAction(
      Uuid? itemId, NextSyncAction newNextSyncAction) async {
    final db = await _dbFuture;

    await db.update(
        tableTimelinePins,
        {
          "nextSyncAction":
              TimelinePin.nextSyncActionEnumMap()[newNextSyncAction]
        },
        where: "itemId = ?",
        whereArgs: [itemId.toString()]);
  }

  Future<void> delete(Uuid? itemId) async {
    final db = await _dbFuture;

    await db.delete(tableTimelinePins,
        where: "itemId = ?", whereArgs: [itemId.toString()]);
  }

  Future<void> deleteAll() async {
    final db = await _dbFuture;
    await db.delete(tableTimelinePins);
  }

  Future<void> resetSyncStatus() async {
    final db = await _dbFuture;

    // Watch has been reset. We can delete all pins that were pending
    // deletion
    await db.delete(tableTimelinePins, where: "nextSyncAction = ?", whereArgs: [
      TimelinePin.nextSyncActionEnumMap()[NextSyncAction.Delete]
    ]);

    // Mark all pins to re-upload
    await db.update(
        tableTimelinePins,
        {
          "nextSyncAction":
              TimelinePin.nextSyncActionEnumMap()[NextSyncAction.Upload]
        },
        where: "nextSyncAction = ?",
        whereArgs: [
          TimelinePin.nextSyncActionEnumMap()[NextSyncAction.Nothing]
        ]);
  }

  Future<void> markAllPinsFromAppForDeletion(Uuid appUuid) async {
    final db = await _dbFuture;

    await db.update(
        tableTimelinePins,
        {
          "nextSyncAction":
              TimelinePin.nextSyncActionEnumMap()[NextSyncAction.Delete]
        },
        where: "parentId = ?",
        whereArgs: [appUuid.toString()]);
  }
}

final AutoDisposeProvider<TimelinePinDao> timelinePinDaoProvider =
    Provider.autoDispose<TimelinePinDao>((ref) {
  final dbFuture = ref.watch(databaseProvider.future);
  return TimelinePinDao(dbFuture);
});

const tableTimelinePins = "timeline_pin";
