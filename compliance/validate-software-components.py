#!/usr/bin/env python3

import json
import re
import sys
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[1]

EXPECTED_PACKAGES = {
    "python3": "/usr/share/doc/python3/copyright",
    "inotify-tools": "/usr/share/doc/inotify-tools/copyright",
    "curl": "/usr/share/doc/curl/copyright",
    "rsync": "/usr/share/doc/rsync/copyright",
    "chromium": "/usr/share/doc/chromium/copyright",
    "kiwix-tools": "/usr/share/doc/kiwix-tools/copyright",
    "zim-tools": "/usr/share/doc/zim-tools/copyright",
}

APPROVED_VENDORED_COMPONENTS = {
    "maplibre-gl-js": {
        "version": "5.13.0",
        "license_expression": "BSD-3-Clause",
        "license_file": (
            "maps/vendor/maplibre-gl-js/LICENSE.txt"
        ),
        "asset_prefix": "maps/vendor/maplibre-gl-js/",
    },
    "pmtiles-js": {
        "version": "4.4.1",
        "license_expression": "BSD-3-Clause",
        "license_file": (
            "maps/vendor/pmtiles-js/LICENSE.txt"
        ),
        "asset_prefix": "maps/vendor/pmtiles-js/",
    },
    "fflate": {
        "version": "0.8.2",
        "license_expression": "MIT",
        "license_file": (
            "maps/vendor/pmtiles-js/FFLATE-LICENSE.txt"
        ),
        "asset_prefix": "maps/vendor/pmtiles-js/",
    },
}

REGISTER_FIELDS = {
    "schema_version",
    "register_id",
    "title",
    "description",
    "project",
    "packages",
    "vendored_components",
}

PROJECT_FIELDS = {
    "name",
    "version",
    "license_expression",
    "license_file",
    "copyright_notice",
}

PACKAGE_FIELDS = {
    "component_id",
    "display_name",
    "package_name",
    "purpose",
    "homepage",
    "version_source",
    "license_summary",
    "copyright_file",
    "source_information",
    "required",
}

VENDORED_FIELDS = {
    "component_id",
    "display_name",
    "version",
    "purpose",
    "homepage",
    "license_expression",
    "license_summary",
    "license_file",
    "source_information",
    "asset_paths",
    "required",
}

ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
VERSION_PATTERN = re.compile(
    r"^[0-9]+[.][0-9]+[.][0-9]+"
    r"(?:[-+][0-9A-Za-z.-]+)?$"
)


def check_fields(label, value, expected, errors):
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object.")
        return False

    missing = sorted(expected - set(value))
    unknown = sorted(set(value) - expected)

    if missing:
        errors.append(
            f"{label} is missing fields: {', '.join(missing)}"
        )

    if unknown:
        errors.append(
            f"{label} contains unknown fields: {', '.join(unknown)}"
        )

    return not missing and not unknown


def require_text(label, value, errors):
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{label} must be a nonempty string.")


def safe_repo_path(value):
    if not isinstance(value, str) or not value:
        return False

    if "\\" in value or value.startswith("/"):
        return False

    path = PurePosixPath(value)

    return not any(
        part in {"", ".", ".."}
        for part in path.parts
    )


