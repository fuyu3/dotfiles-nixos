import QtQuick
import Quickshell.Io

Item {
    id: root

    Theme { id: theme }

    property bool vertical: false
    property bool active: true
    property color foregroundColor: "#ffffff"
    property color mutedColor: theme.neutralTextMuted
    property real cpuUsage: 0
    property real ramUsage: -1
    property real ramUsedKiB: -1
    property real gpuUsage: -1
    property real cpuTempC: -1
    property real gpuTempC: -1
    property string gpuText: "N/D"
    property bool cpuReady: false
    property var diskEntries: []
    property real previousCpuIdle: -1
    property real previousCpuTotal: -1

    readonly property int pollInterval: 2000
    readonly property string cpuText: cpuReady ? Math.round(cpuUsage) + "%" : "--"
    readonly property string ramText: formatMemoryAmount(ramUsedKiB)
    readonly property string cpuTempText: cpuTempC >= 0 ? Math.round(cpuTempC) + "°" : "N/D"
    readonly property string gpuTempText: gpuTempC >= 0 ? Math.round(gpuTempC) + "°" : "N/D"
    readonly property string statsCommand:
        "valid_pct() {\n"
        + "  printf '%s' \"$1\" | grep -Eq '^[0-9]+$'\n"
        + "}\n"
        + "valid_temp() {\n"
        + "  printf '%s' \"$1\" | grep -Eq '^-?[0-9]+([.][0-9]+)?$'\n"
        + "}\n"
        + "normalize_temp() {\n"
        + "  awk -v raw=\"$1\" 'BEGIN { if (raw == \"\") exit 1; if (raw > 1000 || raw < -1000) raw = raw / 1000; printf \"%.0f\", raw }'\n"
        + "}\n"
        + "pick_hwmon_temp() {\n"
        + "  hwdir=\"$1\"\n"
        + "  preferred_regex=\"$2\"\n"
        + "  fallback=\"\"\n"
        + "  for label in \"$hwdir\"/temp*_label; do\n"
        + "    [ -r \"$label\" ] || continue\n"
        + "    input=\"${label%_label}_input\"\n"
        + "    [ -r \"$input\" ] || continue\n"
        + "    label_text=$(tr '[:upper:]' '[:lower:]' < \"$label\" 2>/dev/null)\n"
        + "    value=$(cat \"$input\" 2>/dev/null)\n"
        + "    valid_temp \"$value\" || continue\n"
        + "    if printf '%s' \"$label_text\" | grep -Eq \"$preferred_regex\"; then\n"
        + "      normalize_temp \"$value\"\n"
        + "      return 0\n"
        + "    fi\n"
        + "    [ -n \"$fallback\" ] || fallback=\"$value\"\n"
        + "  done\n"
        + "  if [ -z \"$fallback\" ]; then\n"
        + "    for input in \"$hwdir\"/temp*_input; do\n"
        + "      [ -r \"$input\" ] || continue\n"
        + "      value=$(cat \"$input\" 2>/dev/null)\n"
        + "      valid_temp \"$value\" || continue\n"
        + "      fallback=\"$value\"\n"
        + "      break\n"
        + "    done\n"
        + "  fi\n"
        + "  [ -n \"$fallback\" ] || return 1\n"
        + "  normalize_temp \"$fallback\"\n"
        + "}\n"
        + "read_engine_busy() {\n"
        + "  card_path=\"$1\"\n"
        + "  engine_paths=$(find \"$card_path\" -maxdepth 4 -type f \\( -path \"$card_path/engine/*/busy\" -o -path \"$card_path/gt/gt*/busy\" \\) 2>/dev/null)\n"
        + "  [ -n \"$engine_paths\" ] || return 1\n"
        + "  busy1=$(awk '{sum += $1} END {print sum + 0}' $engine_paths 2>/dev/null)\n"
        + "  sleep 0.12\n"
        + "  busy2=$(awk '{sum += $1} END {print sum + 0}' $engine_paths 2>/dev/null)\n"
        + "  awk -v b1=\"$busy1\" -v b2=\"$busy2\" 'BEGIN {delta = b2 - b1; if (delta < 0) delta = 0; value = delta / 1200000; if (value > 100) value = 100; printf \"%.0f\", value}'\n"
        + "}\n"
        + "read_cpu_temp_hwmon() {\n"
        + "  for hw in /sys/class/hwmon/hwmon*; do\n"
        + "    [ -r \"$hw/name\" ] || continue\n"
        + "    name=$(tr '[:upper:]' '[:lower:]' < \"$hw/name\" 2>/dev/null)\n"
        + "    case \"$name\" in\n"
        + "      coretemp|k10temp|zenpower|fam15h_power|cpu_thermal|x86_pkg_temp)\n"
        + "        candidate=$(pick_hwmon_temp \"$hw\" 'package|tctl|tdie|cpu' 2>/dev/null)\n"
        + "        if valid_temp \"$candidate\"; then\n"
        + "          printf '%s' \"$candidate\"\n"
        + "          return 0\n"
        + "        fi\n"
        + "        ;;\n"
        + "    esac\n"
        + "  done\n"
        + "  return 1\n"
        + "}\n"
        + "read_cpu_temp_sensors() {\n"
        + "  [ -n \"$sensors_output\" ] || return 1\n"
        + "  printf '%s\n' \"$sensors_output\" | awk '\n"
        + "    /^[^[:space:]].*$/ && $0 !~ /^Adapter:/ && $0 !~ /:$/ {\n"
        + "      header = tolower($0)\n"
        + "      in_cpu = (header ~ /(coretemp|k10temp|zenpower|fam15h_power|cpu_thermal|x86_pkg_temp)/)\n"
        + "      next\n"
        + "    }\n"
        + "    in_cpu && /[-+]?[0-9]+([.][0-9]+)?°C/ {\n"
        + "      low = tolower($0)\n"
        + "      score = 1\n"
        + "      if (low ~ /(package id|package|tctl|tdie)/) score = 4\n"
        + "      else if (low ~ /(tccd|core [0-9]+)/) score = 3\n"
        + "      else if (low ~ /temp[0-9]+/) score = 2\n"
        + "      if (match($0, /[-+]?[0-9]+([.][0-9]+)?°C/)) {\n"
        + "        raw = substr($0, RSTART, RLENGTH)\n"
        + "        gsub(/[+°C]/, \"\", raw)\n"
        + "        if (score > best_score) {\n"
        + "          best_score = score\n"
        + "          best = raw\n"
        + "        }\n"
        + "      }\n"
        + "    }\n"
        + "    END { if (best != \"\") printf \"%.0f\", best }\n"
        + "  '\n"
        + "}\n"
        + "read_cpu_temp_zone() {\n"
        + "  for zone in /sys/class/thermal/thermal_zone*; do\n"
        + "    [ -r \"$zone/type\" ] || continue\n"
        + "    [ -r \"$zone/temp\" ] || continue\n"
        + "    zone_type=$(tr '[:upper:]' '[:lower:]' < \"$zone/type\" 2>/dev/null)\n"
        + "    case \"$zone_type\" in\n"
        + "      x86_pkg_temp|cpu-thermal|cpu_thermal|soc_thermal|k10temp)\n"
        + "        candidate=$(cat \"$zone/temp\" 2>/dev/null)\n"
        + "        valid_temp \"$candidate\" || continue\n"
        + "        normalize_temp \"$candidate\"\n"
        + "        return 0\n"
        + "        ;;\n"
        + "    esac\n"
        + "  done\n"
        + "  return 1\n"
        + "}\n"
        + "read_gpu_temp_card() {\n"
        + "  card=\"$1\"\n"
        + "  for hw in \"$card\"/device/hwmon/hwmon*; do\n"
        + "    [ -d \"$hw\" ] || continue\n"
        + "    candidate=$(pick_hwmon_temp \"$hw\" 'edge|junction|gpu|package' 2>/dev/null)\n"
        + "    if valid_temp \"$candidate\"; then\n"
        + "      printf '%s' \"$candidate\"\n"
        + "      return 0\n"
        + "    fi\n"
        + "  done\n"
        + "  return 1\n"
        + "}\n"
        + "read_gpu_temp_sensors() {\n"
        + "  [ -n \"$sensors_output\" ] || return 1\n"
        + "  printf '%s\n' \"$sensors_output\" | awk '\n"
        + "    /^[^[:space:]].*$/ && $0 !~ /^Adapter:/ && $0 !~ /:$/ {\n"
        + "      header = tolower($0)\n"
        + "      in_gpu = (header ~ /(amdgpu|nouveau|nvidia|i915|xe)/)\n"
        + "      next\n"
        + "    }\n"
        + "    in_gpu && /[-+]?[0-9]+([.][0-9]+)?°C/ {\n"
        + "      low = tolower($0)\n"
        + "      score = 1\n"
        + "      if (low ~ /(edge|junction|gpu)/) score = 4\n"
        + "      else if (low ~ /(package|temp[0-9]+)/) score = 2\n"
        + "      if (match($0, /[-+]?[0-9]+([.][0-9]+)?°C/)) {\n"
        + "        raw = substr($0, RSTART, RLENGTH)\n"
        + "        gsub(/[+°C]/, \"\", raw)\n"
        + "        if (score > best_score) {\n"
        + "          best_score = score\n"
        + "          best = raw\n"
        + "        }\n"
        + "      }\n"
        + "    }\n"
        + "    END { if (best != \"\") printf \"%.0f\", best }\n"
        + "  '\n"
        + "}\n"
        + "read_gpu_temp_zone() {\n"
        + "  for zone in /sys/class/thermal/thermal_zone*; do\n"
        + "    [ -r \"$zone/type\" ] || continue\n"
        + "    [ -r \"$zone/temp\" ] || continue\n"
        + "    zone_type=$(tr '[:upper:]' '[:lower:]' < \"$zone/type\" 2>/dev/null)\n"
        + "    case \"$zone_type\" in\n"
        + "      gpu-thermal|gpu_thermal|amdgpu|i915|xe|nouveau|nvidia)\n"
        + "        candidate=$(cat \"$zone/temp\" 2>/dev/null)\n"
        + "        valid_temp \"$candidate\" || continue\n"
        + "        normalize_temp \"$candidate\"\n"
        + "        return 0\n"
        + "        ;;\n"
        + "    esac\n"
        + "  done\n"
        + "  return 1\n"
        + "}\n"
        + "sensors_output=\"\"\n"
        + "if command -v sensors >/dev/null 2>&1; then\n"
        + "  sensors_output=$(sensors 2>/dev/null)\n"
        + "fi\n"
        + "read _ user nice system idle iowait irq softirq steal _ < /proc/stat\n"
        + "cpu_idle=$((idle + iowait))\n"
        + "cpu_total=$((user + nice + system + idle + iowait + irq + softirq + steal))\n"
        + "mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)\n"
        + "mem_avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)\n"
        + "mem_used=$((mem_total - mem_avail))\n"
        + "cpu_temp=$(read_cpu_temp_hwmon 2>/dev/null)\n"
        + "if ! valid_temp \"$cpu_temp\"; then\n"
        + "  cpu_temp=$(read_cpu_temp_sensors 2>/dev/null)\n"
        + "fi\n"
        + "if ! valid_temp \"$cpu_temp\"; then\n"
        + "  cpu_temp=$(read_cpu_temp_zone 2>/dev/null)\n"
        + "fi\n"
        + "if ! valid_temp \"$cpu_temp\"; then\n"
        + "  cpu_temp=\"N/A\"\n"
        + "fi\n"
        + "gpu=\"N/A\"\n"
        + "gpu_temp=\"N/A\"\n"
        + "for card in /sys/class/drm/card[0-9]*; do\n"
        + "  [ -r \"$card/device/vendor\" ] || continue\n"
        + "  vendor=$(cat \"$card/device/vendor\" 2>/dev/null)\n"
        + "  driver=\"\"\n"
        + "  if [ -L \"$card/device/driver\" ]; then\n"
        + "    driver=$(basename \"$(readlink -f \"$card/device/driver\")\")\n"
        + "  fi\n"
        + "  candidate=\"\"\n"
        + "  candidate_temp=\"\"\n"
        + "  if [ \"$driver\" = \"nvidia\" ] || [ \"$vendor\" = \"0x10de\" ]; then\n"
        + "    if command -v nvidia-smi >/dev/null 2>&1; then\n"
        + "      nvidia_line=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)\n"
        + "      candidate=$(printf '%s' \"$nvidia_line\" | awk -F',' 'NR==1 {gsub(/ /, \"\", $1); print $1}')\n"
        + "      candidate_temp=$(printf '%s' \"$nvidia_line\" | awk -F',' 'NR==1 {gsub(/ /, \"\", $2); print $2}')\n"
        + "    fi\n"
        + "  fi\n"
        + "  if ! valid_pct \"$candidate\" && [ -r \"$card/device/gpu_busy_percent\" ]; then\n"
        + "    candidate=$(cat \"$card/device/gpu_busy_percent\" 2>/dev/null)\n"
        + "  fi\n"
        + "  if ! valid_pct \"$candidate\"; then\n"
        + "    candidate=$(read_engine_busy \"$card\" 2>/dev/null)\n"
        + "  fi\n"
        + "  if ! valid_temp \"$candidate_temp\"; then\n"
        + "    candidate_temp=$(read_gpu_temp_card \"$card\" 2>/dev/null)\n"
        + "  fi\n"
        + "  if valid_pct \"$candidate\" || valid_temp \"$candidate_temp\"; then\n"
        + "    gpu=\"$candidate\"\n"
        + "    gpu_temp=\"$candidate_temp\"\n"
        + "    break\n"
        + "  fi\n"
        + "done\n"
        + "if ! valid_temp \"$gpu_temp\"; then\n"
        + "  gpu_temp=$(read_gpu_temp_sensors 2>/dev/null)\n"
        + "fi\n"
        + "if ! valid_temp \"$gpu_temp\"; then\n"
        + "  gpu_temp=$(read_gpu_temp_zone 2>/dev/null)\n"
        + "fi\n"
        + "if ! valid_pct \"$gpu\"; then\n"
        + "  gpu=\"N/A\"\n"
        + "fi\n"
        + "if ! valid_temp \"$gpu_temp\"; then\n"
        + "  gpu_temp=\"N/A\"\n"
        + "fi\n"
        + "printf 'CPU %s %s %s\\nMEM %s %s\\nGPU %s %s\\n' \"$cpu_idle\" \"$cpu_total\" \"$cpu_temp\" \"$mem_used\" \"$mem_total\" \"$gpu\" \"$gpu_temp\"\n"
        + "lsblk -b -P -n -o NAME,TYPE,PKNAME,SIZE,FSUSE%,MOUNTPOINTS | awk '\n"
        + "function field(key, line,    marker, rest, quotePos, startPos) {\n"
        + "    marker = key \"=\\\"\"\n"
        + "    startPos = index(line, marker)\n"
        + "    if (!startPos) return \"\"\n"
        + "    rest = substr(line, startPos + length(marker))\n"
        + "    quotePos = index(rest, \"\\\"\")\n"
        + "    if (!quotePos) return \"\"\n"
        + "    return substr(rest, 1, quotePos - 1)\n"
        + "}\n"
        + "{\n"
        + "    name = field(\"NAME\", $0)\n"
        + "    type = field(\"TYPE\", $0)\n"
        + "    pkname = field(\"PKNAME\", $0)\n"
        + "    size = field(\"SIZE\", $0) + 0\n"
        + "    fsuse = field(\"FSUSE%\", $0)\n"
        + "    if (type == \"disk\" && name !~ /^(loop|zram|ram|fd|sr)/) {\n"
        + "        if (!(name in seen)) {\n"
        + "            order[++count] = name\n"
        + "            seen[name] = 1\n"
        + "        }\n"
        + "        directPct[name] = (fsuse ~ /^[0-9]+%$/ ? substr(fsuse, 1, length(fsuse) - 1) + 0 : -1)\n"
        + "    } else if (type == \"part\" && pkname in seen && fsuse ~ /^[0-9]+%$/) {\n"
        + "        gsub(/%/, \"\", fsuse)\n"
        + "        weightedUse[pkname] += size * (fsuse + 0)\n"
        + "        weightedSize[pkname] += size\n"
        + "    }\n"
        + "}\n"
        + "END {\n"
        + "    for (i = 1; i <= count; ++i) {\n"
        + "        name = order[i]\n"
        + "        if (weightedSize[name] > 0)\n"
        + "            pct = int((weightedUse[name] / weightedSize[name]) + 0.5)\n"
        + "        else if (directPct[name] >= 0)\n"
        + "            pct = int(directPct[name] + 0.5)\n"
        + "        else\n"
        + "            pct = \"N/A\"\n"
        + "        printf \"DISK %s %s\\n\", name, pct\n"
        + "    }\n"
        + "}\n"
        + "'\n"

    implicitWidth: vertical ? Math.max(40, verticalContent.implicitWidth) : horizontalContent.implicitWidth
    implicitHeight: vertical ? verticalContent.implicitHeight : horizontalContent.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function formatMemoryAmount(kibibytes) {
        if (kibibytes < 0 || isNaN(kibibytes))
            return "--"

        var mebibytes = kibibytes / 1024
        if (mebibytes < 1024)
            return Math.round(mebibytes) + "M"

        var gibibytes = mebibytes / 1024
        var roundedGiB = Math.round(gibibytes * 10) / 10
        if (Math.abs(roundedGiB - Math.round(roundedGiB)) < 0.05)
            return Math.round(roundedGiB) + "G"

        return roundedGiB.toFixed(1) + "G"
    }

    function usageColor(usage) {
        if (usage < 0)
            return mutedColor
        if (usage >= 85)
            return theme.erro
        if (usage >= 65)
            return theme.alerta
        if (usage >= 35)
            return "#9ad8ff"
        return theme.sucesso
    }

    function tempColor(temp) {
        if (temp < 0)
            return mutedColor
        if (temp >= 85)
            return theme.erro
        if (temp >= 72)
            return theme.alerta
        if (temp >= 58)
            return "#ffd1a3"
        return theme.sucesso
    }

    function parseStats(output) {
        var cpuIdle = -1
        var cpuTotal = -1
        var cpuTemp = -1
        var memUsed = -1
        var memTotal = -1
        var gpuValue = "N/A"
        var gpuTemp = -1
        var disks = []
        var lines = output.trim().split("\n")

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim()
            if (!line)
                continue

            var parts = line.split(/\s+/)
            switch (parts[0]) {
            case "CPU":
                if (parts.length >= 4) {
                    cpuIdle = Number(parts[1])
                    cpuTotal = Number(parts[2])
                    cpuTemp = parts[3] !== "N/A" ? Number(parts[3]) : -1
                }
                break
            case "MEM":
                if (parts.length >= 3) {
                    memUsed = Number(parts[1])
                    memTotal = Number(parts[2])
                }
                break
            case "GPU":
                if (parts.length >= 3) {
                    gpuValue = parts[1]
                    gpuTemp = parts[2] !== "N/A" ? Number(parts[2]) : -1
                }
                break
            case "DISK":
                if (parts.length >= 3) {
                    var diskUsage = Number(parts[2])
                    var validUsage = !isNaN(diskUsage)
                    disks.push({
                        name: parts[1],
                        usage: validUsage ? clamp(diskUsage, 0, 100) : -1,
                        text: validUsage ? Math.round(diskUsage) + "%" : "N/D"
                    })
                }
                break
            }
        }

        if (cpuIdle >= 0 && cpuTotal > 0) {
            if (previousCpuTotal >= 0 && cpuTotal > previousCpuTotal) {
                var deltaTotal = cpuTotal - previousCpuTotal
                var deltaIdle = cpuIdle - previousCpuIdle
                if (deltaTotal > 0) {
                    cpuUsage = clamp((1 - (deltaIdle / deltaTotal)) * 100, 0, 100)
                    cpuReady = true
                }
            }

            previousCpuIdle = cpuIdle
            previousCpuTotal = cpuTotal
        }

        cpuTempC = cpuTemp >= 0 ? cpuTemp : -1

        if (memUsed >= 0 && memTotal > 0) {
            ramUsedKiB = memUsed
            ramUsage = clamp((memUsed / memTotal) * 100, 0, 100)
        } else {
            ramUsedKiB = -1
            ramUsage = -1
        }

        if (gpuValue !== "N/A" && !isNaN(Number(gpuValue))) {
            gpuUsage = clamp(Number(gpuValue), 0, 100)
            gpuText = Math.round(gpuUsage) + "%"
        } else {
            gpuUsage = -1
            gpuText = "N/D"
        }

        gpuTempC = gpuTemp >= 0 ? gpuTemp : -1
        diskEntries = disks
    }

    function refresh() {
        if (!active || statsProcess.running)
            return

        statsProcess.running = true
    }

    Timer {
        id: pollTimer
        interval: root.pollInterval
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: statsProcess
        running: false
        command: ["bash", "-lc", root.statsCommand]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseStats(text)
        }
    }

    onActiveChanged: {
        if (active)
            refresh()
    }

    Column {
        id: verticalContent
        visible: root.vertical
        spacing: 5
        anchors.horizontalCenter: parent.horizontalCenter

        Column {
            spacing: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CPU"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 7
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.cpuText
                color: root.usageColor(root.cpuUsage)
                font.family: "Rubik"
                font.pixelSize: 9
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.cpuTempText
                color: root.tempColor(root.cpuTempC)
                font.family: "Rubik"
                font.pixelSize: 8
                font.bold: true
            }
        }
            
        Column {
            spacing: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GPU"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 7
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.gpuText
                color: root.usageColor(root.gpuUsage)
                font.family: "Rubik"
                font.pixelSize: 9
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.gpuTempText
                color: root.tempColor(root.gpuTempC)
                font.family: "Rubik"
                font.pixelSize: 8
                font.bold: true
            }
        }

        Column {
            spacing: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RAM"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 7
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.ramText
                color: root.usageColor(root.ramUsage)
                font.family: "Rubik"
                font.pixelSize: 9
                font.bold: true
            }
        }

        

        Repeater {
            model: root.diskEntries

            Column {
                required property var modelData
                spacing: 1
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.name
                    color: root.mutedColor
                    font.family: "Rubik"
                    font.pixelSize: 6
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.text
                    color: root.usageColor(modelData.usage)
                    font.family: "Rubik"
                    font.pixelSize: 8
                    font.bold: true
                }
            }
        }
    }

    Row {
        id: horizontalContent
        visible: !root.vertical
        spacing: 10
        anchors.verticalCenter: parent.verticalCenter

        Column {
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "CPU"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 8
                font.bold: true
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    text: root.cpuText
                    color: root.usageColor(root.cpuUsage)
                    font.family: "Rubik"
                    font.pixelSize: 10
                    font.bold: true
                }

                Text {
                    text: root.cpuTempText
                    color: root.tempColor(root.cpuTempC)
                    font.family: "Rubik"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }
        
        Column {
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "GPU"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 8
                font.bold: true
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Text {
                    text: root.gpuText
                    color: root.usageColor(root.gpuUsage)
                    font.family: "Rubik"
                    font.pixelSize: 10
                    font.bold: true
                }

                Text {
                    text: root.gpuTempText
                    color: root.tempColor(root.gpuTempC)
                    font.family: "Rubik"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }
        
        Column {
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "RAM"
                color: root.mutedColor
                font.family: "Rubik"
                font.pixelSize: 8
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.ramText
                color: root.usageColor(root.ramUsage)
                font.family: "Rubik"
                font.pixelSize: 10
                font.bold: true
            }
        }

        

        Repeater {
            model: root.diskEntries

            Column {
                required property var modelData
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.name
                    color: root.mutedColor
                    font.family: "Rubik"
                    font.pixelSize: 8
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.text
                    color: root.usageColor(modelData.usage)
                    font.family: "Rubik"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }
    }
}
