import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

import 'package:flutter/foundation.dart';

DatabaseConnection connect(String name) {
  return DatabaseConnection.delayed(
    Future(() async {
      final probed = await WasmDatabase.probe(
        sqlite3Uri: Uri.parse('sqlite3.wasm'),
        driftWorkerUri: Uri.parse('drift_worker.js'),
        databaseName: name,
      );

      final available = probed.availableStorages.toList();
      debugPrint('[DriftWeb] Available storages: $available');

      // We avoid opfsLocks because NavigatorLocksExecutor deadlocks on schema
      // migrations during ensureOpen / onCreate.
      // Prefer: opfsShared, then sharedIndexedDb, then unsafeIndexedDb, then inMemory.
      WasmStorageImplementation selected;
      if (available.contains(WasmStorageImplementation.opfsShared)) {
        selected = WasmStorageImplementation.opfsShared;
      } else if (available.contains(WasmStorageImplementation.sharedIndexedDb)) {
        selected = WasmStorageImplementation.sharedIndexedDb;
      } else if (available.contains(WasmStorageImplementation.unsafeIndexedDb)) {
        selected = WasmStorageImplementation.unsafeIndexedDb;
      } else {
        selected = WasmStorageImplementation.inMemory;
      }

      debugPrint('[DriftWeb] Selected storage: $selected');

      final connection = await probed.open(
        selected,
        name,
      );

      return connection;
    }),
  );
}
