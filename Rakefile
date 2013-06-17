desc 'Test specs'
task 'test' do
  sh "bundle exec bacon -r simplecov -a"
end

desc 'Generate API document'
task 'html' do
  sh "bundle exec yard doc -o html --hide-void-return --no-api"
end

desc 'Show undocumented function list'
task 'html:undoc' do
  sh "bundle exec yard stats --list-undoc --no-api --compact"
end

desc "Download javascript libraries"
task "download:js" do
  cd "public" do
    sh "curl http://code.jquery.com/jquery-1.10.1.js > js/jquery-1.10.1.js"
    sh "curl http://underscorejs.org/underscore.js > js/underscore.js"
    sh "curl http://backbonejs.org/backbone.js > js/backbone.js"
    sh "curl http://twitter.github.io/bootstrap/assets/bootstrap.zip > bootstrap.zip"
    sh "unzip -o bootstrap.zip"
    sh "rm bootstrap.zip"
    sh "cp -R bootstrap/js ."
    sh "cp -R bootstrap/css ."
    sh "cp -R bootstrap/img ."
    sh "rm -rf bootstrap"
    sh "curl http://d3js.org/d3.v3.zip > d3.v3.zip"
    sh "unzip -o d3.v3.zip d3.v3.js"
    sh "mv d3.v3.js js/d3.v3.js"
    sh "rm d3.v3.zip"
  end
end

task :default => :test
