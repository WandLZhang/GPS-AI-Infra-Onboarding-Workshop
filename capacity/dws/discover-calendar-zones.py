#!/usr/bin/env python3
"""
@file discover-calendar-zones.py
@brief Finds the zones that take DWS Calendar mode requests for each eligible
       GPU, H4D and TPU machine type, and writes the results to a CSV.

@details This script:
  1. Uses the Compute Engine API to list the A3, A4 and H4D machine types in every zone
  2. For each unique (machine_type, region), probes the Calendar mode advice API
  3. Does the same for TPU v5e, v5p and v6e
  4. Writes every zone's status to a CSV next to the script. RECOMMENDED and
     NO_CAPACITY mean the zone takes Calendar requests for that machine type.

  Regions and zones come from the Compute Engine machineTypes API. Only the machine
  families are hardcoded.

  Usage:
    python3 -m venv .venv && source .venv/bin/activate
    pip install google-api-python-client google-auth
    gcloud auth application-default login
    python discover-calendar-zones.py --project <PROJECT_ID> [--gpu-only | --tpu-only]

  The advice API is read-only: it creates no reservation and costs nothing. Your project
  needs the compute.advice.calendarMode permission.

@author Willis Zhang
@date 2026-02-09
"""

import google.auth

from google.auth.transport.requests import Request
from googleapiclient import discovery
import csv
import os
from datetime import datetime, timedelta, timezone
from collections import defaultdict


def discover_gpu_machine_types(project_id, credentials):
    """
    @brief Lists the Calendar-eligible GPU and H4D machine types in every zone.

    @details Uses machineTypes().aggregatedList() to find every machine type whose name
             starts with one of GPU_PREFIXES, and returns the regions that carry each one.

    @param project_id Google Cloud project ID
    @param credentials Google auth credentials

    @return dict mapping machine_type -> set of regions where it exists
    """
    service = discovery.build('compute', 'v1', credentials=credentials)

    # Calendar mode takes A4, A3 Ultra, A3 Mega, A3 High with 8 GPUs, A3 Edge and H4D
    # ("Future reservation requests in calendar mode", last updated 2026-10-13).
    # The advice API rejects A2, G2 and G4 with "This machine family is not supported
    # in Calendar Mode." (checked 2026-10-15), so probing them only adds minutes.
    GPU_PREFIXES = ('a3-', 'a4-', 'h4d-')

    machine_to_regions = defaultdict(set)
    machine_to_zones = defaultdict(set)

    print("[1/3] Discovering all GPU machine types across all zones...")

    request = service.machineTypes().aggregatedList(project=project_id)
    while request is not None:
        response = request.execute()
        for scope_name, scope_data in response.get('items', {}).items():
            if scope_name.startswith("zones/"):
                zone_name = scope_name.split('/')[-1]
                region = '-'.join(zone_name.split('-')[:-1])
                for mt in scope_data.get('machineTypes', []):
                    mt_name = mt.get('name', '')
                    if any(mt_name.startswith(prefix) for prefix in GPU_PREFIXES):
                        machine_to_regions[mt_name].add(region)
                        machine_to_zones[mt_name].add(zone_name)
        request = service.machineTypes().aggregatedList_next(
            previous_request=request, previous_response=response
        )

    print(f"  Found {len(machine_to_regions)} unique GPU machine types across {len(set().union(*machine_to_regions.values()))} regions")
    for mt in sorted(machine_to_regions.keys()):
        regions = machine_to_regions[mt]
        zones = machine_to_zones[mt]
        print(f"    {mt}: {len(zones)} zones, {len(regions)} regions")

    return machine_to_regions


