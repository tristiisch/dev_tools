#!/bin/sh

add_symlinks() {
	for file in ./scripts/*.sh; do
		filename=$(basename "$file")
        target="/bin/${filename%.sh}"
		sudo ln -s "$(realpath "$file")" "$target"
		sudo chmod +x "$target"
	done
}

remove_symlinks() {
	for file in ./scripts/*.sh; do
		filename=$(basename "$file")
        target="/bin/${filename%.sh}"
		sudo rm "$target"
	done
}

set_permissions() {
	for file in /bin/*.sh; do
		if [ -L "$file" ]; then
			chmod +x "$file"
		fi
	done
}

# Main script
case "$1" in
	add)
		add_symlinks
		;;
	remove)
		remove_symlinks
		;;
	set_permissions)
		set_permissions
		;;
	*)
		echo "Usage: $0 {add|remove|set_permissions}"
		exit 1
		;;
esac

exit 0
