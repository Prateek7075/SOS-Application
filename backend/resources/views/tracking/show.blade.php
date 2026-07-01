<!DOCTYPE html>
<html>
<head>
    <title>Live SOS Tracking</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #fff5f5;
            margin: 0;
            padding: 20px;
            color: #222;
        }

        .container {
            max-width: 600px;
            margin: 0 auto;
        }

        .card {
            background: white;
            border-radius: 14px;
            padding: 20px;
            box-shadow: 0 4px 18px rgba(0, 0, 0, 0.08);
        }

        .title {
            color: #d32f2f;
            text-align: center;
            margin-bottom: 10px;
        }

        .subtitle {
            text-align: center;
            color: #555;
            margin-bottom: 25px;
        }

        .row {
            display: flex;
            justify-content: space-between;
            border-bottom: 1px solid #eee;
            padding: 12px 0;
            gap: 10px;
        }

        .label {
            font-weight: bold;
        }

        .status-active {
            color: green;
            font-weight: bold;
        }

        .status-cancelled {
            color: red;
            font-weight: bold;
        }

        .map-button {
            display: block;
            text-align: center;
            background: #d32f2f;
            color: white;
            text-decoration: none;
            padding: 14px;
            border-radius: 10px;
            margin-top: 20px;
            font-weight: bold;
        }

        .error {
            color: red;
            text-align: center;
            font-weight: bold;
        }

        .refresh-text {
            text-align: center;
            color: #777;
            margin-top: 12px;
            font-size: 14px;
        }
    </style>
</head>
<body>
<div class="container">
    <div class="card">
        <h1 class="title">Emergency SOS Tracking</h1>
        <p class="subtitle">This page shows the latest shared emergency location.</p>

        <div id="content">
            <p class="refresh-text">Loading tracking details...</p>
        </div>

        <p class="refresh-text">
            This page refreshes automatically every 5 seconds.
        </p>
    </div>
</div>

<script>
    const trackingToken = @json($trackingToken);

    async function loadTrackingData() {
        const content = document.getElementById('content');

        try {
            const response = await fetch(`/api/v1/public/track/${trackingToken}?t=${Date.now()}`, {
                cache: 'no-store',
            });
            const result = await response.json();

            if (!response.ok || result.success === false) {
                content.innerHTML = `
                    <p class="error">${result.message || 'Tracking data not available'}</p>
                `;
                return;
            }

            const data = result.data;
            const latestLocation = data.latest_location;
            const initialLocation = data.initial_location;

            const location = latestLocation || initialLocation;

            const latitude = location.latitude;
            const longitude = location.longitude;

            const mapsUrl = `https://maps.google.com/?q=${latitude},${longitude}`;

            const statusClass = data.status === 'active'
                ? 'status-active'
                : 'status-cancelled';

            content.innerHTML = `
                <div class="row">
                    <span class="label">SOS Status</span>
                    <span class="${statusClass}">${data.status}</span>
                </div>

                <div class="row">
                    <span class="label">Latitude</span>
                    <span>${latitude}</span>
                </div>

                <div class="row">
                    <span class="label">Longitude</span>
                    <span>${longitude}</span>
                </div>

                <div class="row">
                    <span class="label">Accuracy</span>
                    <span>${latestLocation?.accuracy ?? 'Not available'}</span>
                </div>

                <div class="row">
                    <span class="label">Battery</span>
                    <span>${latestLocation?.battery_percentage ?? 'Not available'}</span>
                </div>

                <div class="row">
                    <span class="label">Last Updated</span>
                    <span>${latestLocation?.created_at ?? 'Initial location only'}</span>
                </div>

                <a class="map-button" href="${mapsUrl}" target="_blank">
                    Open Location In Google Maps
                </a>
            `;
        } catch (error) {
            content.innerHTML = `
                <p class="error">Failed to load tracking data.</p>
            `;
        }
    }

    loadTrackingData();
    setInterval(loadTrackingData, 5000);
</script>
</body>
</html>