def probe_calendar_support(project_id, machine_type, region, credentials, service=None):
    """
    @brief Probes the Calendar Mode advisory API for a given machine type and region.

    @details Makes a single API call with a far-future date range. Parses the response
             to determine which zones support Calendar mode:
             - RECOMMENDED = Calendar available, capacity found
             - NO_CAPACITY = Calendar supported but no free capacity in search window
             - NOT_SUPPORTED = Calendar mode doesn't take this machine type in this zone,
               even where the zone carries it

    @param project_id Google Cloud project ID
    @param machine_type The machine type to probe (e.g., 'a3-highgpu-8g')
    @param region The GCP region to probe (e.g., 'us-central1')
    @param credentials Google auth credentials
    @param service Optional pre-built beta compute service to avoid rebuilding per call

    @return list of dicts with keys: zone, status, details, machine_type, gpu_label
    """
    if service is None:
        service = discovery.build('compute', 'beta', credentials=credentials)

    # GPU label mapping for human-readable output
    GPU_LABELS = {
        'a3-highgpu': 'NVIDIA H100 80GB',
        'a3-megagpu': 'NVIDIA H100 80GB MEGA',
        'a3-ultragpu': 'NVIDIA H200 141GB',
        'a3-edgegpu': 'NVIDIA H100 80GB (Edge)',
        'a4-highgpu': 'NVIDIA B200 180GB',
    }

    # Determine the GPU label from machine type prefix
    mt_prefix = '-'.join(machine_type.split('-')[:2])
    gpu_label = GPU_LABELS.get(mt_prefix, machine_type)

    # Use a wide future window to maximize chance of response
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    start = now + timedelta(days=5)
    end = now + timedelta(days=90)
    duration = timedelta(days=1)

    request_body = {
        "futureResourcesSpecs": {
            "probe": {
                "timeRangeSpec": {
                    "startTimeNotEarlierThan": start.isoformat() + "Z",
                    "startTimeNotLaterThan": end.isoformat() + "Z",
                    "minDuration": f"{int(duration.total_seconds())}s",
                    "maxDuration": f"{int(duration.total_seconds())}s",
                },
                "targetResources": {
                    "specificSkuResources": {
                        "instanceCount": "1",
                        "machineType": machine_type
                    }
                },
                "deploymentType": "DENSE"
            }
        }
    }

    results = []

    try:
        request = service.advice().calendarMode(
            project=project_id, region=region, body=request_body
        )
        response = request.execute()

        for recommendation in response.get("recommendations", []):
            spec = recommendation.get("recommendationsPerSpec", {}).get("probe", {})

            # The recommended zone (Calendar found capacity here)
            location = spec.get("location", "")
            if location:
                zone = location.replace("zones/", "")
                results.append({
                    'zone': zone,
                    'status': 'RECOMMENDED',
                    'details': 'Calendar mode available, capacity found',
                    'machine_type': machine_type,
                    'gpu_label': gpu_label,
                })

            # Other zones in this region
            for zone_path, info in spec.get("otherLocations", {}).items():
                zone = zone_path.replace("zones/", "")
                status = info.get("status", "UNKNOWN")
                details = info.get("details", "")
                results.append({
                    'zone': zone,
                    'status': status,
                    'details': details,
                    'machine_type': machine_type,
                    'gpu_label': gpu_label,
                })

    except Exception as err:
        error_str = str(err)
        # Skip "not supported" errors; many combos return them.
        if "not supported" in error_str.lower() or "invalid" in error_str.lower():
            pass
        elif "not found" in error_str.lower():
            pass
        else:
            print(f"\n    Warning: {machine_type} in {region}: {err}")

    return results


def probe_tpu_calendar_support(project_id, tpu_name, vm_family, region, chip_count, credentials, service=None):
    """
    @brief Probes Calendar Mode for TPU types using aggregateResources format.

    @param project_id Google Cloud project ID
    @param tpu_name Human-readable TPU name
    @param vm_family The VM family string for calendar-mode API
    @param region The GCP region
    @param chip_count Minimum chip count to request
    @param credentials Google auth credentials
    @param service Optional pre-built beta compute service

    @return list of dicts with zone discovery data
    """
    if service is None:
        service = discovery.build('compute', 'beta', credentials=credentials)

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    start = now + timedelta(days=5)
    end = now + timedelta(days=90)
    duration = timedelta(days=1)

    # maxDuration is mandatory. Without it, every TPU probe fails with HTTP 400
    # "Time range spec must be fully specified", which the caller reports as
    # "no response", so the run looks clean but finds no TPU zones.
    #
    # deploymentType DENSE is a GPU/H4D concept. TPUs default to FLEXIBLE
    # (best-effort co-location), and DENSE isn't accepted for them.
    request_body = {
        "futureResourcesSpecs": {
            "probe": {
                "timeRangeSpec": {
                    "startTimeNotEarlierThan": start.isoformat() + "Z",
                    "startTimeNotLaterThan": end.isoformat() + "Z",
                    "minDuration": f"{int(duration.total_seconds())}s",
                    "maxDuration": f"{int(duration.total_seconds())}s",
                },
                "targetResources": {
                    "aggregateResources": {
                        "acceleratorCount": str(chip_count),
                        "vmFamily": vm_family,
                        "workloadType": "BATCH",
                    }
                },
            }
        }
    }

    results = []

    try:
        request = service.advice().calendarMode(
            project=project_id, region=region, body=request_body
        )
        response = request.execute()

        for recommendation in response.get("recommendations", []):
            spec = recommendation.get("recommendationsPerSpec", {}).get("probe", {})

            location = spec.get("location", "")
            if location:
                zone = location.replace("zones/", "")
                results.append({
                    'zone': zone,
                    'status': 'RECOMMENDED',
                    'details': 'Calendar mode available, capacity found',
                    'machine_type': vm_family,
                    'gpu_label': tpu_name,
                })

            for zone_path, info in spec.get("otherLocations", {}).items():
                zone = zone_path.replace("zones/", "")
                status = info.get("status", "UNKNOWN")
                details = info.get("details", "")
                results.append({
                    'zone': zone,
                    'status': status,
                    'details': details,
                    'machine_type': vm_family,
                    'gpu_label': tpu_name,
                })

    except Exception as err:
        error_str = str(err)
        if "not supported" not in error_str.lower() and "invalid" not in error_str.lower() and "not found" not in error_str.lower():
            print(f"\n    Warning: {tpu_name} in {region}: {err}")

    return results


