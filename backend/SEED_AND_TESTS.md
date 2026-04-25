# Backend Seed & Test Guide

This document explains what seed data exists in backend and what reservation unit tests currently cover.

## Seed Data (DbInitializer)

Seeding runs from `EasyPark.API/Program.cs` after migrations.

### Always seeded / upserted
- `CityCoordinates`
  - Full city list with `City`, `Latitude`, `Longitude`
  - Upsert behavior: existing rows are updated, missing rows are inserted

### Seeded when roles are missing (fresh auth setup)
- Roles:
  - `Admin`
  - `User`
- Users:
  - `desktop` (admin)
  - `mobile` (regular user)

### Parking location seed (idempotent)
- 12 locations total:
  - 10 in Mostar
  - 1 in Sarajevo
  - 1 in Velika Kladuša
- 1-2 parking spots per location for easier availability testing
- Every location has at least one `Regular` spot
- Mixed availability of `Disabled`, `Electric`, and `Covered` spot types
- Mixed recommendation attributes (`Is24Hours`, `HasVideoSurveillance`, etc.) for CBF testing

## Reservation Unit Tests

Main file: `EasyPark.Tests/Services/ReservationServiceTests.cs`

### Covered scenarios
- Invalid references:
  - parking spot not found
  - inactive parking spot
- Time validation:
  - end <= start
  - start time in the past
- Authentication / authorization:
  - missing user claims (unauthorized)
  - non-owner `GetById` forbidden
  - admin `GetById` allowed
- Balance:
  - insufficient coins
- Auto-assignment validation:
  - missing `SpotType`
  - missing `ParkingLocationId`
  - no active spots for requested type
  - all spots of requested type reserved
- Overlap logic:
  - overlap with active reservation blocks
  - cancelled/expired reservations do not block
- Update validation:
  - invalid status value
  - non-owner update forbidden
  - update time overlap blocked
- Happy path:
  - successful insert calculates price and sets pending status

### Run reservation test suite

```powershell
dotnet test backend/EasyPark.Tests/EasyPark.Tests.csproj --filter "FullyQualifiedName~ReservationServiceTests"
```

## Notes
- For deterministic local testing, run backend with migration + seeding, then run tests.
- If you only changed seed values, backend restart is enough (no DB wipe required due to upsert logic for cities and idempotent parking seed).