def validate(register, license_path):
    errors = []

    if not check_fields(
        "Register",
        register,
        REGISTER_FIELDS,
        errors,
    ):
        return errors

    if register.get("schema_version") != 1:
        errors.append("schema_version must equal 1.")

    register_id = register.get("register_id")

    if (
        not isinstance(register_id, str)
        or not ID_PATTERN.fullmatch(register_id)
    ):
        errors.append("register_id is invalid.")

    require_text("title", register.get("title"), errors)
    require_text("description", register.get("description"), errors)

    project = register.get("project")

    if check_fields(
        "Project",
        project,
        PROJECT_FIELDS,
        errors,
    ):
        require_text("project.name", project.get("name"), errors)
        require_text("project.version", project.get("version"), errors)
        require_text(
            "project.license_expression",
            project.get("license_expression"),
            errors,
        )
        require_text(
            "project.copyright_notice",
            project.get("copyright_notice"),
            errors,
        )

        if project.get("license_file") != "LICENSE":
            errors.append(
                "project.license_file must equal LICENSE."
            )

        try:
            license_text = license_path.read_text(encoding="utf-8")
        except OSError as error:
            errors.append(
                f"Unable to read project license: {error}"
            )
        else:
            if license_text.splitlines()[0] != "MIT License":
                errors.append(
                    "The current LICENSE file is not the expected MIT license."
                )

            if project.get("license_expression") != "MIT":
                errors.append(
                    "Project license expression does not match LICENSE."
                )

            notice = project.get("copyright_notice")

            if isinstance(notice, str) and notice not in license_text:
                errors.append(
                    "Project copyright notice does not match LICENSE."
                )

    packages = register.get("packages")

    if not isinstance(packages, list) or not packages:
        errors.append("packages must be a nonempty list.")
        return errors

    seen_ids = set()
    seen_names = set()

    for number, package in enumerate(packages, start=1):
        label = f"Package {number}"

        if not check_fields(
            label,
            package,
            PACKAGE_FIELDS,
            errors,
        ):
            continue

        component_id = package.get("component_id")
        package_name = package.get("package_name")

        if (
            not isinstance(component_id, str)
            or not ID_PATTERN.fullmatch(component_id)
        ):
            errors.append(f"{label} has an invalid component_id.")
        elif component_id in seen_ids:
            errors.append(
                f"Duplicate component_id: {component_id}"
            )
        else:
            seen_ids.add(component_id)

        if package_name in seen_names:
            errors.append(
                f"Duplicate package_name: {package_name}"
            )
        else:
            seen_names.add(package_name)

        if component_id != package_name:
            errors.append(
                f"{label} component_id must match package_name."
            )

        if package_name not in EXPECTED_PACKAGES:
            errors.append(
                f"{label} contains an unapproved package: "
                f"{package_name!r}"
            )
        elif (
            package.get("copyright_file")
            != EXPECTED_PACKAGES[package_name]
        ):
            errors.append(
                f"{label} has an unexpected copyright path."
            )

        if package.get("version_source") != "dpkg-query":
            errors.append(
                f"{label} version_source must equal dpkg-query."
            )

        homepage = package.get("homepage")

        if (
            not isinstance(homepage, str)
            or not homepage.startswith("https://")
        ):
            errors.append(
                f"{label} homepage must use HTTPS."
            )

        for field in (
            "display_name",
            "purpose",
            "license_summary",
            "source_information",
        ):
            require_text(
                f"{label}.{field}",
                package.get(field),
                errors,
            )

        if not isinstance(package.get("required"), bool):
            errors.append(
                f"{label}.required must be true or false."
            )

    if seen_names != set(EXPECTED_PACKAGES):
        missing = sorted(set(EXPECTED_PACKAGES) - seen_names)
        unexpected = sorted(seen_names - set(EXPECTED_PACKAGES))

        if missing:
            errors.append(
                "Required packages are missing: "
                + ", ".join(missing)
            )

        if unexpected:
            errors.append(
                "Unexpected packages are present: "
                + ", ".join(unexpected)
            )

    vendored = register.get("vendored_components")

    if not isinstance(vendored, list):
        errors.append(
            "vendored_components must be a list."
        )
        return errors

    seen_vendored_ids = set()

    for number, component in enumerate(
        vendored,
        start=1,
    ):
        label = f"Vendored component {number}"

        if not check_fields(
            label,
            component,
            VENDORED_FIELDS,
            errors,
        ):
            continue

        component_id = component.get("component_id")

        if (
            not isinstance(component_id, str)
            or not ID_PATTERN.fullmatch(component_id)
        ):
            errors.append(
                f"{label} has an invalid component_id."
            )
            continue

        if component_id in seen_vendored_ids:
            errors.append(
                f"Duplicate vendored component_id: {component_id}"
            )
        else:
            seen_vendored_ids.add(component_id)

        approved = APPROVED_VENDORED_COMPONENTS.get(
            component_id
        )

        if approved is None:
            errors.append(
                f"{label} contains an unapproved vendored component: "
                f"{component_id!r}"
            )
            continue

        for field in (
            "display_name",
            "purpose",
            "license_summary",
            "source_information",
        ):
            require_text(
                f"{label}.{field}",
                component.get(field),
                errors,
            )

        version = component.get("version")

        if (
            not isinstance(version, str)
            or not VERSION_PATTERN.fullmatch(version)
        ):
            errors.append(
                f"{label}.version must be a semantic version."
            )
        elif version != approved["version"]:
            errors.append(
                f"{label} has an unapproved version."
            )

        homepage = component.get("homepage")

        if (
            not isinstance(homepage, str)
            or not homepage.startswith("https://")
        ):
            errors.append(
                f"{label}.homepage must use HTTPS."
            )

        if (
            component.get("license_expression")
            != approved["license_expression"]
        ):
            errors.append(
                f"{label} has an unexpected license expression."
            )

        license_file = component.get("license_file")

        if (
            license_file != approved["license_file"]
            or not safe_repo_path(license_file)
        ):
            errors.append(
                f"{label} has an unexpected license path."
            )

        asset_paths = component.get("asset_paths")

        if not isinstance(asset_paths, list) or not asset_paths:
            errors.append(
                f"{label}.asset_paths must be a nonempty list."
            )
        else:
            seen_assets = set()

            for asset_path in asset_paths:
                if (
                    not safe_repo_path(asset_path)
                    or not asset_path.startswith(
                        approved["asset_prefix"]
                    )
                ):
                    errors.append(
                        f"{label} contains an unsafe asset path."
                    )
                    continue

                if asset_path in seen_assets:
                    errors.append(
                        f"{label} contains a duplicate asset path."
                    )
                else:
                    seen_assets.add(asset_path)

        if component.get("required") is not True:
            errors.append(
                f"{label}.required must be true."
            )

    expected_vendored = set(
        APPROVED_VENDORED_COMPONENTS
    )

    if seen_vendored_ids != expected_vendored:
        missing = sorted(
            expected_vendored - seen_vendored_ids
        )
        unexpected = sorted(
            seen_vendored_ids - expected_vendored
        )

        if missing:
            errors.append(
                "Required vendored components are missing: "
                + ", ".join(missing)
            )

        if unexpected:
            errors.append(
                "Unexpected vendored components are present: "
                + ", ".join(unexpected)
            )

    return errors


def main():
    if len(sys.argv) > 3:
        print(
            "Usage: validate-software-components.py "
            "[REGISTER.json] [LICENSE]",
            file=sys.stderr,
        )
        return 2

    register_path = (
        Path(sys.argv[1])
        if len(sys.argv) >= 2
        else ROOT / "compliance/software-components.json"
    )

    license_path = (
        Path(sys.argv[2])
        if len(sys.argv) >= 3
        else ROOT / "LICENSE"
    )

    try:
        register = json.loads(
            register_path.read_text(encoding="utf-8")
        )
    except FileNotFoundError:
        print(
            f"FAIL: Register not found: {register_path}",
            file=sys.stderr,
        )
        return 2
    except json.JSONDecodeError as error:
        print(f"FAIL: Invalid JSON: {error}")
        return 1

    if not isinstance(register, dict):
        print("FAIL: Register root must be an object.")
        return 1

    errors = validate(register, license_path)

    if errors:
        for error in errors:
            print(f"FAIL: {error}")

        return 1

    print(
        "PASS: Software register contains "
        f"{len(register['packages'])} approved direct packages."
    )
    print("PASS: Project license matches the MIT LICENSE file.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
