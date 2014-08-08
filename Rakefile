require 'structx'

class LibInfo < StructX
  PUBLIC_LIB_DIR = Pathname.new(File.dirname(__FILE__)) + "public" + "lib"

  member :type
  member :url
  member :name

  def path
    case type
    when :js
      PUBLIC_LIB_DIR + "js" + name
    when :css
      PUBLIC_LIB_DIR + "css" + name
    when :font
      PUBLIC_LIB_DIR + "fonts" + name
    end
  end
end

class LibItem
  def initialize(context, &b)
    @info = LibInfo.new
    @context = context

    # eval the block with a library information object
    b.call(@info)

    # make a rake's task
    context.send(:file, @info.path) do
      install
      context.send(:sh, "echo 'downloaded #{@info.path} from #{@info.url} at' `date -R` >> lib-installer.log")
    end
  end

  def install
    download(@info.url, path)
  end

  def path
    @info.path
  end

  def download(url, path)
    @context.instance_eval do
      sh "curl -L #{url} > #{path}"
    end
  end
end

class LibInstaller
  def self.define(context, &b)
    new(context, &b)
  end

  def initialize(context, &b)
    @list = []
    @context = context
    b.call(self)
  end

  def add(&b)
    @list << LibItem.new(@context, &b)
  end

  def list
    @list.map {|item| item.path}
  end
end

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

desc "Setup lib directory"
task "setup:lib" do
  mkpath "public/lib/js"
  mkpath "public/lib/css"
  mkpath "public/lib/fonts"
end

libs = LibInstaller.define(self) do |installer|
  # jquery
  installer.add do |lib|
    lib.type = :js
    lib.url  = "http://code.jquery.com/jquery-1.11.1.min.js"
    lib.name = "jquery.js"
  end

  # undersocre
  installer.add do |lib|
    lib.type = :js
    lib.url  = "https://github.com/jashkenas/underscore/raw/1.5.2/underscore-min.js"
    lib.name = "underscore.js"
  end

  # d3
  installer.add do |lib|
    lib.type = :js
    lib.url = "https://github.com/mbostock/d3/raw/v3.3.10/d3.min.js"
    lib.name = "d3.js"
  end

  # bootstrap
  installer.add do |lib|
    lib.type = :js
    lib.url = "https://raw.github.com/twbs/bootstrap/v3.0.2/dist/js/bootstrap.min.js"
    lib.name = "bootstrap.js"
  end
  installer.add do |lib|
    lib.type = :css
    lib.url  = "https://raw.github.com/twbs/bootstrap/v3.0.2/dist/css/bootstrap.min.css"
    lib.name = "bootstrap.css"
  end
  installer.add do |lib|
    lib.type = :css
    lib.url  = "https://raw.github.com/twbs/bootstrap/v3.0.2/dist/css/bootstrap-theme.min.css"
    lib.name = "bootstrap-theme.css"
  end
  installer.add do |lib|
    lib.type = :font
    lib.url  = "https://github.com/twbs/bootstrap/raw/v3.0.2/dist/fonts/glyphicons-halflings-regular.eot"
    lib.name = "glyphicons-halflings-regular.eot"
  end
  installer.add do |lib|
    lib.type = :font
    lib.url  = "https://github.com/twbs/bootstrap/raw/v3.0.2/dist/fonts/glyphicons-halflings-regular.eot"
    lib.name = "glyphicons-halflings-regular.eot"
  end
  installer.add do |lib|
    lib.type = :font
    lib.url  = "https://github.com/twbs/bootstrap/raw/v3.0.2/dist/fonts/glyphicons-halflings-regular.svg"
    lib.name = "glyphicons-halflings-regular.svg"
  end
  installer.add do |lib|
    lib.type = :font
    lib.url  = "https://github.com/twbs/bootstrap/raw/v3.0.2/dist/fonts/glyphicons-halflings-regular.ttf"
    lib.name = "glyphicons-halflings-regular.ttf"
  end
  installer.add do |lib|
    lib.type = :font
    lib.url  = "https://github.com/twbs/bootstrap/raw/v3.0.2/dist/fonts/glyphicons-halflings-regular.woff"
    lib.name = "glyphicons-halflings-regular.woff"
  end

  # CryptJS
  installer.add do |lib|
    lib.type = :js
    lib.url = "http://crypto-js.googlecode.com/svn/tags/3.1.2/build/rollups/sha512.js"
    lib.name = "sha512.js"
  end
end

desc "Download javascript libraries"
task "download:lib" => libs.list

desc "Clean library directory"
task "clean:lib" do
  sh "rm -rf public/lib/*"
end

#
# main tasks
#

desc "Setup PIONE webclient"
task "setup" => ["setup:lib", "download:lib"]

desc "Clean non-persistent files"
task "clean" => ["clean:lib"]

task :default => :test
