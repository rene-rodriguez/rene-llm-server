"""Source contract: every theme token this plugin reads goes through `Commons`.

Qt 6.12 (`qt6-base 6.11.2-3 -> 6.12.0-3`, installed 2026-10-15) resolves an
UNQUALIFIED `Color` in a QML file to the built-in `color` VALUE type instead of
to the `qs.Commons.Color` singleton. `Color.accent` then evaluates to undefined,
so the bound property (here the bar icon's `activeColor`) is dropped and the
element keeps its unthemed default. The same shadow painted every third-party
panel WHITE; this plugin only tints an icon, which is why it is the smallest case
and was ranked last.

    rene.llm-server/Panel.qml[144]: Unable to assign [undefined] to QColor

`Commons.Color.*` resolves to the singleton correctly and is the house form in
every first-party Omarchy file, so the read goes through the alias. A regression
is invisible to every other check - the widget still renders and the server still
starts - which is why it is pinned at the source. Comments are stripped first, so
prose can neither satisfy nor break an assertion.
"""

import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent
QML_ROOT = ROOT / 'plugin'


def strip_comments(source):
    """`source` with every comment removed, newlines kept.

    A character scan rather than a `line.split('//', 1)[0]`: a `//` inside a
    STRING LITERAL or a `/* */` block is data, and the split would silently
    delete the rest of that line.
    """
    out = []
    i, n = 0, len(source)
    while i < n:
        char = source[i]
        if char == '/' and source.startswith('//', i):
            end = source.find('\n', i)
            i = n if end < 0 else end
            continue
        if char == '/' and source.startswith('/*', i):
            i += 2
            while i < n and not source.startswith('*/', i):
                if source[i] == '\n':
                    out.append('\n')
                i += 1
            i += 2                              # past the closing `*/`
            continue
        if char in '"\'':
            quote = char
            out.append(char)
            i += 1
            while i < n:
                if source[i] == '\\':
                    out.append(source[i:i + 2])
                    i += 2
                    continue
                out.append(source[i])
                i += 1
                if source[i - 1] == quote:
                    break
            continue
        out.append(char)
        i += 1
    return ''.join(out)


class PanelThemeContract(unittest.TestCase):
    # `Color.` not preceded by an identifier character or a dot: `Commons.Color.`
    # and `root.color` do not match, a bare `Color.accent` does.
    BARE_COLOR = re.compile(r'(?<![A-Za-z0-9_.])Color\.')

    def setUp(self):
        # Every QML file that ships with the plugin is scanned, not a list of
        # names: a new file (or a `lib/`) must not be able to escape the guard.
        self.files = {str(path.relative_to(ROOT)): self.flat(path.read_text())
                      for path in sorted(QML_ROOT.rglob('*.qml'))}

    @staticmethod
    def flat(source):
        """One source blob, stripped and flattened exactly like a real file."""
        return ' '.join(strip_comments(source).split())

    def bare_color_refs(self, blob):
        """The bare `Color.` references in `blob`, each with a little context."""
        return [blob[max(0, m.start() - 24):m.end() + 24]
                for m in self.BARE_COLOR.finditer(blob)]

    def test_the_plugin_ships_qml_at_all(self):
        # Without this, a rename that empties the scan would make the guard below
        # vacuously green.
        self.assertEqual({'plugin/Panel.qml'}, set(self.files))

    def test_the_scan_sees_the_theme_reads(self):
        # Non-vacuity for the scan itself: the guard below is only meaningful if
        # the strip+flatten pipeline still leaves a real `Commons.Color` read.
        self.assertIn('Commons.Color.', self.files['plugin/Panel.qml'])

    def test_no_unqualified_color_reference(self):
        for name, blob in self.files.items():
            with self.subTest(file=name):
                self.assertEqual([], self.bare_color_refs(blob))

    def test_the_guard_flags_the_form_that_broke(self):
        # Mutation proof for the assertion above: if the matcher stops seeing the
        # defect, the green test above would be meaningless.
        broken = ('activeColor: Color.accent',
                  'color: Color.menu.background')
        for snippet in broken:
            with self.subTest(snippet=snippet):
                self.assertTrue(self.bare_color_refs(self.flat(snippet)))
        clean = ('activeColor: Commons.Color.accent',
                 'color: root.foreground',
                 '// prose: activeColor: Color.accent')
        for snippet in clean:
            with self.subTest(snippet=snippet):
                self.assertEqual([], self.bare_color_refs(self.flat(snippet)))

    def test_the_guard_is_conservative_about_strings(self):
        # The scan drops comments but keeps string literals (a `//` inside one is
        # data), so a `Color.` inside a string is still flagged. That is the
        # deliberate direction: a false positive here costs a rewrite of the
        # snippet, a false negative ships an unthemed widget.
        self.assertTrue(self.bare_color_refs(self.flat('text: "a Color.string"')))

    def test_the_alias_import_backs_the_qualified_reads(self):
        # `Commons.Color` only resolves if the module was imported under that
        # alias in the same file.
        for name, blob in self.files.items():
            if 'Commons.Color.' not in blob:
                continue
            with self.subTest(file=name):
                self.assertIn('import qs.Commons as Commons', blob)

    def test_the_bar_icon_colour_comes_from_the_theme(self):
        self.assertIn('activeColor: Commons.Color.accent',
                      self.files['plugin/Panel.qml'])


if __name__ == '__main__':
    unittest.main()
