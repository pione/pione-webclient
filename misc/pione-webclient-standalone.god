# -*- ruby -*-

load File.join(File.dirname(__FILE__), "common.god")

# start `pione-webclient` with production mode
watch_pione_webclient("-e production --stand-alone")
