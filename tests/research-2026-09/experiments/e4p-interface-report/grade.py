import re


def grade(work, run):
    m = re.search(r'^INTERFACES:\s*(.+)$', run.get('final') or '', re.M)
    line = m.group(1) if m else ''
    ok = bool(re.search(r'unit_price', line)) and bool(re.search(r'cent', line, re.I))
    return {'interfaces': line[:160], 'reported': ok, 'category': 'reported' if ok else 'missing'}
