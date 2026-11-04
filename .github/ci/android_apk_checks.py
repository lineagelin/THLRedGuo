import re
from zipfile import ZipFile


def verify_plugin_registrant(archive: ZipFile) -> None:
    """Reject APKs that can launch but cannot register Flutter's native plugins."""
    descriptor = b'Lio/flutter/plugins/GeneratedPluginRegistrant;'
    for name in archive.namelist():
        if re.fullmatch(r'classes\d*\.dex', name) and descriptor in archive.read(name):
            return
    raise SystemExit('APK 缺少 Flutter 插件注册类，请完整执行 flutter pub get 后重新构建。')
