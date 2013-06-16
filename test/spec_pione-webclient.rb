require 'pione/webclient'
require 'rack/test'

include Rack::Test::Methods

def app
  Pione::WebClient
end

describe "Pione::WebClient" do
  it "shold get index" do
    get '/'
    last_response.should.ok
    last_response.body.size.should > 0
  end
end

