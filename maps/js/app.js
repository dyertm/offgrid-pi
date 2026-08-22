"use strict";

const elements = {
  dashboardLink: document.getElementById("dashboard-link"),
  readerHost: document.getElementById("reader-host"),
  packStatus: document.getElementById("pack-status"),
  packCount: document.getElementById("pack-count"),
  catalogMessage: document.getElementById("catalog-message"),
  packList: document.getElementById("pack-list"),
  mapWorkspace: document.getElementById("map-workspace"),
  mapCanvas: document.getElementById("map-canvas"),
  renderMessage: document.getElementById("render-message"),
  mapZoomIn: document.getElementById("map-zoom-in"),
  mapZoomOut: document.getElementById("map-zoom-out"),
  mapResetView: document.getElementById("map-reset-view"),
  mapHelp: document.getElementById("map-help"),
  mapHelpPanel: document.getElementById("map-help-panel"),
  mapHelpClose: document.getElementById("map-help-close"),
  detailsPanel: document.getElementById("details-panel"),
  selectedHeading: document.getElementById("selected-map-heading"),
  selectedStatus: document.getElementById("selected-status"),
  selectedDescription: document.getElementById("selected-description"),
  selectedRegion: document.getElementById("selected-region"),
  selectedVersion: document.getElementById("selected-version"),
  selectedDataDate: document.getElementById("selected-data-date"),
  selectedZoom: document.getElementById("selected-zoom"),
  limitationsSection: document.getElementById("limitations-section"),
  selectedLimitations: document.getElementById("selected-limitations"),
};

const state = {
  packs: [],
  selectedKey: null,
  protocol: null,
  archive: null,
  map: null,
};

function dashboardUrl() {
  const hostname = window.location.hostname || "offgridpi";

  return `${window.location.protocol}//${hostname}:8081/`;
}

function packKey(pack) {
  return `${pack.pack_id}@${pack.version}`;
}

function selectedPack() {
  return state.packs.find(
    (pack) => packKey(pack) === state.selectedKey,
  ) || null;
}

function humanStatus(status) {
  if (status === "published") {
    return "Published";
  }

  if (status === "deprecated") {
    return "Deprecated";
  }

  return "Draft";
}

function formatDate(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);

  if (!match) {
    return value;
  }

  const [, year, month, day] = match;

  return `${year}-${month}-${day}`;
}

function clearChildren(element) {
  while (element.firstChild) {
    element.removeChild(element.firstChild);
  }
}

function showEmptyState() {
  state.selectedKey = null;

  elements.packStatus.textContent = "No maps installed";
  elements.packCount.textContent = "0";
  elements.catalogMessage.hidden = false;
  elements.catalogMessage.textContent =
    "No installed map packs were found. Map packs can be added through the local content-management workflow.";
  elements.detailsPanel.hidden = true;
  elements.mapWorkspace.hidden = false;
}

function showErrorState() {
  state.selectedKey = null;

  elements.packStatus.textContent = "Maps unavailable";
  elements.packCount.textContent = "—";
  elements.catalogMessage.hidden = false;
  elements.catalogMessage.textContent =
    "Installed maps could not be loaded. The rest of Offgrid Pi remains available.";
  elements.detailsPanel.hidden = true;
  elements.mapWorkspace.hidden = false;
}

