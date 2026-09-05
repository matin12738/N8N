# =============================================================================
# Custom n8n Image
# -----------------------------------------------------------------------------
# Base          : official n8nio/n8n (already non-root, hardened)
# Extra layer   : inject a safe URL-parser script that runs before the
#                 official entrypoint continues.
#
# Security layers:
#   1. Build as root only for the COPY + chmod, then drop back to node
#   2. Script is owned by node:node and not world-writable
#   3. Official ENTRYPOINT is left untouched (defence in depth)
# =============================================================================

FROM n8nio/n8n:latest

# Temporary root only for file installation
USER root

# Place the script in the official docker-entrypoint.d directory.
# Scripts are executed in alphabetical order; 99- guarantees it runs last.
COPY start.sh /docker-entrypoint.d/99-custom-env-parser.sh

# Make executable + lock ownership to the non-root user that will run the process
RUN chmod 0755 /docker-entrypoint.d/99-custom-env-parser.sh \
    && chown node:node /docker-entrypoint.d/99-custom-env-parser.sh

# Drop privileges permanently
USER node

# Document the port (does not publish it)
EXPOSE 5678

# Do NOT override ENTRYPOINT or CMD.
# The official image will:
#   1. run every script under /docker-entrypoint.d/
#   2. then start the real n8n process