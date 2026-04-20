from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


VERILOG_EXTENSIONS = {".v": "", ".sv": "-sv"}
HEADER_EXTENSIONS = {".vh", ".svh"}
VHDL_EXTENSIONS = {".vhd", ".vhdl"}
SCRIPTABLE_CONSTRAINT_EXTENSIONS = {".edc", ".sdc", ".tcl"}
PIN_ASSIGNMENT_RE = re.compile(r"^set_location_assignment\s+(\S+)\s+-to\s+(.+)$", re.IGNORECASE)
GLOBAL_LOCATION_RE = re.compile(
    r"^set_global_assignment\s+-name\s+LOCATION\s+(\S+)\s+-to\s+(.+)$",
    re.IGNORECASE,
)
AUTO_SYNC_MARKER = "# auto-synced location assignments from Codex helper"
SYNTH_SUMMARY_PATTERNS = [
    re.compile(r"Implemented \d+ device resources", re.IGNORECASE),
    re.compile(r"Implemented \d+ logic cells", re.IGNORECASE),
    re.compile(r"Implemented \d+ RAM segments", re.IGNORECASE),
    re.compile(r"Analysis & Synthesis was (?:successful|unsuccessful)", re.IGNORECASE),
]
ROUTE_SUMMARY_PATTERNS = [
    re.compile(r"^\[INFO\]\s+ClockName:", re.IGNORECASE),
    re.compile(r"^\[INFO\]\s+WNS:", re.IGNORECASE),
    re.compile(r"All was well!", re.IGNORECASE),
]
BITGEN_SUMMARY_PATTERNS = [
    re.compile(r"Bitstream file\(s\) output success", re.IGNORECASE),
    re.compile(r"Compressed PSK file output success", re.IGNORECASE),
    re.compile(r"All was well!", re.IGNORECASE),
]
PACK_SUMMARY_PATTERNS = [
    re.compile(r"Save eLinx design check point\(\.ecp\) complete", re.IGNORECASE),
    re.compile(r"Write cluster XML file complete", re.IGNORECASE),
    re.compile(r"All was well!", re.IGNORECASE),
]
FAILURE_SUMMARY_PATTERNS = [
    re.compile(r"^\s*ERROR[:\s]", re.IGNORECASE),
    re.compile(r"\bfailed\b", re.IGNORECASE),
    re.compile(r"\bunsuccessful\b", re.IGNORECASE),
]
TIMING_SUMMARY_PATTERNS = [
    re.compile(r"^\[INFO\]\s+ClockName:", re.IGNORECASE),
    re.compile(r"^\[INFO\]\s+WNS:", re.IGNORECASE),
    re.compile(r"^\[INFO\]\s+TNS:", re.IGNORECASE),
]
PLL_INSTANCE_RE = re.compile(r'Instantiated megafunction "([^"]+\|altpll:[^"]+)"')
PLL_PARAM_RE = re.compile(r'Parameter "([^"]+)" = "([^"]+)"')


def _qsf_pin_sync_enabled() -> bool:
    """
    Keep helper-driven QSF rewrites opt-in.

    Native GUI projects should treat the .qsf as the single source of truth so the
    tool UI does not get silently rewritten by the helper. When a compatibility flow
    really needs pin mirroring into the .qsf, set ELINX_SYNC_QSF_PINS=1 explicitly.
    """
    return os.environ.get("ELINX_SYNC_QSF_PINS", "").strip() == "1"


def _compat_synth_only_enabled() -> bool:
    """
    Allow skipping the native synth step when it is known to hang.

    This keeps the helper useful for iterative debug on projects that already have a
    working Quartus-compatible synthesis path.
    """
    return os.environ.get("ELINX_FORCE_COMPAT_SYNTH", "").strip() == "1"


@dataclass
class ProjectMetadata:
    epr: Path
    project_dir: Path
    project_name: str
    top_entity: str
    series_name: str
    device_name: str
    package_name: str
    synth_run: str
    imple_run: str
    design_files: list[Path]
    constraint_files: list[Path]
    target_constraint_file: Path | None

    @property
    def synth_dir(self) -> Path:
        return self.project_dir / f"{self.project_name}.runs" / self.synth_run

    @property
    def imple_dir(self) -> Path:
        return self.project_dir / f"{self.project_name}.runs" / self.imple_run

    @property
    def synth_vqm(self) -> Path:
        return self.synth_dir / f"{self.project_name}.vqm"

    @property
    def synth_map_report(self) -> Path:
        return self.synth_dir / f"{self.project_name}.map.rpt"

    @property
    def synth_script(self) -> Path:
        return self.synth_dir / f"{self.project_name}.ys"

    @property
    def synth_result_log(self) -> Path:
        return self.synth_dir / f"{self.project_name}.result"

    @property
    def synth_pack_script(self) -> Path:
        return self.synth_dir / f"{self.project_name}_pack.tcl"

    @property
    def synth_ecp(self) -> Path:
        return self.synth_dir / f"{self.project_name}_{self.series_name}.ecp"

    @property
    def synth_ver_pb(self) -> Path:
        return self.synth_dir / f"{self.project_name}.ver.pb"

    @property
    def synth_psf(self) -> Path:
        return self.synth_dir / f"{self.project_name}.run.psf"

    @property
    def route_script(self) -> Path:
        return self.imple_dir / f"{self.project_name}_route.tcl"

    @property
    def timing_script(self) -> Path:
        return self.imple_dir / f"{self.project_name}_timing.tcl"

    @property
    def bitgen_script(self) -> Path:
        return self.imple_dir / f"{self.project_name}_bitgen.tcl"

    @property
    def imple_psf(self) -> Path:
        return self.imple_dir / f"{self.project_name}.run.psf"

    @property
    def imple_ver_pb(self) -> Path:
        return self.imple_dir / f"{self.project_name}.ver.pb"

    @property
    def imple_ecp(self) -> Path:
        return self.imple_dir / f"{self.project_name}_{self.series_name}_{self.device_name}.ecp"

    @property
    def imple_log(self) -> Path:
        return self.imple_dir / f"{self.project_name}.edi"

    @property
    def timing_log(self) -> Path:
        return self.imple_dir / f"{self.project_name}.edt"

    @property
    def timing_report(self) -> Path:
        return self.imple_dir / f"{self.project_name}.tan.rpt"

    @property
    def slack_report(self) -> Path:
        return self.imple_dir / f"{self.project_name}.slack.rpt"

    @property
    def route_status_report(self) -> Path:
        return self.imple_dir / f"{self.project_name}_route_status.rpt"

    @property
    def bitgen_log(self) -> Path:
        return self.imple_dir / f"{self.project_name}.edb"

    @property
    def bitgen_psk(self) -> Path:
        return self.imple_dir / f"{self.project_name}.psk"

    @property
    def bitgen_comp_psk(self) -> Path:
        return self.imple_dir / f"{self.project_name}_comp.psk"

    @property
    def log4cpp_src(self) -> Path:
        return self.project_dir / "log4cpp.property"

    @property
    def compat_qpf(self) -> Path | None:
        candidate = self.project_dir / f"{self.project_name}.qpf"
        return candidate if candidate.exists() else None

    @property
    def qsf(self) -> Path:
        return self.project_dir / f"{self.project_name}.qsf"


