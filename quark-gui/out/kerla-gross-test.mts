// Grosstest: ~150 MB Pakete per q installieren, benutzen, loeschen. Aufruf: npx tsx kerla-gross-test.ts
import { execSync, spawn } from "node:child_process";
import { createServer } from "node:http";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const out = import.meta.dirname;
const root = join(out, "..");
const dock = (script: string) =>
  execSync(`docker run --rm -v "${root}:/x" alpine:3.22 sh /x/out/${script}`, {
    stdio: "inherit", env: { ...process.env, MSYS_NO_PATHCONV: "1" },
  });

if (!existsSync(join(out, "srv-gross", "idx"))) { console.log("1/4 Lager bauen"); dock("mk-gross.sh"); }
else console.log("1/4 Lager schon da");

console.log("2/4 Test-cpio packen"); dock("mkg.sh");

const srv = createServer((q, r) => {
  const f = join(out, "srv-gross", (q.url ?? "/").replace(/[^\w./-]/g, ""));
  if (!existsSync(f)) { r.writeHead(404).end(); return; }
  const b = readFileSync(f); r.writeHead(200, { "Content-Length": b.length, Connection: "close" }).end(b);
});
srv.keepAliveTimeout = 0;
srv.listen(8001, "127.0.0.1");

console.log("3/4 Kernel bauen + QEMU starten (dauert)");
// spawn statt execSync: der Server muss waehrend QEMU laeuft antworten koennen
await new Promise<void>((res) => {
  spawn("bash", ["variante-g.sh", "g1"], { cwd: out, stdio: "inherit", env: { ...process.env, CPIO: "gross.cpio" } })
    .on("close", () => res());
});
srv.close();

console.log("4/4 Ergebnis");
const log = readFileSync(join(out, "g1.log"), "latin1").replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/\r/g, "");
const lines = log.split("\n").filter((l) => /^(OK|FEHLER|q:|kein|==)/.test(l));
console.log(lines.join("\n"));
const ok = lines.filter((l) => l.startsWith("OK")).length, bad = lines.filter((l) => l.startsWith("FEHLER")).length;
console.log(`\n${ok} OK, ${bad} FEHLER, Ende erreicht: ${log.includes("==ENDE")}`);
process.exit(bad === 0 && log.includes("==ENDE") ? 0 : 1);
