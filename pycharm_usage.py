#!/usr/bin/env python3
"""
pycharm-usage: Show PyCharm activity broken down by periods for a given day.
"""

import argparse
import os
import shutil
import re
import sys
import glob
import platform
from collections import defaultdict
from datetime import datetime, timedelta, date


# ---------------------------------------------------------------------------
# ANSI colors
# ---------------------------------------------------------------------------
RESET  = "\033[0m"
BOLD   = "\033[1m"
DIM      = "\033[2m"
DARK_GREY = "\033[90m"
GREEN  = "\033[32m"
YELLOW = "\033[33m"
CYAN   = "\033[36m"
RED    = "\033[31m"
WHITE  = "\033[37m"


# ---------------------------------------------------------------------------
# Component-based classification
# Keys are the short label (last dotted segment) of the component string.
# Components not listed here are treated as "uncategorized".
# ---------------------------------------------------------------------------

AUTO_COMPONENTS = {
    "GitHubCodingAgentJobsService",
    "ActionUpdater",
    "AcpIconCacheManager",
    "AcpAgentRegistry",
    "AcpRegistryFetcher",
    "AcpAgentsConfigService",
    "AcpDistributionResolver",
    "AcpAgentFactory",
    "QuotaManager2Impl",
    "AIAPromoEventsConfigService",
    "Cache",
    "SystemPythonServiceImplKt",
    "LlmInfoService",
    "MatterhornHttpClientService",
    "deprecationLogger",
    "OrderItem",
    "GrazieActivationPageVm",
    "JunieAipLicenseRepositoryKt",
    "AiaActivationTransmitter",
    "AiaActivationState",
    "JunieActivationStateListener",
    "GrazieJbaAuthStepKt",
    "JunieGrazieLLMProxy",
    "DragAndDropCoordinator$Companion",
    "PerformanceWatcherImpl",
    "JVMResponsivenessMonitor",
}


# ---------------------------------------------------------------------------
# 1. Locate log files
# ---------------------------------------------------------------------------
def find_log_files():
    """Return a list of idea.log* / idea.*.log paths, newest rotation first."""
    system = platform.system()

    def globs_for(directory):
        """Both naming conventions: idea.log* and idea.*.log"""
        return (
            glob.glob(os.path.join(directory, "idea.log*")) +
            glob.glob(os.path.join(directory, "idea.*.log"))
        )

    candidates = []

    if system == "Darwin":
        base = os.path.expanduser("~/Library/Logs/JetBrains")
        for d in glob.glob(os.path.join(base, "PyCharm*")):
            candidates += globs_for(d)
            candidates += globs_for(os.path.join(d, "log"))

    elif system == "Linux":
        base = os.path.expanduser("~/.cache/JetBrains")
        for d in glob.glob(os.path.join(base, "PyCharm*")):
            candidates += globs_for(os.path.join(d, "log"))
        # Older layout
        base2 = os.path.expanduser("~/.local/share/JetBrains")
        for d in glob.glob(os.path.join(base2, "PyCharm*")):
            candidates += globs_for(os.path.join(d, "log"))

    elif system == "Windows":
        appdata = os.environ.get("APPDATA", "")
        base = os.path.join(appdata, "JetBrains")
        for d in glob.glob(os.path.join(base, "PyCharm*")):
            candidates += globs_for(os.path.join(d, "log"))

    # Also check the current directory (useful for testing)
    candidates += globs_for(".")

    if not candidates:
        return []

    # Deduplicate and sort: idea.log first, then rotations in ascending order
    # Handles both idea.log.N and idea.N.log naming conventions.
    seen = set()
    unique = []
    for p in candidates:
        rp = os.path.realpath(p)
        if rp not in seen:
            seen.add(rp)
            unique.append(p)

    def sort_key(p):
        name = os.path.basename(p)
        if name == "idea.log":
            return (0, 0)
        # idea.log.N  (e.g. idea.log.1)
        m = re.search(r'\.(\d+)$', name)
        if m:
            return (1, int(m.group(1)))
        # idea.N.log  (e.g. idea.1.log)
        m = re.search(r'idea\.(\d+)\.log$', name)
        if m:
            return (1, int(m.group(1)))
        return (2, 0)

    unique.sort(key=sort_key)
    return unique


