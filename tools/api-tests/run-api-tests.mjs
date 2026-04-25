#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const DEFAULT_CONFIG_PATH = path.resolve(
  process.cwd(),
  'tools',
  'api-tests',
  'config.local.json',
);

const tinyJpegBase64 =
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wCEAAkGBxAQEBAQEBIQEA8PDw8PEA8PDw8PDw8QFREWFhURFRUYHSggGBolGxUVITEhJSkrLi4uFx8zODMtNygtLisBCgoKDg0OGhAQGy0lICUtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLf/AABEIAAEAAQMBIgACEQEDEQH/xAAXAAEBAQEAAAAAAAAAAAAAAAAAAQID/8QAFhEBAQEAAAAAAAAAAAAAAAAAAAER/9oADAMBAAIQAxAAAAHjA//EABgQAQEAAwAAAAAAAAAAAAAAAAEAERAh/9oACAEBAAEFAmVqv//EABQRAQAAAAAAAAAAAAAAAAAAABD/2gAIAQMBAT8BP//EABQRAQAAAAAAAAAAAAAAAAAAABD/2gAIAQIBAT8BP//EABkQAQADAQEAAAAAAAAAAAAAAAEAESExUf/aAAgBAQAGPwLJr2r/xAAaEAEAAwEBAQAAAAAAAAAAAAABABEhMUFh/9oACAEBAAE/IWSyl0MJSVQ7d5//2gAMAwEAAgADAAAAED//xAAVEQEBAAAAAAAAAAAAAAAAAAAQIf/aAAgBAwEBPxBf/8QAFBEBAAAAAAAAAAAAAAAAAAAAEP/aAAgBAgEBPxB//8QAHBABAAMAAgMAAAAAAAAAAAAAAREAITFBYXGR/9oACAEBAAE/EMNLsG2Yz0x9mXqIrj6VpS5oE7S3/9k=';

const ANSI = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  gray: '\x1b[90m',
};

let requestCounter = 0;

function parseArgs(argv) {
  const args = {
    suite: 'all',
    config: DEFAULT_CONFIG_PATH,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--suite' && argv[i + 1]) {
      args.suite = argv[i + 1];
      i += 1;
      continue;
    }
    if (token === '--config' && argv[i + 1]) {
      args.config = path.resolve(process.cwd(), argv[i + 1]);
      i += 1;
      continue;
    }
  }

  return args;
}

function loadConfig(configPath) {
  if (!fs.existsSync(configPath)) {
    throw new Error(
      `Config not found: ${configPath}. Copy tools/api-tests/config.example.json to config.local.json first.`,
    );
  }

  const raw = fs.readFileSync(configPath, 'utf8');
  const parsed = JSON.parse(raw);
  const baseUrl = (parsed.baseUrl || '').replace(/\/+$/, '');

  if (!baseUrl) {
    throw new Error('Config missing baseUrl.');
  }

  return {
    baseUrl,
    desktop: parsed.desktop ?? {},
    mobile: parsed.mobile ?? {},
  };
}

