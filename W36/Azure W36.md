# Azure W36
#### Emma Westberg<br>
GitHub repo: GitHub repo: https://github.com/98emmwes/azure-MOV25 <br>

### Nätverket <br>
Jag skapade ett VNet till ärendeformuläret från "...W34". VNet:et heter ```vnet-novatrix``` och har adressrymden ```10.0.0.0/16```. Sedan skapade jag två subnät för det. <br>

| Subnät | IP Range | NSG | Syfte |
| :--- | :--- | :--- | :--- |
| snet-web | 10.0.1.0 - 10.0.1.255 |```nsg-web```| 
| snet-db | 10.0.2.0 - 10.0.2.255 |```nsg-db```| besk |

<br>

#### NSG (Network Security Group) regler<br>
##### nsg-web <br>

| Priority | Name | Port | Protocol | Source | Source Tag | Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 100 | Allow-80-HTTP | ```80``` (HTTP) | TCP | ```Service Tag``` | ```Internet``` | Allow |
| 110 | Allow-443-HTTPS | ```443``` (HTTPS) | TCP | ```Service Tag``` | ```Internet``` | Allow |
| 200| Allow-22-SSH-Admin | ```22``` (SSH) | TCP | My IP address (```admin.sshSource```) | [Autofill] | Allow |

<br>

##### nsg-db<br>

| Priority | Name | Port | Protocol | Source | Source Tag | Action |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 100 | Allow-80-HTTP | ```80``` (HTTP) | TCP | ```Service Tag``` | ```Internet``` | Allow |
| 110 | Allow-443-HTTPS | ```443``` (HTTPS) | TCP | ```Service Tag``` | ```Internet``` | Allow |

<br>

#### Network Interface<br>
Eftersom jag inte ännu hade skapat vnet och subnet när jag skapade min VM under vecka 34, ```vm-novatrix-web```, så hade jag anslutit min VM till Azures default virtuella nätverkskort vid uppskapning. Eftersom en VM blir låst i det vnet som den uppskapas i så blev jag tvungen att skapa en ny VM som jag anslöt till korrekt vnet och subnet. <br>

##### Network Interface Specifics
| Resouce Group | Name | Virtual Network | Subnet
| :--- | :--- | :--- | :--- |
| ```rg-novatrix-v34``` | ```nic-vm-novatrix-web``` | ```vnet-novatrix (rg-novatrix-v34)``` | ```snet-web``` |

<br>

#### Verifiering <br>
Under ```Network Watcher``` -> ```Network diagnostic tools``` -> ```IP flow verify``` kan jag verifiera vilken trafik som släpps in. <br>
Skärmdumpar finns i GitHub repo. <br>

##### Allow port 80 <br>
<img width="963" height="619" alt="Skärmbild 2026-09-19 230301" src="https://github.com/user-attachments/assets/e11844b6-d933-4ada-aac9-6b9d0eb9b3d2" />
##### Allow port 443 <br>
<img width="902" height="618" alt="Skärmbild 2026-09-19 230420" src="https://github.com/user-attachments/assets/a9b595d2-fe39-40a1-981c-739dd3e0a554" />
##### Allow port 22 from host <br>
<img width="897" height="617" alt="Skärmbild 2026-09-19 230624" src="https://github.com/user-attachments/assets/c5fd9f2b-8247-41d8-9414-8d02efb507c8" />
##### Deny port 22 from other than host IP <br>
<img width="896" height="615" alt="Skärmbild 2026-09-19 230718" src="https://github.com/user-attachments/assets/9d2143c4-acca-4906-bc68-3a7b22a9012b" />
