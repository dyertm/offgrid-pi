#!/usr/bin/env python3

import argparse
import html
import json
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fail(message):
    print(f"FAIL: {message}", file=sys.stderr)
    return 1


def validate_register(validator, register, license_file):
    result = subprocess.run(
        [
            sys.executable,
            str(validator),
            str(register),
            str(license_file),
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    if result.returncode == 0:
        return

    details = "\n".join(
        part.strip()
        for part in (result.stdout, result.stderr)
        if part.strip()
    )

    raise RuntimeError(
        "Software register validation failed."
        + (f"\n{details}" if details else "")
    )


def installed_version(dpkg_query, package_name):
    result = subprocess.run(
        [
            dpkg_query,
            "-W",
            "-f=${Version}",
            package_name,
        ],
        text=True,
        capture_output=True,
        check=False,
    )

    if result.returncode != 0:
        return None

    version = result.stdout.strip()
    return version or None


def system_file(system_root, absolute_path):
    return system_root / absolute_path.lstrip("/")


def package_html(package, version, notice_name):
    display_name = html.escape(package["display_name"])
    package_name = html.escape(package["package_name"])
    purpose = html.escape(package["purpose"])
    license_summary = html.escape(package["license_summary"])
    source_information = html.escape(package["source_information"])
    homepage = html.escape(package["homepage"], quote=True)
    shown_version = html.escape(version)

    notice_link = ""

    if notice_name is not None:
        safe_notice_name = html.escape(
            notice_name,
            quote=True,
        )

        notice_link = f"""
            <a href="notices/{safe_notice_name}">
              Read installed copyright notice
            </a>
        """.strip()

    return f"""
        <article class="component">
          <div class="component-header">
            <h3>{display_name}</h3>
            <span class="component-version">
              {shown_version}
            </span>
          </div>

          <p>{purpose}</p>

          <ul class="component-meta">
            <li>
              <strong>Debian package:</strong>
              <code>{package_name}</code>
            </li>
            <li>
              <strong>License summary:</strong>
              {license_summary}
            </li>
            <li>
              <strong>Source information:</strong>
              {source_information}
            </li>
          </ul>

          <div class="component-links">
            {notice_link}

            <a href="{homepage}">
              Upstream project
            </a>
          </div>
        </article>
    """.strip()


def render_page(register, components, generated_at):
    project = register["project"]

    project_name = html.escape(project["name"])
    project_version = html.escape(project["version"])
    project_license = html.escape(project["license_expression"])
    copyright_notice = html.escape(
        project["copyright_notice"]
    )

    component_markup = "\n\n".join(components)

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta
    name="viewport"
    content="width=device-width, initial-scale=1"
  >
  <meta
    name="description"
    content="Offline software licenses and notices for Offgrid Pi"
  >

  <title>Legal &amp; Notices | Offgrid Pi</title>

  <link rel="stylesheet" href="../css/styles.css">
  <link rel="stylesheet" href="legal.css">
</head>

<body>
  <div class="page legal-page">
    <header class="site-header">
      <div>
        <p class="eyebrow">Offline legal information</p>
        <h1>Legal &amp; Notices</h1>
        <p class="subtitle">
          Project licensing and installed software information
        </p>
      </div>

      <div class="header-actions">
        <a class="dashboard-return" href="../">
          ← Dashboard
        </a>
      </div>
    </header>

    <main>
      <section class="legal-intro">
        <h2>{project_name}</h2>

        <p>
          Project version: <strong>{project_version}</strong><br>
          Project license: <strong>{project_license}</strong><br>
          {copyright_notice}
        </p>

        <div class="component-links">
          <a href="notices/offgrid-pi-license.txt">
            Read the complete project license
          </a>
        </div>
      </section>

      <section class="legal-panel legal-warning">
        <h2>About this register</h2>

        <p>
          This page records the direct software packages intentionally
          installed by Offgrid Pi. Debian packages can include additional
          libraries, dependencies, copyright holders, and license terms.
          The complete installed Debian copyright records are provided
          locally below. Components may be marked as not installed when
          this page is generated for a partial module installation.
        </p>

        <p>
          This notice inventory is not, by itself, a corresponding-source
          distribution or written source offer. Source-fulfilment
          procedures must be prepared separately before distributing a
          commercial release image.
        </p>

        <p>
          External project links are informational and might not be
          available while the system is offline.
        </p>
      </section>

      <section class="legal-panel">
        <h2>Direct software components</h2>

        <div class="component-list">
          {component_markup}
        </div>
      </section>

      <p class="generated-at">
        Generated from the installed system at {generated_at}.
      </p>
    </main>

    <footer class="site-footer">
      <span>Read-only offline notices</span>
      <span>No cloud account required</span>
    </footer>
  </div>
</body>
</html>
"""


def generate(args):
    register_path = args.register.resolve()
    license_path = args.license.resolve()
    stylesheet_path = args.stylesheet.resolve()
    validator_path = args.validator.resolve()
    output_root = args.output_root.resolve()
    system_root = args.system_root.resolve()

    validate_register(
        validator_path,
        register_path,
        license_path,
    )

    register = json.loads(
        register_path.read_text(encoding="utf-8")
    )

    if not stylesheet_path.is_file():
        raise RuntimeError(
            f"Stylesheet not found: {stylesheet_path}"
        )

    if not license_path.is_file():
        raise RuntimeError(
            f"Project license not found: {license_path}"
        )

    output_root.parent.mkdir(parents=True, exist_ok=True)

    temporary = Path(
        tempfile.mkdtemp(
            prefix=".offgridpi-legal-",
            dir=output_root.parent,
        )
    )

    try:
        notices = temporary / "notices"
        notices.mkdir()

        shutil.copyfile(
            stylesheet_path,
            temporary / "legal.css",
        )

        shutil.copyfile(
            license_path,
            notices / "offgrid-pi-license.txt",
        )

        rendered_components = []
        installed_count = 0

        for package in register["packages"]:
            package_name = package["package_name"]
            version = installed_version(
                args.dpkg_query,
                package_name,
            )

            if version is None:
                if package["required"] and not args.allow_missing:
                    raise RuntimeError(
                        "Required package is not installed: "
                        f"{package_name}"
                    )

                rendered_components.append(
                    package_html(
                        package,
                        "Not installed",
                        None,
                    )
                )
                continue

            copyright_source = system_file(
                system_root,
                package["copyright_file"],
            )

            if not copyright_source.is_file():
                raise RuntimeError(
                    "Installed copyright record is missing: "
                    f"{copyright_source}"
                )

            notice_name = f"{package_name}.txt"

            shutil.copyfile(
                copyright_source,
                notices / notice_name,
            )

            installed_count += 1

            rendered_components.append(
                package_html(
                    package,
                    version,
                    notice_name,
                )
            )

        generated_at = (
            datetime.now(timezone.utc)
            .replace(microsecond=0)
            .isoformat()
            .replace("+00:00", "Z")
        )

        page = render_page(
            register,
            rendered_components,
            generated_at,
        )

        (temporary / "index.html").write_text(
            page,
            encoding="utf-8",
        )

        if output_root.exists():
            if output_root.is_dir():
                shutil.rmtree(output_root)
            else:
                output_root.unlink()

        temporary.rename(output_root)

    except Exception:
        shutil.rmtree(temporary, ignore_errors=True)
        raise

    print(
        "PASS: Generated Legal & Notices page with "
        f"{installed_count} installed component(s) "
        f"out of {len(rendered_components)} registered."
    )
    print(f"Output: {output_root}")


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Generate the offline Offgrid Pi Legal & Notices page."
        )
    )

    parser.add_argument(
        "--register",
        type=Path,
        default=ROOT / "compliance/software-components.json",
    )
    parser.add_argument(
        "--license",
        type=Path,
        default=ROOT / "LICENSE",
    )
    parser.add_argument(
        "--stylesheet",
        type=Path,
        default=ROOT / "dashboard/legal/legal.css",
    )
    parser.add_argument(
        "--validator",
        type=Path,
        default=(
            ROOT
            / "compliance"
            / "validate-software-components.py"
        ),
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "--system-root",
        type=Path,
        default=Path("/"),
    )
    parser.add_argument(
        "--dpkg-query",
        default="dpkg-query",
    )
    parser.add_argument(
        "--allow-missing",
        action="store_true",
        help=(
            "Generate a truthful partial-install page instead of "
            "failing when a registered package is not installed."
        ),
    )

    return parser.parse_args()


def main():
    try:
        generate(parse_args())
    except (OSError, RuntimeError, ValueError) as error:
        return fail(str(error))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
