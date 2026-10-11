"""Nordvik felanmalan - enkel Flask-app.

Tar emot formularet fran /submit och sparar varje felanmalan i blob-containern
'felanmalningar' med VM:ens hanterade identitet (ingen nyckel eller losenord i koden).

Varje anmalan blir en "mapp" i containern:
    <tidsstampel>-<id>/anmalan.json   (uppgifterna)
    <tidsstampel>-<id>/bild.<ext>     (bilden, om en bild skickades med)

Konfiguration kommer fran miljovariabler (satts i /etc/nordvik-app.env):
    STORAGE_ACCOUNT   storage-kontots namn
    AZURE_CLIENT_ID   klient-id for den hanterade identiteten (id-nordvik-app)
    CONTAINER_NAME    (valfri) default: felanmalningar
    FLOW_URL          (valfri) Power Automate HTTP-url, anvands i steg 5
"""
import json
import logging
import os
import urllib.request
import uuid
from datetime import datetime, timezone
from html import escape

from azure.identity import ManagedIdentityCredential
from azure.storage.blob import BlobServiceClient, ContentSettings
from flask import Flask, request

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 10 * 1024 * 1024  # 10 MB, samma som nginx
logging.basicConfig(level=logging.INFO)
log = logging.getLogger("nordvik")

STORAGE_ACCOUNT = os.environ["STORAGE_ACCOUNT"]
CLIENT_ID = os.environ["AZURE_CLIENT_ID"]
CONTAINER = os.environ.get("CONTAINER_NAME", "felanmalningar")
FLOW_URL = os.environ.get("FLOW_URL", "")

KATEGORIER = {"varme", "vatten", "las", "el", "ventilation", "ovrigt"}
AKUTA = {"varme", "vatten", "las"}
BILDTYPER = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/gif": "gif",
    "image/webp": "webp",
    "image/heic": "heic",
}

# Skapas en gang. Namnet pekar via privat DNS pa private endpoint (10.0.2.x).
_credential = ManagedIdentityCredential(client_id=CLIENT_ID)
_service = BlobServiceClient(
    account_url=f"https://{STORAGE_ACCOUNT}.blob.core.windows.net",
    credential=_credential,
)
_container = _service.get_container_client(CONTAINER)


def sida(rubrik, text, status=200):
    """Enkel svarssida i samma stil som formularet."""
    html = f"""<!DOCTYPE html>
<html lang="sv"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nordvik Fastigheter - {escape(rubrik)}</title>
<style>
body {{ font-family: Arial, sans-serif; background-color: #eef2f1; margin: 50px; }}
.container {{ background: #fff; padding: 30px; max-width: 520px; margin: 0 auto;
  border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }}
h1 {{ color: #1f4e46; }}
a {{ color: #1f4e46; }}
</style></head><body><div class="container">
<h1>{escape(rubrik)}</h1><p>{text}</p>
<p><a href="/">Tillbaka till formuläret</a></p>
</div></body></html>"""
    return html, status


def notifiera_flode(post):
    """Steg 5: skicka anmalan till Power Automate om FLOW_URL ar satt. Fel stoppar inte anmalan."""
    if not FLOW_URL:
        return
    try:
        req = urllib.request.Request(
            FLOW_URL,
            data=json.dumps(post).encode("utf-8"),
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        urllib.request.urlopen(req, timeout=10).close()
    except Exception:
        log.exception("Kunde inte anropa Power Automate")


@app.get("/healthz")
def healthz():
    return "ok"


@app.post("/submit")
def submit():
    rubrik = request.form.get("rubrik", "").strip()
    kategori = request.form.get("kategori", "").strip()
    fastighet = request.form.get("fastighet", "").strip()
    beskrivning = request.form.get("beskrivning", "").strip()
    bild = request.files.get("bild")

    if not (rubrik and fastighet and beskrivning) or kategori not in KATEGORIER:
        return sida("Felanmälan saknar uppgifter", "Fyll i alla fält och försök igen.", 400)
    if len(rubrik) > 200 or len(fastighet) > 200 or len(beskrivning) > 5000:
        return sida("För lång text", "Korta ned texten och försök igen.", 400)

    bild_ext = None
    if bild and bild.filename:
        bild_ext = BILDTYPER.get(bild.mimetype)
        if bild_ext is None:
            return sida("Filtypen stöds inte", "Bifoga en bild (jpg, png, gif, webp eller heic).", 400)

    nu = datetime.now(timezone.utc)
    anmalan_id = f"{nu:%Y%m%dT%H%M%SZ}-{uuid.uuid4().hex[:8]}"
    post = {
        "id": anmalan_id,
        "mottagen": nu.isoformat(),
        "rubrik": rubrik,
        "kategori": kategori,
        "akut": kategori in AKUTA,
        "fastighet": fastighet,
        "beskrivning": beskrivning,
        "bild": f"{anmalan_id}/bild.{bild_ext}" if bild_ext else None,
    }

    try:
        if bild_ext:
            _container.upload_blob(
                name=post["bild"],
                data=bild.stream,
                content_settings=ContentSettings(content_type=bild.mimetype),
                overwrite=False,
            )
        _container.upload_blob(
            name=f"{anmalan_id}/anmalan.json",
            data=json.dumps(post, ensure_ascii=False, indent=2).encode("utf-8"),
            content_settings=ContentSettings(content_type="application/json"),
            overwrite=False,
        )
    except Exception:
        log.exception("Kunde inte spara felanmalan %s", anmalan_id)
        return sida("Något gick fel", "Felanmälan kunde inte sparas. Försök igen om en stund.", 500)

    log.info("Sparade felanmalan %s (kategori=%s)", anmalan_id, kategori)
    notifiera_flode(post)
    return sida(
        "Tack för din felanmälan",
        f"Vi har tagit emot den. Referensnummer: <strong>{escape(anmalan_id)}</strong>.",
    )


@app.errorhandler(413)
def for_stor(_e):
    return sida("Bilden är för stor", "Maxstorlek är 10 MB.", 413)