def _fail(message: str) -> int:
    print(f"[elinx-native] ERROR: {message}", file=sys.stderr)
    return 1


def _require_env_path(name: str) -> Path:
    raw = os.environ.get(name, "").strip()
    if not raw:
        raise RuntimeError(f"Environment variable {name} is not set.")
    value = Path(raw)
    if not value.exists():
        raise RuntimeError(f"{name} points to a missing path: {value}")
    return value


def _pick_run(root: ET.Element, run_type: str, preferred_id: str | None = None) -> ET.Element:
    runs = [run for run in root.findall("./Runs/Run") if run.get("Type") == run_type]
    if not runs:
        raise RuntimeError(f"No {run_type} run was found in the .epr file.")
    if preferred_id:
        for run in runs:
            if run.get("Id") == preferred_id:
                return run
    for run in runs:
        if run.get("State") == "current":
            return run
    return runs[0]


def _option_value(run: ET.Element, option_id: str) -> str:
    for option in run.findall("./Option"):
        if option.get("Id") == option_id or option.get("Name") == option_id:
            value = (option.text or option.get("Val") or "").strip()
            if value:
                return value
    raise RuntimeError(f"Option {option_id!r} is missing from run {run.get('Id')!r}.")


def _resolve_project_member(project_dir: Path, file_path: str) -> Path:
    normalized = file_path.strip().replace("\\", "/")
    if not normalized:
        raise RuntimeError("Encountered an empty file path in the .epr file.")
    if len(normalized) >= 3 and normalized[1:3] == ":/":
        return Path(normalized)
    return project_dir / normalized.lstrip("/")


def _file_set_by_name(root: ET.Element) -> dict[str, ET.Element]:
    return {file_set.get("Name", ""): file_set for file_set in root.findall("./FileSets/FileSet")}


def _parse_file_set(project_dir: Path, file_set: ET.Element | None) -> list[Path]:
    if file_set is None:
        return []
    files: list[Path] = []
    for node in file_set.findall("./File"):
        path_attr = node.get("Path")
        if path_attr:
            files.append(_resolve_project_member(project_dir, path_attr))
    return files


def _parse_target_constraint(project_dir: Path, file_set: ET.Element | None) -> Path | None:
    if file_set is None:
        return None
    for option in file_set.findall("./Config/Option"):
        if option.get("Name") == "TargetConstrsFile" or option.get("Id") == "TargetConstrsFile":
            value = (option.get("Val") or option.text or "").strip()
            if value:
                return _resolve_project_member(project_dir, value)
    return None


def load_project_metadata(epr_path: Path) -> ProjectMetadata:
    tree = ET.parse(epr_path)
    root = tree.getroot()
    synth_run = _pick_run(root, "Synthesis")
    imple_run = _pick_run(root, "Implementation", preferred_id=synth_run.get("SynthRun"))
    if imple_run.get("SynthRun"):
        synth_run = _pick_run(root, "Synthesis", preferred_id=imple_run.get("SynthRun"))

    file_sets = _file_set_by_name(root)
    src_set_name = synth_run.get("SrcSet", "")
    constr_set_name = synth_run.get("ConstrsSet", "")
    if src_set_name not in file_sets:
        raise RuntimeError(f"Synthesis source set {src_set_name!r} was not found in the .epr file.")
    if constr_set_name and constr_set_name not in file_sets:
        raise RuntimeError(f"Constraint set {constr_set_name!r} was not found in the .epr file.")

    src_set = file_sets[src_set_name]
    constr_set = file_sets[constr_set_name] if constr_set_name else None
    return ProjectMetadata(
        epr=epr_path,
        project_dir=epr_path.parent,
        project_name=epr_path.stem,
        top_entity=_option_value(synth_run, "TopModule"),
        series_name=_option_value(synth_run, "Series"),
        device_name=_option_value(synth_run, "Device"),
        package_name=_option_value(synth_run, "Package"),
        synth_run=synth_run.get("Id") or "synth_1",
        imple_run=imple_run.get("Id") or "imple_1",
        design_files=_parse_file_set(epr_path.parent, src_set),
        constraint_files=_parse_file_set(epr_path.parent, constr_set),
        target_constraint_file=_parse_target_constraint(epr_path.parent, constr_set),
    )


def _rel_to_project(meta: ProjectMetadata, path: Path) -> str:
    return path.resolve().relative_to(meta.project_dir.resolve()).as_posix()


def _quote_tcl(path: Path) -> str:
    return path.as_posix().replace('"', '\\"')