function renderPack(pack) {
  if (!state.protocol) {
    return;
  }

  if (state.map) {
    state.map.remove();
    state.map = null;
  }

  const basemapUrl = new URL(
    pack.basemap_url,
    window.location.href,
  ).href;

  state.archive = new pmtiles.PMTiles(basemapUrl);
  state.protocol.add(state.archive);

  state.map = new maplibregl.Map({
    container: elements.mapCanvas,
    style: {
      version: 8,
      sources: {
        basemap: {
          type: "vector",
          url: `pmtiles://${basemapUrl}`,
        },
      },
      layers: [
        {
          id: "offline-background",
          type: "background",
          paint: {
            "background-color": "#0f171f",
          },
        },
        {
          id: "earth",
          type: "fill",
          source: "basemap",
          "source-layer": "earth",
          paint: {
            "fill-color": "#d8d2bf",
          },
        },
        {
          id: "landcover",
          type: "fill",
          source: "basemap",
          "source-layer": "landcover",
          paint: {
            "fill-color": "#b9c9a5",
            "fill-opacity": 0.55,
          },
        },
        {
          id: "landuse",
          type: "fill",
          source: "basemap",
          "source-layer": "landuse",
          paint: {
            "fill-color": "#c7d3b2",
            "fill-opacity": 0.45,
          },
        },
        {
          id: "water",
          type: "fill",
          source: "basemap",
          "source-layer": "water",
          filter: ["==", ["geometry-type"], "Polygon"],
          paint: {
            "fill-color": "#89b6cf",
          },
        },
        {
          id: "boundaries",
          type: "line",
          source: "basemap",
          "source-layer": "boundaries",
          paint: {
            "line-color": "#727272",
            "line-width": 1,
            "line-opacity": 0.7,
          },
        },
        {
          id: "roads",
          type: "line",
          source: "basemap",
          "source-layer": "roads",
          paint: {
            "line-color": "#f3eee3",
            "line-width": [
              "interpolate",
              ["linear"],
              ["zoom"],
              3, 0.4,
              10, 1.5,
              15, 4,
            ],
          },
        },
        {
          id: "buildings",
          type: "fill",
          source: "basemap",
          "source-layer": "buildings",
          minzoom: 11,
          paint: {
            "fill-color": "#b6aa9b",
            "fill-outline-color": "#95897d",
          },
        },
        {
          id: "road-labels",
          type: "symbol",
          source: "basemap",
          "source-layer": "roads",
          minzoom: 10,
          layout: {
            "symbol-placement": "line",
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["sans-serif"],
            "text-size": 11,
          },
          paint: {
            "text-color": "#3f3a34",
            "text-halo-color": "#f5f1e8",
            "text-halo-width": 1.5,
          },
        },
        {
          id: "place-labels",
          type: "symbol",
          source: "basemap",
          "source-layer": "places",
          minzoom: 4,
          layout: {
            "text-field": ["coalesce", ["get", "name:en"], ["get", "name"]],
            "text-font": ["sans-serif"],
            "text-size": [
              "interpolate",
              ["linear"],
              ["zoom"],
              4, 11,
              10, 16,
            ],
          },
          paint: {
            "text-color": "#20272c",
            "text-halo-color": "#f4f1e8",
            "text-halo-width": 1.5,
          },
        },
      ],
    },
    bounds: pack.region.bounds,
    fitBoundsOptions: {
      padding: 24,
      maxZoom: pack.region.max_zoom,
    },
    attributionControl: false,
  });

  elements.renderMessage.hidden = false;
  elements.renderMessage.querySelector("h2").textContent =
    "Preparing offline map";
  elements.renderMessage.querySelector("p:last-child").textContent =
    "Loading local vector map data.";

  state.map.on("load", () => {
    elements.renderMessage.hidden = true;
  });
}

function selectPack(pack) {
  state.selectedKey = packKey(pack);

  for (const button of elements.packList.querySelectorAll(".pack-card")) {
    button.setAttribute(
      "aria-pressed",
      button.dataset.packKey === state.selectedKey
        ? "true"
        : "false",
    );
  }

  elements.selectedHeading.textContent = pack.name;
  elements.selectedStatus.textContent = humanStatus(pack.status);
  elements.selectedDescription.textContent = pack.description;
  elements.selectedRegion.textContent = pack.region.name;
  elements.selectedVersion.textContent = pack.version;
  elements.selectedDataDate.textContent = formatDate(pack.data_date);
  elements.selectedZoom.textContent =
    `${pack.region.min_zoom}–${pack.region.max_zoom}`;

  clearChildren(elements.selectedLimitations);

  if (pack.limitations.length > 0) {
    for (const limitation of pack.limitations) {
      const item = document.createElement("li");
      item.textContent = limitation;
      elements.selectedLimitations.appendChild(item);
    }

    elements.limitationsSection.hidden = false;
  } else {
    elements.limitationsSection.hidden = true;
  }

  elements.mapWorkspace.hidden = false;
  elements.detailsPanel.hidden = false;

  renderPack(pack);
}

function createPackCard(pack) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "pack-card";
  button.dataset.packKey = packKey(pack);
  button.setAttribute("aria-pressed", "false");

  const title = document.createElement("span");
  title.className = "pack-card-title";
  title.textContent = pack.name;

  const region = document.createElement("span");
  region.className = "pack-card-region";
  region.textContent = pack.region.name;

  const meta = document.createElement("span");
  meta.className = "pack-card-meta";
  meta.textContent =
    `Version ${pack.version} • Data ${formatDate(pack.data_date)}`;

  button.append(title, region, meta);

  button.addEventListener("click", () => {
    selectPack(pack);
  });

  return button;
}

function renderPacks(packs) {
  state.packs = packs;
  clearChildren(elements.packList);

  if (packs.length === 0) {
    showEmptyState();
    return;
  }

  elements.catalogMessage.hidden = true;
  elements.packCount.textContent = String(packs.length);
  elements.packStatus.textContent =
    packs.length === 1
      ? "1 map installed"
      : `${packs.length} maps installed`;

  for (const pack of packs) {
    elements.packList.appendChild(
      createPackCard(pack),
    );
  }

  selectPack(packs[0]);
}

