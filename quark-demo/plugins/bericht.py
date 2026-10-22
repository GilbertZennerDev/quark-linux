# Bericht-Plugin: eine kleine Datenbank (sqlite) auswerten und daraus eine Seite mit Diagramm bauen.
import sqlite3, base64, sys
db = sqlite3.connect(":memory:")
db.execute("create table ausgaben (monat text, rubrik text, euro real)")
daten = [("Jan","Miete",720),("Jan","Essen",310),("Jan","Freizeit",95),("Feb","Miete",720),("Feb","Essen",280),("Feb","Freizeit",140),
         ("Mrz","Miete",720),("Mrz","Essen",335),("Mrz","Freizeit",60),("Apr","Miete",720),("Apr","Essen",298),("Apr","Freizeit",180),
         ("Mai","Miete",720),("Mai","Essen",301),("Mai","Freizeit",75),("Jun","Miete",720),("Jun","Essen",322),("Jun","Freizeit",210)]
db.executemany("insert into ausgaben values (?,?,?)", daten)
monate = [r[0] for r in db.execute("select monat from ausgaben group by monat order by min(rowid)")]
summe = {m: s for m, s in db.execute("select monat, sum(euro) from ausgaben group by monat")}
rubrik = list(db.execute("select rubrik, sum(euro), round(100*sum(euro)/(select sum(euro) from ausgaben),1) from ausgaben group by rubrik order by 2 desc"))
gesamt = db.execute("select sum(euro) from ausgaben").fetchone()[0]
hoch = max(summe.values())
bars = ""
for i, m in enumerate(monate):
    h = int(180 * summe[m] / hoch); x = 40 + i * 70
    bars += '<rect x="%d" y="%d" width="46" height="%d" rx="4" fill="#c2692f"/>' % (x, 210 - h, h)
    bars += '<text x="%d" y="232" font-size="13" text-anchor="middle">%s</text>' % (x + 23, m)
    bars += '<text x="%d" y="%d" font-size="12" text-anchor="middle">%d</text>' % (x + 23, 204 - h, summe[m])
zeilen = "".join("<tr><td>%s</td><td>%.0f €</td><td>%s %%</td></tr>" % r for r in rubrik)
html = """<!doctype html><meta charset="utf-8"><title>Ausgaben-Bericht aus der Mini-VM</title>
<style>body{font-family:system-ui,sans-serif;max-width:640px;margin:2rem auto;padding:0 1rem;background:#faf5ee;color:#2b2118}
h1{font-size:1.4rem}svg{width:100%%;background:#fff;border-radius:12px;padding:8px}td{padding:.3rem 1rem .3rem 0}small{color:#7a6a58}</style>
<h1>Ausgaben Jan–Jun: %d € gesamt</h1>
<svg viewBox="0 0 480 245">%s</svg>
<table>%s</table>
<p><small>Diese Seite hat eine Linux-VM gebaut, die als 450-KB-Datei gestartet ist (sqlite + Python, per Plugin nachgeladen).</small></p>""" % (gesamt, bars, zeilen)
print("BEGIN-FILE bericht.html")
s = base64.b64encode(html.encode("utf-8")).decode()
for k in range(0, len(s), 76):
    print(s[k:k + 76])
print("END-FILE")
sys.stdout.flush()
