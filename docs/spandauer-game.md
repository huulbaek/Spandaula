# Spandauer - Et socialt deduktionsspil

Spandauer er et Mafia/Werewolf-lignende spil indbygget i Spandaula-appen. Spillet bruger Aulas beskedsystem som transport- og lagringsmekanisme, hvilket betyder at spillere får notifikationer via Aula når det er deres tur.

## Koncept

Spillet foregår i en landsby hvor nogle af beboerne hemmeligt er **Spandauere** (🥐) - ondskabsfulde wienerbrød der spiser landsbyboerne om natten. Landsbyboerne skal finde og stemme spandauerne ud, før de bliver spist.

## Roller

| Rolle | Emoji | Hold | Beskrivelse |
|-------|-------|------|-------------|
| **Landsbyboer** | 👨‍🌾 | Landsbyen | Stem spandauerne ud af landsbyen |
| **Spandauer** | 🥐 | Spandauere | Spis landsbyboerne om natten uden at blive opdaget |
| **Seer** | 👁️ | Landsbyen | Undersøg én spiller hver nat for at finde spandauerne |
| **Heler** | 💚 | Landsbyen | Beskyt én spiller hver nat mod spandauernes angreb |
| **Jæger** | 🏹 | Landsbyen | Når du dør, kan du tage én spiller med dig i graven |

## Spillets gang

### Nat-fase 🌙
1. Alle spillere "sover"
2. **Spandauerne** vælger hvem de vil spise
3. **Seeren** (hvis i live) undersøger én spiller
4. **Heleren** (hvis i live) beskytter én spiller

### Dag-fase ☀️
1. Spillerne vågner og ser hvem der blev spist i nat
2. Diskussion og mistanke
3. Afstemning - spilleren med flest stemmer bliver stemt ud
4. Rollen på den udstemte spiller afsløres

### Vinderbetingelser
- **Landsbyboerne vinder** når alle spandauere er elimineret
- **Spandauerne vinder** når de er lige så mange eller flere end landsbyboerne

## Anbefalet rollefordeling

| Spillere | Spandauere | Seer | Heler | Jæger |
|----------|------------|------|-------|-------|
| 5-6 | 1 | ✓ | - | - |
| 7-8 | 2 | ✓ | ✓ | - |
| 9-10 | 2 | ✓ | ✓ | ✓ |
| 11+ | 3 | ✓ | ✓ | ✓ |

## Teknisk arkitektur

### Hvordan det virker

Spillet bruger Aulas eksisterende beskedsystem som "database" og transport:

```
┌─────────────────────────────────────────────────────┐
│  Aula Backend (uændret)                             │
│  - Gemmer beskeder                                  │
│  - Sender push-notifikationer                       │
│  - Håndterer tråd-deltagere                         │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  Beskedtråd                                         │
│  ┌───────────────────────────────────────────────┐  │
│  │ 🎮eyJ2IjoxLCJnIjoic3BfMTIzIiwidCI6InZvdGUi... │  │
│  │  ↳ Menneske ser: mærkeligt emoji-rod          │  │
│  │  ↳ Spandaula ser: VOTE event, spiller stemte  │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  Spandaula App                                      │
│  - Parser beskeder for spil-kommandoer              │
│  - Viser spil-UI med roller og handlinger           │
│  - Sender kodede beskeder for spil-træk             │
└─────────────────────────────────────────────────────┘
```

### Beskedprotokol

Alle spilbeskeder starter med `🎮` efterfulgt af base64-kodet JSON:

```
🎮eyJ2IjoxLCJnIjoic3BfYWJjMTIzIiwidCI6InZvdGUiLCJkIjp7InRhcmdldElkIjo0Mn0sInRzIjoiMjAyNC0wMS0xNVQxMjowMDowMFoifQ==
```

Dekodet:
```json
{
  "v": 1,
  "g": "sp_abc123",
  "t": "vote",
  "d": {"targetId": 42},
  "ts": "2024-01-15T12:00:00Z"
}
```

### Rolletildeling og hemmeligholdelse

Roller krypteres per-spiller, så kun den pågældende spiller kan se sin egen rolle:

```dart
// Hver spillers rolle krypteres med deres ID + spil-salt
encryptedRoles: {
  "player_1": "krypteret_blob_1", // Kun spiller 1 kan læse
  "player_2": "krypteret_blob_2", // Kun spiller 2 kan læse
}
```

### Event-typer

| Event | Beskrivelse |
|-------|-------------|
| `gameCreated` | Spil oprettet med spillerliste |
| `rolesAssigned` | Roller tildelt (krypteret) |
| `nightStarted` | Nat-fase begynder |
| `dayStarted` | Dag-fase begynder |
| `spandauerKill` | Spandauer vælger offer |
| `seerInvestigate` | Seer undersøger spiller |
| `healerProtect` | Heler beskytter spiller |
| `vote` | Spiller stemmer |
| `playerKilled` | Spiller dræbt om natten |
| `playerLynched` | Spiller stemt ud |
| `gameEnded` | Spil slut med vinder |

## Filstruktur

```
lib/features/games/
├── models/
│   ├── game_enums.dart      # GamePhase, Role, Team, etc.
│   ├── game_event.dart      # Event-klasse med factories
│   ├── game_player.dart     # Spiller-tilstand
│   ├── spandauer_game.dart  # Fuld spiltilstand
│   └── models.dart          # Barrel export
├── protocol/
│   ├── spandauer_protocol.dart  # Encode/decode beskeder
│   ├── role_encryption.dart     # Rollekryptering
│   └── protocol.dart            # Barrel export
├── engine/
│   ├── spandauer_engine.dart    # Tilstandsrekonstruktion
│   └── engine.dart              # Barrel export
├── providers/
│   └── games_provider.dart      # Riverpod providers
└── screens/
    ├── games_list_screen.dart   # Spilliste
    ├── create_game_screen.dart  # Opret nyt spil
    ├── game_view_screen.dart    # Spilvisning
    └── widgets/
        ├── role_card.dart       # Vis din rolle
        ├── player_circle.dart   # Spilleroversigt
        ├── action_panel.dart    # Handlingsknapper
        └── game_log.dart        # Eventlog
```

## Fremtidige udvidelser

- [ ] Timer på faser (automatisk faseovergang)
- [ ] Flere roller (Cupid, Witch, etc.)
- [ ] Seer-resultat visning
- [ ] Jæger-hævn implementation
- [ ] Spilstatistik og leaderboard
- [ ] Lyd-effekter for fase-overgange
