# Azure W41: Nordvik Fastigheter - Hyresgästportal 
**Repo:** https://github.com/98emmwes/azure-MOV25/tree/main/W41

**Namn:** Emma Westberg

**Klass:** MOV25



> **OBS!** Jag gjorde om hela miljön vid ett tillfälle, med hjälp av mitt repo, så vissa suffix kan skilja sig från bilderna.

## Syfte

Nordvik Fastigheter AB förvaltar bostäder och lokaler och vill lansera en hyresgästportal i molnet. Kärnan är en felanmälan: en hyresgäst fyller i rubrik, kategori, fastighet, beskrivning och en bild på felet och skickar in. Förvaltare tar emot och hanterar anmälningarna och ekonomi har läsande insyn. Portalen ska vara publikt nåbar medan lagringen är skyddad, vara provisionerad som kod och ge ett automatiserat arbetsflöde mot Nordviks Microsoft 365.

Lösningen bygger på kursens verktyg (virtuell maskin, nätverk, storage, ARM, Power Automate), men är utformad efter Nordviks behov: andra roller, andra data och en egen felanmälan.

## Innehåll

- [x] Del A: Centrala tjänster och virtualiseringsnivåer
- [x] Delmoment 1: Compute - webbserver och felanmälningsformulär
- [X] Delmoment 2: IAM - roller för hyresgäst, förvaltare och ekonomi
- [x] Delmoment 3: Nätverk och säkerhet - defense in depth
- [X] Delmoment 4: Storage - säker lagring, lifecycle-policy för kontrakt och protokoll
- [X] Delmoment 5: IaC - ARM-mall
- [x] Delmoment 6: Automation och integration - Power Automate mot SharePoint, Teams och Outlook
- [X] Delmoment 7: Dokumentation

## Översikt

<img width="812" height="443" alt="Skärmbild 2026-10-11 225225" src="https://github.com/user-attachments/assets/6ce53249-73fd-438a-b26a-01559c661035" />



En felanmälan, steg för steg:

1. Hyresgästen öppnar `https://<webbserverns IP>/` och fyller i formuläret. nginx skickar all trafik på port 80 vidare till HTTPS.
2. Nginx skickar `/submit` vidare till Flask-appen på `127.0.0.1:5000`.
3. Appen kontrollerar uppgifterna och sparar anmalan.json och bilden i containern felanmalningar, via lagringens privata endpoint och med webbserverns hanterade identitet. Inga nycklar eller lösenord finns i koden.
4. Appen skickar uppgifterna (utan bilden) till Power Automate-flödet.
5. Flödet skapar en rad i SharePoint-listan och skickar ett Teams-meddelande. Är kategorin värme, vatten eller lås skickas dessutom ett mejl direkt.
6. Hyresgästen får en bekräftelsesida med ett kort referensnummer (t.ex. FA-261011-K7M4PQ), och flödet skickar en bekräftelse med samma uppgifter till hyresgästens e-postadress.

## Del A: Centrala tjänster och virtualiseringsnivåer

### Tjänsterna i lösningen

| Område | Tjänst | Vad den gör hos Nordvik |
|---|---|---|
| Compute | **Virtuell maskin** (Ubuntu 24.04, `Standard_D2ls_v6`) | Kör webbservern nginx och felanmälningsappen. |
| Compute | **Publik IP + nätverkskort** | Gör webbservern nåbar från internet. |
| Nätverk | **Virtual Network** med två subnät | Eget privat nätverk: `snet-web` för webbservern, `snet-data` för lagringens privata ingång. |
| Nätverk | **Network Security Group (NSG)** | Brandväggsregler per subnät. |
| Nätverk | **Private Endpoint + privat DNS-zon** | Ger lagringskontot en privat adress inne i nätverket, så webbservern når det utan att trafiken går över internet. |
| Storage | **Storage account (Blob, ZRS)** | Sparar felanmälningar och bilder i en privat container. |
| IAM | **Hanterad identitet + RBAC** | Webbservern loggar in mot lagringen utan lösenord och får bara skriva till en container. |
| IaC | **ARM-mall + cloud-init** | Hela miljön, inklusive installationen av webbservern, beskrivs som kod. |
| Automation | **Power Automate, SharePoint, Teams, Outlook** | Lägger anmälan i en lista och notifierar förvaltaren. |