def _stage_header(mode: str, meta: ProjectMetadata) -> None:
    print(f"[elinx-native] Mode={mode}")
    print(f"[elinx-native] EPR={meta.epr}")
    print(f"[elinx-native] Project={meta.project_name}")
    print(f"[elinx-native] Top={meta.top_entity}")
    print(f"[elinx-native] Series={meta.series_name}")
    print(f"[elinx-native] Device={meta.device_name}")
    print(f"[elinx-native] Package={meta.package_name}")
    print(f"[elinx-native] Synth run={meta.synth_run}")
    print(f"[elinx-native] Imple run={meta.imple_run}")


def _ensure_log4cpp(log4cpp_path: Path, output_path: Path) -> None:
    if log4cpp_path.exists():
        return
    content = "\n".join(
        [
            "# log4cpp.properties",
            "",
            "log4cpp.rootCategory=DEBUG,A1",
            "log4cpp.category.console=DEBUG, rootAppender",
            "",
            "log4cpp.appender.rootAppender=ConsoleAppender",
            "log4cpp.appender.rootAppender.layout=PatternLayout",
            "log4cpp.appender.rootAppender.layout.ConversionPattern=[%p] %m%n ",
            "",
            "log4cpp.appender.A1=RollingFileAppender",
            f"log4cpp.appender.A1.fileName={output_path.as_posix()}",
            "log4cpp.appender.A1.maxBackupIndex=1",
            "log4cpp.appender.A1.append=false",
            "log4cpp.appender.A1.layout=PatternLayout",
            "log4cpp.appender.A1.layout.ConversionPattern=%d [%p] %m%n ",
            "",
        ]
    )
    log4cpp_path.write_text(content, encoding="utf-8", newline="\n")


def _strip_tcl_quotes(token: str) -> str:
    value = token.strip()
    if value.startswith("{") and value.endswith("}"):
        return value[1:-1].strip()
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1].strip()
    return value


def _brace_tcl_token(token: str) -> str:
    return "{" + token.replace("}", "\\}") + "}"


def _normalize_assignment_target(token: str) -> str:
    return token.replace("\\[", "[").replace("\\]", "]")


def _parse_constraint_file(path: Path) -> tuple[list[tuple[str, str]], list[str]]:
    pin_assignments: list[tuple[str, str]] = []
    timing_lines: list[str] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = PIN_ASSIGNMENT_RE.match(stripped)
        if match:
            pin_assignments.append((_strip_tcl_quotes(match.group(1)), _strip_tcl_quotes(match.group(2))))
            continue
        match = GLOBAL_LOCATION_RE.match(stripped)
        if match:
            pin_assignments.append((_strip_tcl_quotes(match.group(1)), _strip_tcl_quotes(match.group(2))))
            continue
        if stripped.lower().startswith("set_global_assignment"):
            continue
        timing_lines.append(stripped)
    return pin_assignments, timing_lines


def _collect_constraints(meta: ProjectMetadata) -> tuple[list[tuple[str, str]], list[str]]:
    seen_paths: set[Path] = set()
    pin_assignments: list[tuple[str, str]] = []
    timing_lines: list[str] = []
    for candidate in [*meta.constraint_files, meta.target_constraint_file]:
        if candidate is None:
            continue
        resolved = candidate.resolve()
        if resolved in seen_paths:
            continue
        seen_paths.add(resolved)
        if candidate.suffix.lower() not in SCRIPTABLE_CONSTRAINT_EXTENSIONS:
            continue
        parsed_pins, parsed_timing = _parse_constraint_file(candidate)
        pin_assignments.extend(parsed_pins)
        timing_lines.extend(parsed_timing)
    return pin_assignments, timing_lines


def _update_qsf_pin_assignments(meta: ProjectMetadata, pin_assignments: list[tuple[str, str]]) -> None:
    if not meta.qsf.exists() or not pin_assignments:
        return
    deduped: dict[str, str] = {}
    for pin, port in pin_assignments:
        deduped[port] = pin
    filtered_lines: list[str] = []
    for raw_line in meta.qsf.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if stripped == AUTO_SYNC_MARKER:
            continue
        if PIN_ASSIGNMENT_RE.match(stripped) or GLOBAL_LOCATION_RE.match(stripped):
            continue
        filtered_lines.append(raw_line)
    if filtered_lines and filtered_lines[-1].strip():
        filtered_lines.append("")
    filtered_lines.append(AUTO_SYNC_MARKER)
    for port, pin in sorted(deduped.items()):
        filtered_lines.append(f"set_location_assignment {pin} -to {_normalize_assignment_target(port)}")
    meta.qsf.write_text("\n".join(filtered_lines) + "\n", encoding="utf-8", newline="\n")


def ensure_synth_inputs(meta: ProjectMetadata) -> None:
    if not meta.design_files:
        raise RuntimeError("The .epr file does not list any HDL source files.")
    for design_file in meta.design_files:
        if not design_file.exists():
            raise RuntimeError(f"Missing HDL source listed by the .epr file: {design_file}")
    for constraint_file in meta.constraint_files:
        if not constraint_file.exists():
            raise RuntimeError(f"Missing constraint file listed by the .epr file: {constraint_file}")
    if meta.target_constraint_file and not meta.target_constraint_file.exists():
        raise RuntimeError(f"Missing target constraint file listed by the .epr file: {meta.target_constraint_file}")
    if _qsf_pin_sync_enabled():
        pin_assignments, _ = _collect_constraints(meta)
        _update_qsf_pin_assignments(meta, pin_assignments)


def ensure_route_inputs(meta: ProjectMetadata) -> None:
    required = [
        (meta.synth_ecp, "synthesis checkpoint"),
        (meta.synth_ver_pb, "synthesis ver.pb"),
        (meta.synth_psf, "synthesis run.psf"),
    ]
    for path, label in required:
        if not path.exists():
            raise RuntimeError(
                f"Missing {label}: {path}\n"
                "Run native synthesis first so the implementation flow has an .ecp/.ver.pb/.psf to consume."
            )
    meta.imple_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(meta.synth_psf, meta.imple_psf)


