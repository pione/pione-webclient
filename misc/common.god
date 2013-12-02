# -*- ruby -*-

DIR = File.join(File.dirname(__FILE__), "..")

# Watch `pione-webclient` command.
#
# @param env_name [Symbol]
#   running environment name, e.g. `:production`, `:development`.
def watch_pione_webclient(additional_options="")
  God.watch do |w|
    w.name = "pione-webclient"
    w.start = "ruby -I lib bin/pione-webclient %s" % additional_options
    w.log = File.join(DIR, "pione-webclient-god.log")
    w.dir = DIR
    w.keepalive
  end
end
