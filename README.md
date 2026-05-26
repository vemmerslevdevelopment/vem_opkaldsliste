# vem_opkaldsliste

**Krav:** `es_extended`, `oxmysql`, `lb-phone` (anbefalet)

---

## Exports

### Export til at tilføje opkald fra spiller

Denne export er kun tilgængelig fra server

```lua
-- source: Spillerens source
-- message: Besked der skal vises
-- job: Det job beskeden skal sendes til
exports['vem_opkaldsliste']:AddCall(source, message, job)
```

*Coords hentes automatisk*

---

### Export til at sende opkald uden spillers source

Denne export er kun tilgængelig fra server

```lua
-- source: nil
-- message: Besked der skal vises
-- job: Det job beskeden skal sendes til
-- coords: Koordinaterne hvor opkaldet er
exports['vem_opkaldsliste']:AddCall(nil, message, job, coords)
```

---

### Export til anonymt opkald (skjult nummer)

Denne export er kun tilgængelig fra server

```lua
-- source: Spillerens source
-- message: Besked der skal vises
-- job: Det job beskeden skal sendes til
exports['vem_opkaldsliste']:AddAnonymousCall(source, message, job)
```

*Coords hentes automatisk*

---
<img width="1382" height="789" alt="image" src="https://github.com/user-attachments/assets/4a236e90-d157-4040-a229-06cc42b6fbca" />

