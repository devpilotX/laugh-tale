# host.env.example.ps1 - template. Copy to host.env.ps1 and fill in.
#
# host.env.ps1 is git-ignored. Acceptance row 2 requires that a grep for IP
# addresses and absolute host paths across the repository returns nothing, and
# spec 5.1 requires the stack rebuild anywhere without editing code. Connection
# details are therefore configuration, never source.
#
# Copy:  Copy-Item scripts\host.env.example.ps1 scripts\host.env.ps1
# Then edit the copy.

# Path to the SSH private key. Never commit the key itself (.gitignore blocks *.pem).
$LT_SSH_KEY  = '<absolute path to your .pem file>'

# user@host for the VPS.
$LT_SSH_DEST = '<user>@<host-or-ip>'

# The Pelican server volume UUID to inspect, or '' to auto-detect the only one.
$LT_VOLUME   = ''