### Tre nivåer av virtualisering

| | Virtuell maskin (VM) | Container | Serverless |
|---|---|---|---|
| **Vad man får** | En hel dator med eget operativsystem | Ett paket med appen och det den behöver, delar operativsystem med andra containrar | Bara sin egen kod, plattformen sköter resten |
| **Man sköter själv** | Operativsystem, patchar, webbserver, skalning, appen | Container-avbilden och appen, oftast skalning | Bara koden |
| **Kostnad** | Betalar så länge den är igång | Betalar för igång-tid, kan skalas ner | Betalar per körning, nära noll utan trafik |
| **Skalning** | Man lägger till fler maskiner själv | Snabbare än VM, måste konfigureras | Automatisk |
| **Passar för** | Full kontroll, äldre system, egen programvara | Appar som ska flyttas lätt mellan miljöer | Händelsestyrda uppgifter med ojämn trafik |

### Vald virtualisering: VM

Portalen är byggd på en **virtuell maskin** därför att:

- Uppgiften ber om att provisionera en värdmiljö och driftsätta formuläret där, och en VM visar hela kedjan: nätverkskort, publik IP, NSG, operativsystem, webbserver och app.
- Full kontroll gör det enkelt att förklara och verifiera varje lager i säkerheten: SSH bara från admin-IP, HTTPS med omdirigering, privat väg till lagringen.
- cloud-init gör att hela servern, inklusive nginx, appen och tjänsten, byggs automatiskt vid första uppstart. Det gör lösningen återskapbar från repot.

**Avgränsningar mot Nordviks krav, att redovisa öppet:**

- **Tillgänglighet.** Kravet är 99,5 % på kontorstid och att tåla att en instans faller bort. En enda VM uppfyller inte det. Lagringen är zonredundant (ZRS), men webbservern är en enda instans. I skarp drift hade man kört minst två VM i olika tillgänglighetszoner bakom en lastbalanserare, eller flyttat appen till en tjänst som skalar själv.
- **Kostnad nattetid.** Nordvik vill inte betala för oanvänd kapacitet. En VM kostar dygnet runt, och att stänga av den på natten går emot att akuta fel (vattenläcka) kan komma när som helst. Serverless (t.ex. Azure Functions) passar trafikmönstret bättre: nära noll på natten, toppar på 300 anmälningar i timmen och upp till 120 samtidiga användare.
- **Certifikat.** nginx använder ett självsignerat certifikat som skapas vid första uppstart. I skarp drift behövs ett riktigt certifikat och ett domännamn.


## Namngivning

Följer kursens mönster typ-företag-syfte: `rg-nordvik`, `vnet-nordvik`, `vm-nordvik-web`, `nsg-nordvik-web`, `pip-nordvik-web`, `id-nordvik-app`, `pe-nordvik-storage`. Storage account: `stnordvik98emmwes01` (st + nordvik + användarnamn + löpnummer, 19 tecken).

## Taggning

Alla resurser får samma taggar via parametern `tags` i ARM-mallen, så ekonomi kan följa kostnad per fastighet och avdelning i Cost Management:

| Tagg | Värde |
|---|---|
| `foretag` | `nordvik` |
| `fastighet` | `samtliga` |
| `avdelning` | `forvaltning` |
| `miljo` | `prod` |

Portalen är en delad plattform för alla 48 fastigheter, så taggen `fastighet` har värdet `samtliga` och inte en enskild fastighet.

## Delmoment 1: Compute

Webbservern `vm-nordvik-web` skapas av ARM-mallen: Ubuntu 24.04 LTS, storlek `Standard_D2ls_v6` (2 vCPU, 4 GB) med NVMe-diskkontroller, i Sweden Central. Inloggning sker bara med SSH-nyckel (lösenord är avstängt). Vid första uppstart kör **cloud-init** och installerar nginx, git, openssl och Python, skapar ett självsignerat certifikat, klonar det här repot och kör `app/setup-app.sh`.

