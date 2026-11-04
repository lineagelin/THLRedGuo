import io
import unittest
from zipfile import ZipFile

from android_apk_checks import verify_plugin_registrant


class PluginRegistrantCheckTest(unittest.TestCase):
    def check_archive(self, entries):
        buffer = io.BytesIO()
        with ZipFile(buffer, 'w') as archive:
            for name, data in entries.items():
                archive.writestr(name, data)
        buffer.seek(0)
        with ZipFile(buffer) as archive:
            verify_plugin_registrant(archive)

    def test_accepts_registrant_in_secondary_dex(self):
        self.check_archive({
            'classes.dex': b'unrelated class',
            'classes2.dex': b'Lio/flutter/plugins/GeneratedPluginRegistrant;',
        })

    def test_rejects_missing_registrant_even_when_asset_mentions_it(self):
        with self.assertRaisesRegex(SystemExit, 'Flutter'):
            self.check_archive({
                'classes.dex': b'unrelated class',
                'assets/note.txt': b'Lio/flutter/plugins/GeneratedPluginRegistrant;',
            })


if __name__ == '__main__':
    unittest.main()
