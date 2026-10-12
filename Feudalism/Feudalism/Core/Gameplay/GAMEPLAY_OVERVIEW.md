# Gameplay – pregled i fokus

## Što trenutno postoji

| Sustav | Stanje | Datoteke |
|--------|--------|----------|
| **Resursi** | Potrošnja (gradnja) radi; dodavanje (proizvodnja) nije povezano s gradnjom | `GameState.resources`, `GameResources.add/subtract` |
| **Hrana** | `food`, `hay`, `hop` u GameState – statične vrijednosti, nitko ih ne mijenja tijekom igre | `GameState` |
| **Potez** | `currentTurn` postoji, nikad se ne povećava | `GameState.currentTurn` |
| **Zgrade** | Postavljanje i prikaz na karti; nema učinka (proizvodnja, prihod) | `Placement`, `GameMap.placements` |
| **Vlasništvo** | Placements nemaju `realmId` – sve je “igračevo” u solo | `Placement`, `GameSituationSnapshot` (realmId: nil) |
| **HP / borba** | `Placement.currentHealth` postoji; nema napada, oštećenja ni game overa | `Placement`, `ObjectHealth` |
| **Pobjeda** | `hasWinner`, `winningRealmId`, `defeatRealm()` – nigdje se ne poziva | `GameState` |
| **AI** | Snapshot + profil; `decideNextAction` prazan | `ComputerLordAI`, `GameSituationSnapshot` |
| **Vrijeme** | Godišnja doba (60 s / 240 s) samo za HUD; ne utječu na gameplay | `ContentView` Timer, `SeasonIcon` |
| **HUD broj** | `hudScoreCurrent` / `hudScoreMax` (npr. populacija) – uvijek 0/0 | `ContentView` |

Zaključak: **nema game loopa** koji mijenja stanje (proizvodnja, potrošnja, potez, pobjeda). Igra je u fazi “postavi zgradu i vidi je na karti”.

---

## Preporučeni fokus (prioritet)

### 1. Game loop + ekonomija (solo)

- **Jedan izvor**: npr. `GameplayTick` koji se pokreće kad je `isLevelReady` i solo mod.
- **Timer**: npr. svakih 10–15 sekundi (ili 1 “potez” po dobu godine).
- **Proizvodnja po zgradama** (solo, igrač posjeduje sve):
  - Broj placemenata po `objectId` (Windmill, Bakery, Granary, Farm/Chicken/Corn, Stone, Iron, Market…) → pozivi `resources.add(...)` i `gameState.food += ...` itd. prema jednostavnoj tablici (npr. 1 Windmill = +2 bread/tick).
- **Potrošnja** (opcionalno u prvoj iteraciji):
  - “Populacija” = npr. zbroj kuća (Hotel, House) ili fiksna vrijednost; svaki tick `food -= population` (cap npr. 0).
- **Potez**: u ticku `currentTurn += 1` (za budući AI i save).

Rezultat: igrač vidi da zgrade “nešto rade” (resursi/hrana rastu), što je prvi dojam pravog gameplaya.

### 2. HUD “populacija / kapacitet”

- Uvesti u GameState (solo) npr. `population: Int` i `populationCapacity: Int` (ili koristiti `hudScoreCurrent`/`hudScoreMax` izravno iz jednog izvora).
- Izgradnje: kuće/hoteli povećavaju kapacitet; “populacija” može rasti do kapaciteta (npr. +1 svaki N tickova ako ima dovoljno hrane).
- `ContentView`: `hudScoreCurrent = gameState.population`, `hudScoreMax = gameState.populationCapacity`, da HUD prikaže stvarno stanje.

### 3. Vlasništvo (realmId na Placement)

- Dodati opcionalno `realmId: String?` na `Placement` (ili poseban rječnik placementId → realmId).
- Pri postavljanju u solo: `realmId = playerRealmId`.
- Snapshot za AI: `realmId` popunjen prema vlasniku.
- Nužno za: više igrača, AI koji gradi na “svojoj” teritoriji, ispravan prikaz tko što posjeduje.

### 4. Pobjeda / poraz (solo i last standing)

- **Solo**: npr. “soft” cilj (dostići X zlata / X stanovnika) ili bez game overa; ili game over ako `food == 0` i `population > 0` N poteza (glad).
- **Last standing**: kada jedan realm nema teritorija ili kralj “pade” → `defeatRealm(id)`; kada `hasSingleRemainingFaction` → prikaz pobjednika.
- Potrebno: jasna definicija “teritorija” (ćelije pod kontrolom) i “kralj pao” (npr. glavna građevina uništena ili poseban unit).

### 5. Borba i oštećenja (kasnije)

- Sustav napada na `Placement` (ili na “jedinice” ako ih uvedeš): smanjenje `currentHealth`, uništenje kad 0.
- Povezati s vlasništvom (napad samo na tuđe) i s `defeatRealm` (npr. uništenje “dvorca” = poraz).

### 6. AI (nakon 1–3)

- U game loopu: za svaki computer realm poziv `ComputerLordAI.decideNextAction(gameState)`.
- Implementirati jednostavne odluke (gradi X ako ima resurse, napadaj Y) dok se ne uključi model; snapshot već ima sve potrebno za input.

---

## Sljedeći konkretni korak

Implementirati **GameplayTick** (timer u GameState ili poseban servis) koji:

1. Pokreće se kad `isLevelReady && isSoloMode`, npr. svakih 12 sekundi.
2. Računa proizvodnju iz `gameMap.placements`: po `objectId` broji zgrade i dodaje resurse/hranu u `GameState.resources` i `GameState.food`/`hay`/`hop`.
3. (Opcionalno) Računa “populaciju” i kapacitet iz zgrada i ažurira `GameState` vrijednosti koje HUD koristi za `hudScoreCurrent` / `hudScoreMax`.
4. Povećava `currentTurn` za 1.

Time se gameplay fokusira na **ekonomiju i osjećaj napretka** bez odmah uvodenja borbe ili AI.