Storleken valdes efter att ha kontrollerat både kvot och kapacitetsbegränsningar i regionen.

### Formuläret

[`app/public/index.html`](app/public/index.html) innehåller formuläret med rubrik, kategori, fastighet och lägenhet, beskrivning och bild. Det skickas som `multipart/form-data` till `/submit`.

### Felanmälningsappen

[`app/app.py`](app/app.py) är en liten Flask-app som körs med gunicorn som en systemd-tjänst (`nordvik-app`). Den:

- kontrollerar kategori, textlängd, bildtyp och storlek (högst 10 MB, samma som nginx),
- markerar värme, vatten och lås som akuta,
- sparar varje anmälan som `<tidsstämpel>-<id>/anmalan.json` plus eventuell `bild.<ext>` i containern `felanmalningar`,
- anropar Power Automate om miljövariabeln `FLOW_URL` finns, och sparar ändå anmälan om anropet misslyckas.

Konfigurationen (lagringskontots namn och identitetens klient-id) ligger i `/etc/nordvik-app.env` på servern, inte i koden.

### Nginx

[`app/nginx-nordvik.conf`](app/nginx-nordvik.conf) skickar port 80 vidare till HTTPS, serverar formuläret och skickar `/submit` till appen. `client_max_body_size` är höjd till 10 MB så att bilder på 2-5 MB får plats.

## Delmoment 2: IAM

**Gjort:** webbservern har en användartilldelad **hanterad identitet**, `id-nordvik-app`, med rollen *Storage Blob Data Contributor* scopad till containern `felanmalningar`. Den kan alltså skriva anmälningar men inte nå något annat i lagringskontot. Appen loggar in med den identiteten, utan nycklar.

| Roll | Åtkomst | Hur |
|---|---|---|
| Hyresgäst | Skapar anmälningar via formuläret. Ingen egen Entra-identitet och ingen direktåtkomst till lagringen. | Medveten avgränsning, se nedan. |
| Förvaltare | Hanterar anmälningar | Säkerhetsgrupp `sg-nordvik-forvaltare`: *Storage Blob Data Contributor* på containern, redigera på SharePoint-listan. |
| Ekonomi | Läsande insyn | Säkerhetsgrupp `sg-nordvik-ekonomi`: *Storage Blob Data Reader* på containern, läsa på SharePoint-listan. |


## Delmoment 3: Nätverk och säkerhet

Anmälningarna innehåller personuppgifter. Webbservern är publik, men lagringen är det inte.

**Nätverk:** `vnet-nordvik` (10.0.0.0/16) med två subnät.

| Subnät | Adresser | Innehåll | NSG |
|---|---|---|---|
| `snet-web` | 10.0.1.0/24 | Webbservern | `nsg-nordvik-web`: tillåt 80 och 443 från internet, tillåt 22 (SSH) bara från admin-IP |
| `snet-data` | 10.0.2.0/24 | Lagringens privata endpoint | `nsg-nordvik-data`: tillåt 443 bara från 10.0.1.0/24 |

**Privat endpoint:** `pe-nordvik-storage` ger lagringskontot en privat adress i `snet-data`. Den privata DNS-zonen `privatelink.blob.core.windows.net`, länkad till VNet:et, gör att lagringens namn slår upp till den privata adressen för webbservern.

### Defense in depth

| Lager | Skydd |
|---|---|
| Ingång | Bara port 80 och 443 är öppna mot internet. Port 80 omdirigeras till HTTPS. |
| Administration | SSH tillåts bara från admin-IP, och bara med nyckel. |
| Nätverk | En NSG per subnät. Lagringens subnät tar bara emot 443 från webbservern. |
| Lagring | Brandväggens standardregel är `Deny`, publik blobåtkomst är avstängd, endast HTTPS och TLS 1.2. |
| Privat väg | Webbservern når lagringen via privat endpoint, inte över internet. |
| Identitet | Hanterad identitet utan lösenord, roll scopad till en container. |
| Hemligheter | Flödets URL och SSH-nyckeln finns aldrig i repot. |


