import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves where this vault's data lives.
///
/// If a folder named [portableFolderName] already exists next to the
/// running executable, the vault is treated as portable — this is how
/// copying the app plus that folder onto a USB drive takes the whole
/// vault with it. Otherwise, storage falls back to the normal OS
/// application-data location, under [appSupportFolderName].
///
/// The folder name is deliberately specific, not a generic `data`:
/// Flutter's own Windows build output already puts a folder literally
/// named `data` next to the exe (flutter_assets, icudtl.dat, app.so) —
/// checking for that name unconditionally treated every build as
/// portable and silently wrote the vault into Flutter's own asset
/// folder. A distinctive name that Flutter (or anything else) would
/// never create by coincidence is the actual fix, not a workaround.
///
/// This class is shared by every app built on this vault engine.
/// [portableFolderName] and [appSupportFolderName] default to the
/// original Sovereign Vault app's values so it needs no changes to
/// keep reading its existing users' data — a sibling app (e.g.
/// Sovereign Vault X) MUST override both to distinct values before
/// its first use, or the two apps would read and write the same
/// on-disk vault out from under each other.
class StoragePaths {
  StoragePaths._();
  static Directory? _cached;

  static String portableFolderName = 'AuroraVaultData';
  static String appSupportFolderName = 'sovereign_vault';

  static Future<Directory> resolveDataDir() async {
    if (_cached != null) return _cached!;

    final exeDir = File(Platform.resolvedExecutable).parent;
    final portable = Directory(p.join(exeDir.path, portableFolderName));
    if (await portable.exists()) {
      _cached = portable;
      return portable;
    }

    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appSupport.path, appSupportFolderName));
    if (!await dir.exists()) await dir.create(recursive: true);
    _cached = dir;
    return dir;
  }
}
