require "pione/webclient"

Pione::System::Global.webclient_root = Pione::Location[File.dirname(__FILE__)]

describe "Pione::WebClient::ProcessingType" do
  before do
    @type = Pione::WebClient::ProcessingType.new("Test", Location["/path/to/package"])
  end

  it "should get the name" do
    @type.name.should == "Test"
  end

  it "should get the location" do
    @type.location.should == Location["/path/to/package"]
  end

  it "should get processing types" do
    types = Pione::WebClient::ProcessingType.read
    types.each do |type|
      type.should.kind_of(Pione::WebClient::ProcessingType)
    end
  end
end
