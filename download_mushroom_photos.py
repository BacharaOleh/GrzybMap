import os
import json
import ssl
import time
import io
import urllib.request
import urllib.parse
from PIL import Image

ctx = ssl._create_unverified_context()
headers = {
    'User-Agent': 'GrzybMapMobile/1.0 (https://github.com/BacharaOleh/GrzybMap; contact: 83633550+BacharaOleh@users.noreply.github.com)'
}

SPECIES = [
    ('borowik_szlachetny', ['Borowik_szlachetny', 'Boletus_edulis']),
    ('borowik_sosnowy', ['Borowik_sosnowy', 'Boletus_pinophilus']),
    ('podgrzybek_brunatny', ['Podgrzybek_brunatny', 'Imleria_badia', 'Boletus_badius']),
    ('podgrzybek_zajaczek', ['Podgrzybek_zajączek', 'Xerocomellus_chrysenteron', 'Boletus_chrysenteron']),
    ('pieprznik_jadalny', ['Pieprznik_jadalny', 'Cantharellus_cibarius']),
    ('maslak_zwyczajny', ['Maślak_zwyczajny', 'Suillus_luteus']),
    ('maslak_ziarnisty', ['Maślak_ziarnisty', 'Suillus_granulatus']),
    ('mleczaj_rydz', ['Mleczaj_rydz', 'Lactarius_deliciosus']),
    ('mleczaj_jodlowy', ['Mleczaj_jodłowy', 'Lactarius_salmonicolor']),
    ('kozlarz_babka', ['Koźlarz_babka', 'Leccinum_scabrum']),
    ('kozlarz_czerwony', ['Koźlarz_czerwony', 'Leccinum_aurantiacum']),
    ('kozlarz_grabowy', ['Koźlarz_grabowy', 'Leccinum_pseudoscabrum', 'Leccinum_carpini']),
    ('czubajka_kania', ['Czubajka_kania', 'Macrolepiota_procera']),
    ('opienka_miodowa', ['Opieńka_miodowa', 'Armillaria_mellea']),
    ('gaska_zielona', ['Gąska_zielona', 'Tricholoma_equestre']),
    ('gasowka_fioletowawa', ['Gąsówka_fioletowawa', 'Lepista_nuda', 'Collybia_nuda']),
    ('boczniak_ostrygowaty', ['Boczniak_ostrygowaty', 'Pleurotus_ostreatus']),
    ('plomiennica_zimowa', ['Płomiennica_zimowa', 'Flammulina_velutipes']),
    ('goryczak_zolciowy', ['Goryczak_żółciowy', 'Tylopilus_felleus']),
    ('lisieczka_pomaranczowa', ['Lisieczka_pomarańczowa', 'Hygrophoropsis_aurantiaca']),
    ('mleczaj_welnianka', ['Mleczaj_wełnianka', 'Lactarius_torminosus']),
    ('muchomor_sromotnikowy', ['Muchomor_sromotnikowy', 'Muchomor_zielonawy', 'Amanita_phalloides']),
    ('maslanka_wiazkowa', ['Maślanka_wiązkowa', 'Hypholoma_fasciculare']),
]

OUT_DIR = os.path.join('grzybmap_app', 'assets', 'mushrooms')
BUILD_DIR = os.path.join('grzybmap_app', 'build', 'web', 'assets', 'mushrooms')

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(BUILD_DIR, exist_ok=True)

def fetch_image_url(query):
    for lang in ['pl', 'en']:
        url = f'https://{lang}.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(query)}'
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, context=ctx) as r:
                data = json.loads(r.read().decode('utf-8'))
                img_url = data.get('originalimage', {}).get('source') or data.get('thumbnail', {}).get('source')
                if img_url:
                    return img_url, lang
        except Exception:
            pass
        time.sleep(0.3)
    return None, None

def process_and_save(img_url, out_path, target_size=(640, 480)):
    req = urllib.request.Request(img_url, headers=headers)
    with urllib.request.urlopen(req, context=ctx) as r:
        raw_bytes = r.read()
    
    im = Image.open(io.BytesIO(raw_bytes)).convert('RGB')
    
    tw, th = target_size
    target_ratio = tw / th
    w, h = im.size
    img_ratio = w / h
    
    if img_ratio > target_ratio:
        new_w = int(h * target_ratio)
        left = (w - new_w) // 2
        im = im.crop((left, 0, left + new_w, h))
    else:
        new_h = int(w / target_ratio)
        top = int((h - new_h) * 0.35)
        top = max(0, min(top, h - new_h))
        im = im.crop((0, top, w, top + new_h))
        
    im = im.resize(target_size, Image.Resampling.LANCZOS)
    im.save(out_path, 'WEBP', quality=85, method=6)
    return os.path.getsize(out_path)

print('=== Starting mushroom photo fetcher ===')
success_count = 0

for file_id, candidates in SPECIES:
    found_url = None
    found_title = None
    found_lang = None
    
    for c in candidates:
        url, lang = fetch_image_url(c)
        if url:
            found_url = url
            found_title = c
            found_lang = lang
            break
        time.sleep(0.5)
        
    if found_url:
        target_file = os.path.join(OUT_DIR, f'{file_id}.webp')
        build_file = os.path.join(BUILD_DIR, f'{file_id}.webp')
        try:
            size_bytes = process_and_save(found_url, target_file)
            # Copy to build directory as well
            with open(target_file, 'rb') as f_in, open(build_file, 'wb') as f_out:
                f_out.write(f_in.read())
            print(f'[OK] {file_id:24} -> {found_title} ({found_lang}) [{size_bytes // 1024} KB]')
            success_count += 1
        except Exception as e:
            print(f'[ERROR] {file_id:24} -> Save failed: {e}')
    else:
        print(f'[FAIL] {file_id:24} -> No image found in candidates: {candidates}')
        
    time.sleep(0.8)

print(f'\nFinished: {success_count}/{len(SPECIES)} photos successfully downloaded and converted.')
