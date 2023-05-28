import sys
import os

sys.path.insert(0, os.path.abspath(''))

master_doc = 'README'

source_suffix = '.rst'

project = u'Luatest'

exclude_patterns = [
    'doc/locale',
    'doc/output',
    'doc/README.md',
    'doc/cleanup.py',
    'doc/requirements.txt',
]

language = 'en'
locale_dirs = ['./doc/locale']
gettext_compact = False
gettext_location = True