def ensure_sta_inputs(meta: ProjectMetadata) -> None:
    if not meta.imple_ecp.exists():
        raise RuntimeError(
            f"Missing implementation checkpoint: {meta.imple_ecp}\n"
            "Run elinx-compile.cmd for this .epr project first and wait for route to finish."
        )
    if not meta.imple_psf.exists():
        raise RuntimeError(f"Missing implementation constraint snapshot: {meta.imple_psf}")


def ensure_bitgen_inputs(meta: ProjectMetadata) -> None:
    required = [
        (meta.imple_ecp, "implementation checkpoint"),
        (meta.imple_ver_pb, "implementation ver.pb"),
        (meta.imple_psf, "implementation run.psf"),
    ]
    for path, label in required:
        if not path.exists():
            raise RuntimeError(
                f"Missing {label}: {path}\n"
                "Run elinx-compile.cmd until route finishes before starting bitgen."
            )


def _verilog_include_args(meta: ProjectMetadata) -> list[str]:
    include_dirs: list[str] = ["%DESIGN_PATH%"]
    seen: set[str] = {"%DESIGN_PATH%"}
    for design_file in meta.design_files:
        ext = design_file.suffix.lower()
        if ext not in VERILOG_EXTENSIONS and ext not in HEADER_EXTENSIONS:
            continue
        rel_dir = _rel_to_project(meta, design_file.parent)
        token = "%DESIGN_PATH%" if rel_dir == "." else f"%DESIGN_PATH%/{rel_dir}"
        if token not in seen:
            include_dirs.append(token)
            seen.add(token)
    return include_dirs


