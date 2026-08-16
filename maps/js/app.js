"use strict";

const elements = {
  dashboardLink: document.getElementById("dashboard-link"),
  readerHost: document.getElementById("reader-host"),
  packStatus: document.getElementById("pack-status"),
  packCount: document.getElementById("pack-count"),
  catalogMessage: document.getElementById("catalog-message"),
  packList: document.getElementById("pack-list"),
  mapWorkspace: document.getElementById("map-workspace"),
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
};

function dashboardUrl() {
  const hostname = window.location.hostname || "offgridpi";

  return `${window.location.protocol}//${hostname}:8081/`;
}

function packKey(pack) {
  return `${pack.pack_id}@${pack.version}`;
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

  elements.mapWorkspace.hidden = true;
  elements.detailsPanel.hidden = false;
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

function initialize() {
  const hostname = window.location.hostname || "offgridpi";

  elements.readerHost.textContent = hostname;
  elements.dashboardLink.href = dashboardUrl();

  loadPacks();
}

initialize();
