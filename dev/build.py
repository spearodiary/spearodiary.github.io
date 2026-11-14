#!/usr/bin/env python3
"""Build the published site from dev/src/site.html.

The source keeps an empty Supabase config and a __BUILD__ placeholder.
This script fills in the project's public URL and *publishable* key
(safe to ship in a browser page; never put the secret/service_role key here)
and a build stamp, then writes ../index.html.

    python3 dev/build.py          # writes index.html at the repo root
"""
import pathlib, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'dev' / 'src' / 'site.html'
OUT = ROOT / 'index.html'

SUPABASE_URL = 'https://mxerbyvbdednjnvhhjlp.supabase.co'
SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_2HOShiym_l2vWygC7SKlcA_gTa8k9NE'

s = SRC.read_text(encoding='utf-8')
cfg_empty = "  supabaseUrl:'',\n  supabaseAnonKey:''"
assert s.count(cfg_empty) == 1, 'config placeholder not found'
assert s.count("const B='__BUILD__'") == 1, 'build placeholder not found'
s = s.replace(cfg_empty, f"  supabaseUrl:'{SUPABASE_URL}',\n  supabaseAnonKey:'{SUPABASE_PUBLISHABLE_KEY}'")
s = s.replace("const B='__BUILD__'", f"const B='{int(time.time())}'")
OUT.write_text(s, encoding='utf-8')
print('wrote', OUT)
