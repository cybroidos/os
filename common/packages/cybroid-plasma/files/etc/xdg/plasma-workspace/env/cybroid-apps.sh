# CybroidOS: apps' plain names (Files, Terminal...) come first. See
# /usr/libexec/cybroid/app-names.
case ":${XDG_DATA_DIRS}:" in
*:/usr/share/cybroid/apps:*) ;;
*) export XDG_DATA_DIRS="/usr/share/cybroid/apps:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;;
esac