def write_synth_script(meta: ProjectMetadata) -> None:
    include_args = [f"-I{path}" for path in _verilog_include_args(meta)]
    lines = [
        "# auto-generated by Codex eLinx helper",
        f"set DESIGN_PATH={meta.project_dir.as_posix()}",
        f"set prj_name={meta.project_name}",
    ]
    for design_file in meta.design_files:
        rel_path = _rel_to_project(meta, design_file)
        ext = design_file.suffix.lower()
        if ext in HEADER_EXTENSIONS:
            continue
        if ext in VERILOG_EXTENSIONS:
            command = ["read_verilog"]
            if VERILOG_EXTENSIONS[ext]:
                command.append(VERILOG_EXTENSIONS[ext])
            command.extend(include_args)
            command.append(f'"%DESIGN_PATH%/{rel_path}"')
            lines.append(" ".join(command))
            continue
        if ext in VHDL_EXTENSIONS:
            lines.append(f'read_vhdl "%DESIGN_PATH%/{rel_path}"')
            continue
        raise RuntimeError(f"Unsupported HDL source extension in .epr: {design_file.name}")
    rel_vqm = _rel_to_project(meta, meta.synth_vqm)
    lines.append(
        f'synth_stratix -top {meta.top_entity} -family {meta.series_name} -vqm "%DESIGN_PATH%/{rel_vqm}"'
    )
    lines.append("")
    meta.synth_script.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def write_run_psf(meta: ProjectMetadata, output_path: Path) -> None:
    lines: list[str] = ["# auto-generated by Codex eLinx helper"]
    pin_assignments, timing_lines = _collect_constraints(meta)
    deduped: dict[str, str] = {}
    for pin, port in pin_assignments:
        deduped[port] = pin
    for port, pin in sorted(deduped.items()):
        lines.append(
            f"set_location_assignment {pin} -to {_brace_tcl_token(_normalize_assignment_target(port))}"
        )
    lines.extend(timing_lines)
    lines.append("")
    output_path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def write_pack_script(meta: ProjectMetadata, shell_bin: Path) -> None:
    lines = [
        f'cd   "{_quote_tcl(shell_bin)}"',
        f'set tclFile  "{_quote_tcl(shell_bin / "run_pack.tcl")}"',
        f'set dir "{_quote_tcl(meta.project_dir)}"',
        f'set prj {meta.project_name}',
        f'set topEntity {meta.top_entity}',
        f'set seriesName "{meta.series_name}"',
        f'set deviceName "{meta.device_name}"',
        f'set packageName "{meta.package_name}"',
        f'set synthName {meta.synth_run}',
        "source $tclFile",
        "run_pack $dir $prj $topEntity $seriesName $deviceName $packageName $synthName",
        "exit 0",
        "",
    ]
    meta.synth_pack_script.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def write_route_script(meta: ProjectMetadata, shell_bin: Path) -> None:
    lines = [
        f'cd   "{_quote_tcl(shell_bin)}"',
        f'set tclFile  "{_quote_tcl(shell_bin / "run_route.tcl")}"',
        f'set dir "{_quote_tcl(meta.project_dir)}"',
        f'set prj {meta.project_name}',
        f'set topEntity {meta.top_entity}',
        f'set seriesName "{meta.series_name}"',
        f'set deviceName "{meta.device_name}"',
        f'set packageName "{meta.package_name}"',
        f'set synthName {meta.synth_run}',
        f'set ImpleName {meta.imple_run}',
        "source $tclFile",
        "run_route $dir $prj $topEntity $seriesName $deviceName $packageName $synthName $ImpleName",
        "exit 0",
        "",
    ]
    meta.route_script.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def write_timing_script(meta: ProjectMetadata, shell_bin: Path) -> None:
    lines = [
        f'cd   "{_quote_tcl(shell_bin)}"',
        f'set tclFile  "{_quote_tcl(shell_bin / "run_timing_analysis.tcl")}"',
        f'set dir "{_quote_tcl(meta.project_dir)}"',
        f'set prj {meta.project_name}',
        f'set topEntity {meta.top_entity}',
        f'set seriesName "{meta.series_name}"',
        f'set deviceName "{meta.device_name}"',
        f'set ImpleName {meta.imple_run}',
        "source $tclFile",
        "run_timing_analysis $dir $prj $topEntity $seriesName $deviceName $ImpleName",
        "exit 0",
        "",
    ]
    meta.timing_script.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def write_bitgen_script(meta: ProjectMetadata, shell_bin: Path) -> None:
    pin_assignments, _ = _collect_constraints(meta)
    deduped: dict[str, str] = {}
    for pin, port in pin_assignments:
        deduped[port] = pin

    lines = [
        f'cd   "{_quote_tcl(shell_bin)}"',
        f'set projectDir "{_quote_tcl(meta.project_dir)}"',
        f'set projectName {meta.project_name}',
        f'set topEntity {meta.top_entity}',
        f'set seriesName "{meta.series_name}"',
        f'set deviceName {meta.device_name}',
        f'set packageName {meta.package_name}',
        f'set synthName {meta.synth_run}',
        f'set ImpleName {meta.imple_run}',
        "set_global_assignment -name TOP_LEVEL_ENTITY $topEntity",
        "set_global_assignment -name DESIGN_PATH $projectDir",
        "set_global_assignment -name PROJECT_NAME $projectName",
        "set_global_assignment -name PACKAGE_NAME $packageName",
        "set_global_assignment -name SYNTH_NAME $synthName",
        "set_global_assignment -name DESIGNIMPLE_PATH $projectDir/$projectName.runs/$ImpleName",
        "set vecname $projectName",
        "set vecdir $projectDir",
        "regsub -all {\\\\} $vecdir {/} vecdir",
        "regsub -all {\\\\} $vecdir {/} resultdir",
        "set_global_assignment -name DEVICE_SERIES $seriesName",
        "set_global_assignment -name DEVICE_NAME $deviceName",
        "setlogfile $projectDir/log4cpp.property $projectDir/$projectName.runs/$ImpleName/$projectName.edb",
        "source  ..\\\\Infrastructure\\\\psk_intern\\\\$seriesName\\\\series_library\\\\arc_guide.tcl",
        "set_arc_ucm_parameter TILE_DAT_PATH           ..\\\\Infrastructure\\\\psk_intern\\\\$seriesName\\\\series_library\\\\tile",
        "set_arc_ucm_parameter STRUCTURE_PATH          ..\\\\Infrastructure\\\\psk_intern\\\\$seriesName\\\\$deviceName\\\\$packageName\\\\structure.dat",
        "set_arc_ucm_parameter TILE_TIMING_DAT_PATH    ..\\\\Infrastructure\\\\psk_intern\\\\$seriesName\\\\$deviceName\\\\timing_info.dat",
        "if {[catch {arc_deserialize_device_info} err_msg]||[catch {arc_deserialize_tile_info} err_msg]} {",
        '  puts "arc generate Error:$err_msg"',
        "  exit 1",
        "} else {",
        '  puts "arc generate Success"',
        "}",
        'puts "arc_gene is 1"',
        "set_arc_ucm_parameter SRAM_CORRELATION_PATH   ..\\\\Infrastructure\\\\psk_appendix\\\\$seriesName\\\\series_library\\\\correlation",
        "set_arc_ucm_parameter CORRELATION_DAT_PATH    ..\\\\Infrastructure\\\\psk_intern\\\\$seriesName\\\\series_library\\\\correlation",
        "set_arc_ucm_parameter CONFIGMODE_DAT_PATH     ..\\\\Infrastructure\\\\psk_intern\\\\$seriesName\\\\series_library\\\\configmode",
        "arc_deserialize_cfgcell_info",
        "arc_deserialize_configmode_info",
        "set cur_dir [pwd]",
        'set_global_assignment -name ELINX_PATH "$cur_dir"',
        'set_global_assignment -name BITGEN_GUIDE ..\\\\Infrastructure\\\\psk_intern\\\\$seriesName\\\\$deviceName\\\\bitgen_guide.xml',
    ]
    for port, pin in sorted(deduped.items()):
        lines.append(
            f"set_location_assignment {pin} -to {_brace_tcl_token(_normalize_assignment_target(port))}"
        )
    lines.extend(
        [
            "load_pb_ver $projectDir/$projectName.runs/$ImpleName/$vecname.ver.pb",
            "if {[catch {udm_load_checkpoint $projectDir/$projectName.runs/$ImpleName/$projectName\\_$seriesName\\_$deviceName.ecp} err_msg]} {",
            '  puts "Load ECP Error happend $err_msg"',
            "  exit 1",
            "}",
            "if {[catch {udm_parse_ipspecific -b} err_msg]} {",
            "  puts \"udm_parse_ipspecific failed!\"",
            "  exit 1",
            "}",
            "if {[catch {udm_parse_meminitial} err_msg]} {",
            "  puts \"udm_parse_meminitial failed!\"",
            "  exit 1",
            "}",
            "if {[catch {bitgen_cfgcram} err_msg]} {",
            "  puts \"bitgen_cfgcram failed!\"",
            "  exit 1",
            "}",
            "bitgen_genecc",
            "if {[catch {bitgen_cfgbram} err_msg]} {",
            "  puts \"bitgen_cfgbram failed!\"",
            "  exit 1",
            "}",
            "bitgen_genfst",
            "bitgen_genmin",
            "if {[catch {bitgen_genpsk -o} err_msg]} {",
            "  puts \"bitgen_genpsk failed!\"",
            "  exit 1",
            "}",
            "set fid [open \"$projectDir/$projectName.runs/$ImpleName/$projectName.edb\" a+]",
            'puts $fid "Bitgen all was well"',
            "close $fid",
            'puts "All was well!"',
            "exit 0",
            "",
        ]
    )
    meta.bitgen_script.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def _format_command(command: list[str]) -> str:
    return " ".join(f'"{part}"' if " " in part else part for part in command)


