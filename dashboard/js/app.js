"use strict";

const hostname = window.location.hostname || "localhost";

const kiwixLink = document.getElementById("kiwix-link");
const dashboardHost = document.getElementById("dashboard-host");

if (kiwixLink) {
  kiwixLink.href = `http://${hostname}:8080`;
}

if (dashboardHost) {
  dashboardHost.textContent = hostname;
}
