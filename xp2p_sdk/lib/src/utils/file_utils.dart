
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

import '../log/logger.dart';

class FileUtils {
  static const _tag = 'FileUtils';

  /// 保存数据至具体路径
  ///
  /// [data] 待保存数据
  /// [path] 保存的目录
  /// [fileName] 文件名
  /// return 保存失败时返回 null，反之返回 File 对象
  static Future<File?> saveUint8ListToPath(Uint8List data, String path, String fileName) async {
    final absolutePath = '$path/$fileName';
    Logger.d('Save ${data.length} data, locate in: $absolutePath)', _tag);

    try {
      final file = File(absolutePath);
      await file.parent.create(recursive: true);
      return file.writeAsBytes(data, flush: true);
    } catch (e) {
      Logger.eWithException('Save data error', e, _tag);
      return null;
    }
  }

  /// 保存数据至 App 外部存储目录
  ///
  /// [data] 待保存数据
  /// [fileName] 文件名
  ///
  /// return 保存失败时返回 null，反之返回 File 对象
  static Future<File?> saveUint8ListToAppDocument(Uint8List data, String fileName) async {
    // Android平台使用外部存储目录: /storage/emulated/0/Android/data/包名/files
    // iOS平台使用应用文档目录
    Directory? dir;
    if (Platform.isAndroid) {
      // 获取外部存储目录 (对应 /storage/emulated/0/Android/data/包名/files)
      dir = await getExternalStorageDirectory();
    } else {
      // iOS使用应用文档目录
      dir = await getApplicationDocumentsDirectory();
    }

    if (dir == null) {
      Logger.e('无法获取存储目录', _tag);
      return null;
    }

    return saveUint8ListToPath(data, dir.path, fileName);
  }


}