# EasyPark CLI API tests

Run all frontend-relevant API flows from CMD, no GUI tools.

## 1) Prepare local config

Copy:

`tools/api-tests/config.example.json` -> `tools/api-tests/config.local.json`

Adjust credentials/baseUrl if needed.

## 2) Run tests from CMD

All suites:

`node tools/api-tests/run-api-tests.mjs --suite all`

Desktop only:

`node tools/api-tests/run-api-tests.mjs --suite desktop`

Mobile only:

`node tools/api-tests/run-api-tests.mjs --suite mobile`

Custom config path:

`node tools/api-tests/run-api-tests.mjs --suite all --config tools/api-tests/config.local.json`
