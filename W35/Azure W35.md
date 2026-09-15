# Azure W35
**Emma Westberg**
GitHub repo: https://github.com/98emmwes/azure-MOV25

### Identiteter
Jag har skapat två användare och två grupper för veckans uppgift. Respektive användare med namn som matchar gruppnamnet har lagts till i respektive grupp. Användarna har fått dessa specifika användarkonton som de ska använda för när de ska göra administrativa saker så att rättigheterna inte sätts på deras egna användarkonton som används på en daglig basis. Detta för att minska risken för katastrofala misstag under dagligt arbete eller vid potentiella intrång på deras användarkonton som de använder dagligen.<br>

| Grupp | Användare | Behörighet | 
| :--- | :--- | :--- |
| Azure-Drift | drift-maja | Den här gruppen har behörigheten *Contributor* på resursgruppen "rg-novatrix". Det innebär att medlemmarna i den här gruppen får skapa och ändra informationen men inte styra åtkomst. |
| Azure-Utveckling | utveckling-fred | Den här gruppen har behörigheten *Reader* i resursgruppen "rg-novatrix". Det innebär att medlemmarna i den här gruppen får läsa informationen men inte ändra någonting. |
| --- | MID-novatrix-app | Inga behörigheter delegerade under den här veckan. Se mer info under nästa rubrik.

<br>

### Managed Identity
Inför uppgiften i vecka 37 skapade jag en användare, ``` MID-novatrix-app ```, som applikationen ska använda för skapa ärenden till lagringen. Den här användaren är inte med i någon grupp och har inte blivit tilldelade några rättigheter under denna veckan. <br>
<br>
### Verifiering Skärmdumpar 
#### Nedan är verifiering av drift-majas behörigheter. <br>
<img width="971" height="348" alt="Skärmbild 2026-09-10 202454" src="https://github.com/user-attachments/assets/492f0777-1e7b-4fdc-acdc-b39bd89b6e1a" /> <br>
<br>
#### Nedan är verifiering av utveckling-freds behörigheter. <br>
<img width="954" height="358" alt="Skärmbild 2026-09-10 202519" src="https://github.com/user-attachments/assets/2f07f9ad-2634-4da3-939d-248b974db848" /> <br>
<br>
#### Nedan är verifiering av uppskapning av användaren MID-novatrix-app.
<img width="1063" height="428" alt="Skärmbild 2026-09-15 170308" src="https://github.com/user-attachments/assets/0ff256ff-dd83-4bb1-b760-80ca6292728d" />
