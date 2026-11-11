# CIT-OS: apps' plain names (Files, Terminal...) come first. See
# /usr/libexec/citos/app-names.
case ":${XDG_DATA_DIRS}:" in
*:/usr/share/citos/apps:*) ;;
*) export XDG_DATA_DIRS="/usr/share/citos/apps:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ;;
esac
