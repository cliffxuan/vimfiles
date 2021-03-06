import unittest

import pastebin


class TestCase(unittest.TestCase):
    def test_get_fullpath_with_good_path(self):
        dataset = [
            ('foo', 'http://hastebin.com/raw/foo'),
            ('http://hastebin.com/foo', 'http://hastebin.com/raw/foo'),
            ('http://hastebin.com/raw/foo', 'http://hastebin.com/raw/foo'),
        ]
        for path, url in dataset:
            self.assertEqual(pastebin.Hastebin.get_fullpath(path), url)

    def test_get_fullpath_with_bad_path(self):
        dataset = [
            'http://hastebin.com/raw',
            ]
        for path in dataset:
            self.assertRaises(
                Exception, pastebin.Hastebin.get_fullpath, path)

    def test_message(self):
        messags = [
            "foo",
            "f'o'o",
            'f"o"o',
            '''f"'o'"o''',
            """a'b"c\nd\t\\e"""
        ]
        for msg in messags:
            pastebin.error_msg(msg)

if __name__ == '__main__':
    try:
        unittest.main()
    except SystemExit:
        pass