## Delmoment 4: Storage

Storage-kontot `stnordvik98emmwes01` skapas av mallen med:

- `Standard_ZRS`, så en datacenterzon kan falla bort,
- `allowBlobPublicAccess: false`, `supportsHttpsTrafficOnly: true`, `minimumTlsVersion: TLS1_2`,
- brandvägg med standardregel `Deny` och en IP-regel för admin-IP, så att lagringen kan kontrolleras utifrån,
- containern `felanmalningar` med `publicAccess: None`.

Dimensionering: 5-10 GB nya bilder per år ryms enkelt, och kontrakt och protokoll (cirka 40 GB) läses sällan efter tre månader.


## Delmoment 5: IaC

Hela miljön finns i [`infra/azuredeploy.json`](infra/azuredeploy.json) med parametrar i [`infra/azuredeploy.parameters.json`](infra/azuredeploy.parameters.json). [`infra/deploy.ps1`](infra/deploy.ps1) slår upp den egna publika IP-adressen och SSH-nyckeln, och kör sedan `group create`, `validate`, `what-if` och (efter bekräftelse) `create`.

Mallen innehåller storage-kontot och containern, två NSG:er, VNet med subnät, privat DNS-zon med länk, privat endpoint med DNS-grupp, hanterad identitet med rolltilldelning, publik IP, nätverkskort och VM med cloud-init. Alla resurser är taggade.

**Parametrar:** `namePrefix`, `location`, `userName`, `storageSuffix`, `sku`, `adminIp`, `sshPublicKey`, `adminUsername`, `vmSize`, `vmDiskControllerType`, `repoUrl`, `repoFolder`, `tags`. Personliga värden (IP, nyckel) ligger i en lokal parameterfil som är ignorerad av Git.

**Utanför mallen:** Entra-grupper, SharePoint-listan och Power Automate-flödet är inte Azure-resurser och byggs för hand.

## Delmoment 6: Automation och integration

En inskickad felanmälan ska ge en post i en lista och en notis till förvaltaren. Lösningen gör båda, och akuta fel ger dessutom ett direkt mejl.

**SharePoint-listan** `Felanmalningar` ligger på sajten `Nordvik Felanmalan`, med kolumnerna Title (rubrik), Referens, Kategori, Akut, Fastighet, Mottagen, BildSokvag och Beskrivning.

**Flödet** `Nordvik felanmalan` startas av en HTTP-begäran (triggern *När en HTTP-begäran tas emot*, ett premiumflöde) och har tre delar:

1. **Skapa objekt** i SharePoint-listan med uppgifterna från anmälan.
2. **Teams-meddelande** till förvaltaren.
3. **Villkor:** om `akut` är sant skickas ett Outlook-mejl direkt (hög prioritet).

Appen anropar flödet, flödet läser inte från lagringen. Det gör att lagringen kan vara stängd för allt utom webbservern, utan att Power Automate behöver släppas in.

**Händelsekedja:** formulär → nginx → Flask → Blob Storage och Power Automate → SharePoint, Teams och Outlook.

**Flödets URL är en hemlighet.** Den innehåller en nyckel och ligger bara i `/etc/nordvik-app.env` på servern, aldrig i repot.

**Begränsning:** appen skickar bara bildens sökväg i lagringen, inte själva bilden, eftersom lagringen är nätverkslåst. En förbättring är att skicka bilden base64-kodad och bifoga den i mejlet.



## Felsökning

Problemen under driftsättningen (az login med MFA, PowerShell-policy, SSH-nyckel, kvot och kapacitet för VM-storlek) finns i [`Nordvik_W41_troubleshooting_log.md`](Nordvik_W41_troubleshooting_log.md). Fler problem under steg 3-6:

| Problem | Orsak | Lösning |
|---|---|---|
| `The '<' operator is reserved` i PowerShell | Platshållare som `<webPublicIp>` skrevs in bokstavligt | Byt ut dem mot de riktiga värdena |
| `Unit nordvik-app.service could not be found` | Installationsskriptet hade aldrig körts klart | Kör `setup-app.sh` på VM:en igen |
| `fatal: not a git repository` | Terminalen stod i en vanlig mapp, inte i en klonad repo | Klona repot och kopiera in `W41`, sedan `git add/commit/push` |
| `No such file or directory` för `w41` | Linux skiljer på stora och små bokstäver | Mappen heter `W41` |
| Microsoft 365 admin center: ingen behörighet | Inloggad med privat Microsoft-konto, inte arbetskonto | Logga in med arbetskontot i tenanten, `@...onmicrosoft.com` |
| SharePoint saknas i office.com | Licensen var inte tilldelad användaren (och kontot var ett gästkonto) | Skapa ett eget medlemskonto, tilldela licens och Global Administrator |
| `ERR_TOO_MANY_REDIRECTS` | Gamla inloggningscookies från flera konton | InPrivate-fönster och direkt SharePoint-adress |
| Flödet startade inte | `FLOW_URL` hade skrivits för hand med stray `<` och `>` från platshållare | Kopiera URL:en med kopieringsknappen i triggern och klistra in med Ctrl+Shift+V |

## Återskapa lösningen

**Förutsättningar:** Azure-prenumeration, Microsoft 365 med SharePoint och Teams, Power Automate med premium-licens (eller provperiod), PowerShell, Azure CLI och ett publikt GitHub-repo.

**1. Microsoft 365 (en gång):** skapa SharePoint-sajten `Nordvik Felanmalan` och listan `Felanmalningar` med kolumnerna ovan. Bygg flödet enligt Delmoment 6 och kopiera HTTP-URL:en från triggern.

**2. Azure:**

```powershell
az login --tenant <TENANT_ID>
az account show
cd W41\infra
.\deploy.ps1 -SshKeyPath "$HOME\.ssh\<din-nyckel>.pub"
```

Svara `y` när skriptet frågar om create. När det är klart skriver mallen ut `webUrl`.

**3. Koppla flödet:** SSH till servern och lägg in flödets URL i `/etc/nordvik-app.env` som `FLOW_URL="..."`, och starta om tjänsten:

```
sudo nano /etc/nordvik-app.env
sudo systemctl restart nordvik-app
```

**4. Testa:** öppna webbadressen, skicka en felanmälan i kategori vatten och en i el, och kontrollera listan, notisen, mejlet och lagringen:

```
az storage blob list --account-name stnordvik98emmwes01 -c felanmalningar --auth-mode login -o table
```

**Riva:**

```powershell
az group delete --name rg-nordvik --yes
```

## Avgränsningar och förbättringar

- En VM är en enskild instans och uppfyller inte kravet att tåla bortfall. I skarp drift: två VM i olika zoner bakom en lastbalanserare, eller serverless (se Del A).
- Självsignerat certifikat. I skarp drift: riktigt certifikat och domännamn.
- Flödets URL läggs in för hand efter driftsättningen. Förbättring: skicka den som `securestring`-parameter.
- Hyresgäster har ingen inloggning i dagsläget. 
- Bilden skickas inte till flödet (se Delmoment 6).

## Filerna i repot

```
W41/
├── README.md                              den här dokumentationen
├── Nordvik_W41_troubleshooting_log.md     felsökningslogg för driftsättningen
├── infra/
│   ├── azuredeploy.json                   ARM-mallen
│   ├── azuredeploy.parameters.json        parametrar, utan personliga värden
│   └── deploy.ps1                         driftsättningsskript
├── app/
│   ├── app.py                             Flask-appen
│   ├── requirements.txt                   Python-beroenden
│   ├── nordvik-app.service                systemd-tjänst
│   ├── setup-app.sh                       installerar appen på webbservern
│   ├── nginx-nordvik.conf                 nginx-konfiguration
│   └── public/index.html                  felanmälningsformuläret
└── images/                                skärmbilder
```