def run_process(command: list[str], cwd: Path, capture: bool = False) -> tuple[int, str]:
    print("[elinx-native] Launch=" + _format_command(command))
    if not capture:
        completed = subprocess.run(command, cwd=cwd)
        return completed.returncode, ""
    completed = subprocess.run(
        command,
        cwd=cwd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return completed.returncode, completed.stdout or ""


def _print_tool_tail(label: str, content: str, max_lines: int = 60) -> None:
    stripped = content.strip()
    if not stripped:
        return
    lines = stripped.splitlines()
    print(f"[elinx-native] {label} output (last {min(len(lines), max_lines)} lines):")
    for line in lines[-max_lines:]:
        print(line)


def _read_text_if_exists(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def patch_quartus_pll_attrs(meta: ProjectMetadata) -> None:
    """
    Quartus-compatible VQM can lower altpll to stratix_pll and drop the high-level
    clk0_* attributes that eLinx Timer still expects when creating PLL clocks.
    Copy those attributes back from the synthesis report before eLinx pack/route.
    """
    if not meta.synth_vqm.exists() or not meta.synth_map_report.exists():
        return

    pll_params: dict[str, dict[str, str]] = {}
    current_inst: str | None = None
    for line in _read_text_if_exists(meta.synth_map_report).splitlines():
        inst_match = PLL_INSTANCE_RE.search(line)
        if inst_match:
            current_inst = inst_match.group(1)
            pll_params.setdefault(current_inst, {})
            continue
        if current_inst is None:
            continue
        param_match = PLL_PARAM_RE.search(line)
        if param_match:
            pll_params[current_inst][param_match.group(1)] = param_match.group(2)

    if not pll_params:
        return

    lines = _read_text_if_exists(meta.synth_vqm).splitlines()
    changed = False
    def _format_defparam_value(param_name: str, value: str) -> str:
        if param_name.endswith("_phase_shift"):
            return f'"{value}"'
        if re.fullmatch(r"-?\d+", value):
            return value
        return f'"{value}"'

    clk0_attrs = ("clk0_multiply_by", "clk0_divide_by", "clk0_duty_cycle", "clk0_phase_shift")
    for inst_name, params in pll_params.items():
        missing_attrs = [attr for attr in clk0_attrs if params.get(attr)]
        if not missing_attrs:
            continue
        cell_name = f"\\{inst_name}|pll"
        if any(f"defparam {cell_name} .clk0_multiply_by" in line for line in lines):
            continue
        insert_at: int | None = None
        clk0_counter_prefix = f"defparam {cell_name} .clk0_counter"
        n_prefix = f"defparam {cell_name} .n "
        for idx, line in enumerate(lines):
            if line.startswith(clk0_counter_prefix):
                insert_at = idx + 1
                break
            if insert_at is None and line.startswith(n_prefix):
                insert_at = idx + 1
        if insert_at is None:
            continue
        patch_lines = [
            f"defparam {cell_name} .{attr} = {_format_defparam_value(attr, params[attr])};"
            for attr in missing_attrs
        ]
        lines[insert_at:insert_at] = patch_lines
        changed = True

    if changed:
        meta.synth_vqm.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
        print("[elinx-native] Patched Quartus VQM PLL clk0 attributes for eLinx Timer.")


def _print_regex_matches(label: str, content: str, patterns: list[re.Pattern[str]]) -> None:
    matches: list[str] = []
    seen: set[str] = set()
    for line in content.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        for pattern in patterns:
            if pattern.search(stripped):
                if stripped not in seen:
                    seen.add(stripped)
                    matches.append(stripped)
                break
    if matches:
        print(f"[elinx-native] {label}:")
        for line in matches:
            print(f"[elinx-native]   {line}")


def run_native_synth(meta: ProjectMetadata, shell_bin: Path, native_synth: Path, implementation: Path) -> int:
    ensure_synth_inputs(meta)
    meta.synth_dir.mkdir(parents=True, exist_ok=True)
    _ensure_log4cpp(meta.log4cpp_src, meta.synth_dir / f"{meta.project_name}.edi")
    write_synth_script(meta)
    write_run_psf(meta, meta.synth_psf)
    write_pack_script(meta, shell_bin)
    synth_exit, synth_output = run_process(
        [str(native_synth), "-l", str(meta.synth_result_log), "-s", str(meta.synth_script)],
        shell_bin,
        capture=True,
    )
    if synth_exit != 0:
        synth_log_text = _read_text_if_exists(meta.synth_result_log)
        _print_regex_matches("Native synthesis failure", synth_output, FAILURE_SUMMARY_PATTERNS)
        _print_regex_matches("Native synthesis result failure", synth_log_text, FAILURE_SUMMARY_PATTERNS)
        _print_tool_tail("Native synthesis", synth_output, max_lines=20)
        _print_tool_tail("Native synthesis result log", synth_log_text, max_lines=20)
        return synth_exit
    if not meta.synth_vqm.exists():
        raise RuntimeError(f"Synthesis finished without producing the expected VQM file: {meta.synth_vqm}")
    patch_quartus_pll_attrs(meta)
    pack_exit, pack_output = run_process(
        [str(implementation), "-silence", "-f", str(meta.synth_pack_script)],
        shell_bin,
        capture=True,
    )
    if pack_exit != 0:
        _print_tool_tail("Native synth pack", pack_output)
    _print_regex_matches(
        "Native synthesis summary",
        _read_text_if_exists(meta.synth_result_log) or synth_output,
        SYNTH_SUMMARY_PATTERNS,
    )
    print(f"[elinx-native] Native synthesis script={meta.synth_script}")
    print(f"[elinx-native] Native synthesis log={meta.synth_result_log}")
    print(f"[elinx-native] Native pack script={meta.synth_pack_script}")
    print(f"[elinx-native] Native synth checkpoint={meta.synth_ecp}")
    print(f"[elinx-native] Native synth ver.pb={meta.synth_ver_pb}")
    return pack_exit


def run_compat_synth(
    meta: ProjectMetadata,
    quartus_map: Path,
    implementation: Path,
    revision: str | None,
) -> int:
    if meta.compat_qpf is None:
        raise RuntimeError(
            "Native synthesis failed and no sibling .qpf file is available for Quartus-compatible fallback."
        )
    ensure_synth_inputs(meta)
    meta.synth_dir.mkdir(parents=True, exist_ok=True)
    write_run_psf(meta, meta.synth_psf)
    write_pack_script(meta, implementation.parent)
    compat_revision = (revision or meta.project_name).strip() or meta.project_name
    print("[elinx-native] Native synthesis failed; falling back to Quartus-compatible synthesis.")
    print(f"[elinx-native] Compat backend QPF={meta.compat_qpf}")
    print(f"[elinx-native] Compat backend revision={compat_revision}")
    compat_exit, compat_output = run_process(
        [str(quartus_map), meta.project_name, "-c", compat_revision],
        meta.project_dir,
        capture=True,
    )
    if compat_exit != 0:
        _print_tool_tail("Compat synthesis", compat_output)
        return compat_exit
    _print_regex_matches("Compat synthesis summary", compat_output, SYNTH_SUMMARY_PATTERNS)
    tool_dir = quartus_map.parent
    ehiway_map = tool_dir / "ehiway_map.exe"
    ehiway_cdb = tool_dir / "ehiway_cdb.exe"
    quartus_cdb = tool_dir / "quartus_cdb.exe"

    map_tool: Path | None = ehiway_map if ehiway_map.exists() else None
    cdb_tool: Path | None = ehiway_cdb if ehiway_cdb.exists() else (quartus_cdb if quartus_cdb.exists() else None)

    if map_tool is not None:
        map_exit, map_output = run_process(
            [str(map_tool), "--read_settings_files=on", "--write_settings_files=off", compat_revision],
            meta.project_dir,
            capture=True,
        )
        if map_exit != 0:
            _print_tool_tail("Compat ehiway_map", map_output)
            return map_exit
        _print_regex_matches("Compat ehiway_map summary", map_output, SYNTH_SUMMARY_PATTERNS)

    if cdb_tool is not None:
        cdb_exit, cdb_output = run_process(
            [str(cdb_tool), meta.project_name, "-c", compat_revision, f"--vqm={meta.synth_vqm}"],
            meta.project_dir,
            capture=True,
        )
        if cdb_exit != 0:
            _print_tool_tail("Compat ehiway_cdb", cdb_output)
            return cdb_exit
        _print_regex_matches("Compat ehiway_cdb summary", cdb_output, SYNTH_SUMMARY_PATTERNS)
        patch_quartus_pll_attrs(meta)

        pack_exit, pack_output = run_process(
            [str(implementation), "-silence", "-f", str(meta.synth_pack_script)],
            implementation.parent,
            capture=True,
        )
        if pack_exit != 0:
            _print_tool_tail("Compat synth pack", pack_output)
            return pack_exit
        _print_regex_matches("Compat synth pack summary", pack_output, PACK_SUMMARY_PATTERNS)

    print(f"[elinx-native] Compat synth checkpoint={meta.synth_ecp}")
    print(f"[elinx-native] Compat synth ver.pb={meta.synth_ver_pb}")
    print(f"[elinx-native] Compat synth psf={meta.synth_psf}")
    return compat_exit


def run_synth_with_fallback(
    meta: ProjectMetadata,
    shell_bin: Path,
    native_synth: Path,
    implementation: Path,
    quartus_map: Path,
    revision: str | None,
) -> int:
    if _compat_synth_only_enabled():
        print("[elinx-native] ELINX_FORCE_COMPAT_SYNTH=1, skipping native synthesis and using compatibility synthesis directly.")
        compat_exit = run_compat_synth(meta, quartus_map, implementation, revision)
        if compat_exit == 0:
            return 0
        print(f"[elinx-native] Compat synthesis failed with exit code {compat_exit}.")
        return compat_exit

    native_error: str | None = None
    try:
        native_exit = run_native_synth(meta, shell_bin, native_synth, implementation)
        if native_exit == 0:
            return 0
        native_error = f"exit code {native_exit}"
    except RuntimeError as exc:
        native_exit = 1
        native_error = str(exc)

    if meta.compat_qpf is None:
        if native_error:
            print(f"[elinx-native] Native synthesis failed without compatibility fallback: {native_error}")
        return native_exit

    if native_error:
        print(f"[elinx-native] Native synthesis fallback trigger: {native_error}")
    compat_exit = run_compat_synth(meta, quartus_map, implementation, revision)
    if compat_exit == 0:
        return 0
    print(f"[elinx-native] Compat synthesis failed with exit code {compat_exit}.")
    return compat_exit


def run_native_route(meta: ProjectMetadata, shell_bin: Path, implementation: Path) -> int:
    ensure_route_inputs(meta)
    _ensure_log4cpp(meta.log4cpp_src, meta.imple_log)
    write_route_script(meta, shell_bin)
    route_exit, route_output = run_process(
        [str(implementation), "-silence", "-f", str(meta.route_script)],
        shell_bin,
        capture=True,
    )
    imple_log_text = _read_text_if_exists(meta.imple_log)
    if route_exit != 0:
        _print_tool_tail("Native route", route_output)
        _print_tool_tail("Native implementation log", imple_log_text)
        return route_exit
    _print_regex_matches(
        "Native route summary",
        route_output + "\n" + imple_log_text,
        ROUTE_SUMMARY_PATTERNS,
    )
    print(f"[elinx-native] Native route script={meta.route_script}")
    print(f"[elinx-native] Native implementation log={meta.imple_log}")
    print(f"[elinx-native] Native route status report={meta.route_status_report}")
    print(f"[elinx-native] Native timing report={meta.timing_report}")
    print(f"[elinx-native] Native slack report={meta.slack_report}")
    return route_exit


def run_native_timing(meta: ProjectMetadata, shell_bin: Path, implementation: Path) -> int:
    ensure_sta_inputs(meta)
    write_timing_script(meta, shell_bin)
    timing_exit, timing_output = run_process(
        [str(implementation), "-silence", "-f", str(meta.timing_script)],
        shell_bin,
        capture=True,
    )
    timing_log_text = _read_text_if_exists(meta.timing_log)
    if timing_exit != 0:
        _print_tool_tail("Native timing", timing_output)
        _print_tool_tail("Native timing log", timing_log_text)
        return timing_exit
    _print_regex_matches(
        "Native timing summary",
        timing_output + "\n" + timing_log_text,
        TIMING_SUMMARY_PATTERNS,
    )
    print(f"[elinx-native] Native timing script={meta.timing_script}")
    print(f"[elinx-native] Native timing log={meta.timing_log}")
    print(f"[elinx-native] Native timing report={meta.timing_report}")
    print(f"[elinx-native] Native slack report={meta.slack_report}")
    return timing_exit


def run_native_bitgen(meta: ProjectMetadata, shell_bin: Path, bitgen_executable: Path) -> int:
    ensure_bitgen_inputs(meta)
    write_bitgen_script(meta, shell_bin)
    bitgen_exit, bitgen_output = run_process(
        [str(bitgen_executable), "-silence", "-f", str(meta.bitgen_script)],
        shell_bin,
        capture=True,
    )
    bitgen_log_text = _read_text_if_exists(meta.bitgen_log)
    if bitgen_exit != 0:
        _print_tool_tail("Native bitgen", bitgen_output)
        _print_tool_tail("Native bitgen log", bitgen_log_text)
        return bitgen_exit
    _print_regex_matches(
        "Native bitgen summary",
        bitgen_output + "\n" + bitgen_log_text,
        BITGEN_SUMMARY_PATTERNS,
    )
    print(f"[elinx-native] Native bitgen script={meta.bitgen_script}")
    print(f"[elinx-native] Native bitgen log={meta.bitgen_log}")
    print(f"[elinx-native] Native psk={meta.bitgen_psk}")
    print(f"[elinx-native] Native compressed psk={meta.bitgen_comp_psk}")
    return bitgen_exit


def do_compile(args: argparse.Namespace) -> int:
    shell_bin = _require_env_path("ELINX_SHELL_BIN")
    native_synth = _require_env_path("ELINX_NATIVE_SYNTH")
    implementation = _require_env_path("ELINX_NATIVE_IMPL")
    quartus_map = _require_env_path("ELINX_QUARTUS_MAP")
    meta = load_project_metadata(Path(args.epr).resolve())
    _stage_header("compile", meta)
    synth_exit = run_synth_with_fallback(
        meta,
        shell_bin,
        native_synth,
        implementation,
        quartus_map,
        args.revision,
    )
    if synth_exit != 0:
        return synth_exit
    return run_native_route(meta, shell_bin, implementation)


def do_synth(args: argparse.Namespace) -> int:
    shell_bin = _require_env_path("ELINX_SHELL_BIN")
    native_synth = _require_env_path("ELINX_NATIVE_SYNTH")
    implementation = _require_env_path("ELINX_NATIVE_IMPL")
    quartus_map = _require_env_path("ELINX_QUARTUS_MAP")
    meta = load_project_metadata(Path(args.epr).resolve())
    _stage_header("synth", meta)
    return run_synth_with_fallback(
        meta,
        shell_bin,
        native_synth,
        implementation,
        quartus_map,
        args.revision,
    )


def do_sta(args: argparse.Namespace) -> int:
    shell_bin = _require_env_path("ELINX_SHELL_BIN")
    implementation = _require_env_path("ELINX_NATIVE_IMPL")
    meta = load_project_metadata(Path(args.epr).resolve())
    _stage_header("sta", meta)
    return run_native_timing(meta, shell_bin, implementation)


def do_bitgen(args: argparse.Namespace) -> int:
    shell_bin = _require_env_path("ELINX_SHELL_BIN")
    bitgen_executable = _require_env_path("ELINX_NATIVE_BITGEN")
    meta = load_project_metadata(Path(args.epr).resolve())
    _stage_header("bitgen", meta)
    return run_native_bitgen(meta, shell_bin, bitgen_executable)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Native eLinx helper flow.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    compile_parser = subparsers.add_parser("compile", help="run native synth + route from an .epr project")
    compile_parser.add_argument("--epr", required=True, help="path to the .epr project")
    compile_parser.add_argument("--revision", required=False, help="compatibility fallback revision name")
    compile_parser.add_argument("--log-dir", required=False, help="reserved for wrapper compatibility")
    compile_parser.set_defaults(func=do_compile)

    synth_parser = subparsers.add_parser("synth", help="run native synthesis + pack from an .epr project")
    synth_parser.add_argument("--epr", required=True, help="path to the .epr project")
    synth_parser.add_argument("--revision", required=False, help="compatibility fallback revision name")
    synth_parser.add_argument("--log-dir", required=False, help="reserved for wrapper compatibility")
    synth_parser.set_defaults(func=do_synth)

    sta_parser = subparsers.add_parser("sta", help="run native timing analysis from an .epr project")
    sta_parser.add_argument("--epr", required=True, help="path to the .epr project")
    sta_parser.add_argument("--log-dir", required=False, help="reserved for wrapper compatibility")
    sta_parser.set_defaults(func=do_sta)

    bitgen_parser = subparsers.add_parser("bitgen", help="run native bitgen from an .epr project")
    bitgen_parser.add_argument("--epr", required=True, help="path to the .epr project")
    bitgen_parser.add_argument("--log-dir", required=False, help="reserved for wrapper compatibility")
    bitgen_parser.set_defaults(func=do_bitgen)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.func(args)
    except RuntimeError as exc:
        return _fail(str(exc))
    except ET.ParseError as exc:
        return _fail(f"Failed to parse .epr XML: {exc}")


if __name__ == "__main__":
    raise SystemExit(main())