async function requestJson({
  baseUrl,
  method,
  endpoint,
  headers = {},
  body,
  expectedStatus = 200,
  name,
}) {
  requestCounter += 1;
  const requestNo = requestCounter;
  const url = `${baseUrl}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;
  const finalHeaders = {
    'Content-Type': 'application/json',
    ...headers,
  };

  const payloadPreview =
    body === undefined ? '(none)' : JSON.stringify(body, null, 2).slice(0, 700);

  console.log(
    `${ANSI.cyan}${ANSI.bold}[${requestNo}]${ANSI.reset} ${ANSI.yellow}${method}${ANSI.reset} ${url}`,
  );
  console.log(`${ANSI.gray}    name:${ANSI.reset} ${name}`);
  console.log(`${ANSI.gray}    payload:${ANSI.reset} ${payloadPreview}`);

  const start = Date.now();
  const response = await fetch(url, {
    method,
    headers: finalHeaders,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  const elapsedMs = Date.now() - start;
  const text = await response.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }

  if (response.status !== expectedStatus) {
    console.log(
      `${ANSI.red}${ANSI.bold}    FAIL${ANSI.reset} expected=${expectedStatus} actual=${response.status} time=${elapsedMs}ms`,
    );
    console.log(
      `${ANSI.red}    response:${ANSI.reset} ${JSON.stringify(data, null, 2).slice(0, 1200)}`,
    );
    throw new Error(`${name} failed (${method} ${endpoint})`);
  }

  console.log(
    `${ANSI.green}${ANSI.bold}    SUCCESS${ANSI.reset} status=${response.status} time=${elapsedMs}ms`,
  );
  console.log(
    `${ANSI.green}    response:${ANSI.reset} ${JSON.stringify(data, null, 2).slice(0, 700)}`,
  );
  return data;
}

async function runDesktopSuite(config) {
  console.log('\n--- DESKTOP SUITE ---');

  const login = await requestJson({
    baseUrl: config.baseUrl,
    method: 'POST',
    endpoint: '/User/login',
    headers: {
      'X-Client-Type': 'desktop',
    },
    body: {
      username: config.desktop.username,
      password: config.desktop.password,
    },
    expectedStatus: 200,
    name: 'Desktop login',
  });

  const accessToken = login?.accessToken;
  const refreshToken = login?.refreshToken;
  if (!accessToken || !refreshToken) {
    throw new Error('Desktop login missing accessToken/refreshToken.');
  }

  const authHeaders = {
    Authorization: `Bearer ${accessToken}`,
    'X-Client-Type': 'desktop',
  };

  const locations = await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: '/ParkingLocation?page=0&pageSize=5&city=Mostar',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Desktop get parking locations',
  });

  const target =
    locations?.resultList?.find((x) => x?.id === config.desktop.updateLocationId) ??
    locations?.resultList?.[0];
  if (!target?.id) {
    throw new Error('No parking location found for desktop update test.');
  }

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'PUT',
    endpoint: `/ParkingLocation/${target.id}`,
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Desktop update parking location (photo + payload)',
    body: {
      name: target.name,
      address: target.address,
      cityId: target.cityId,
      description: `API test update ${new Date().toISOString()}`,
      latitude: target.latitude,
      longitude: target.longitude,
      pricePerHour: target.pricePerHour ?? 3,
      priceRegular: target.priceRegular ?? 3,
      priceDisabled: target.priceDisabled ?? 2,
      priceElectric: target.priceElectric ?? 4,
      priceCovered: target.priceCovered ?? 5,
      hasVideoSurveillance: target.hasVideoSurveillance ?? true,
      hasNightSurveillance: target.hasNightSurveillance ?? true,
      hasRamp: target.hasRamp ?? false,
      is24Hours: target.is24Hours ?? true,
      hasOnlinePayment: target.hasOnlinePayment ?? true,
      hasSecurityGuard: target.hasSecurityGuard ?? true,
      hasWifi: target.hasWifi ?? true,
      hasRestroom: target.hasRestroom ?? true,
      hasAttendant: target.hasAttendant ?? false,
      isActive: target.isActive ?? true,
      photo: tinyJpegBase64,
    },
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: '/ParkingSpot?page=0&pageSize=5&parkingLocationId=1',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Desktop get parking spots',
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: '/ReservationHistory?page=0&pageSize=5',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Desktop get reservation history',
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: '/Report?page=0&pageSize=5',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Desktop get reports',
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'POST',
    endpoint: '/User/logout',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Desktop logout',
    body: { refreshToken },
  });
}

async function runMobileSuite(config) {
  console.log('\n--- MOBILE SUITE ---');

  const login = await requestJson({
    baseUrl: config.baseUrl,
    method: 'POST',
    endpoint: '/User/login',
    headers: {
      'X-Client-Type': 'mobile',
    },
    body: {
      username: config.mobile.username,
      password: config.mobile.password,
    },
    expectedStatus: 200,
    name: 'Mobile login',
  });

  const accessToken = login?.accessToken;
  const refreshToken = login?.refreshToken;
  const userId = login?.user?.id;
  if (!accessToken || !refreshToken || !userId) {
    throw new Error('Mobile login missing accessToken/refreshToken/user.id.');
  }

  const authHeaders = {
    Authorization: `Bearer ${accessToken}`,
    'X-Client-Type': 'mobile',
  };

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: '/ParkingLocation?page=0&pageSize=10&city=Mostar',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Mobile get parking locations',
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: '/ParkingLocation/recommendations',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Mobile get recommendations',
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: '/Reservation?page=0&pageSize=5',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Mobile get reservations',
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: `/Notification?page=0&pageSize=10&userId=${userId}`,
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Mobile get notifications',
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: `/Bookmark?page=0&pageSize=10&userId=${userId}`,
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Mobile get bookmarks',
  });

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'POST',
    endpoint: '/User/logout',
    headers: authHeaders,
    expectedStatus: 200,
    name: 'Mobile logout',
    body: { refreshToken },
  });
}

async function main() {
  const { suite, config: configPath } = parseArgs(process.argv.slice(2));
  const config = loadConfig(configPath);

  await requestJson({
    baseUrl: config.baseUrl,
    method: 'GET',
    endpoint: '/ParkingLocation?page=0&pageSize=1',
    expectedStatus: 200,
    name: 'Anonymous smoke',
  });

  if (suite === 'desktop' || suite === 'all') {
    await runDesktopSuite(config);
  }

  if (suite === 'mobile' || suite === 'all') {
    await runMobileSuite(config);
  }

  console.log(`\n${ANSI.green}${ANSI.bold}ALL REQUESTS PASSED.${ANSI.reset}`);
}

main().catch((err) => {
  console.error(`\n${ANSI.red}${ANSI.bold}API TEST FAILED.${ANSI.reset}`);
  console.error(`${ANSI.red}${err.message}${ANSI.reset}`);
  process.exit(1);
});
