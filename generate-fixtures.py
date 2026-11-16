from pathlib import Path
import sys
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image, ImageDraw
from pptx import Presentation
from pptx.util import Inches

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / 'test-fixtures'
root.mkdir(parents=True, exist_ok=True)
phrase = 'Uji konversi Indonesia 123'

im = Image.new('RGB', (240, 120), 'white')
draw = ImageDraw.Draw(im)
draw.rectangle((0, 0, 119, 119), fill=(220, 20, 20))
draw.rectangle((120, 0, 239, 119), fill=(20, 20, 220))
im.save(root / 'gambar.png')
im.save(root / 'gambar.jpg', quality=95)
exif = Image.Exif()
exif[274] = 6
im.save(root / 'orientasi.jpg', exif=exif, quality=95)
im.save(root / 'dua-halaman.tiff', save_all=True, append_images=[im.transpose(Image.Transpose.ROTATE_90)])
im.save(root / 'animasi.gif', save_all=True, append_images=[Image.new('RGB', im.size, 'green')], duration=100, loop=0)

(root / 'catatan.txt').write_text(phrase + '\nBaris kedua: hasil PDF.\n', encoding='utf-8')
(root / 'catatan.rtf').write_text('{\\rtf1\\ansi ' + phrase + '\\par Baris kedua.}', encoding='ascii')
(root / 'tabel.csv').write_text('Keterangan,Jumlah\n' + phrase + ',123\n', encoding='utf-8')
(root / 'rusak.png').write_text('this is not a PNG', encoding='utf-8')
(root / 'unsupported.xyz').write_text('unsupported', encoding='utf-8')

types = '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>{}</Types>'
rels = '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="{}"/></Relationships>'
with ZipFile(root / 'dokumen.docx', 'w', ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', types.format('<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'))
    z.writestr('_rels/.rels', rels.format('word/document.xml'))
    z.writestr('word/document.xml', '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>' + phrase + '</w:t></w:r></w:p><w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>')
with ZipFile(root / 'lembar.xlsx', 'w', ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', types.format('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'))
    z.writestr('_rels/.rels', rels.format('xl/workbook.xml'))
    z.writestr('xl/workbook.xml', '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Uji" sheetId="1" r:id="rId1"/></sheets></workbook>')
    z.writestr('xl/_rels/workbook.xml.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>')
    z.writestr('xl/worksheets/sheet1.xml', '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><cols><col min="1" max="1" width="40" customWidth="1"/></cols><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>' + phrase + '</t></is></c></row><row r="2"><c r="A2"><v>123</v></c></row></sheetData></worksheet>')
pres = Presentation()
slide = pres.slides.add_slide(pres.slide_layouts[6])
slide.shapes.add_textbox(Inches(1), Inches(1), Inches(8), Inches(2)).text = phrase
pres.save(root / 'presentasi.pptx')
print('Fixture files:', len(list(root.iterdir())))
