<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Emergency SOS Tracking</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <!-- MapLibre GL JS CSS -->
    <link
        rel="stylesheet"
        href="https://unpkg.com/maplibre-gl/dist/maplibre-gl.css"
    />

    <style>

        :root {
            --danger: #ef4444;
            --danger-dark: #b91c1c;
            --bg: #0b1120;
            --bg-deep: #08101e;
            --card: #111827;
            --card-soft: #162033;
            --field: #0f172a;
            --border: #243041;
            --border-strong: #2b3a52;
            --primary: #f8fafc;
            --muted: #94a3b8;
            --soft-text: #cbd5e1;
            --success: #22c55e;
            --warning: #f59e0b;
            --map-blue: #3b82f6;
            --shadow: 0 18px 34px rgba(0, 0, 0, 0.28);
            --radius-lg: 28px;
            --radius-md: 20px;
        }

        * {
            box-sizing: border-box;
        }

        body {
            margin: 0;
            font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Arial, sans-serif;
            background:
                radial-gradient(circle at top left, rgba(239, 68, 68, 0.14), transparent 30%),
                radial-gradient(circle at bottom right, rgba(59, 130, 246, 0.10), transparent 34%),
                linear-gradient(180deg, var(--bg-deep), var(--bg), #111827);
            color: var(--primary);
            min-height: 100vh;
        }

        .page {
            width: 100%;
            min-height: 100vh;
            padding: 18px;
        }

        .container {
            width: 100%;
            max-width: 900px;
            margin: 0 auto;
        }

        .hero-card {
            background: linear-gradient(135deg, #0f172a, #111827, #172033);
            color: white;
            border-radius: 32px;
            padding: 24px;
            box-shadow: 0 24px 48px rgba(0, 0, 0, 0.32);
            margin-bottom: 18px;
            overflow: hidden;
            position: relative;
            border: 1px solid var(--border);
        }

        .hero-card::after {
            content: "";
            position: absolute;
            width: 230px;
            height: 230px;
            border-radius: 50%;
            background: rgba(239, 68, 68, 0.12);
            right: -92px;
            top: -92px;
        }

        .hero-card::before {
            content: "";
            position: absolute;
            width: 160px;
            height: 160px;
            border-radius: 50%;
            background: rgba(59, 130, 246, 0.08);
            left: -70px;
            bottom: -70px;
        }

        .hero-content {
            position: relative;
            z-index: 2;
        }

        .hero-top {
            display: flex;
            align-items: center;
            gap: 16px;
            margin-bottom: 18px;
        }

        .hero-icon {
            width: 70px;
            height: 70px;
            border-radius: 24px;
            background: rgba(239, 68, 68, 0.16);
            border: 1px solid rgba(239, 68, 68, 0.35);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 35px;
            flex-shrink: 0;
            box-shadow: 0 0 32px rgba(239, 68, 68, 0.22);
        }

        .title {
            font-size: 30px;
            font-weight: 900;
            letter-spacing: -0.6px;
            margin: 0;
            line-height: 1.08;
            color: var(--primary);
        }

        .subtitle {
            margin: 8px 0 0;
            color: var(--soft-text);
            line-height: 1.55;
            font-size: 15px;
            max-width: 640px;
            font-weight: 500;
        }

        .status-area {
            margin-top: 18px;
            padding: 16px;
            border-radius: 22px;
            background: rgba(15, 23, 42, 0.72);
            border: 1px solid var(--border);
            backdrop-filter: blur(10px);
        }

        .card {
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: var(--radius-lg);
            padding: 20px;
            box-shadow: var(--shadow);
            margin-bottom: 18px;
        }

        .section-header {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 16px;
        }

        .section-icon {
            width: 46px;
            height: 46px;
            border-radius: 16px;
            background: rgba(239, 68, 68, 0.14);
            color: var(--danger);
            border: 1px solid rgba(239, 68, 68, 0.25);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 23px;
            flex-shrink: 0;
        }

        .section-title {
            font-size: 19px;
            font-weight: 900;
            margin: 0;
            letter-spacing: -0.2px;
            color: var(--primary);
        }

        .section-subtitle {
            color: var(--muted);
            font-size: 13.5px;
            margin: 4px 0 0;
            line-height: 1.4;
            font-weight: 500;
        }

        #map {
            width: 100%;
            height: 420px;
            border-radius: 24px;
            overflow: hidden;
            background: #0f172a;
            border: 1px solid var(--border);
            box-shadow:
                inset 0 0 0 1px rgba(255, 255, 255, 0.03),
                0 16px 28px rgba(0, 0, 0, 0.20);
        }

        .maplibregl-ctrl-group {
            background: rgba(17, 24, 39, 0.96) !important;
            border: 1px solid var(--border) !important;
            box-shadow: 0 10px 24px rgba(0, 0, 0, 0.35) !important;
        }

        .maplibregl-ctrl-group button {
            width: 34px;
            height: 34px;
            background: rgba(17, 24, 39, 0.96) !important;
            color: var(--primary) !important;
        }

        .maplibregl-ctrl button .maplibregl-ctrl-icon {
            filter: invert(1);
        }

        .map-layer-control {
            background: rgba(17, 24, 39, 0.96);
            border: 1px solid var(--border);
            border-radius: 14px;
            box-shadow: 0 12px 26px rgba(0, 0, 0, 0.36);
            padding: 7px;
            font-family: inherit;
            width: 132px;
            pointer-events: auto;
            user-select: none;
            backdrop-filter: blur(10px);
        }

        .map-layer-control-title {
            font-size: 11px;
            font-weight: 900;
            color: var(--muted);
            margin: 2px 5px 6px;
        }

        .map-layer-option {
            width: 100%;
            border: none;
            background: transparent;
            padding: 8px 9px;
            border-radius: 10px;
            text-align: left;
            font-size: 12px;
            font-weight: 800;
            color: var(--soft-text);
            cursor: pointer;
            line-height: 1.1;
        }

        .map-layer-option:hover {
            background: rgba(255, 255, 255, 0.06);
        }

        .map-layer-option.active {
            background: rgba(239, 68, 68, 0.15);
            color: var(--danger);
        }

        .map-center-control {
            width: 34px;
            height: 34px;
            border: none;
            background: rgba(17, 24, 39, 0.96) !important;
            color: var(--danger) !important;
            font-size: 17px;
            font-weight: 900;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .map-center-control:hover {
            background: rgba(239, 68, 68, 0.14) !important;
        }

        .sos-map-marker {
            width: 28px;
            height: 28px;
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .status {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 9px 14px;
            border-radius: 999px;
            font-weight: 900;
            margin-bottom: 12px;
            font-size: 13px;
            letter-spacing: 0.4px;
            border: 1px solid currentColor;
        }

        .status::before {
            content: "";
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: currentColor;
        }

        .active {
            background: rgba(34, 197, 94, 0.13);
            color: var(--success);
        }

        .cancelled {
            background: rgba(239, 68, 68, 0.13);
            color: var(--danger);
        }

        .expired {
            background: rgba(245, 158, 11, 0.13);
            color: var(--warning);
        }

        .health-alert {
            margin-top: 12px;
            padding: 14px;
            border-radius: 18px;
            border: 1px solid var(--border);
            background: var(--field);
        }

        .health-title {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 15px;
            font-weight: 900;
            color: var(--primary);
            margin-bottom: 6px;
        }

        .health-message {
            color: var(--soft-text);
            font-size: 13.5px;
            line-height: 1.5;
            font-weight: 600;
        }

        .health-fresh {
            background: rgba(34, 197, 94, 0.13);
            border-color: rgba(34, 197, 94, 0.24);
        }

        .health-delayed {
            background: rgba(245, 158, 11, 0.13);
            border-color: rgba(245, 158, 11, 0.24);
        }

        .health-stale,
        .health-critical-stale {
            background: rgba(239, 68, 68, 0.13);
            border-color: rgba(239, 68, 68, 0.24);
        }

        .health-stopped,
        .health-expired,
        .health-waiting {
            background: rgba(148, 163, 184, 0.12);
            border-color: rgba(148, 163, 184, 0.22);
        }

        .status-meta {
            font-size: 14px;
            line-height: 1.5;
            color: var(--soft-text);
            font-weight: 600;
        }

        .status-meta strong {
            color: var(--primary);
        }

        .profile-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 12px;
        }

        .info-row {
            padding: 14px;
            background: var(--field);
            border: 1px solid var(--border);
            border-radius: 18px;
            line-height: 1.4;
        }

        .label {
            font-weight: 800;
            display: block;
            color: var(--muted);
            font-size: 12.5px;
            margin-bottom: 5px;
        }

        .value {
            font-size: 15px;
            color: var(--primary);
            font-weight: 700;
            word-break: break-word;
        }

        .button-row {
            display: grid;
            grid-template-columns: 1fr;
            gap: 10px;
            margin-top: 16px;
        }

        .button,
        .secondary-button,
        .outline-button {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            text-align: center;
            text-decoration: none;
            padding: 15px 16px;
            border-radius: 16px;
            font-weight: 900;
            font-size: 15px;
            transition: transform 0.15s ease, box-shadow 0.15s ease, opacity 0.15s ease;
            cursor: pointer;
        }

        .button {
            background: var(--danger);
            color: white;
            box-shadow: 0 12px 24px rgba(239, 68, 68, 0.26);
        }

        .secondary-button {
            background: var(--field);
            color: var(--primary);
            border: 1px solid var(--border);
            box-shadow: 0 12px 24px rgba(0, 0, 0, 0.20);
        }

        .outline-button {
            background: var(--field);
            color: #fca5a5;
            border: 1px solid rgba(239, 68, 68, 0.38);
        }

        .button:hover,
        .secondary-button:hover,
        .outline-button:hover {
            transform: translateY(-1px);
        }

        .small {
            font-size: 13.5px;
            color: var(--muted);
            margin-top: 12px;
            line-height: 1.55;
            font-weight: 500;
        }

        .error {
            color: #fca5a5;
            font-weight: 800;
            line-height: 1.5;
        }

        .map-actions {
            margin-top: 14px;
        }

        .tracking-card {
            display: grid;
            gap: 12px;
        }

        .tracking-info {
            display: flex;
            align-items: flex-start;
            gap: 12px;
            padding: 14px;
            border-radius: 18px;
            background: var(--field);
            border: 1px solid var(--border);
        }

        .tracking-info-icon {
            width: 40px;
            height: 40px;
            border-radius: 14px;
            background: rgba(34, 197, 94, 0.12);
            color: var(--success);
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            font-size: 21px;
        }

        .tracking-info-title {
            font-weight: 900;
            color: var(--primary);
            font-size: 14.5px;
            margin-bottom: 3px;
        }

        .tracking-info-text {
            color: var(--muted);
            line-height: 1.45;
            font-size: 13.5px;
            font-weight: 500;
        }

        .pulse {
            width: 20px;
            height: 20px;
            background: var(--danger);
            border-radius: 50%;
            border: 4px solid white;
            box-shadow: 0 0 0 rgba(239, 68, 68, 0.4);
            animation: pulse 1.5s infinite;
        }

        @keyframes pulse {
            0% {
                box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.65);
            }
            70% {
                box-shadow: 0 0 0 18px rgba(239, 68, 68, 0);
            }
            100% {
                box-shadow: 0 0 0 0 rgba(239, 68, 68, 0);
            }
        }

        .loading-line {
            width: 100%;
            height: 14px;
            border-radius: 999px;
            background: linear-gradient(90deg, #0f172a, #1f2937, #0f172a);
            background-size: 200% 100%;
            animation: loading 1.2s infinite;
            border: 1px solid var(--border);
        }

        @keyframes loading {
            0% {
                background-position: 200% 0;
            }
            100% {
                background-position: -200% 0;
            }
        }

        @media (min-width: 640px) {
            .page {
                padding: 28px;
            }

            .hero-card {
                padding: 30px;
            }

            .profile-grid {
                grid-template-columns: 1fr 1fr;
            }

            .full-width {
                grid-column: 1 / -1;
            }

            .button-row {
                grid-template-columns: 1fr 1fr;
            }

            .button-row.three {
                grid-template-columns: 1fr 1fr 1fr;
            }
        }

        @media (max-width: 480px) {
            .page {
                padding: 14px;
            }

            .hero-card,
            .card {
                border-radius: 24px;
            }

            .hero-top {
                align-items: flex-start;
            }

            .hero-icon {
                width: 58px;
                height: 58px;
                border-radius: 20px;
                font-size: 30px;
            }

            .title {
                font-size: 25px;
            }

            #map {
                height: 340px;
                border-radius: 20px;
            }

            .button-row.three {
                grid-template-columns: 1fr;
            }
        }

    </style>
</head>
<body>
<div class="page">
    <div class="container">

        <section class="hero-card">
            <div class="hero-content">
                <div class="hero-top">
                    <div class="hero-icon">🚨</div>
                    <div>
                        <h1 class="title">Emergency SOS Tracking</h1>
                        <p class="subtitle">
                            This page shows the latest shared emergency location and important emergency profile details.
                        </p>
                    </div>
                </div>

                <div class="status-area" id="statusBox">
                    <div class="loading-line"></div>
                    <div class="status-meta" style="margin-top: 10px;">
                        Loading SOS status...
                    </div>
                </div>
            </div>
        </section>

        <section class="card">
            <div class="section-header">
                <div class="section-icon">👤</div>
                <div>
                    <h2 class="section-title">Emergency Profile</h2>
                    <p class="section-subtitle">Important details shared by the person in emergency.</p>
                </div>
            </div>

            <div id="profileDetails">
                <div class="loading-line"></div>
                <div class="small">Loading profile details...</div>
            </div>
        </section>

        <section class="card">
            <div class="section-header">
                <div class="section-icon">📍</div>
                <div>
                    <h2 class="section-title">Live Location</h2>
                    <p class="section-subtitle">Latest available emergency location on map.</p>
                </div>
            </div>

            <div id="map"></div>

            <div id="locationDetails" class="map-actions">
                <div class="small">Loading location...</div>
            </div>
        </section>

        <section class="card">
            <div class="section-header">
                <div class="section-icon">🔄</div>
                <div>
                    <h2 class="section-title">Tracking Information</h2>
                    <p class="section-subtitle">This page updates automatically.</p>
                </div>
            </div>

            <div class="tracking-card">
                <div class="tracking-info">
                    <div class="tracking-info-icon">⏱</div>
                    <div>
                        <div class="tracking-info-title">Auto refresh</div>
                        <div class="tracking-info-text">Every 30 seconds</div>
                    </div>
                </div>

                <div class="tracking-info">
                    <div class="tracking-info-icon">🗺</div>
                    <div>
                        <div class="tracking-info-title">Map movement</div>
                        <div class="tracking-info-text">
                            The marker will move when a new location update is received.
                        </div>
                    </div>
                </div>

                <div class="tracking-info">
                    <div class="tracking-info-icon">📱</div>
                    <div>
                        <div class="tracking-info-title">Keep page open</div>
                        <div class="tracking-info-text">
                            Keep this page open to continuously view updated emergency location.
                        </div>
                    </div>
                </div>
            </div>
        </section>

    </div>
</div>

<!-- MapLibre GL JS -->
<script src="https://unpkg.com/maplibre-gl/dist/maplibre-gl.js"></script>

<script>
    const trackingToken = @json($trackingToken);
    const maxVisibleAccuracyRadiusMeters = 300;

    let map = null;
    let marker = null;
    let latestMapLatitude = null;
    let latestMapLongitude = null;
    let currentMapLayer = 'street';

    const mapLayerIds = [
        'street-layer',
        'satellite-layer',
        'hybrid-satellite-layer',
        'hybrid-labels-layer',
        'terrain-layer',
    ];

    function escapeHtml(value) {
        if (value === null || value === undefined) {
            return '';
        }

        return String(value)
            .replaceAll('&', '&amp;')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .replaceAll('"', '&quot;')
            .replaceAll("'", '&#039;');
    }

    function valueOrNotAdded(value) {
        if (value === null || value === undefined || String(value).trim() === '') {
            return 'Not added';
        }

        return escapeHtml(value);
    }

    function cleanPhone(value) {
        if (!value) {
            return '';
        }

        return String(value).replace(/[^\d+]/g, '');
    }

    function formatDateTime(value) {
        if (!value) {
            return 'Not available';
        }

        const date = new Date(value);

        if (Number.isNaN(date.getTime())) {
            return escapeHtml(value);
        }

        return date.toLocaleString();
    }

    function formatBattery(value) {
        if (value === null || value === undefined || String(value).trim() === '') {
            return 'Not available';
        }

        return `${escapeHtml(value)}%`;
    }

    function formatAgeSeconds(seconds) {
        if (seconds === null || seconds === undefined || Number.isNaN(Number(seconds))) {
            return 'Not available';
        }

        const value = Math.round(Number(seconds));

        if (value < 60) {
            return `${value} second${value === 1 ? '' : 's'} ago`;
        }

        const minutes = Math.round(value / 60);

        if (minutes < 60) {
            return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
        }

        const hours = Math.floor(minutes / 60);
        const remainingMinutes = minutes % 60;

        return `${hours}h ${remainingMinutes}m ago`;
    }

    function formatAccuracy(value) {
        if (value === null || value === undefined || String(value).trim() === '') {
            return 'Not available';
        }

        const accuracy = Math.round(Number(value));

        if (Number.isNaN(accuracy)) {
            return 'Not available';
        }

        return `${accuracy} meter${accuracy === 1 ? '' : 's'}`;
    }

    function getHealthClass(state) {
        switch (state) {
            case 'fresh':
                return 'health-fresh';
            case 'delayed':
                return 'health-delayed';
            case 'stale':
                return 'health-stale';
            case 'critical_stale':
                return 'health-critical-stale';
            case 'stopped':
                return 'health-stopped';
            case 'expired':
                return 'health-expired';
            case 'waiting':
                return 'health-waiting';
            default:
                return 'health-waiting';
        }
    }

    function getHealthIcon(state) {
        switch (state) {
            case 'fresh':
                return '🟢';
            case 'delayed':
                return '🟠';
            case 'stale':
                return '⚠️';
            case 'critical_stale':
                return '🚨';
            case 'stopped':
                return '⛔';
            case 'expired':
                return '⌛';
            case 'waiting':
                return '⏳';
            default:
                return 'ℹ️';
        }
    }

    function getHealthTitle(state) {
        switch (state) {
            case 'fresh':
                return 'Live tracking active';
            case 'delayed':
                return 'Location update delayed';
            case 'stale':
                return 'No recent location update';
            case 'critical_stale':
                return 'Location critically delayed';
            case 'stopped':
                return 'SOS is no longer active';
            case 'expired':
                return 'Tracking link expired';
            case 'waiting':
                return 'Waiting for location';
            default:
                return 'Tracking status';
        }
    }

    function buildGoogleMapsUrl(latitude, longitude) {
        return `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`;
    }

    function createMapStyle() {
        return {
            version: 8,
            sources: {
                street: {
                    type: 'raster',
                    tiles: [
                        'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        'https://c.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ],
                    tileSize: 256,
                    attribution: '&copy; OpenStreetMap contributors',
                },
                satellite: {
                    type: 'raster',
                    tiles: [
                        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    ],
                    tileSize: 256,
                    attribution: 'Tiles &copy; Esri',
                },
                hybridLabels: {
                    type: 'raster',
                    tiles: [
                        'https://a.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
                        'https://b.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
                        'https://c.basemaps.cartocdn.com/rastertiles/voyager_only_labels/{z}/{x}/{y}.png',
                    ],
                    tileSize: 256,
                    attribution: '&copy; CARTO &copy; OpenStreetMap contributors',
                },
                terrain: {
                    type: 'raster',
                    tiles: [
                        'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
                        'https://b.tile.opentopomap.org/{z}/{x}/{y}.png',
                        'https://c.tile.opentopomap.org/{z}/{x}/{y}.png',
                    ],
                    tileSize: 256,
                    attribution: 'Map data: &copy; OpenStreetMap contributors, SRTM | Map style: &copy; OpenTopoMap',
                },
            },
            layers: [
                {
                    id: 'street-layer',
                    type: 'raster',
                    source: 'street',
                    layout: {
                        visibility: 'visible',
                    },
                },
                {
                    id: 'satellite-layer',
                    type: 'raster',
                    source: 'satellite',
                    layout: {
                        visibility: 'none',
                    },
                },
                {
                    id: 'hybrid-satellite-layer',
                    type: 'raster',
                    source: 'satellite',
                    layout: {
                        visibility: 'none',
                    },
                },
                {
                    id: 'hybrid-labels-layer',
                    type: 'raster',
                    source: 'hybridLabels',
                    layout: {
                        visibility: 'none',
                    },
                },
                {
                    id: 'terrain-layer',
                    type: 'raster',
                    source: 'terrain',
                    layout: {
                        visibility: 'none',
                    },
                },
            ],
        };
    }

    function setMapLayer(layerName) {
        if (!map) {
            return;
        }

        currentMapLayer = layerName;

        mapLayerIds.forEach((layerId) => {
            if (!map.getLayer(layerId)) {
                return;
            }

            map.setLayoutProperty(layerId, 'visibility', 'none');
        });

        if (layerName === 'street') {
            map.setLayoutProperty('street-layer', 'visibility', 'visible');
        }

        if (layerName === 'satellite') {
            map.setLayoutProperty('satellite-layer', 'visibility', 'visible');
        }

        if (layerName === 'hybrid') {
            map.setLayoutProperty('hybrid-satellite-layer', 'visibility', 'visible');
            map.setLayoutProperty('hybrid-labels-layer', 'visibility', 'visible');
        }

        if (layerName === 'terrain') {
            map.setLayoutProperty('terrain-layer', 'visibility', 'visible');
        }

        document.querySelectorAll('.map-layer-option').forEach((button) => {
            button.classList.toggle(
                'active',
                button.dataset.layer === layerName
            );
        });
    }

    class MapLayerControl {
        onAdd(mapInstance) {
            const container = document.createElement('div');
            container.className = 'maplibregl-ctrl map-layer-control';

            container.innerHTML = `
                <div class="map-layer-control-title">Map</div>

                <button type="button" class="map-layer-option active" data-layer="street">
                    Street
                </button>

                <button type="button" class="map-layer-option" data-layer="satellite">
                    Satellite
                </button>

                <button type="button" class="map-layer-option" data-layer="hybrid">
                    Hybrid
                </button>

                <button type="button" class="map-layer-option" data-layer="terrain">
                    Terrain
                </button>
            `;

            const stopMapEvent = (event) => {
                event.stopPropagation();
            };

            container.addEventListener('mousedown', stopMapEvent);
            container.addEventListener('dblclick', stopMapEvent);
            container.addEventListener('touchstart', stopMapEvent);
            container.addEventListener('wheel', stopMapEvent);

            container.querySelectorAll('.map-layer-option').forEach((button) => {
                button.addEventListener('click', (event) => {
                    event.preventDefault();
                    event.stopPropagation();

                    setMapLayer(button.dataset.layer);
                });
            });

            return container;
        }

        onRemove() {}
    }

    class CenterLocationControl {
        onAdd(mapInstance) {
            const container = document.createElement('div');
            container.className = 'maplibregl-ctrl maplibregl-ctrl-group';

            const button = document.createElement('button');
            button.type = 'button';
            button.className = 'map-center-control';
            button.title = 'Center location';
            button.innerHTML = '🎯';

            button.addEventListener('click', (event) => {
                event.preventDefault();
                event.stopPropagation();

                centerLocationDot();
            });

            container.appendChild(button);

            return container;
        }

        onRemove() {}
    }

    function createSosMarkerElement() {
        const markerWrapper = document.createElement('div');
        markerWrapper.className = 'sos-map-marker';
        markerWrapper.innerHTML = '<div class="pulse"></div>';

        return markerWrapper;
    }

    function initializeOrUpdateMap(latitude, longitude) {
        const lat = parseFloat(latitude);
        const lng = parseFloat(longitude);

        if (Number.isNaN(lat) || Number.isNaN(lng)) {
            return;
        }

        latestMapLatitude = lat;
        latestMapLongitude = lng;

        if (!map) {
            map = new maplibregl.Map({
                container: 'map',
                style: createMapStyle(),
                center: [lng, lat],
                zoom: 16,
            });

            map.addControl(new maplibregl.NavigationControl(), 'top-right');
            map.addControl(new CenterLocationControl(), 'top-right');
            map.addControl(new MapLayerControl(), 'bottom-left');

            map.on('load', () => {
                createOrUpdateMarker(lat, lng);
                initializeRouteSourceAndLayers();
                initializeAccuracySourceAndLayers();
            });

            return;
        }

        createOrUpdateMarker(lat, lng);
    }

    function createOrUpdateMarker(lat, lng) {
        if (!map) {
            return;
        }

        if (!marker) {
            marker = new maplibregl.Marker({
                element: createSosMarkerElement(),
                anchor: 'center',
            })
                .setLngLat([lng, lat])
                .setPopup(
                    new maplibregl.Popup({
                        offset: 18,
                    }).setHTML('<strong>Latest SOS location</strong>')
                )
                .addTo(map);

            return;
        }

        marker.setLngLat([lng, lat]);
    }

    function centerLocationDot() {
        if (!map || latestMapLatitude === null || latestMapLongitude === null) {
            alert('Location is not available yet.');
            return;
        }

        map.flyTo({
            center: [latestMapLongitude, latestMapLatitude],
            zoom: 16,
            essential: true,
        });

        if (marker) {
            marker.togglePopup();
        }
    }

    function initializeRouteSourceAndLayers() {
        if (!map || map.getSource('sos-route')) {
            return;
        }

        map.addSource('sos-route', {
            type: 'geojson',
            data: {
                type: 'Feature',
                geometry: {
                    type: 'LineString',
                    coordinates: [],
                },
                properties: {},
            },
        });

        map.addLayer({
            id: 'sos-route-line',
            type: 'line',
            source: 'sos-route',
            layout: {
                'line-cap': 'round',
                'line-join': 'round',
            },
            paint: {
                'line-color': '#e53935',
                'line-width': 3,
                'line-opacity': 0.65,
            },
        });

        map.addSource('sos-start-point', {
            type: 'geojson',
            data: {
                type: 'Feature',
                geometry: {
                    type: 'Point',
                    coordinates: [],
                },
                properties: {},
            },
        });

        map.addLayer({
            id: 'sos-start-point-circle',
            type: 'circle',
            source: 'sos-start-point',
            paint: {
                'circle-radius': 7,
                'circle-color': '#ffffff',
                'circle-stroke-color': '#111827',
                'circle-stroke-width': 3,
            },
        });
    }

    function updateRouteLine(locationHistory) {
        if (!map || !Array.isArray(locationHistory) || locationHistory.length === 0) {
            return;
        }

        if (!map.getSource('sos-route')) {
            map.once('load', () => {
                updateRouteLine(locationHistory);
            });
            return;
        }

        const routePoints = locationHistory
            .map((location) => {
                const lat = parseFloat(location.latitude);
                const lng = parseFloat(location.longitude);

                if (Number.isNaN(lat) || Number.isNaN(lng)) {
                    return null;
                }

                return [lng, lat];
            })
            .filter((point) => point !== null);

        if (routePoints.length === 0) {
            return;
        }

        map.getSource('sos-route').setData({
            type: 'Feature',
            geometry: {
                type: 'LineString',
                coordinates: routePoints,
            },
            properties: {},
        });

        map.getSource('sos-start-point').setData({
            type: 'Feature',
            geometry: {
                type: 'Point',
                coordinates: routePoints[0],
            },
            properties: {},
        });
    }

    function initializeAccuracySourceAndLayers() {
        if (!map || map.getSource('sos-accuracy')) {
            return;
        }

        map.addSource('sos-accuracy', {
            type: 'geojson',
            data: {
                type: 'Feature',
                geometry: {
                    type: 'Polygon',
                    coordinates: [],
                },
                properties: {},
            },
        });

        map.addLayer({
            id: 'sos-accuracy-fill',
            type: 'fill',
            source: 'sos-accuracy',
            paint: {
                'fill-color': '#e53935',
                'fill-opacity': 0.04,
            },
        });

        map.addLayer({
            id: 'sos-accuracy-outline',
            type: 'line',
            source: 'sos-accuracy',
            paint: {
                'line-color': '#e53935',
                'line-width': 1.5,
                'line-opacity': 0.5,
            },
        });
    }

    function buildAccuracyCircleGeoJson(latitude, longitude, radiusMeters) {
        const lat = parseFloat(latitude);
        const lng = parseFloat(longitude);
        const radius = Number(radiusMeters);

        if (
            Number.isNaN(lat) ||
            Number.isNaN(lng) ||
            Number.isNaN(radius) ||
            radius <= 0 ||
            radius > maxVisibleAccuracyRadiusMeters
        ) {
            return {
                type: 'Feature',
                geometry: {
                    type: 'Polygon',
                    coordinates: [],
                },
                properties: {},
            };
        }

        const points = [];
        const earthRadiusMeters = 6378137;
        const latRadians = lat * Math.PI / 180;
        const lngRadians = lng * Math.PI / 180;
        const distanceRadians = radius / earthRadiusMeters;

        for (let index = 0; index <= 64; index++) {
            const bearing = index * 2 * Math.PI / 64;

            const pointLatRadians = Math.asin(
                Math.sin(latRadians) * Math.cos(distanceRadians) +
                Math.cos(latRadians) * Math.sin(distanceRadians) * Math.cos(bearing)
            );

            const pointLngRadians = lngRadians + Math.atan2(
                Math.sin(bearing) * Math.sin(distanceRadians) * Math.cos(latRadians),
                Math.cos(distanceRadians) - Math.sin(latRadians) * Math.sin(pointLatRadians)
            );

            points.push([
                pointLngRadians * 180 / Math.PI,
                pointLatRadians * 180 / Math.PI,
            ]);
        }

        return {
            type: 'Feature',
            geometry: {
                type: 'Polygon',
                coordinates: [points],
            },
            properties: {},
        };
    }

    function updateAccuracyCircle(latitude, longitude, accuracy) {
        if (!map) {
            return;
        }

        if (!map.getSource('sos-accuracy')) {
            map.once('load', () => {
                updateAccuracyCircle(latitude, longitude, accuracy);
            });
            return;
        }

        map.getSource('sos-accuracy').setData(
            buildAccuracyCircleGeoJson(latitude, longitude, accuracy)
        );
    }

    function renderEmergencyProfile(profile) {
        const profileDetails = document.getElementById('profileDetails');

        if (!profile) {
            profileDetails.innerHTML = `
                <div class="error">
                    Emergency profile details are unavailable.
                </div>
            `;
            return;
        }

        const phone = cleanPhone(profile.phone);
        const relativePhone = cleanPhone(profile.relative_phone);

        let callButtons = '';

        if (phone) {
            callButtons += `
                <a class="button" href="tel:${phone}">
                    📞 Call User
                </a>
            `;
        }

        if (relativePhone) {
            callButtons += `
                <a class="outline-button" href="tel:${relativePhone}">
                    📞 Call Emergency Relative
                </a>
            `;
        }

        callButtons += `
            <a class="secondary-button" href="tel:112">
                🚑 Call Emergency Number 112
            </a>
        `;

        profileDetails.innerHTML = `
            <div class="profile-grid">
                <div class="info-row">
                    <span class="label">Name</span>
                    <span class="value">${valueOrNotAdded(profile.name)}</span>
                </div>

                <div class="info-row">
                    <span class="label">Phone</span>
                    <span class="value">${valueOrNotAdded(profile.phone)}</span>
                </div>

                <div class="info-row">
                    <span class="label">Blood Group</span>
                    <span class="value">${valueOrNotAdded(profile.blood_group)}</span>
                </div>

                <div class="info-row">
                    <span class="label">Emergency Relative</span>
                    <span class="value">${valueOrNotAdded(profile.relative_name)}</span>
                </div>

                <div class="info-row">
                    <span class="label">Relative Phone</span>
                    <span class="value">${valueOrNotAdded(profile.relative_phone)}</span>
                </div>

                <div class="info-row full-width">
                    <span class="label">Address</span>
                    <span class="value">${valueOrNotAdded(profile.address)}</span>
                </div>
            </div>

            <div class="button-row three">
                ${callButtons}
            </div>
        `;
    }

    async function loadTrackingDetails() {
        const statusBox = document.getElementById('statusBox');
        const locationDetails = document.getElementById('locationDetails');

        try {
            const response = await fetch(`/api/v1/public/track/${encodeURIComponent(trackingToken)}`, {
                headers: {
                    'Accept': 'application/json'
                }
            });

            const body = await response.json();

            if (!response.ok) {
                const message = body.message || 'Tracking details are unavailable';
                const health = body.data?.tracking_health || {
                    state: 'expired',
                    message: message,
                    last_update_age_seconds: null,
                };

                statusBox.innerHTML = `
                    <div class="status expired">Unavailable</div>

                    <div class="health-alert ${getHealthClass(health.state)}">
                        <div class="health-title">
                            ${getHealthIcon(health.state)} ${getHealthTitle(health.state)}
                        </div>
                        <div class="health-message">
                            ${escapeHtml(health.message || message)}
                        </div>
                    </div>
                `;

                locationDetails.innerHTML = `
                    <div class="error">
                        Location could not be loaded.
                    </div>
                `;

                return;
            }

            const data = body.data;
            const status = data.status || 'unknown';
            const health = data.tracking_health || {
                state: 'waiting',
                message: 'Tracking health is not available.',
                last_update_age_seconds: null,
            };

            renderEmergencyProfile(data.emergency_profile);

            const latestLocation = data.latest_location;
            const initialLocation = data.initial_location;
            const locationToShow = latestLocation || initialLocation;

            let statusClass = 'cancelled';

            if (status === 'active') {
                statusClass = 'active';
            } else if (status === 'cancelled') {
                statusClass = 'cancelled';
            } else if (health.state === 'expired') {
                statusClass = 'expired';
            }

            statusBox.innerHTML = `
                <div class="status ${statusClass}">
                    ${escapeHtml(status.toUpperCase())}
                </div>

                <div class="health-alert ${getHealthClass(health.state)}">
                    <div class="health-title">
                        ${getHealthIcon(health.state)} ${getHealthTitle(health.state)}
                    </div>
                    <div class="health-message">
                        ${escapeHtml(health.message || 'Tracking status is being checked.')}
                    </div>
                </div>

                <div class="status-meta" style="margin-top: 12px;">
                    <strong>Last update:</strong>
                    ${formatAgeSeconds(health.last_update_age_seconds)}
                    <br>
                    <strong>Link expires at:</strong>
                    ${formatDateTime(data.expires_at)}
                </div>
            `;

            if (!locationToShow) {
                locationDetails.innerHTML = `
                    <div class="error">
                        No location is available yet.
                    </div>

                    <div class="button-row">
                        <a class="outline-button" href="javascript:void(0)" onclick="loadTrackingDetails()">
                            🔄 Refresh Now
                        </a>
                    </div>
                `;

                return;
            }

            const latitude = locationToShow.latitude;
            const longitude = locationToShow.longitude;

            initializeOrUpdateMap(latitude, longitude);
            updateRouteLine(data.location_history || []);
            updateAccuracyCircle(
                latitude,
                longitude,
                latestLocation ? latestLocation.accuracy : null
            );

            locationDetails.innerHTML = `
                <div class="profile-grid" style="margin-top: 14px;">
                    <div class="info-row">
                        <span class="label">Latitude</span>
                        <span class="value">${escapeHtml(latitude)}</span>
                    </div>

                    <div class="info-row">
                        <span class="label">Longitude</span>
                        <span class="value">${escapeHtml(longitude)}</span>
                    </div>

                    <div class="info-row">
                        <span class="label">Battery</span>
                        <span class="value">
                            ${latestLocation ? formatBattery(latestLocation.battery_percentage) : 'Not available'}
                        </span>
                    </div>

                    <div class="info-row">
                        <span class="label">GPS Accuracy</span>
                        <span class="value">
                            ${latestLocation ? formatAccuracy(latestLocation.accuracy) : 'Not available'}
                        </span>
                    </div>

                    <div class="info-row">
                        <span class="label">Tracking Health</span>
                        <span class="value">
                            ${escapeHtml(getHealthTitle(health.state))}
                        </span>
                    </div>

                    <div class="info-row full-width">
                        <span class="label">Last Updated</span>
                        <span class="value">
                            ${latestLocation ? formatDateTime(latestLocation.created_at) : 'Initial location only'}
                        </span>
                    </div>

                    <div class="info-row full-width">
                        <span class="label">What this means</span>
                        <span class="value">
                            ${escapeHtml(health.message || 'Showing latest available location.')}
                        </span>
                    </div>
                </div>

                <div class="button-row three">
                    <a class="button" href="${buildGoogleMapsUrl(latitude, longitude)}" target="_blank">
                        🗺 Open in Google Maps
                    </a>
                </div>
            `;
        } catch (error) {
            statusBox.innerHTML = `
                <div class="status expired">Connection Error</div>

                <div class="health-alert health-critical-stale">
                    <div class="health-title">
                        🚨 Could not refresh tracking
                    </div>
                    <div class="health-message">
                        This browser could not reach the SOS server. Please check internet connection and try again.
                    </div>
                </div>
            `;

            locationDetails.innerHTML = `
                <div class="error">
                    Please check your internet connection and refresh the page.
                </div>
            `;
        }
    }

    loadTrackingDetails();

    setInterval(loadTrackingDetails, 30000);
</script>
</body>
</html>
