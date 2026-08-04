"use strict";

const DATA_URL = "../data/system-status.json";
const REFRESH_INTERVAL_MS = 60_000;

const overallStatus = document.getElementById("overall-status");
const statusMessage = document.getElementById("status-message");
const statusSummary = document.getElementById("status-summary");
const servicePanel = document.getElementById("service-panel");
const serviceList = document.getElementById("service-list");

function formatBytes(value) {
  if (!Number.isFinite(value) || value < 0) {
    return "Unavailable";
  }

  const units = ["B", "KiB", "MiB", "GiB", "TiB"];
  let amount = value;
  let index = 0;

  while (amount >= 1024 && index < units.length - 1) {
    amount /= 1024;
    index += 1;
  }

  const digits = index === 0 ? 0 : 1;
  return `${amount.toFixed(digits)} ${units[index]}`;
}

function formatUptime(value) {
  if (!Number.isFinite(value) || value < 0) {
    return "Unavailable";
  }

  const days = Math.floor(value / 86400);
  const hours = Math.floor((value % 86400) / 3600);
  const minutes = Math.floor((value % 3600) / 60);

  if (days > 0) {
    return `${days}d ${hours}h`;
  }

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }

  return `${minutes}m`;
}

function formatTemperature(value) {
  if (!value || value === "unavailable") {
    return "Unavailable";
  }

  return String(value).replace(/^temp=/, "");
}

function throttleDescription(value) {
  if (!value || value === "unavailable") {
    return "Throttle state unavailable";
  }

  if (value === "throttled=0x0") {
    return "No throttling detected";
  }

  return String(value);
}

function addSummaryCard(title, value, detail) {
  const card = document.createElement("article");
  card.className = "status-card";

  const heading = document.createElement("h2");
  heading.textContent = title;

  const primary = document.createElement("p");
  primary.className = "status-value";
  primary.textContent = value;

  const secondary = document.createElement("p");
  secondary.className = "status-detail";
  secondary.textContent = detail;

  card.append(heading, primary, secondary);
  statusSummary.append(card);
}

function serviceHealth(service) {
  if (service.required === false) {
    return {
      label: "Not required",
      className: "state-muted",
    };
  }

  const active = service.active === "active";
  const portReady = (
    service.port === undefined ||
    service.listening === true
  );
  const httpReady = (
    service.http_status === undefined ||
    ["200", "301", "302"].includes(service.http_status)
  );

  if (active && portReady && httpReady) {
    return {
      label: "Healthy",
      className: "state-good",
    };
  }

  return {
    label: "Attention",
    className: "state-warning",
  };
}

function addServiceRow(service) {
  const row = document.createElement("article");
  row.className = "service-row";

  const information = document.createElement("div");

  const name = document.createElement("h3");
  name.className = "service-name";
  name.textContent = service.name || service.service;

  const details = [
    service.service,
    `Active: ${service.active}`,
    `Enabled: ${service.enabled}`,
  ];

  if (service.port !== undefined) {
    details.push(`TCP ${service.port}`);
    details.push(
      service.listening ? "Listening" : "Port closed"
    );
    details.push(`HTTP: ${service.http_status}`);
  }

  const detail = document.createElement("p");
  detail.className = "service-detail";
  detail.textContent = details.join(" • ");

  information.append(name, detail);

  const health = serviceHealth(service);
  const state = document.createElement("span");
  state.className = `service-state ${health.className}`;
  state.textContent = health.label;

  row.append(information, state);
  serviceList.append(row);
}

function renderReport(report) {
  statusSummary.replaceChildren();
  serviceList.replaceChildren();

  const hardware = report.hardware || {};
  const storage = report.storage || {};
  const kiwix = report.kiwix || {};
  const documents = report.documents || {};
  const backups = report.backups || {};
  const failedUnits = Array.isArray(report.failed_units)
    ? report.failed_units
    : [];

  addSummaryCard(
    "Hostname",
    String(report.hostname || "Unavailable"),
    "Local Offgrid Pi system"
  );

  addSummaryCard(
    "Uptime",
    formatUptime(report.uptime_seconds),
    "Time since last boot"
  );

  addSummaryCard(
    "Temperature",
    formatTemperature(hardware.temperature),
    throttleDescription(hardware.throttled)
  );

  addSummaryCard(
    "Storage",
    `${storage.used_percent ?? "?"}% used`,
    `${formatBytes(storage.free_bytes)} free`
  );

  addSummaryCard(
    "Kiwix Content",
    String(kiwix.approved_zim_count ?? 0),
    "Approved ZIM archives"
  );

  addSummaryCard(
    "Documents",
    String(documents.total_files ?? 0),
    documents.available
      ? "Public catalog available"
      : "Catalog unavailable"
  );

  addSummaryCard(
    "Backups",
    String(backups.count ?? 0),
    "Configuration snapshots"
  );

  addSummaryCard(
    "Failed Units",
    String(failedUnits.length),
    failedUnits.length === 0
      ? "None detected"
      : "Review required"
  );

  const services = Array.isArray(report.services)
    ? report.services
    : [];

  services.forEach(addServiceRow);

  const state = report.overall === "HEALTHY"
    ? "HEALTHY"
    : "ATTENTION";

  overallStatus.textContent = state;
  overallStatus.className = (
    state === "HEALTHY"
      ? "status-badge status-healthy"
      : "status-badge status-attention"
  );

  const refreshed = new Date().toLocaleTimeString(
    [],
    {
      hour: "numeric",
      minute: "2-digit",
      second: "2-digit",
    }
  );

  statusMessage.className = "status-message";
  statusMessage.textContent = (
    `Latest local report loaded at ${refreshed}. ` +
    "This page refreshes once per minute."
  );

  statusSummary.hidden = false;
  servicePanel.hidden = false;
}

async function loadStatus() {
  try {
    const response = await fetch(
      `${DATA_URL}?timestamp=${Date.now()}`,
      {
        cache: "no-store",
      }
    );

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const report = await response.json();

    if (!["HEALTHY", "ATTENTION"].includes(report.overall)) {
      throw new Error("Invalid system state");
    }

    renderReport(report);
  } catch (error) {
    overallStatus.textContent = "Unavailable";
    overallStatus.className = "status-badge status-error";

    statusMessage.className = "status-message error";
    statusMessage.textContent = (
      "The local system-status report could not be loaded. " +
      `Details: ${error.message}`
    );
  }
}

loadStatus();
window.setInterval(loadStatus, REFRESH_INTERVAL_MS);
