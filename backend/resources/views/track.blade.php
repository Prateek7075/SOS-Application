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
        body {
            margin: 0;
            font-family: Arial, sans-serif;
            background: #f3f4f6;
            color: #222;
        }

        .container {
            max-width: 760px;
            margin: 0 auto;
            padding: 16px;
        }

        .card {
            background: white;
            border-radius: 18px;
            padding: 18px;
            box-shadow: 0 4px 18px rgba(0, 0, 0, 0.08);
            margin-bottom: 16px;
        }

        .hero-card {
            background: linear-gradient(135deg, #b71c1c, #d32f2f);
            color: white;
        }

        .title {
            font-size: 26px;
            font-weight: bold;
            margin-bottom: 8px;
        }

        .subtitle {
            opacity: 0.9;
            margin-bottom: 12px;
            line-height: 1.5;
        }

        .section-title {
            font-size: 18px;
            font-weight: bold;
            margin-bottom: 12px;
        }

        #map {
            width: 100%;
            height: 380px;
            border-radius: 16px;
            overflow: hidden;
            background: #e0e0e0;
        }

        .status {
            display: inline-block;
            padding: 8px 14px;
            border-radius: 999px;
            font-weight: bold;
            margin-bottom: 12px;
            font-size: 14px;
        }

        .active {
            background: #ffebee;
            color: #c62828;
        }

        .cancelled {
            background: #eeeeee;
            color: #555;
        }

        .expired {
            background: #fff3e0;
            color: #ef6c00;
        }

        .profile-grid {
            display: grid;
            grid-template-columns: 1fr;
            gap: 10px;
        }

        .info-row {
            padding: 10px 12px;
            background: #f8f8f8;
            border-radius: 12px;
            line-height: 1.4;
        }

        .label {
            font-weight: bold;
            display: block;
            color: #555;
            font-size: 13px;
            margin-bottom: 4px;
        }

        .value {
            font-size: 15px;
            color: #222;
        }

        .button {
            display: block;
            text-align: center;
            background: #c62828;
            color: white;
            text-decoration: none;
            padding: 14px;
            border-radius: 12px;
            font-weight: bold;
            margin-top: 14px;
        }

        .secondary-button {
            display: block;
            text-align: center;
            background: #222;
            color: white;
            text-decoration: none;
            padding: 14px;
            border-radius: 12px;
            font-weight: bold;
            margin-top: 10px;
        }

        .outline-button {
            display: block;
            text-align: center;
            background: white;
            color: #c62828;
            border: 1px solid #c62828;
            text-decoration: none;
            padding: 13px;
            border-radius: 12px;
            font-weight: bold;
            margin-top: 10px;
        }

        .small {
            font-size: 13px;
            color: #777;
            margin-top: 12px;
            line-height: 1.5;
        }

        .error {
            color: #c62828;
            font-weight: bold;
        }

        .pulse {
            width: 18px;
            height: 18px;
            background: #c62828;
            border-radius: 50%;
            border: 3px solid white;
            box-shadow: 0 0 0 rgba(198, 40, 40, 0.4);
            animation: pulse 1.5s infinite;
        }

        @keyframes pulse {
            0% {
                box-shadow: 0 0 0 0 rgba(198, 40, 40, 0.6);
            }
            70% {
                box-shadow: 0 0 0 16px rgba(198, 40, 40, 0);
            }
            100% {
                box-shadow: 0 0 0 0 rgba(198, 40, 40, 0);
            }
        }

        @media (min-width: 640px) {
            .profile-grid {
                grid-template-columns: 1fr 1fr;
            }

            .full-width {
                grid-column: 1 / -1;
            }
        }
    </style>
</head>
<body>
<div class="container">

    <div class="card hero-card">
        <div class="title">Emergency SOS Tracking</div>
        <div class="subtitle">
            This page shows the latest shared emergency location and important emergency profile details.
        </div>

        <div id="statusBox">
            Loading SOS status...
        </div>
    </div>

    <div class="card">
        <div class="section-title">Emergency Profile</div>
        <div id="profileDetails">
            Loading profile details...
        </div>
    </div>

    <div class="card">
        <div class="section-title">Live Location</div>
        <div id="map"></div>

        <div id="locationDetails">
            Loading location...
        </div>
    </div>

    <div class="card">
        <div class="section-title">Tracking Information</div>
        <div class="info-row">
            <span class="label">Auto refresh</span>
            <span class="value">Every 15 seconds</span>
        </div>
        <div class="small">
            Keep this page open to see updated emergency location. The marker will move when a new location update is received.
        </div>
    </div>
</div>

<!-- Leaflet Map JS -->
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

<script>
    const trackingToken = @json($trackingToken);

    let map = null;
    let marker = null;

    const emergencyIcon = L.divIcon({
        className: '',
        html: '<div class="pulse"></div>',
        iconSize: [24, 24],
        iconAnchor: [12, 12],
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

    function buildGoogleMapsUrl(latitude, longitude) {
        return `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`;
    }

    function initializeOrUpdateMap(latitude, longitude) {
        const lat = parseFloat(latitude);
        const lng = parseFloat(longitude);

        if (Number.isNaN(lat) || Number.isNaN(lng)) {
            return;
        }

        if (!map) {
            map = L.map('map').setView([lat, lng], 16);

            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '&copy; OpenStreetMap contributors'
            }).addTo(map);

            marker = L.marker([lat, lng], {
                icon: emergencyIcon,
            }).addTo(map);

            marker.bindPopup('Latest SOS location').openPopup();

            return;
        }

        marker.setLatLng([lat, lng]);
        map.panTo([lat, lng]);
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
                    Call User
                </a>
            `;
        }

        if (relativePhone) {
            callButtons += `
                <a class="outline-button" href="tel:${relativePhone}">
                    Call Emergency Relative
                </a>
            `;
        }

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

            ${callButtons}

            <a class="secondary-button" href="tel:112">
                Call Emergency Number 112
            </a>
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

                statusBox.innerHTML = `
                    <div class="status expired">Unavailable</div>
                    <div class="error">${escapeHtml(message)}</div>
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

            renderEmergencyProfile(data.emergency_profile);

            const latestLocation = data.latest_location;
            const initialLocation = data.initial_location;

            const locationToShow = latestLocation || initialLocation;

            let statusClass = 'cancelled';

            if (status === 'active') {
                statusClass = 'active';
            } else if (status === 'cancelled') {
                statusClass = 'cancelled';
            }

            statusBox.innerHTML = `
                <div class="status ${statusClass}">
                    ${escapeHtml(status.toUpperCase())}
                </div>

                <div>
                    <strong>Link expires at:</strong>
                    ${formatDateTime(data.expires_at)}
                </div>
            `;

            if (!locationToShow) {
                locationDetails.innerHTML = `
                    <div class="error">
                        No location is available yet.
                    </div>
                `;

                return;
            }

            const latitude = locationToShow.latitude;
            const longitude = locationToShow.longitude;

            initializeOrUpdateMap(latitude, longitude);

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

                    <div class="info-row full-width">
                        <span class="label">Last Updated</span>
                        <span class="value">
                            ${latestLocation ? formatDateTime(latestLocation.created_at) : 'Initial location only'}
                        </span>
                    </div>
                </div>

                <a class="button" href="${buildGoogleMapsUrl(latitude, longitude)}" target="_blank">
                    Open Latest Location in Google Maps
                </a>
            `;
        } catch (error) {
            statusBox.innerHTML = `
                <div class="status expired">Connection Error</div>
                <div class="error">
                    Could not load tracking details.
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

    setInterval(loadTrackingDetails, 15000);
</script>
</body>
</html>