# ---------------------------------------------------------------------------
# 2. Parse a single log line
# ---------------------------------------------------------------------------
# Example line:
#   2024-01-15 14:32:07,841 [ 12345]   INFO - #com.intellij.SomeClass - message text
LOG_RE = re.compile(
    r'^(\d{4}-\d{2}-\d{2})\s+'           # date
    r'(\d{2}:\d{2}:\d{2}),\d+'           # time
    r'\s*\[\s*\d+\]\s+'                  # thread id
    r'(\w+)'                             # level (INFO/WARN/ERROR…)
    r'\s+-\s+'                           # separator
    r'([^-]+?)'                          # component (between the two dashes)
    r'\s+-\s+'                           # separator
    r'(.*)'                              # message
)

def parse_log_line(line):
    """
    Returns dict with keys: date, time, level, component, message
    or None if the line doesn't match.
    """
    m = LOG_RE.match(line.rstrip())
    if not m:
        return None
    return {
        "date":      m.group(1),
        "time":      m.group(2),
        "level":     m.group(3),
        "component": m.group(4).strip(),
        "message":   m.group(5).strip(),
    }


# ---------------------------------------------------------------------------
# 3. Classify a parsed line by its component label
# ---------------------------------------------------------------------------
def classify_component(component):
    """
    Returns "auto" if the component is in AUTO_COMPONENTS, else "uncategorized".
    """
    label = short_label(component)
    if label in AUTO_COMPONENTS:
        return "auto"
    return "uncategorized"


# ---------------------------------------------------------------------------
# 4. Extract a short readable label from the component string
# ---------------------------------------------------------------------------
def short_label(component):
    """
    '#com.intellij.openapi.project.impl.ProjectManagerImpl'
    → 'ProjectManagerImpl'
    """
    c = component.lstrip("#")
    parts = c.split(".")
    return parts[-1] if parts else c


