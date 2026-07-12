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
    @vite('resources/css/map.css')

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
    window.trackingToken = @json($trackingToken);
</script>

@vite('resources/js/map.js')
</body>
</html>
