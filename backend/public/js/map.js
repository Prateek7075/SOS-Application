const centerLocationIcon = '/images/center_location_btn.png';

const trackingToken = window.trackingToken;
const maxVisibleAccuracyRadiusMeters = 300;
const refreshIntervalMilliseconds = 30000;

let map = null;
let marker = null;

let latestMapLatitude = null;
let latestMapLongitude = null;

let trackingRequestInProgress = false;

const autoCenterOnLocationUpdate = true;

const mapLayerIds = [
    'street-layer',
    'satellite-layer',
    'hybrid-satellite-layer',
    'hybrid-labels-layer',
    'terrain-layer',
];

/**
 * Escape HTML characters before inserting backend values
 * inside innerHTML.
 */
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

/**
 * Return a safe value or "Not added".
 */
function valueOrNotAdded(value) {
    if (
        value === null ||
        value === undefined ||
        String(value).trim() === ''
    ) {
        return 'Not added';
    }

    return escapeHtml(value);
}

/**
 * Remove unwanted characters from phone numbers.
 */
function cleanPhone(value) {
    if (!value) {
        return '';
    }

    return String(value)
        .trim()
        .replace(/[^\d+]/g, '')
        .replace(/(?!^)\+/g, '');
}

/**
 * Convert backend datetime into the user's local format.
 */
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

/**
 * Format battery percentage.
 */
function formatBattery(value) {
    if (
        value === null ||
        value === undefined ||
        String(value).trim() === ''
    ) {
        return 'Not available';
    }

    const battery = Number(value);

    if (!Number.isFinite(battery)) {
        return 'Not available';
    }

    return `${Math.round(battery)}%`;
}

/**
 * Convert seconds into readable time.
 */