# ---------------------------------------------------------------------------
# 5. Bucket lines into 15-minute slots for the target date
# ---------------------------------------------------------------------------
def bucket_key(time_str, period_mins=15):
    """'14:32:07' → '14:30' (start of period bucket, given period_mins)"""
    h, m, _ = time_str.split(":")
    bucket_m = (int(m) // period_mins) * period_mins
    return f"{int(h):02d}:{bucket_m:02d}"


def bucket_lines(parsed_lines, target_date_str, period_mins=15, since_time=None):
    """
    Group parsed lines by period bucket for target_date_str ('YYYY-MM-DD').
    If since_time is given, lines earlier than that time are excluded.
    Returns dict: bucket_key → list of parsed line dicts.
    """
    buckets = defaultdict(list)
    for pl in parsed_lines:
        if pl["date"] == target_date_str:
            if since_time is not None:
                line_time = datetime.strptime(pl["time"], "%H:%M:%S").time()
                if line_time < since_time:
                    continue
            key = bucket_key(pl["time"], period_mins)
            buckets[key].append(pl)
    return buckets


# ---------------------------------------------------------------------------
# 6. Top N activity labels in a bucket, color-coded by classification
# ---------------------------------------------------------------------------
ACTIVITY_COLOR = {
    "uncategorized": "\033[32m",   # green
    "auto":          "\033[90m",   # dark grey
}

def top_activities(lines, n=3):
    """
    Returns ANSI-colored "Label (count)" strings, sorted by count descending.
    Each label is colored by the dominant classification of its lines.
    Pass n=None to return all distinct components.
    """
    counts     = defaultdict(int)
    cls_counts = defaultdict(lambda: defaultdict(int))

    for pl in lines:
        label = short_label(pl["component"])
        cls   = classify_component(pl["component"])
        counts[label] += 1
        cls_counts[label][cls] += 1

    ranked = sorted(counts.items(), key=lambda x: x[1], reverse=True)
    if n is not None:
        ranked = ranked[:n]

    result = []
    for label, total in ranked:
        dominant_cls = max(cls_counts[label], key=cls_counts[label].get)
        color = ACTIVITY_COLOR[dominant_cls]
        result.append(f"{color}{label} ({total}){RESET}")
    return result


# ---------------------------------------------------------------------------
# 7. Render the table
# ---------------------------------------------------------------------------
def render_table(buckets, target_date_str, all_components=False,
                 user_only=False, threshold=10, period_mins=15, since_time=None):
    if not buckets:
        print(f"{YELLOW}No log entries found for {target_date_str}.{RESET}")
        print("Check that PyCharm has been run and that log files are present.")
        return

    # Column widths — W_ACT expands to fill the terminal
    W_TIME  = 17
    W_UNCAT = 9
    W_AUTO  = 7
    term_width  = shutil.get_terminal_size((80, 24)).columns
    fixed_width = W_TIME + 1 + W_UNCAT + 1 + W_AUTO + 1  # +1 per pipe character
    W_ACT       = max(20, term_width - fixed_width - 1)   # -1 for leading space in acts cell

    divider = (
        "-" * W_TIME + "+"
        + "-" * W_UNCAT + "+"
        + "-" * W_AUTO + "+"
        + "-" * W_ACT
    )

    header = (
        f"{'Time Range':<{W_TIME}}|"
        f"{'Uncat':>{W_UNCAT}}|"
        f"{'Auto':>{W_AUTO}}|"
        f" {'Top Activities':<{W_ACT-1}}"
    )

    print()
    print(f"{BOLD}{CYAN}PyCharm Usage — {target_date_str}{RESET}")
    print()
    print(BOLD + header + RESET)
    print(divider)

    for slot in sorted(buckets.keys()):
        lines = buckets[slot]
        total = len(lines)
        uncat = sum(1 for pl in lines if classify_component(pl["component"]) == "uncategorized")
        auto  = total - uncat
        is_user_active = uncat >= threshold

        if user_only and not is_user_active:
            continue

        # End time of the bucket
        h, m = map(int, slot.split(":"))
        end_m = m + period_mins
        end_h = h + end_m // 60
        end_m = end_m % 60
        time_range = f"{slot} - {end_h:02d}:{end_m:02d}"

        acts = top_activities(lines, n=None if all_components else 3)

        # Green if period meets user-active threshold, dim otherwise.
        row_color = GREEN if is_user_active else DIM

        # Fixed columns (colored by row_color); auto value always grey;
        # activities use their own colors.
        fixed = (
            f"{time_range:<{W_TIME}}|"
            f"{uncat:>{W_UNCAT}}|"
            f"{DARK_GREY}{auto:>{W_AUTO}}{RESET}{row_color}|"
        )
        # Blank fixed prefix used for option-A continuation rows.
        blank_fixed = (
            f"{'':>{W_TIME}}|"
            f"{'':>{W_UNCAT}}|"
            f"{'':>{W_AUTO}}|"
        )

        # Fit as many comma-separated activity tokens onto each line as possible
        # without exceeding W_ACT visible characters (ANSI codes don't count).
        def visible_len(s):
            return len(re.sub(r'\033\[[0-9;]*m', '', s))

        lines_out = []
        current_tokens = []
        current_len = 0
        for i, token in enumerate(acts):
            sep = ", " if current_tokens else ""
            addition = visible_len(sep + token)
            if current_tokens and current_len + addition > W_ACT - 1:
                lines_out.append((sep.join(current_tokens) if current_tokens else ""))
                current_tokens = [token]
                current_len = visible_len(token)
            else:
                current_tokens.append(token)
                current_len += addition
        if current_tokens:
            lines_out.append(", ".join(current_tokens))
        if not lines_out:
            lines_out = ["—"]

        for i, act_line in enumerate(lines_out):
            if i == 0:
                print(row_color + fixed + RESET + " " + act_line)
            else:
                print(row_color + blank_fixed + RESET + " " + act_line)

    print(divider)

    # Summary totals (across all buckets, not filtered by user_only)
    all_lines  = [pl for lines in buckets.values() for pl in lines]
    uncat_all  = sum(1 for pl in all_lines if classify_component(pl["component"]) == "uncategorized")
    auto_all   = len(all_lines) - uncat_all

    user_active_buckets = sum(
        1 for slot, lines in buckets.items()
        if sum(1 for pl in lines if classify_component(pl["component"]) == "uncategorized") >= threshold
    )
    user_hours   = (user_active_buckets * period_mins) // 60
    user_minutes = (user_active_buckets * period_mins) % 60

    summary = (
        f"{'TOTAL':<{W_TIME}}|"
        f"{uncat_all:>{W_UNCAT}}|"
        f"{auto_all:>{W_AUTO}}|"
        f"{'':>{W_ACT}}"
    )
    print(BOLD + summary + RESET)
    print()

    # Friendly date label
    today    = date.today()
    analyzed = date.fromisoformat(target_date_str)
    delta    = (today - analyzed).days
    if delta == 0:
        day_label = "today"
    elif delta == 1:
        day_label = "yesterday"
    else:
        day_label = f"{delta} days ago"

    # Format duration
    if user_hours == 0:
        duration_str = f"{user_minutes}m"
    elif user_minutes == 0:
        duration_str = f"{user_hours}h"
    else:
        duration_str = f"{user_hours}h {user_minutes}m"

    print(f"  {BOLD}Date analyzed :{RESET}  {target_date_str}  ({day_label})")
    if since_time is not None:
        print(f"  {BOLD}Since         :{RESET}  {since_time.strftime('%H:%M')}")
    print(f"  {BOLD}Threshold     :{RESET}  {threshold} uncategorized lines  "
          f"(period = {period_mins} min)")
    print(f"  {BOLD}Active periods:{RESET}  {user_active_buckets} × {period_mins}-min periods "
          f"meeting threshold")
    print(f"  {BOLD}Active time   :{RESET}  {GREEN}{BOLD}{duration_str}{RESET}")
    print()

    # Legend
    print(f"  {GREEN}■{RESET} User-active (uncat >= {threshold})   "
          f"{DIM}■{RESET} Below threshold")
    print()


# ---------------------------------------------------------------------------
# 8. Main
# ---------------------------------------------------------------------------
def positive_int(value):
    """argparse type that accepts only positive integers."""
    try:
        v = int(value)
        if v <= 0:
            raise ValueError
        return v
    except ValueError:
        raise argparse.ArgumentTypeError(f"must be a positive integer, got: {value!r}")


def parse_time(value):
    """argparse type that accepts HH or HH:MM (24-hour) and returns a datetime.time."""
    for fmt in ("%H:%M", "%H"):
        try:
            return datetime.strptime(value, fmt).time()
        except ValueError:
            continue
    raise argparse.ArgumentTypeError(f"must be HH or HH:MM (24-hour format), got: {value!r}")


def main():
    parser = argparse.ArgumentParser(
        prog="pycharm-usage",
        description="Show PyCharm activity broken down by periods for a given day.",
    )
    parser.add_argument(
        "days_back", nargs="?", type=int, default=0, metavar="DAYS",
        help="how many days back to analyse (0 = today, 1 = yesterday, …)",
    )
    parser.add_argument(
        "-a", "--all-components", action="store_true",
        help="show all components per period (default: top 3)",
    )
    parser.add_argument(
        "-u", "--user-only", action="store_true",
        help="suppress periods not classified as user activity",
    )
    parser.add_argument(
        "-t", "--threshold", type=positive_int, default=10, metavar="N",
        help="min uncategorized lines for a period to count as user activity (default: 10)",
    )
    parser.add_argument(
        "-p", "--period", type=positive_int, default=15, metavar="N",
        dest="period_mins",
        help="period length in minutes (default: 15)",
    )
    parser.add_argument(
        "-s", "--since-time", type=parse_time, default=None, metavar="HH[:MM]",
        help="only include log lines at or after this time of day (24-hour format)",
    )
    ns = parser.parse_args()
    all_components = ns.all_components
    user_only      = ns.user_only
    threshold      = ns.threshold
    period_mins    = ns.period_mins
    since_time     = ns.since_time

    if ns.days_back < 0:
        parser.error("DAYS must be a non-negative integer.")
    days_back = ns.days_back

    target_date = date.today() - timedelta(days=days_back)
    target_date_str = target_date.strftime("%Y-%m-%d")

    # Find log files
    log_files = find_log_files()
    if not log_files:
        print(f"{RED}Error:{RESET} No idea.log files found.")
        print("Expected locations:")
        print("  macOS  : ~/Library/Logs/JetBrains/PyCharm*/idea.log*")
        print("  Linux  : ~/.cache/JetBrains/PyCharm*/log/idea.log*")
        print("  Windows: %APPDATA%\\JetBrains\\PyCharm*\\log\\idea.log*")
        sys.exit(1)

    print(f"{DIM}Found {len(log_files)} log file(s). Scanning…{RESET}", end="\r")

    # Parse files in newest-first order.  After each file, if the oldest date
    # seen in that file is earlier than the target, all remaining files are
    # guaranteed to be older still, so we stop before opening the next one.
    parsed_lines = []
    for path in log_files:
        oldest_date_in_file = None
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    pl = parse_log_line(line)
                    if pl is None:
                        continue
                    if pl["date"] == target_date_str:
                        parsed_lines.append(pl)
                    if oldest_date_in_file is None or pl["date"] < oldest_date_in_file:
                        oldest_date_in_file = pl["date"]
        except OSError as e:
            print(f"{YELLOW}Warning:{RESET} Could not read {path}: {e}")

        # If the oldest line in this file predates the target, no subsequent
        # (older) file can contain the target date.
        if oldest_date_in_file is not None and oldest_date_in_file < target_date_str:
            break

    # Clear the scanning message
    print(" " * 60, end="\r")

    buckets = bucket_lines(parsed_lines, target_date_str, period_mins=period_mins,
                          since_time=since_time)
    render_table(buckets, target_date_str, all_components=all_components,
                 user_only=user_only, threshold=threshold, period_mins=period_mins,
                 since_time=since_time)


if __name__ == "__main__":
    main()
