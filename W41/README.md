# W41 - Examination: Nordvik Fastigheter AB, hyresgästportal

Repo: https://github.com/98emmwes/azure-MOV25/tree/main/W41

Kurs: Microsoft Azure, MOV25
Av: Emma Westberg (98emmwes)

Hyresgästportal med felanmälan (rubrik, kategori, beskrivning och bild), driftsatt på Azure och provisionerad som kod med ARM-templates.

## Mappstruktur

```
W41/
  infra/          ARM-mall och parameterfil
  app/            Webbsida och nginx-konfiguration (Flask-appen kommer i steg 3)
  docs/           Dokumentation och diagram
  screenshots/    Verifieringar
```

## Så återskapas miljön

1. Klona repot och gå till `W41/infra`.
2. Kopiera `azuredeploy.parameters.json` till `azuredeploy.parameters.local.json` och fyll i `adminIp` och `sshPublicKey`. Den lokala filen ignoreras av git.
3. Skapa resursgruppen och deploya:

```
az group create --name rg-nordvik --location swedencentral
az deployment group validate --resource-group rg-nordvik --template-file azuredeploy.json --parameters "@azuredeploy.parameters.local.json"
az deployment group what-if --resource-group rg-nordvik --template-file azuredeploy.json --parameters "@azuredeploy.parameters.local.json"
az deployment group create --resource-group rg-nordvik --template-file azuredeploy.json --parameters "@azuredeploy.parameters.local.json"
```

4. Öppna `webUrl` från deploymentens outputs i webbläsaren.

## Status

- [x] Steg 1: mappstruktur
- [x] Steg 2: baslinje (nätverk, lagring, identitet, webbserver)
- [ ] Steg 3: felanmälningsappen
- [ ] Steg 4: lifecycle, kontrakt-container, roller
- [ ] Steg 5: Power Automate
- [ ] Steg 6: återskapande i ren resursgrupp
