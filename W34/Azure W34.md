# Azure W34
**Emma Westberg**

## Delmoment 1: GitHub-repo
Länk till mitt GitHub-repo för kursen: https://github.com/98emmwes/azure-MOV25/tree/main

## Delmoment 2: Virtuell Server
Jag skapade en resursgrupp och en virtuell maskin.
**Resource Group**
Name: rg-novatrix-v34
Region: (Europe) Sweden Central

**Virtual Machine**
Name: vm-novatrix-web
OS/Image: Linux/Ubuntu Server 24.04 LTS - x64 Gen 2
Size: Standard B2ats v2
Opened ports: Port 80 (opened after installation and configuration of Nginx)

## Delmoment 3: Konfigurera värdmiljön
Vid uppskapning av VM i Azure så skapades en SSH-nyckel som jag laddade ned och lade på ett säkert ställe. Sedan använde jag mig av följande kommandon för att använda nyckeln och ge behörigheter till enheten som jag arbetar från för att kunna ansluta till VM:en och installera Nginx.

```
# Navigera till mappen med SSH-nyckeln
cd C:\MOV25\Azure

# Sätt behörigheter på enheter. Inheritance stänger av arv så inga rättigheter kan ärvas nedåt
icacls .\vm-novatrix-web_key.pem /inheritance:r

# Grant:r ger läs-rättigheter till den aktuella användaren
icacls .\vm-novatrix-web_key.pem /grant:r "$($env:USERNAME):R"

# Anslut till VM
ssh -i .\vm-novatrix-web_key.pem azureuser@74.241.129.149

# Uppdatera VM
sudo apt update
sudo apt upgrade -y

# Installera Nginx
sudo apt install nginx -y

# Kontrollera att Nginx är igång
systemctl status nginx
```


## Delmoment 4: Kundtjänstsida med ärendeformulär
**Öppna port 80**
För att kunna se hemsidan utifrån så öppnade jag port 80 (http) i Azure under:
Home -> vm-novatrix-web -> Networking -> Network Settings -> Rules -> + Create port rule -> Inbound rule

**Port rule-inställningar**
Source: Any
Source port ranges: *
Destination: Any
Service: HTTP
Destination port ranges: 80
Protocol: TCP
Action: Allow
Priority: 310
Name: allow-http
___
**Anpassa kundtjänstsida och formulär**
Navigera till mappen där Nginx letar efter innehåll med kommandot:
```
cd /var/www/html
```
Öppna sidan för redigering med kommandot:
```
sudo nano index.nginx-debian.html
```
Därefter använde jag följande html-kod till mitt kundformulär:
```

<!DOCTYPE html>
<html>
<head>
<title>Welcome to Novatrix</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Novatrix</h1>
<p>Uppdateras inom kort.</p>

<form>
<label for='name'>Namn</label>
<input type='text' id='name' name='name' >
<label for='mail' >Mail</label>
<input type='text' id='mail' name='mail'><br/>
<label for='msg'>Meddelande</label>
<textarea id='msg' name='msg rows='4' cols='50'></textarea></br>
<input type='submit' value='Skicka'>
</form>

</body>
</html>

```
___
>[!NOTE]
Jag hade en del problem när jag skulle ansluta från min lokala enhet till min VM i Azure och använde följande kommandon för att lösa problemet:
```
# Skapade sökväg
mkdir $env:USERPROFILE\.ssh -Force

# Kopierade SSH-nyckeln till användarprofilen
Copy-Item .\vm-novatrix-web_key.pem $env:USERPROFILE\.ssh\

# Skapade variabel för nyckelns sökväg
$key="$env:USERPROFILE\.ssh\vm-novatrix-web_key.pem"

# Stängde av behörighetsarv på nyckeln
icacls $key /inheritance:r

# Satte läsbehörighet på nyckeln
icacls $key /grant:r "$($env:USERNAME):(R)"

# Kontrollerade nyckelns behörigheter
icacls $key

# Anslöt med nyckeln till servern via SSH
ssh -i $key azureuser@74.241.129.149
```
## Delmoment 5: Verifiera och dokumentera