function formatAgeSeconds(seconds) {
    if (
        seconds === null ||
        seconds === undefined ||
        Number.isNaN(Number(seconds))
    ) {
        return 'Not available';
    }

    const value = Math.max(
        0,
        Math.round(Number(seconds))
    );

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

/**
 * Format GPS accuracy.
 */
function formatAccuracy(value) {
    if (
        value === null ||
        value === undefined ||
        String(value).trim() === ''
    ) {
        return 'Not available';
    }

    const accuracy = Math.round(Number(value));

    if (!Number.isFinite(accuracy)) {
        return 'Not available';
    }

    return `${accuracy} meter${accuracy === 1 ? '' : 's'}`;
}

/**
 * Return CSS class according to tracking health.
 */
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

/**
 * Return icon according to tracking health.
 */
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

/**
 * Return heading according to tracking health.
 */
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

/**
 * Build Google Maps location URL.
 */
function buildGoogleMapsUrl(latitude, longitude) {
    const coordinates = `${latitude},${longitude}`;

    return (
        'https://www.google.com/maps/search/' +
        `?api=1&query=${encodeURIComponent(coordinates)}`
    );
}

/**
 * Return an empty valid GeoJSON collection.
 */
function createEmptyGeoJsonCollection() {
    return {
        type: 'FeatureCollection',
        features: [],
    };
}

/**
 * Create the complete MapLibre map style.
 */
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
                attribution:
                    '&copy; CARTO &copy; OpenStreetMap contributors',
            },

            terrain: {
                type: 'raster',
                tiles: [
                    'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
                    'https://b.tile.opentopomap.org/{z}/{x}/{y}.png',
                    'https://c.tile.opentopomap.org/{z}/{x}/{y}.png',
                ],
                tileSize: 256,
                attribution:
                    'Map data: &copy; OpenStreetMap contributors, SRTM | ' +
                    'Map style: &copy; OpenTopoMap',
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

/**
 * Change the currently visible map layer.
 */
function setMapLayer(layerName) {
    if (!map) {
        return;
    }

    mapLayerIds.forEach((layerId) => {
        if (!map.getLayer(layerId)) {
            return;
        }

        map.setLayoutProperty(
            layerId,
            'visibility',
            'none'
        );
    });

    if (layerName === 'street') {
        map.setLayoutProperty(
            'street-layer',
            'visibility',
            'visible'
        );
    }

    if (layerName === 'satellite') {
        map.setLayoutProperty(
            'satellite-layer',
            'visibility',
            'visible'
        );
    }

    if (layerName === 'hybrid') {
        map.setLayoutProperty(
            'hybrid-satellite-layer',
            'visibility',
            'visible'
        );

        map.setLayoutProperty(
            'hybrid-labels-layer',
            'visibility',
            'visible'
        );
    }

    if (layerName === 'terrain') {
        map.setLayoutProperty(
            'terrain-layer',
            'visibility',
            'visible'
        );
    }

    document
        .querySelectorAll('.map-layer-option')
        .forEach((button) => {
            button.classList.toggle(
                'active',
                button.dataset.layer === layerName
            );
        });
}

/**
 * Custom control for changing map layers.
 */
class MapLayerControl {
    onAdd(mapInstance) {
        this.map = mapInstance;

        const container = document.createElement('div');

        container.className =
            'maplibregl-ctrl map-layer-control';

        container.innerHTML = `
            <button
                type="button"
                class="map-layer-toggle"
                aria-expanded="false"
                aria-label="Change map layer"
            >
                🗺️ <span>Layers</span>
            </button>

            <div class="map-layer-options">
                <button
                    type="button"
                    class="map-layer-option active"
                    data-layer="street"
                >
                    Street
                </button>

                <button
                    type="button"
                    class="map-layer-option"
                    data-layer="hybrid"
                >
                    Hybrid
                </button>

                <button
                    type="button"
                    class="map-layer-option"
                    data-layer="terrain"
                >
                    Terrain
                </button>
            </div>
        `;

        const toggleButton = container.querySelector(
            '.map-layer-toggle'
        );

        toggleButton.addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();

            const isExpanded =
                container.classList.toggle('expanded');

            toggleButton.setAttribute(
                'aria-expanded',
                isExpanded ? 'true' : 'false'
            );
        });

        const stopMapEvent = (event) => {
            event.stopPropagation();
        };

        container.addEventListener(
            'mousedown',
            stopMapEvent
        );

        container.addEventListener(
            'dblclick',
            stopMapEvent
        );

        container.addEventListener(
            'touchstart',
            stopMapEvent
        );

        container.addEventListener(
            'wheel',
            stopMapEvent
        );

        container
            .querySelectorAll('.map-layer-option')
            .forEach((button) => {
                button.addEventListener('click', (event) => {
                    event.preventDefault();
                    event.stopPropagation();

                    setMapLayer(button.dataset.layer);

                    container.classList.remove('expanded');

                    toggleButton.setAttribute(
                        'aria-expanded',
                        'false'
                    );
                });
            });

        this.container = container;

        return container;
    }

    onRemove() {
        this.container?.remove();

        this.container = null;
        this.map = null;
    }
}

/**
 * Custom control for centering the map on the SOS marker.
 */
class CenterLocationControl {
    onAdd(mapInstance) {
        this.map = mapInstance;

        const container = document.createElement('div');

        container.className =
            'maplibregl-ctrl maplibregl-ctrl-group';

        const button = document.createElement('button');

        button.type = 'button';
        button.className = 'map-center-control';
        button.title = 'Center location';
        button.setAttribute(
            'aria-label',
            'Center SOS location'
        );

        button.innerHTML = `
            <img
                src="${centerLocationIcon}"
                alt=""
            >
        `;

        button.addEventListener('click', (event) => {
            event.preventDefault();
            event.stopPropagation();

            centerLocationDot();
        });

        container.appendChild(button);

        this.container = container;

        return container;
    }

    onRemove() {
        this.container?.remove();

        this.container = null;
        this.map = null;
    }
}

/**
 * Create the red pulsing SOS marker.
 */
