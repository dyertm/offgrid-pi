"use strict";

(() => {
  if (window.location.port !== "8080") {
    return;
  }

  if (document.getElementById("offgridpi-kiwix-nav")) {
    return;
  }

  const nav = document.createElement("nav");
  nav.id = "offgridpi-kiwix-nav";
  nav.setAttribute("aria-label", "Offgrid Pi navigation");

  const backButton = document.createElement("button");
  backButton.type = "button";
  backButton.className = "offgridpi-kiwix-nav-button";
  backButton.textContent = "← Back";

  backButton.addEventListener("click", () => {
    if (window.history.length > 1) {
      window.history.back();
      return;
    }

    window.location.href =
      `${window.location.protocol}//${window.location.hostname}:8080/`;
  });

  const dashboardLink = document.createElement("a");
  dashboardLink.className = "offgridpi-kiwix-nav-button";
  dashboardLink.textContent = "Dashboard";
  dashboardLink.href =
    `${window.location.protocol}//${window.location.hostname}:8081/`;

  const isKiwixHome = window.location.pathname === "/";

  if (isKiwixHome) {
    const languageButton = document.createElement("button");
    languageButton.type = "button";
    languageButton.className =
      "offgridpi-kiwix-nav-button offgridpi-kiwix-language-button";
    languageButton.textContent = "Language";

    languageButton.addEventListener("click", () => {
      const nativeLanguageButton =
        document.getElementById("uiLanguageSelectorButton");

      if (nativeLanguageButton) {
        nativeLanguageButton.click();
      }
    });

    nav.append(languageButton, backButton, dashboardLink);
  } else {
    nav.append(backButton, dashboardLink);
  }

  document.body.appendChild(nav);

  document.documentElement.classList.add("offgridpi-kiwix-enhanced");

  if (isKiwixHome) {
    document.documentElement.classList.add("offgridpi-kiwix-home");
  }
})();
