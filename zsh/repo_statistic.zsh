#!/usr/bin/env zsh

zmodload zsh/datetime

# ==========================================
# 1. Konfiguration
# ==========================================

base_dir="$HOME/Projekte/clean_gitrepos"

# nameWithOwner UND isPrivate als JSON-Paket
repo_json=$(gh repo list --limit 1000 --json nameWithOwner,isPrivate)

repos=($(echo "$repo_json" | jq -r '.[].nameWithOwner | split("/")[-1]'))

if [[ ${#repos[@]} -eq 0 ]]; then
    print "❌ Fehler: Keine Repositories über 'gh' gefunden oder nicht eingeloggt."
    exit 1
fi

integer count_private=$(echo "$repo_json" | jq -r 'map(select(.isPrivate)) | length')
integer count_public=$(echo "$repo_json" | jq -r 'map(select(.isPrivate | not)) | length')

# ------------------------------------------
# Blacklist für Verzeichnisse
# Ganze Ordner-Strukturen, die komplett ignoriert werden sollen
# ------------------------------------------
ignore_dirs=(
    ".git"
    ".idea"
    "node_modules"
    "__pycache__"
    ".venv"
)

# ------------------------------------------
# Blacklist für das Line-Counting
# Diese Dateien werden für die Files-Statistik gezählt, 
# aber nicht eingelesen.
# ------------------------------------------
ignore_lines=(
    "package-lock.json"
    "yarn.lock"
    "pnpm-lock.yaml"
)

# ------------------------------------------
# Definition über exakte Dateinamen
# Überschreibt die Endungs-Logik.
# ------------------------------------------
name_defs=(
    # --- Projektmanagement & Dokumentation ---
    "Readme Files"      "txt"   "README.md"
    "Readme Files"      "txt"   "README"
    "Change Log Files"  "bin"   "CHANGELOG"
    "Change Log Files"  "bin"   "CHANGELOG.md"
    "License Files"     "bin"   "LICENSE"
    "License Files"     "bin"   "LICENSE_EXAMPLES.txt"
    "License Files"     "bin"   "LICENSE_PhysioNet.txt"

    # --- DevOps, Container & Build-Systeme ---
    "Docker Files"      "txt"   "Docker"
    "Docker Files"      "txt"   "Dockerfile"
    "Docker Files"      "txt"   "Compose"
    "Docker Files"      "txt"   "docker-compose.yml"
    "Docker Files"      "txt"   "compose.yml"
    "Make Files"        "txt"   "Makefile"
    "Make Files"        "txt"   "CMakeLists.txt"

    # --- Versionskontrolle & Entwicklungsumgebung ---
    "Git Config"        "txt"   ".gitignore"
    "VS Code Config"    "txt"   "launch.json"
    "VS Code Config"    "txt"   "tasks.json"
    "VS Code Config"    "txt"   "settings.json"

    # --- Apple / Swift Ökosystem ---
    "Swift Package"     "bin"   "Package.swift"
    "Swift Package"     "bin"   "Package.resolved"

    # --- Security & Schlüssel (SSH/SSL) ---
    "SSL Keys"          "bin"   "host01_userX"
    "SSL Keys"          "bin"   "host01_userY"
    "SSL Keys"          "bin"   "host02_userU"

    # --- Shell & Systemkonfiguration ---
    "Z-Shell"           "txt"   ".zshrc"

    # --- Fotografie & Bildbearbeitung ---
    "Darktable"         "txt"   "Canon.dtstyle"
    "Darktable"         "txt"   "tweaks.css"
)

# ------------------------------------------
# Definition über exakte Teilpfade
# ------------------------------------------
path_defs=(
    # --- Skripte & Shells ---
    "Z-Shell"           "txt"   "mathdefs/.math_decl"
    "Z-Shell"           "txt"   "mathdefs/.zfunc_colors"
    "Z-Shell"           "txt"   "mathdefs/.zfunc_symbols"
)

# ------------------------------------------
# Technologie-Definitionen: "Technologie" "Typ(txt/bin)" ".endung"
# ------------------------------------------
tech_defs=(
    # --- Skripte & Shells ---
    "Shell"             "txt"   ".sh"
    "Z-Shell"           "txt"   ".zsh"
    "Expect"            "txt"   ".expect"

    # --- Python & Machine Learning ---
    "Python"            "txt"   ".py"
    "Python"            "txt"   ".PY"
    "Python"            "bin"   ".pyc"
    "PyTorch Model"     "bin"   ".pt"

    # --- C-Familie (System & Low-Level) ---
    "C"                 "txt"   ".c"
    "C"                 "txt"   ".h"
    "C"                 "bin"   ".o"
    "C++"               "txt"   ".cpp"
    "C++"               "txt"   ".hpp"

    # --- Apple / macOS / iOS Ökosystem ---
    "ObjC"              "txt"   ".m"
    "ObjC++"            "txt"   ".mm"
    "Swift"             "txt"   ".swift"
    "Xcode Config"      "txt"   ".xcconfig"
    "Xcode Workspace"   "bin"   ".xcworkspacedata"
    "Xcode CoreData"    "bin"   ".xcscheme"
    "Xcode Project"     "bin"   ".pbxproj"
    "Xcode Storyboard"  "bin"   ".xib"

    # --- Microsoft / .NET Ökosystem ---
    "C#"                "txt"   ".cs"
    ".Net C# Project"   "bin"   ".csproj"
    "VS Solution"       "bin"   ".sln"

    # --- Webtechnologien ---
    "Html"              "txt"   ".html"
    "Html"              "txt"   ".htm"
    "Css"               "txt"   ".css"
    "JS"                "txt"   ".js"
    "Vue"               "txt"   ".vue"

    # --- Datenstrukturen, Markup & XML ---
    "Json"              "txt"   ".json"
    "Json"              "txt"   ".plist"
    "Xml"               "txt"   ".xml"
    "Xslt"              "txt"   ".xsl"
    "Xslt"              "txt"   ".xslt"
    "Xsd"               "txt"   ".xsd"
    "Xquery"            "txt"   ".xqy"
    "Autosar"           "bin"   ".arxml"

    # --- Datenbanken & Tabellarische Daten ---
    "Sql"               "txt"   ".sql"
    "SQLite Data Files" "bin"   ".sqlite"
    "CSV"               "bin"   ".csv"

    # --- Medien & visuelle Assets ---
    "Images"            "bin"   ".jpg"
    "Images"            "bin"   ".png"
    "Images"            "bin"   ".webp"
    "Images"            "bin"   ".svg"
    "Images"            "bin"   ".ico"
    "Clips"             "bin"   ".mp4"
    "Clips"             "bin"   ".m4v"
    "Fonts"             "bin"   ".ttf"

    # --- Allgemeine Dokumente & Sonstiges ---
    "Text"              "txt"   ".txt"
    "Patch"             "txt"   ".patch"
    "PDF Files"         "bin"   ".pdf"

    # --- Security & Schlüssel (SSH/SSL) ---
    "SSL Keys"          "bin"   ".pub"
)

# ==========================================
# 2. Datenstrukturen initialisieren
# ==========================================

typeset -A ext_to_tech
typeset -A ext_to_type
typeset -A name_to_tech
typeset -A name_to_type

typeset -A path_to_tech
typeset -A path_to_type

# Pfad-Array umwandeln
for (( i=1; i<=$#path_defs; i+=3 )); do
    tech="${path_defs[$i]}"
    type="${path_defs[$i+1]}"
    path="${path_defs[$i+2]}"
    path_to_tech[$path]="$tech"
    path_to_type[$path]="$type"
done

# Endungs-Array umwandeln
for (( i=1; i<=$#tech_defs; i+=3 )); do
    tech="${tech_defs[$i]}"
    type="${tech_defs[$i+1]}"
    ext="${tech_defs[$i+2]}"
    ext_to_tech[$ext]="$tech"
    ext_to_type[$ext]="$type"
done

# Namens-Array umwandeln
for (( i=1; i<=$#name_defs; i+=3 )); do
    tech="${name_defs[$i]}"
    type="${name_defs[$i+1]}"
    name="${name_defs[$i+2]}"
    name_to_tech[$name]="$tech"
    name_to_type[$name]="$type"
done

# Zähler für die Statistiken
typeset -A tech_files
typeset -A tech_lines
integer total_files=0
integer total_lines=0

# ==========================================
# 3. Dateien scannen
# ==========================================

for repo in "${repos[@]}"; do
    repo_dir="${base_dir}/${repo}"
    
    if [[ ! -d "$repo_dir" ]]; then
        echo "Warnung: Verzeichnis $repo_dir nicht gefunden." >&2
        continue
    fi

    # Das 'D' (Dotglob) in (.ND) sorgt dafür, dass versteckte Dateien/Ordner gefunden werden.
    for file in "$repo_dir"/**/*(.ND); do
        
        # Verzeichnis-Blacklist prüfen
        local skip=0
        for dir in "${ignore_dirs[@]}"; do
            # Prüfen, ob der Datei-Pfad durch ein ignoriertes Verzeichnis verläuft
            if [[ "$file" == *(/|)$dir(/*|) ]]; then
                skip=1
                break
            fi
        done
        
        # Wenn skip auf 1 gesetzt wurde, springe direkt zur nächsten Datei
        (( skip )) && continue
        
        filename="${file:t}" # Nur den Dateinamen extrahieren
        
        local tech=""
        local type=""

        # 0. Prio: Ist ein exakter Pfad definiert?
        for p in ${(k)path_to_tech}; do
            # Zsh-Match: Endet der aktuelle Dateipfad auf definierten Pfad?
            if [[ "$file" == *"/$p" ]]; then
                tech="${path_to_tech[$p]}"
                type="${path_to_type[$p]}"
                break
            fi
        done

        # 1. Prio: Ist der exakte Dateiname definiert?
        if [[ -z "$tech" && -n "${name_to_tech[$filename]}" ]]; then
            tech="${name_to_tech[$filename]}"
            type="${name_to_type[$filename]}"
        fi

        # 2. Prio: Fallback auf Endungs-Prüfung
        if [[ -z "$tech" ]]; then
            ext="${file:e}"
            [[ -n "$ext" ]] && ext=".$ext"
            
            tech="${ext_to_tech[$ext]}"
            type="${ext_to_type[$ext]}"
        fi

        # Wenn eine Zuordnung gefunden wurde
        if [[ -n "$tech" ]]; then
            
            # Blacklist-Check: Wenn der Dateiname in ignore_lines ist, als 'bin' behandeln
            if (( ${ignore_lines[(I)$filename]} )); then
                type="bin"
            fi
            
            (( tech_files[$tech]++ ))
            (( total_files++ ))

            # Nur verarbeiten, wenn es als Textdatei gelesen werden soll
            if [[ "$type" == "txt" ]]; then
                
                content="$(<"$file")"
                nl_only="${content//[^$'\n']/}"
                lines=${#nl_only}
                
                [[ -n "$content" && "$content" != *$'\n' ]] && (( lines++ ))
                
                (( tech_lines[$tech] += lines ))
                (( total_lines += lines ))
            fi
        fi
    done
done


strftime -s aktueller_zeitstempel "Status: %d.%m.%Y %H:%M:%S" $EPOCHSECONDS
print ""
print $aktueller_zeitstempel
print ""
print "**# Repos**: ${#repos[@]} ($count_private private, $count_public public)"
print ""
print "**# Files**: $total_files"
print ""

# ==========================================
# 4. Markdown Tabelle generieren
# ==========================================

# Alle eindeutigen Technologien aus ALLEN Hash-Maps sammeln
typeset -aU technologies
technologies=(${(v)ext_to_tech} ${(v)name_to_tech} ${(v)path_to_tech})

# ==========================================
# 5. Daten in parallelen Arrays sammeln
# ==========================================

typeset -a left_tech left_files left_lines
typeset -a right_tech right_files right_lines

for tech in "${technologies[@]}"; do
    if [[ -n "${tech_files[$tech]}" ]]; then
        
        f_count=${tech_files[$tech]:-0}
        l_count=${tech_lines[$tech]:-0}
        
        typeset -F 2 f_percent=0.00
        typeset -F 2 l_percent=0.00
        
        (( total_files > 0 )) && (( f_percent = 100.0 * f_count / total_files ))
        (( total_lines > 0 )) && (( l_percent = 100.0 * l_count / total_lines ))

        # Oben/Links: Mit Zeilen Statistik
        if (( l_count > 0 )); then
            left_tech+=("$tech")
            left_files+=("**$f_count**")
            left_lines+=("**$l_count**")
        # Unten/Rechts: Ohne Zeilen Statistik
        else
            right_tech+=("$tech")
            right_files+=("**$f_count**")
            right_lines+=("")
        fi
    fi
done

# ==========================================
# 6. Maximale Zeilenanzahl ermitteln
# ==========================================

integer max_rows=${#left_tech[@]}
(( ${#right_tech[@]} > max_rows )) && max_rows=${#right_tech[@]}

# ==========================================
# 7. Tabellen-Header ausgeben
# ==========================================

print "<details>"
print "  <summary>Details</summary>"
print ""
print "| Type | Files | Lines | &nbsp;&nbsp;&nbsp;&nbsp;&nbsp; | Type | Files|"
print "|---|---|---|---|---|---|"

# ==========================================
# 8. Zeilen nebeneinander ausgeben
# ==========================================

for (( i=1; i<=max_rows; i++ )); do
    # Zsh Expansion ${array[i]:-} gibt einen leeren String zurück, 
    # falls der Index i nicht existiert (z.B. wenn eine Seite kürzer ist)
    
    printf "| %-21s | %-12s | %-22s | %s | %-21s | %-12s |\n" \
        "${left_tech[i]:-}" \
        "${left_files[i]:-}" \
        "${left_lines[i]:-}" \
        "" \
        "${right_tech[i]:-}" \
        "${right_files[i]:-}"
done
print ""
print "> **Statistics generated with:**"
print "> 1. Run \`gh_clone_all_repos_not_forked\` from [\`.zshrc\`](./zsh/.zshrc)"
print "> 2. Run [\`repo_statistic.zsh\`](./zsh/repo_statistic.zsh)"
print ">"
print ""
print "</details>"