<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Emergency SOS Tracking</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <!-- Leaflet Map CSS -->
    <link
        rel="stylesheet"
        href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
    />

    <style>
        :root {
            --danger: #e53935;
            --danger-dark: #b91c1c;
            --dark: #111827;
            --muted: #6b7280;
            --soft-bg: #f8fafc;
            --card: #ffffff;
            --border: #e5e7eb;
            --success: #16a34a;
            --warning: #f97316;
            --shadow: 0 14px 34px rgba(15, 23, 42, 0.08);
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
                radial-gradient(circle at top left, rgba(229, 57, 53, 0.10), transparent 28%),
                radial-gradient(circle at bottom right, rgba(17, 24, 39, 0.08), transparent 32%),
                var(--soft-bg);
            color: var(--dark);
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
            background: linear-gradient(135deg, var(--danger), var(--danger-dark));
            color: white;
            border-radius: 32px;
            padding: 24px;
            box-shadow: 0 22px 44px rgba(185, 28, 28, 0.22);
            margin-bottom: 18px;
            overflow: hidden;
            position: relative;
        }

        .hero-card::after {
            content: "";
            position: absolute;
            width: 220px;
            height: 220px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.10);
            right: -90px;
            top: -90px;
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
            width: 68px;
            height: 68px;
            border-radius: 24px;
            background: rgba(255, 255, 255, 0.18);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 34px;
            flex-shrink: 0;
        }

        .title {
            font-size: 30px;
            font-weight: 900;
            letter-spacing: -0.6px;
            margin: 0;
            line-height: 1.08;
        }

        .subtitle {
            margin: 8px 0 0;
            color: rgba(255, 255, 255, 0.88);
            line-height: 1.55;
            font-size: 15px;
            max-width: 640px;
            font-weight: 500;
        }

        .status-area {
            margin-top: 18px;
            padding: 16px;
            border-radius: 22px;
            background: rgba(255, 255, 255, 0.13);
            border: 1px solid rgba(255, 255, 255, 0.18);
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
            background: rgba(229, 57, 53, 0.10);
            color: var(--danger);
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
            background: #eef2f7;
            border: 1px solid var(--border);
            box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.4);
        }

        .leaflet-center-location-control {
            width: 42px;
            height: 42px;
            border: none;
            border-radius: 12px;
            background: white;
            color: var(--danger);
            font-size: 20px;
            font-weight: 900;
            cursor: pointer;
            box-shadow: 0 8px 18px rgba(15, 23, 42, 0.18);
            display: flex;
            align-items: center;
            justify-content: center;
        }

        .leaflet-center-location-control:hover {
            background: #fff5f5;
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
        }

        .status::before {
            content: "";
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: currentColor;
        }

        .active {
            background: rgba(255, 255, 255, 0.92);
            color: var(--danger-dark);
        }

        .cancelled {
            background: rgba(255, 255, 255, 0.88);
            color: #374151;
        }

        .expired {
            background: rgba(255, 255, 255, 0.90);
            color: var(--warning);
        }

        .health-alert {
            margin-top: 12px;
            padding: 14px;
            border-radius: 18px;
            border: 1px solid rgba(255, 255, 255, 0.22);
            background: rgba(255, 255, 255, 0.14);
        }

        .health-title {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 15px;
            font-weight: 900;
            color: white;
            margin-bottom: 6px;
        }

        .health-message {
            color: rgba(255, 255, 255, 0.92);
            font-size: 13.5px;
            line-height: 1.5;
            font-weight: 600;
        }

        .health-fresh {
            background: rgba(22, 163, 74, 0.22);
        }

        .health-delayed {
            background: rgba(249, 115, 22, 0.22);
        }

        .health-stale,
        .health-critical-stale {
            background: rgba(185, 28, 28, 0.28);
        }

        .health-stopped,
        .health-expired,
        .health-waiting {
            background: rgba(55, 65, 81, 0.26);
        }

        .status-meta {
            font-size: 14px;
            line-height: 1.5;
            color: rgba(255, 255, 255, 0.92);
            font-weight: 600;
        }

        .status-meta strong {
            color: white;
        }

        .profile-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 12px;
        }

        .info-row {
            padding: 14px;
            background: #f9fafb;
            border: 1px solid #eef0f3;
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
            color: var(--dark);
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
            box-shadow: 0 12px 22px rgba(229, 57, 53, 0.22);
        }

        .secondary-button {
            background: var(--dark);
            color: white;
            box-shadow: 0 12px 22px rgba(17, 24, 39, 0.18);
        }

        .outline-button {
            background: white;
            color: var(--danger);
            border: 1px solid rgba(229, 57, 53, 0.35);
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
            color: var(--danger-dark);
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
            background: #f9fafb;
            border: 1px solid #eef0f3;
        }

        .tracking-info-icon {
            width: 40px;
            height: 40px;
            border-radius: 14px;
            background: rgba(22, 163, 74, 0.10);
            color: var(--success);
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
            font-size: 21px;
        }

        .tracking-info-title {
            font-weight: 900;
            color: var(--dark);
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
            box-shadow: 0 0 0 rgba(229, 57, 53, 0.4);
            animation: pulse 1.5s infinite;
        }

        @keyframes pulse {
            0% {
                box-shadow: 0 0 0 0 rgba(229, 57, 53, 0.65);
            }
            70% {
                box-shadow: 0 0 0 18px rgba(229, 57, 53, 0);
            }
            100% {
                box-shadow: 0 0 0 0 rgba(229, 57, 53, 0);
            }
        }

        .loading-line {
            width: 100%;
            height: 14px;
            border-radius: 999px;
            background: linear-gradient(90deg, #eef2f7, #f8fafc, #eef2f7);
            background-size: 200% 100%;
            animation: loading 1.2s infinite;
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

<!-- Leaflet Map JS -->
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

<script>
    const trackingToken = @json($trackingToken);

    let map = null;
    let marker = null;
    let routeLine = null;
    let startMarker = null;
    let latestMapLatitude = null;
    let latestMapLongitude = null;
    let centerLocationControlAdded = false;

    const emergencyIcon = L.divIcon({
        className: '',
        html: '<div class="pulse"></div>',
        iconSize: [28, 28],
        iconAnchor: [14, 14],
    });

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

    function initializeOrUpdateMap(latitude, longitude) {
        const lat = parseFloat(latitude);
        const lng = parseFloat(longitude);

        if (Number.isNaN(lat) || Number.isNaN(lng)) {
            return;
        }

        latestMapLatitude = lat;
        latestMapLongitude = lng;

        if (!map) {
            map = L.map('map', {
                zoomControl: true,
                scrollWheelZoom: true,
            }).setView([lat, lng], 16);

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '&copy; OpenStreetMap contributors'
            }).addTo(map);

            marker = L.marker([lat, lng], {
                icon: emergencyIcon,
            }).addTo(map);

            marker.bindPopup('Latest SOS location').openPopup();

            addCenterLocationControl();

            return;
        }

        marker.setLatLng([lat, lng]);
    }

    function centerLocationDot() {
        if (!map || latestMapLatitude === null || latestMapLongitude === null) {
            alert('Location is not available yet.');
            return;
        }

        map.setView([latestMapLatitude, latestMapLongitude], 32, {
            animate: true,
        });

        if (marker) {
            marker.openPopup();
        }
    }

    function updateRouteLine(locationHistory) {
        if (!map || !Array.isArray(locationHistory) || locationHistory.length === 0) {
            return;
        }

        const routePoints = locationHistory
            .map((location) => {
                const lat = parseFloat(location.latitude);
                const lng = parseFloat(location.longitude);

                if (Number.isNaN(lat) || Number.isNaN(lng)) {
                    return null;
                }

                return [lat, lng];
            })
            .filter((point) => point !== null);

        if (routePoints.length === 0) {
            return;
        }

        if (!routeLine) {
            routeLine = L.polyline(routePoints, {
                color: '#e53935',
                weight: 5,
                opacity: 0.85,
            }).addTo(map);
        } else {
            routeLine.setLatLngs(routePoints);
        }

        const firstPoint = routePoints[0];

        if (!startMarker) {
            startMarker = L.circleMarker(firstPoint, {
                radius: 7,
                color: '#111827',
                fillColor: '#ffffff',
                fillOpacity: 1,
                weight: 3,
            }).addTo(map);

            startMarker.bindPopup('SOS route started here');
        } else {
            startMarker.setLatLng(firstPoint);
        }
    }

    function addCenterLocationControl() {
        if (!map || centerLocationControlAdded) {
            return;
        }

        const CenterLocationControl = L.Control.extend({
            options: {
                position: 'topright'
            },

            onAdd: function () {
                const button = L.DomUtil.create('button', 'leaflet-center-location-control');

                button.type = 'button';
                button.title = 'Center location dot';
                button.innerHTML = '🎯';

                L.DomEvent.disableClickPropagation(button);
                L.DomEvent.disableScrollPropagation(button);

                L.DomEvent.on(button, 'click', function (event) {
                    L.DomEvent.preventDefault(event);
                    centerLocationDot();
                });

                return button;
            }
        });

        map.addControl(new CenterLocationControl());
        centerLocationControlAdded = true;
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