def write_to_csv(results, output_path):
    """
    @brief Writes discovery results to a CSV file.

    @param results List of dicts with zone discovery data
    @param output_path Path to write the CSV
    """
    with open(output_path, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=[
            'gpu_label', 'machine_type', 'zone', 'region', 'status',
            'calendar_supported', 'details', 'discovered_at'
        ])
        writer.writeheader()
        for r in results:
            region = '-'.join(r['zone'].split('-')[:-1])
            writer.writerow({
                'gpu_label': r.get('gpu_label', ''),
                'machine_type': r['machine_type'],
                'zone': r['zone'],
                'region': region,
                'status': r['status'],
                'calendar_supported': r['status'] in ('RECOMMENDED', 'NO_CAPACITY'),
                'details': r['details'],
                'discovered_at': datetime.now(timezone.utc).isoformat(),
            })
    print(f"  Full results written to: {output_path}")


def main():
    """
    @brief Main entry point. Discovers all Calendar-supported GPU/TPU zones.

    @details Workflow:
      1. Discover all GPU machine types via machineTypes().aggregatedList()
      2. Probe Calendar mode for each unique (machine_type, region)
      3. Optionally probe TPU types
      4. Write results to CSV
    """
    import argparse

    parser = argparse.ArgumentParser(
        description='Discover all GPU/TPU machine types and zones that support DWS Calendar mode'
    )
    parser.add_argument('-p', '--project', type=str,
                        help='GCP project ID (default: current gcloud project)')
    parser.add_argument('--csv', type=str, default='calendar_supported_zones.csv',
                        help='CSV output filename (default: calendar_supported_zones.csv)')
    parser.add_argument('--gpu-only', action='store_true',
                        help='Only discover GPU types, skip TPUs')
    parser.add_argument('--tpu-only', action='store_true',
                        help='Only discover TPU types, skip GPUs')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Verbose output including full API responses')
    args = parser.parse_args()

    # Authenticate
    credentials, default_project = google.auth.default(
        scopes=['https://www.googleapis.com/auth/cloud-platform']
    )
    credentials.refresh(Request())

    project_id = args.project or default_project
    print(f"Using project: {project_id}")
    print(f"Timestamp: {datetime.now(timezone.utc).isoformat()}\n")

    # Build beta service once (reuse across all probes to avoid overhead)
    beta_service = discovery.build('compute', 'beta', credentials=credentials)

    all_results = []

    # ========== GPU DISCOVERY ==========
    if not args.tpu_only:
        # Step 1: Discover all GPU machine types and their regions
        machine_to_regions = discover_gpu_machine_types(project_id, credentials)

        # Step 2: Probe Calendar support for each (machine_type, region)
        total_probes = sum(len(regions) for regions in machine_to_regions.values())
        print(f"\n[2/3] Probing Calendar mode support ({total_probes} probes across {len(machine_to_regions)} machine types)...")

        probe_count = 0
        for machine_type in sorted(machine_to_regions.keys()):
            regions = sorted(machine_to_regions[machine_type])
            for region in regions:
                probe_count += 1
                print(f"  [{probe_count}/{total_probes}] {machine_type} in {region}...", end='', flush=True)

                results = probe_calendar_support(
                    project_id, machine_type, region, credentials, service=beta_service
                )

                supported = [r for r in results if r['status'] in ('RECOMMENDED', 'NO_CAPACITY')]
                not_supported = [r for r in results if r['status'] == 'NOT_SUPPORTED']

                if supported:
                    print(f" ✅ {len(supported)} supported zones")
                elif not_supported:
                    print(f" ❌ not supported")
                elif not results:
                    print(f" no response")
                else:
                    print(f" {len(results)} zones returned")

                all_results.extend(results)

    # ========== TPU DISCOVERY ==========
    if not args.gpu_only:
        # TPU machine-type prefixes on Compute Engine, mapped to a display name, the
        # Calendar-mode VM family, and the smallest chip count to ask for.
        tpu_families = {
            'ct5lp-': ('TPU v5e', 'VM_FAMILY_CLOUD_TPU_LITE_POD_SLICE_CT5LP', 16),
            'ct5p-': ('TPU v5p', 'VM_FAMILY_CLOUD_TPU_POD_SLICE_CT5P', 8),
            'ct6e-': ('TPU v6e', 'VM_FAMILY_CLOUD_TPU_LITE_POD_SLICE_CT6E', 4),
        }
        # TPU7x is on the Calendar mode list, but on 2026-10-15 the advice API rejected
        # VM_FAMILY_CLOUD_TPU_POD_SLICE_TPU7X ("unsupported machine family") and
        # tpu7x-standard-4t ("This machine family is not supported in Calendar Mode."),
        # so this script can't check it.

        # Find the regions that carry each TPU family from the Compute Engine machine types.
        v1_service = discovery.build('compute', 'v1', credentials=credentials)
        tpu_regions = defaultdict(set)
        request = v1_service.machineTypes().aggregatedList(project=project_id)
        while request is not None:
            response = request.execute()
            for scope_name, scope_data in response.get('items', {}).items():
                if scope_name.startswith("zones/"):
                    zone_name = scope_name.split('/')[-1]
                    region = '-'.join(zone_name.split('-')[:-1])
                    for mt in scope_data.get('machineTypes', []):
                        mt_name = mt.get('name', '')
                        for prefix in tpu_families:
                            if mt_name.startswith(prefix):
                                tpu_regions[prefix].add(region)
            request = v1_service.machineTypes().aggregatedList_next(
                previous_request=request, previous_response=response
            )

        print(f"\n[2/3] Probing Calendar mode support for TPU types...")

        for prefix, (tpu_name, vm_family, min_chips) in sorted(tpu_families.items()):
            if prefix not in tpu_regions:
                print(f"  Skipping {tpu_name}: no {prefix}* machine types found")
                continue

            for region in sorted(tpu_regions[prefix]):
                print(f"  {tpu_name} in {region}...", end='', flush=True)

                results = probe_tpu_calendar_support(
                    project_id, tpu_name, vm_family, region, min_chips,
                    credentials, service=beta_service
                )

                supported = [r for r in results if r['status'] in ('RECOMMENDED', 'NO_CAPACITY')]
                if supported:
                    print(f" ✅ {len(supported)} supported zones")
                elif results:
                    print(f" ❌ not supported")
                else:
                    print(f" no response")

                all_results.extend(results)

    # ========== OUTPUT ==========
    print(f"\n[3/3] Writing results...")

    # Separate supported vs not supported
    supported_results = [r for r in all_results if r['status'] in ('RECOMMENDED', 'NO_CAPACITY')]
    not_supported_results = [r for r in all_results if r['status'] == 'NOT_SUPPORTED']

    print(f"\n{'='*80}")
    print(f"  CALENDAR MODE SUPPORT MATRIX")
    print(f"{'='*80}")
    print(f"  Total probes returned: {len(all_results)}")
    print(f"  Calendar-SUPPORTED (machine_type, zone) combos: {len(supported_results)}")
    print(f"  Calendar-NOT_SUPPORTED combos: {len(not_supported_results)}")
    print(f"{'='*80}")

    # Group supported by GPU label -> machine type -> zones
    by_gpu = defaultdict(lambda: defaultdict(list))
    for r in supported_results:
        by_gpu[r.get('gpu_label', r['machine_type'])][r['machine_type']].append(r['zone'])

    for gpu_label in sorted(by_gpu.keys()):
        print(f"\n  {gpu_label}:")
        for mt in sorted(by_gpu[gpu_label].keys()):
            zones = sorted(set(by_gpu[gpu_label][mt]))
            print(f"    {mt}:")
            for z in zones:
                print(f"      - {z}")

    # Write CSV
    csv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), args.csv)
    write_to_csv(all_results, csv_path)

    print(f"\nDone! {len(supported_results)} Calendar-supported (machine_type, zone) combos found.")


if __name__ == '__main__':
    main()
