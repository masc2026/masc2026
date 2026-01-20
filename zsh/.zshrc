gh_clone_all_repos_not_forked () {
	local target_dir="${1:-$HOME/Projekte/clean_gitrepos}" 
	mkdir -p "$target_dir"
	cd "$target_dir" || {
		echo "❌ Fehler: Verzeichnis $target_dir konnte nicht betreten werden."
		return 1
	}
	echo "Lade Liste der eigenen (nicht geforkten) Repositories..."
	local repos=($(gh repo list --limit 1000 --json nameWithOwner,isFork --jq '.[] | select(.isFork == false) | .nameWithOwner')) 
	if [[ ${#repos[@]} -eq 0 ]]
	then
		echo "Keine passenden Repositories gefunden."
		cd - > /dev/null
		return
	fi
	echo "Klone ${#repos[@]} Repositories nach $target_dir..."
	for repo in "${repos[@]}"
	do
		local repo_name="${repo#*/}" 
		if [[ -d "$repo_name" ]]
		then
			echo "⏭️  Überspringe: $repo_name (Verzeichnis existiert bereits)"
		else
			echo "⬇️  Klone: $repo"
			gh repo clone "$repo"
		fi
	done
	echo "✅ Alle eigenen Repositories wurden synchronisiert!"
	cd - > /dev/null
}
