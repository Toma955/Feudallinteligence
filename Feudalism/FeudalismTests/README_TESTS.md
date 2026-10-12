# Unit testovi – Feudalism

## Struktura

- **FeudalismTests** koristi Swift Testing (`import Testing`, `@Test`, `#expect`).
- Testovi su podijeljeni po modulima u zasebne datoteke:
  - `GameResourcesTests.swift` – zalihe, add/subtract, canAfford, reset, subtractForBuilding
  - `BuildCostAndResourceStockTests.swift` – BuildCost, ResourceStock, BuildCosts.shared
  - `HUDResourceCatalogTests.swift` – sadržaj traka (solo, resources, weapons, food)
  - `ResourceAmountPerTickTests.swift` – hasAny, hasConsumption, equality

## Što testirati sljedeće

1. **ObjectBehaviorRegistry** – `behavior(for: objectId)` za poznate objekte (npr. zid, dvorac), `maxHealth`, `transformsResources`.
2. **GameState** – `resourceValue(for: id)` za "gold", "stone", itd. (potrebna instanca GameState s postavljenim `resources`).
3. **ProductionConsumptionCatalog** – broj producers/consumers/transformers, `entry(for: objectId)`.
4. **MapCatalog / MapSizePreset** – `entries(forSide:)`, preseti.
5. **GameMap** – `setPlacementHealth`, `applyDamage` (ako želiš testirati logiku oštećenja).

## Pokretanje

U Xcodeu: **Product → Test** (⌘U), ili desni klik na FeudalismTests → Run Tests.

## Pravila

- Jedan `@Suite` po datoteci (po želji), više `@Test` funkcija.
- Koristi `@testable import Feudalism` da vidiš internal API.
- Za ovisnosti (npr. GameState) koristi stvarne instance ili, ako zatreba, dependency injection (npr. GameState(resources: mockResources)).
