# Spandaula

*– klassens frækkeste krumme*

> **English summary:** Spandaula is an unofficial, hobbyist Flutter client for [Aula](https://www.aula.dk/), the Danish school/daycare communication platform. It is **not affiliated with, endorsed by, or sponsored by KOMBIT, Netcompany, MitID, or any school authority**. Released as a proof-of-concept under the MIT license — use at your own risk. See [Disclaimer](#disclaimer).

## Hvad er det her?

Spandaula er en alternativ Aula-klient til de forældre, der har mistet troen på at den officielle app nogensinde bliver federe. Bygget i Flutter, så den kan være langsom på *alle* platforme.

Det er et hobbyprojekt og en proof-of-concept. Det er **ikke** en officiel klient og har intet med KMD, Netcompany, MitID eller nogen skole at gøre.

## Features

- **Login via MitID** - Ja, det virker!
- **Læs beskeder** - Se alle de beskeder du har glemt at svare på, en smule hurtigere
- **Skriv beskeder** - Undskyld til læreren at Emil ikke havde madpakke med
- **Se opslagstavlen** - Hold dig opdateret med de 47 ugentlige påmindelser om hovedlus
- **Sygemelding** - Meld barnet syg hurtigere end du kan nå overhovedat at overveje en spandauer

## Kom i gang

```bash
flutter pub get
dart run build_runner build
flutter run
```

Kør i demo-mode (uden rigtig Aula-login):

```bash
flutter run --dart-define=DEMO_MODE=true
```

## Hvorfor?

Fordi vi ville have en app der:
- Starter inden solen går ned
- Ikke crasher når man åbner en besked
- Kan melde barnet syg ekstra hurtigt
- Har et multiplayer-spil som alle platforme burde ha

## Teknisk snak

Appen bruger en WebView til MitID/WAYF-login og router efterfølgende API-kald gennem den samme WebView for at kunne bruge HttpOnly-session-cookies. Se [docs/authentication.md](docs/authentication.md) for detaljer.

## Disclaimer

Spandaula er et **uofficielt hobbyprojekt** og en proof-of-concept. Det er ikke udviklet, godkendt eller sponsoreret af KMD, Netcompany, MitID, kommuner, skoler eller nogen anden Aula-aktør. "Aula" er et varemærke tilhørende sine respektive ejere; navnet og logoer bruges udelukkende beskrivende.

Brug på eget ansvar. Vi giver ingen garantier for:
- At det virker (eller bliver ved med at virke — Aulas API kan ændre sig når som helst)
- At din login-session, dine cookies eller dine data håndteres sikkert nok til dine behov
- At brugen er i overensstemmelse med Aulas servicevilkår — det er dit eget ansvar at tjekke
- Glemte forældremøder, ubesvarede beskeder eller eksistentiel krise når du indser hvor mange ulæste beskeder du har

Slutbrugere er selv ansvarlige for deres egne MitID-credentials, session-cookies og eventuelle data appen får adgang til. Hvis du bidrager til projektet: commit aldrig rigtige bruger-data, navne, billeder eller andre persondata. Se `tools/sanitize_demo_data.dart`.

## Bidrag

Pull requests modtages med kyshånd. Issues også, men vi lover intet.

Quick checklist før du opretter en PR:

1. `flutter analyze` skal være clean
2. `flutter test` skal passe
3. Ingen rigtige persondata i commits (kør `tools/sanitize_demo_data.dart` hvis du opdaterer demo-data)
4. Hold ændringer fokuserede — én ting per PR

## Licens

MIT — se [LICENSE](LICENSE).

---

*Spandaula - fordi alt er lidt bedre med en spandauer.*