function createSosMarkerElement() {
    const markerWrapper = document.createElement('div');

    markerWrapper.className = 'sos-map-marker';

    markerWrapper.innerHTML = `
        <div class="pulse"></div>
    `;

    return markerWrapper;
}

/**
 * Create the map or update the current marker position.
 */
function initializeOrUpdateMap(latitude, longitude) {
    const lat = Number(latitude);
    const lng = Number(longitude);

    if (
        !Number.isFinite(lat) ||
        !Number.isFinite(lng)
    ) {
        return false;
    }

    const previousLatitude = latestMapLatitude;
    const previousLongitude = latestMapLongitude;

    const locationChanged =
        previousLatitude === null ||
        previousLongitude === null ||
        previousLatitude !== lat ||
        previousLongitude !== lng;

    latestMapLatitude = lat;
    latestMapLongitude = lng;

    if (!map) {
        map = new maplibregl.Map({
            container: 'map',
            style: createMapStyle(),
            center: [lng, lat],
            zoom: 16,
        });

        map.addControl(
            new maplibregl.NavigationControl(),
            'top-right'
        );

        map.addControl(
            new CenterLocationControl(),
            'top-right'
        );

        map.addControl(
            new MapLayerControl(),
            'bottom-left'
        );

        map.on('load', () => {
            createOrUpdateMarker(lat, lng);
            initializeAccuracySourceAndLayers();
        });

        return true;
    }

    createOrUpdateMarker(lat, lng);

    if (
        autoCenterOnLocationUpdate &&
        locationChanged
    ) {
        map.easeTo({
            center: [lng, lat],
            duration: 700,
            essential: true,
        });
    }

    return true;
}

/**
 * Create a new marker or move the existing marker.
 */
function createOrUpdateMarker(latitude, longitude) {
    if (!map) {
        return;
    }

    if (!marker) {
        const popup = new maplibregl.Popup({
            offset: 18,
        }).setHTML(
            '<strong style="color: black;">' +
            'Latest SOS location' +
            '</strong>'
        );

        marker = new maplibregl.Marker({
            element: createSosMarkerElement(),
            anchor: 'center',
        })
            .setLngLat([longitude, latitude])
            .setPopup(popup)
            .addTo(map);

        return;
    }

    marker.setLngLat([
        longitude,
        latitude,
    ]);
}

/**
 * Center map on the latest SOS location.
 */
function centerLocationDot() {
    if (
        !map ||
        latestMapLatitude === null ||
        latestMapLongitude === null
    ) {
        alert('Location is not available yet.');
        return;
    }

    map.flyTo({
        center: [
            latestMapLongitude,
            latestMapLatitude,
        ],
        zoom: 16,
        essential: true,
    });

    if (marker) {
        const popup = marker.getPopup();

        if (popup && !popup.isOpen()) {
            marker.togglePopup();
        }
    }
}

/**
 * Add the GPS accuracy source and layers.
 */
