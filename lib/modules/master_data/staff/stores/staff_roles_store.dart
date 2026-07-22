import 'package:flutter/foundation.dart';
import '../../../../../core/services/local/database_service.dart';

class StaffRoleAggregate {
  final String roleId;
  final String roleName;
  final int userCount;
  final bool isDefault;

  StaffRoleAggregate({
    required this.roleId,
    required this.roleName,
    required this.userCount,
    required this.isDefault,
  });
}

class StaffRolesStore {
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<List<StaffRoleAggregate>> roles = ValueNotifier<List<StaffRoleAggregate>>([]);
  final ValueNotifier<String?> errorMessage = ValueNotifier<String?>(null);

  Future<void> fetchRoles() async {
    if (isLoading.value) return;
    
    isLoading.value = true;
    errorMessage.value = null;
    
    try {
      final db = DatabaseService.instance;
      final rows = await db.rawQuery('''
        SELECT 
          r.role_id, 
          r.name as role_name, 
          COUNT(s.id) as user_count
        FROM pos_role r
        LEFT JOIN staff s 
          ON LOWER(s.role_name) = LOWER(r.name) 
          AND s.deleted_at IS NULL
          AND s.is_active = 1
        WHERE r.deleted_at IS NULL
        GROUP BY r.role_id, r.name
        ORDER BY r.name ASC
      ''');

      final List<StaffRoleAggregate> loadedRoles = [];
      for (final row in rows) {
        final rName = row['role_name']?.toString() ?? '';
        final rId = row['role_id']?.toString() ?? '';
        final int uCount = int.tryParse(row['user_count']?.toString() ?? '0') ?? 0;
        
        loadedRoles.add(StaffRoleAggregate(
          roleId: rId,
          roleName: rName,
          userCount: uCount,
          isDefault: rName.toLowerCase() == 'kasir',
        ));
      }
      
      roles.value = loadedRoles;
    } catch (e) {
      errorMessage.value = 'Gagal memuat peran staf: $e';
    } finally {
      isLoading.value = false;
    }
  }

  void dispose() {
    isLoading.dispose();
    roles.dispose();
    errorMessage.dispose();
  }
}
