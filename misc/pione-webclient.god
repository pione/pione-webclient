# ~*~ ruby ~*~

DIR = File.join(File.dirname(__FILE__), "..")

God.watch do |w|
  w.name = "pione-webclient"
  w.start = "bundle exec pione-webclient"
  w.log = File.join(DIR, "pione-webclient.god")
  w.dir = DIR
  w.keepalive
end

