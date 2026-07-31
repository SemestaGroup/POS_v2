# Panduan Implementasi UI Mobile

Dokumen ini adalah acuan kerja untuk developer yang mengembangkan tampilan
mobile di POS_v2. Tujuannya: UI mobile dapat berkembang mandiri tanpa
menyalin state, store, query, atau business logic dari tablet.

## Prinsip inti

- Mobile berarti `context.isMobile`, yaitu `MediaQuery.sizeOf(context)` dengan
  `shortestSide < 600`. Jangan membuat breakpoint lokal baru.
- `mobile_portrait/` hanya berisi presentasi UI mobile dan interaksi visual.
- State bersama, controller, sync, filter, serta callback aksi berada di
  router/coordinator atau shared content di root komponen.
- File di `tablet_landscape/` tidak boleh mengimpor mobile view maupun memilih
  device dengan `isMobile`, `isTablet`, atau `MediaQuery` untuk breakpoint.
- Semua fitur tablet yang penting tetap harus tersedia di mobile; ubah bentuk
  interaksinya, jangan hilangkan fungsinya.

## Struktur folder

Gunakan struktur berikut untuk screen baru:

```text
feature/
├── feature_view.dart              # router atau coordinator publik
├── feature_content.dart           # optional: state/UI shared
├── mobile_portrait/
│   └── view.dart                  # UI mobile murni
└── tablet_landscape/
    └── view.dart                  # UI tablet murni
```

`feature_view.dart` mempertahankan nama dan parameter publik view lama. Caller
selalu mengimpor file ini, bukan langsung file tablet atau mobile.

## Pilih pola yang tepat

### A. Thin router

Gunakan bila masing-masing device view sudah menerima seluruh state/callback
yang dibutuhkan.

```dart
class FeatureView extends StatelessWidget {
  const FeatureView({super.key, required this.onSaved});

  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) => context.isMobile
      ? FeatureMobileView(onSaved: onSaved)
      : FeatureTabletLandscapeView(onSaved: onSaved);
}
```

Contoh: `PosWorkspaceView`. Pastikan setiap parameter kontrak diteruskan ke
device view yang memerlukannya.

### B. Stateful coordinator + presentation model

Gunakan bila mobile dan tablet membutuhkan controller, filter, sinkronisasi,
atau data yang sama. Coordinator menjadi pemilik tunggal state; device view
berupa `StatelessWidget` dan menerima model data/callback.

Contoh nyata: Sales Orders (`active_orders`, `parked_orders`, dan
`history_lite`). Jangan menyimpan `TextEditingController` atau listener store
lagi di kedua device view.

### C. Shared content + device entry point

Gunakan bila layout saat ini memang sama di kedua perangkat, tetapi struktur
folder perlu dipisahkan agar adaptasi berikutnya tidak menyentuh state.

```text
products/
├── products_view.dart
├── products_content.dart          # store, filter, refresh; satu kali saja
├── mobile_portrait/view.dart      # return ProductsContent() saat ini
└── tablet_landscape/view.dart     # return ProductsContent() saat ini
```

Contoh saat ini: Products, Promos, Customer List, Staff List, dan Staff
Roles. Saat membuat layout mobile khusus nantinya, edit hanya
`mobile_portrait/view.dart` dan terus gunakan callback/state dari content atau
presentation yang sama.

## Pola Master Data

`MasterDataScreenCoordinator<T>` di
`lib/modules/master_data/shared/widgets/master_data_screen_coordinator.dart`
menyediakan:

- lifecycle `TextEditingController`;
- refresh awal;
- listener `MasterDataListSnapshot<T>`;
- `onSearchChanged`, `onRefresh`, dan `rebuild`;
- pemilihan mobile/tablet dari satu tempat.

Brands dan Categories memakai coordinator ini. Jika membuat list Master Data
baru, prioritaskan pola tersebut daripada mengulang `initState`, `dispose`,
dan `ValueListenableBuilder` di dua device view.

## Tanggung jawab developer mobile

Saat mengadaptasi screen untuk mobile, fokus pada presentasi berikut:

- Ubah row/table lebar menjadi kartu atau list vertikal yang mudah dipindai.
- Pindahkan filter yang padat ke `Wrap`, bottom sheet, atau filter ringkas.
- Jaga area sentuh minimal nyaman; jangan mengandalkan hover atau sidebar.
- Prioritaskan informasi inti pada kartu; detail sekunder dapat ditampilkan
  melalui sheet/detail page.
- Teruskan semua action penting—refresh, filter, edit, detail, dan navigasi—
  melalui callback coordinator/presentation yang sudah ada.

Jangan:

- mengakses store atau service langsung dari `mobile_portrait/view.dart` jika
  coordinator/presentation sudah menyediakannya;
- membuat breakpoint baru dengan `MediaQuery`;
- mengimpor file `tablet_landscape` dari mobile, atau sebaliknya;
- menyalin handler business logic hanya demi menyesuaikan layout.

## Checklist sebelum review

```bash
flutter analyze <path-modul>
rg -n 'context\.(isMobile|isTablet)|shortestSide\s*[<>=!]+\s*600|screenWidth\s*[<>=!]+\s*600' \
  <path-modul>/tablet_landscape/
rg -n 'mobile_portrait' <path-modul>/tablet_landscape/
git diff --check
```

Selain static check, uji di ponsel nyata atau emulator untuk:

1. loading, empty state, dan error state;
2. pencarian, filter, refresh, edit/detail;
3. navigasi kembali dan perpindahan section;
4. teks panjang, data kosong, serta orientasi landscape.

## Referensi implementasi

- Responsive helper: `lib/core/widgets/responsive/responsive_context.dart`
- POS router: `lib/modules/sales/pos/views/pos_workspace/pos_workspace_view.dart`
- Sales Orders coordinator: `lib/modules/sales/orders/views/active_orders/active_orders_view.dart`
- Master Data coordinator: `lib/modules/master_data/shared/widgets/master_data_screen_coordinator.dart`
- Master Data mobile folder: `lib/modules/master_data/**/mobile_portrait/`