function validPack(pack) {
  return (
    pack
    && typeof pack === "object"
    && typeof pack.pack_id === "string"
    && typeof pack.name === "string"
    && typeof pack.version === "string"
    && typeof pack.status === "string"
    && typeof pack.description === "string"
    && typeof pack.data_date === "string"
    && typeof pack.style_id === "string"
    && typeof pack.tile_schema_id === "string"
    && Array.isArray(pack.limitations)
    && pack.limitations.every(
      (item) => typeof item === "string",
    )
    && pack.region
    && typeof pack.region === "object"
    && typeof pack.region.name === "string"
    && Array.isArray(pack.region.bounds)
    && pack.region.bounds.length === 4
    && Array.isArray(pack.region.default_center)
    && pack.region.default_center.length === 2
    && Number.isFinite(pack.region.min_zoom)
    && Number.isFinite(pack.region.max_zoom)
    && typeof pack.manifest_url === "string"
    && typeof pack.basemap_url === "string"
  );
}

async function loadPacks() {
  try {
    const response = await fetch(
      "/api/packs",
      {
        cache: "no-store",
        credentials: "same-origin",
      },
    );

    if (!response.ok) {
      throw new Error(
        `Discovery returned HTTP ${response.status}`,
      );
    }

    const payload = await response.json();

    if (
      !payload
      || payload.schema_version !== 1
      || !Array.isArray(payload.packs)
      || !payload.packs.every(validPack)
    ) {
      throw new Error(
        "Discovery response is invalid.",
      );
    }

    renderPacks(payload.packs);
  } catch (error) {
    console.error(
      "Unable to load installed map packs.",
      error,
    );

    showErrorState();
  }
}

function initializeRenderer() {
  if (
    typeof maplibregl === "undefined"
    || typeof pmtiles === "undefined"
  ) {
    throw new Error(
      "Offline map renderer libraries are unavailable.",
    );
  }

  state.protocol = new pmtiles.Protocol();
  maplibregl.addProtocol(
    "pmtiles",
    state.protocol.tile,
  );
}

function initialize() {
  const hostname = window.location.hostname || "offgridpi";

  elements.readerHost.textContent = hostname;
  elements.dashboardLink.href = dashboardUrl();

  elements.mapZoomIn.addEventListener("click", () => {
    if (state.map) {
      state.map.zoomIn();
    }
  });

  elements.mapZoomOut.addEventListener("click", () => {
    if (state.map) {
      state.map.zoomOut();
    }
  });

  elements.mapResetView.addEventListener("click", () => {
    const pack = selectedPack();

    if (state.map && pack) {
      state.map.fitBounds(
        pack.region.bounds,
        {
          padding: 24,
          maxZoom: pack.region.max_zoom,
        },
      );
    }
  });

  elements.mapHelp.addEventListener("click", () => {
    const willOpen = elements.mapHelpPanel.hidden;
    elements.mapHelpPanel.hidden = !willOpen;
    elements.mapHelp.setAttribute(
      "aria-expanded",
      willOpen ? "true" : "false",
    );
  });

  elements.mapHelpClose.addEventListener("click", () => {
    elements.mapHelpPanel.hidden = true;
    elements.mapHelp.setAttribute("aria-expanded", "false");
    elements.mapHelp.focus();
  });

  document.addEventListener("keydown", (event) => {
    if (!state.map) {
      return;
    }

    if (event.key === "+" || event.key === "=") {
      event.preventDefault();
      state.map.zoomIn();
      return;
    }

    if (event.key === "-" || event.key === "_") {
      event.preventDefault();
      state.map.zoomOut();
      return;
    }

    const panDistance = 100;

    if (event.key === "ArrowUp") {
      event.preventDefault();
      state.map.panBy([0, -panDistance]);
      return;
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      state.map.panBy([0, panDistance]);
      return;
    }

    if (event.key === "ArrowLeft") {
      event.preventDefault();
      state.map.panBy([-panDistance, 0]);
      return;
    }

    if (event.key === "ArrowRight") {
      event.preventDefault();
      state.map.panBy([panDistance, 0]);
      return;
    }

    if (event.key === "Home") {
      const pack = selectedPack();

      if (pack) {
        event.preventDefault();
        state.map.fitBounds(
          pack.region.bounds,
          {
            padding: 24,
            maxZoom: pack.region.max_zoom,
          },
        );
      }
    }
  });

  try {
    initializeRenderer();
  } catch (error) {
    console.error(
      "Unable to initialize offline map rendering.",
      error,
    );

    elements.renderMessage.querySelector("h2").textContent =
      "Map renderer unavailable";
    elements.renderMessage.querySelector("p:last-child").textContent =
      "Installed map details remain available, but the map renderer could not start.";
  }

  loadPacks();
}

initialize();
