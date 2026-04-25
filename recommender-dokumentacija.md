# Recommender dokumentacija (EasyPark)

## Pregled

EasyPark koristi **content-based preporuke** za parking lokacije na osnovu prethodnih zavrsenih rezervacija korisnika.

Implementacija je u:
- `backend/EasyPark.Services/Services/ParkingLocationService.cs` (`GetRecommendationScores`)
- Endpoint: `GET /ParkingLocation/recommendations`

## Ulazni podaci

Algoritam koristi:
- historiju korisnika: samo rezervacije sa statusom `Completed`
- aktivne parking lokacije (`IsActive = true`)
- opcione koordinate korisnika (`latitude`, `longitude`) za distance boost

Ako korisnik nema nijednu zavrsenu rezervaciju, servis vraca prazan skup score-ova.

## Signali i skor

### 1) Preference iz historije korisnika

Iz lokacija koje je korisnik ranije koristio izracunavaju se prosjecne preferencije za:
- `HasVideoSurveillance`
- `HasNightSurveillance`
- disabled mjesta (preko aktivnih spotova tipa `Disabled`)
- `HasRamp`
- `Is24Hours`
- `HasOnlinePayment`
- electric punjenje (aktivni spotovi tipa `Electric`)
- covered mjesta (aktivni spotovi tipa `Covered`)
- `HasSecurityGuard`
- `HasWifi`
- `HasRestroom`
- `HasAttendant`
- prosjecna cijena (`PricePerHour`)

### 2) Match score po lokaciji

Za svaku aktivnu lokaciju:
- svaki feature-match nosi `+0.08` (12 feature-a)
- similarity cijene nosi do `+0.20`
- rezultat se normalizuje i ogranicava na `[0, 1]`

### 3) Distance faktor (opciono)

Ako su poslane koordinate korisnika:
- racuna se Haversine udaljenost
- blize lokacije dobijaju dodatni boost do `+0.16`
- za 10+ km distance boost je 0
- finalni skor ostaje ogranicen na `[0, 1]`

## Izlaz

Endpoint vraca mapu:
- `key`: `ParkingLocationId`
- `value`: decimalni recommendation score (`0.0 - 1.0`)

Napomena: trenutna implementacija ne vraca textual explanation (`reasons`), vec samo score.

## Persistencija i treniranje modela

Nema zasebnog ML modela niti offline treniranja.
Recommender se racuna on-demand direktno iz produkcionih tabela:
- `Reservations`
- `ParkingSpots`
- `ParkingLocations`

## Ogranicenja trenutne implementacije

- nema cold-start fallback rankinga (npr. popularnost) kada korisnik nema historiju
- nema explainability payload-a u API odgovoru
- nema perzistencije preporuka; score se racuna pri svakom pozivu
