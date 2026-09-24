"""Author-owned held-out strings; never loads inference, model, or predictions."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SOURCE_HASHES = {
    'Core/Sources/Core/InputUtils/LocalLanguageRouter.swift': '18d52b77ea308961c155e897cc7b6a9259c1e2b03a4e5dbc51807e410e0fe892',
    'Core/Sources/Core/InputUtils/LocalMixedSegmenter.swift': '5266c41a35edeff07c611e551de8e63de3cf4a65161c70d1ab7a415d5e850864',
    'Core/Sources/Core/Resources/LocalLanguageModel.json': 'e39825afc0a3badfc6e613d05fa600b7d0d0267816e46c45835e916f0dc9a69d',
}
# (English span, Japanese span, intended Japanese reading, stratum).
ROWS = [
    ('calendar', 'niashitanoyoteiwoiretekudasai', 'calendarに明日の予定を入れてください', 'lowercase'),
    ('headphone', 'wokabanniireta', 'headphoneを鞄に入れた', 'lowercase'),
    ('backup', 'gaowattarakonopasokonwokesu', 'backupが終わったらこのパソコンを消す', 'lowercase'),
    ('screen sharing', 'wohajimerumaenimadowotojiteokou', 'screen sharingを始める前に窓を閉じておこう', 'lowercase phrase'),
    ('meeting room', 'nisaifuwowasuretekita', 'meeting roomに財布を忘れてきた', 'lowercase phrase'),
    ('Spotify', 'dekinounokyokuwomouichidokikitai', 'Spotifyで昨日の曲をもう一度聴きたい', 'Titlecase'),
    ('Firefox', 'wotojitemoongakuganatteiru', 'Firefoxを閉じても音楽が鳴っている', 'Titlecase'),
    ('Dropbox', 'nikazokunoshashinwomatometeoita', 'Dropboxに家族の写真をまとめておいた', 'Titlecase'),
    ('Google Maps', 'deekimadenomichiwoshirabeta', 'Google Mapsで駅までの道を調べた', 'Titlecase phrase'),
    ('Apple Music', 'nokinoutsukuttarisutowokikitai', 'Apple Musicの昨日作ったリストを聴きたい', 'Titlecase phrase'),
    ('PDF', 'wobetsunoforudanikopiishitekudasai', 'PDFを別のフォルダにコピーしてください', 'acronym'),
    ('USB', 'gasasattamamaninatteiru', 'USBが挿さったままになっている', 'acronym'),
    ('DNS', 'nosetteiwomotonimodoshita', 'DNSの設定を元に戻した', 'acronym'),
    ('HDMI', 'nokeeburugamijikasugita', 'HDMIのケーブルが短すぎた', 'acronym'),
    ('CPU fan', 'nootogakinouyoriookii', 'CPU fanの音が昨日より大きい', 'acronym phrase'),
    ('paperless', 'nishitakuteatarashiisukyannawokatta', 'paperlessにしたくて新しいスキャナを買った', 'less common lowercase'),
    ('microblog', 'nimaiasashashinwoageteiru', 'microblogに毎朝写真を上げている', 'less common lowercase'),
    ('Readwise', 'nikinounomemowonokoshiteoita', 'Readwiseに昨日のメモを残しておいた', 'less common product'),
    ('Obsidian Sync', 'gasumumadekonomamahouchishiteokou', 'Obsidian Syncが済むまでこのまま放置しておこう', 'less common product phrase'),
    ('deskmat', 'wosentakushitakedomadakawakanai', 'deskmatを洗濯したけどまだ乾かない', 'less common lowercase'),
    ('Please send the meeting notes before lunch.', '', 'Please send the meeting notes before lunch.', 'pure English'),
    ('The new keyboard feels much quieter.', '', 'The new keyboard feels much quieter.', 'pure English'),
    ('I saved a copy in the shared folder.', '', 'I saved a copy in the shared folder.', 'pure English'),
    ('Can you turn off the kitchen light?', '', 'Can you turn off the kitchen light?', 'pure English'),
]

def main():
    for name, expected in SOURCE_HASHES.items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == expected, name
    cases = []
    for index, (english, japanese, _, _) in enumerate(ROWS, 1):
        raw = english + japanese
        assert raw.isascii()
        assert not japanese or (' ' not in japanese and english[-1] != ' ')
        case = {'id': f'v9-final-{index:03}', 'raw': raw,
                'japaneseRanges': [[len(english), len(raw)]] if japanese else [],
                'englishRanges': [[0, len(english)]]}
        coverage = [0] * len(raw)
        for ranges in [case['japaneseRanges'], case['englishRanges']]:
            for start, end in ranges:
                assert 0 <= start < end <= len(raw)
                for i in range(start, end): coverage[i] += 1
        assert all(c == 1 for c in coverage)
        assert raw[:len(english)] == english
        assert raw[len(english):] == japanese
        cases.append(case)
    assert len(cases) == 24 and len({x['raw'] for x in cases}) == 24
    target = OUT/'final-evaluation.json'
    target.write_text(json.dumps(cases, ensure_ascii=False, indent=2)+'\n')
    print('fixture SHA256', hashlib.sha256(target.read_bytes()).hexdigest())
    for case, (english, japanese, reading, group) in zip(cases, ROWS):
        print(case['id'], group, f'EN[{english}] JP[{japanese}]', '=>', reading)

if __name__ == '__main__': main()