function initializeAccuracySourceAndLayers() {
    if (
        !map ||
        map.getSource('sos-accuracy')
    ) {
        return;
    }

    map.addSource('sos-accuracy', {
        type: 'geojson',
        data: createEmptyGeoJsonCollection(),
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

/**
 * Create the GPS accuracy circle GeoJSON.
 */
function buildAccuracyCircleGeoJson(
    latitude,
    longitude,
    radiusMeters
) {
    const lat = Number(latitude);
    const lng = Number(longitude);
    const radius = Number(radiusMeters);

    if (
        !Number.isFinite(lat) ||
        !Number.isFinite(lng) ||
        !Number.isFinite(radius) ||
        radius <= 0 ||
        radius > maxVisibleAccuracyRadiusMeters
    ) {
        return createEmptyGeoJsonCollection();
    }

    const points = [];

    const earthRadiusMeters = 6378137;

    const latRadians =
        lat * Math.PI / 180;

    const lngRadians =
        lng * Math.PI / 180;

    const distanceRadians =
        radius / earthRadiusMeters;

    for (
        let index = 0;
        index <= 64;
        index += 1
    ) {
        const bearing =
            index * 2 * Math.PI / 64;

        const pointLatRadians = Math.asin(
            Math.sin(latRadians) *
            Math.cos(distanceRadians) +

            Math.cos(latRadians) *
            Math.sin(distanceRadians) *
            Math.cos(bearing)
        );

        const pointLngRadians =
            lngRadians +
            Math.atan2(
                Math.sin(bearing) *
                Math.sin(distanceRadians) *
                Math.cos(latRadians),

                Math.cos(distanceRadians) -
                Math.sin(latRadians) *
                Math.sin(pointLatRadians)
            );

        points.push([
            pointLngRadians * 180 / Math.PI,
            pointLatRadians * 180 / Math.PI,
        ]);
    }

    return {
        type: 'FeatureCollection',

        features: [
            {
                type: 'Feature',

                geometry: {
                    type: 'Polygon',
                    coordinates: [points],
                },

                properties: {},
            },
        ],
    };
}

/**
 * Update GPS accuracy circle on the map.
 */
function updateAccuracyCircle(
    latitude,
    longitude,
    accuracy
) {
    if (!map) {
        return;
    }

    const accuracySource =
        map.getSource('sos-accuracy');

    if (!accuracySource) {
        map.once('load', () => {
            initializeAccuracySourceAndLayers();

            updateAccuracyCircle(
                latitude,
                longitude,
                accuracy
            );
        });

        return;
    }

    accuracySource.setData(
        buildAccuracyCircleGeoJson(
            latitude,
            longitude,
            accuracy
        )
    );
}

/**
 * Render emergency profile information.
 */
function renderEmergencyProfile(profile) {
    const profileDetails = document.getElementById(
        'profileDetails'
    );

    if (!profileDetails) {
        return;
    }

    if (!profile) {
        profileDetails.innerHTML = `
            <div class="error">
                Emergency profile details are unavailable.
            </div>
        `;

        return;
    }

    const phone = cleanPhone(profile.phone);

    const relativePhone = cleanPhone(
        profile.relative_phone
    );

    let callButtons = '';

    if (phone) {
        callButtons += `
            <a
                class="button"
                href="tel:${phone}"
            >
                Call User
            </a>
        `;
    }

    if (relativePhone) {
        callButtons += `
            <a
                class="outline-button"
                href="tel:${relativePhone}"
            >
                Call Emergency Relative
            </a>
        `;
    }

    const callButtonsSection = callButtons
        ? `
            <div class="button-row three">
                ${callButtons}
            </div>
        `
        : '';

    profileDetails.innerHTML = `
        <div class="profile-grid">

            <div class="info-row">
                <span class="label">Name</span>

                <span class="value">
                    ${valueOrNotAdded(profile.name)}
                </span>
            </div>

            <div class="info-row">
                <span class="label">Phone</span>

                <span class="value">
                    ${valueOrNotAdded(profile.phone)}
                </span>
            </div>

            <div class="info-row">
                <span class="label">Blood Group</span>

                <span class="value">
                    ${valueOrNotAdded(profile.blood_group)}
                </span>
            </div>

            <div class="info-row">
                <span class="label">
                    Emergency Relative
                </span>

                <span class="value">
                    ${valueOrNotAdded(profile.relative_name)}
                </span>
            </div>

            <div class="info-row">
                <span class="label">
                    Relative Phone
                </span>

                <span class="value">
                    ${valueOrNotAdded(profile.relative_phone)}
                </span>
            </div>

            <div class="info-row full-width">
                <span class="label">Address</span>

                <span class="value">
                    ${valueOrNotAdded(profile.address)}
                </span>
            </div>

        </div>

        ${callButtonsSection}
    `;
}

/**
 * Show an error inside the profile section.
 */
function showProfileError(message) {
    const profileDetails = document.getElementById(
        'profileDetails'
    );

    if (!profileDetails) {
        return;
    }

    profileDetails.innerHTML = `
        <div class="error">
            ${escapeHtml(message)}
        </div>
    `;
}

/**
 * Add click listener to the dynamically created refresh button.
 */
function attachRefreshButton() {
    const refreshButton = document.getElementById(
        'refreshTrackingButton'
    );

    refreshButton?.addEventListener(
        'click',
        () => {
            loadTrackingDetails();
        }
    );
}

/**
 * Load tracking data from the public tracking API.
 */
async function loadTrackingDetails() {
    if (trackingRequestInProgress) {
        return;
    }

    const statusBox = document.getElementById(
        'statusBox'
    );

    const locationDetails = document.getElementById(
        'locationDetails'
    );

    if (!statusBox || !locationDetails) {
        return;
    }

    if (!trackingToken) {
        statusBox.innerHTML = `
            <div class="status expired">
                Invalid Link
            </div>

            <div class="health-alert health-expired">
                <div class="health-title">
                    ⌛ Tracking token is missing
                </div>

                <div class="health-message">
                    This tracking link is invalid or incomplete.
                </div>
            </div>
        `;

        locationDetails.innerHTML = `
            <div class="error">
                Location could not be loaded.
            </div>
        `;

        showProfileError(
            'Emergency profile details are unavailable.'
        );

        return;
    }

    trackingRequestInProgress = true;

    try {
        const response = await fetch(
            `/api/v1/public/track/${encodeURIComponent(trackingToken)}`,
            {
                headers: {
                    Accept: 'application/json',
                },
            }
        );

        let body = {};

        try {
            body = await response.json();
        } catch (jsonError) {
            body = {};
        }

        if (!response.ok) {
            const message =
                body.message ||
                'Tracking details are unavailable.';

            const health =
                body.data?.tracking_health || {
                    state: 'expired',
                    message,
                    last_update_age_seconds: null,
                };

            statusBox.innerHTML = `
                <div class="status expired">
                    Unavailable
                </div>

                <div class="health-alert ${getHealthClass(health.state)}">
                    <div class="health-title">
                        ${getHealthIcon(health.state)}
                        ${getHealthTitle(health.state)}
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

            showProfileError(
                'Emergency profile details are unavailable.'
            );

            return;
        }

        const data = body.data;

        if (
            !data ||
            typeof data !== 'object'
        ) {
            throw new Error(
                'The server returned an invalid tracking response.'
            );
        }

        const status = data.status || 'unknown';

        const health =
            data.tracking_health || {
                state: 'waiting',
                message:
                    'Tracking health is not available.',
                last_update_age_seconds: null,
            };

        renderEmergencyProfile(
            data.emergency_profile
        );

        const latestLocation =
            data.latest_location;

        const initialLocation =
            data.initial_location;

        const locationToShow =
            latestLocation || initialLocation;

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
                ${escapeHtml(String(status).toUpperCase())}
            </div>

            <div class="health-alert ${getHealthClass(health.state)}">
                <div class="health-title">
                    ${getHealthIcon(health.state)}
                    ${getHealthTitle(health.state)}
                </div>

                <div class="health-message">
                    ${escapeHtml(
                        health.message ||
                        'Tracking status is being checked.'
                    )}
                </div>
            </div>

            <div
                class="status-meta"
                style="margin-top: 12px;"
            >
                <strong>Last update:</strong>

                ${formatAgeSeconds(
                    health.last_update_age_seconds
                )}

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
                    <button
                        type="button"
                        class="outline-button"
                        id="refreshTrackingButton"
                    >
                        🔄 Refresh Now
                    </button>
                </div>
            `;

            attachRefreshButton();

            return;
        }

        const latitude = Number(
            locationToShow.latitude
        );

        const longitude = Number(
            locationToShow.longitude
        );

        if (
            !Number.isFinite(latitude) ||
            !Number.isFinite(longitude)
        ) {
            locationDetails.innerHTML = `
                <div class="error">
                    The received location coordinates are invalid.
                </div>

                <div class="button-row">
                    <button
                        type="button"
                        class="outline-button"
                        id="refreshTrackingButton"
                    >
                        🔄 Refresh Now
                    </button>
                </div>
            `;

            attachRefreshButton();

            return;
        }

        initializeOrUpdateMap(
            latitude,
            longitude
        );

        updateAccuracyCircle(
            latitude,
            longitude,
            latestLocation
                ? latestLocation.accuracy
                : null
        );

        locationDetails.innerHTML = `
            <div
                class="profile-grid"
                style="margin-top: 14px;"
            >
                <div class="info-row">
                    <span class="label">
                        Latitude
                    </span>

                    <span class="value">
                        ${escapeHtml(latitude)}
                    </span>
                </div>

                <div class="info-row">
                    <span class="label">
                        Longitude
                    </span>

                    <span class="value">
                        ${escapeHtml(longitude)}
                    </span>
                </div>

                <div class="info-row">
                    <span class="label">
                        Battery
                    </span>

                    <span class="value">
                        ${
                            latestLocation
                                ? formatBattery(
                                    latestLocation.battery_percentage
                                )
                                : 'Not available'
                        }
                    </span>
                </div>

                <div class="info-row">
                    <span class="label">
                        GPS Accuracy
                    </span>

                    <span class="value">
                        ${
                            latestLocation
                                ? formatAccuracy(
                                    latestLocation.accuracy
                                )
                                : 'Not available'
                        }
                    </span>
                </div>

                <div class="info-row">
                    <span class="label">
                        Tracking Health
                    </span>

                    <span class="value">
                        ${escapeHtml(
                            getHealthTitle(health.state)
                        )}
                    </span>
                </div>

                <div class="info-row full-width">
                    <span class="label">
                        Last Updated
                    </span>

                    <span class="value">
                        ${
                            latestLocation
                                ? formatDateTime(
                                    latestLocation.created_at
                                )
                                : 'Initial location only'
                        }
                    </span>
                </div>

                <div class="info-row full-width">
                    <span class="label">
                        What this means
                    </span>

                    <span class="value">
                        ${escapeHtml(
                            health.message ||
                            'Showing latest available location.'
                        )}
                    </span>
                </div>
            </div>

            <div class="button-row three">
                <a
                    class="button"
                    href="${buildGoogleMapsUrl(
                        latitude,
                        longitude
                    )}"
                    target="_blank"
                    rel="noopener noreferrer"
                >
                    🗺 Open in Google Maps
                </a>
            </div>
        `;
    } catch (error) {
        console.error(
            'Could not load SOS tracking details:',
            error
        );

        statusBox.innerHTML = `
            <div class="status expired">
                Connection Error
            </div>

            <div class="health-alert health-critical-stale">
                <div class="health-title">
                    🚨 Could not refresh tracking
                </div>

                <div class="health-message">
                    This browser could not reach the SOS server.
                    Please check the internet connection and try again.
                </div>
            </div>
        `;

        locationDetails.innerHTML = `
            <div class="error">
                Please check your internet connection
                and refresh the page.
            </div>

            <div class="button-row">
                <button
                    type="button"
                    class="outline-button"
                    id="refreshTrackingButton"
                >
                    🔄 Try Again
                </button>
            </div>
        `;

        showProfileError(
            'Emergency profile could not be loaded.'
        );

        attachRefreshButton();
    } finally {
        trackingRequestInProgress = false;
    }
}

/**
 * Load tracking information immediately.
 */
loadTrackingDetails();

/**
 * Refresh tracking information every 30 seconds.
 */
setInterval(
    loadTrackingDetails,
    refreshIntervalMilliseconds
);
