# Recommender Documentation (EasyPark)

## Overview

EasyPark uses a **content-based recommendation** strategy for parking locations.

Implementation:
- Service method: `backend/EasyPark.Services/Services/ParkingLocationService.cs` -> `GetRecommendationScores`
- API endpoint: `GET /ParkingLocation/recommendations`

Query parameters:
- `cityId` (optional)
- `lat`, `lon` (optional, for distance boost)
- `count` (optional, default `3`, clamped to `1..10`)

## Input Data

The recommender uses:
- user reservation history: only reservations with status `Completed`
- user bookmarks (as weaker preference signal)
- active parking locations (`IsActive = true`)
- optional user coordinates (`lat`, `lon`) for proximity bonus

## Cold Start Behavior (No Completed Reservations)

If user has no completed reservations:
- system falls back to top-rated active locations
- ranking uses `AverageRating` descending
- up to `count` results returned
- response still includes explainability text:
  - `CbfExplanation = "Highly rated in your selected city"`

## Scoring Model (Has History)

### 1) User Preference Profile

Profile is built from:
- completed reservation locations (weight `1.0`)
- bookmarked locations (weight `0.5`)

Weighted averages are computed for:
- `HasVideoSurveillance`
- `HasNightSurveillance`
- disabled spot availability (`SpotType == "Disabled"` and active)
- `HasRamp`
- `Is24Hours`
- electric charging availability (`SpotType == "Electric"` and active)
- covered spot availability (`SpotType == "Covered"` and active)
- `HasSecurityGuard`
- `HasWifi`
- `HasRestroom`
- average `PricePerHour`

### 2) Candidate Location Score

For each active candidate location:
- feature similarity: up to `10 * 0.06 = 0.60`
- price similarity: up to `0.15`
- rating component: `(AverageRating / 5.0) * 0.13`
- distance bonus (if `lat/lon` provided):
  - `<= 2 km`: `+0.12`
  - `<= 5 km`: `+0.07`
  - `<= 10 km`: `+0.03`
  - `> 10 km`: `+0`

Final score is clamped to `[0, 1]`, then converted to percent in DTO:
- `CbfScore = round(score * 100)`

## Explainability

API response includes text explanation in `CbfExplanation`.
Possible reasons include:
- `Price fits your preference`
- `Highly rated (...)` / `Well rated (...)` / `Rated (...)`
- `Very close to you` / `Near you`
- `You bookmarked a similar location`
- `Has <feature1>, <feature2>`

## Output Shape

Endpoint returns `List<ParkingLocation>` where each item includes:
- location data
- `CbfScore` (0-100)
- `CbfExplanation` (human-readable reason text)

## Notes

- This is not offline ML training; score is computed on-demand from relational data.
- Main data sources: `Reservations`, `Bookmarks`, `ParkingLocations`, `ParkingSpots`.
- Recommendation count is consumer-configurable via `count` query param.
