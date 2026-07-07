// import 'dart:io';
// import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// void main() async {
//   sqfliteFfiInit();
//   final dbFactory = databaseFactoryFfi;
//   final dbPath = 'C:\\Users\\user\\AppData\\Local\\com.flinkaja.pos\\pos_v2.db'; // Adjust if needed
  
//   if (!File(dbPath).existsSync()) {
//     print('DB not found at \$dbPath');
//     return;
//   }
//   final db = await dbFactory.openDatabase(dbPath);
  
//   final res = await db.rawQuery('SELECT payment_method, payment_mode_name_snapshot, payment_date, amount FROM pos_order_payment LIMIT 20');
//   for (final row in res) {
//     print(row);
//   }
// }
