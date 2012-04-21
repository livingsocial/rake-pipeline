describe "Rake::Pipeline::Graph" do
  Graph = Rake::Pipeline::Graph
  Node  = Rake::Pipeline::Graph::Node

  before do
    @graph = Graph.new
  end

  it "has nodes" do
    @graph.nodes.should == []
  end

  it "can add nodes" do
    @graph.add("foo")
    @graph["foo"].should == Node.new("foo")
  end

  it "can link nodes" do
    @graph.add("foo")
    @graph.add("bar")
    @graph.nodes.should == [Node.new("foo"), Node.new("bar")]
    @graph.link("foo", "bar")
    @graph["foo"].children.map(&:name).should == ["bar"]
    @graph["bar"].parents.map(&:name).should == ["foo"]
  end

  it "can unlink nodes" do
    @graph.add("foo")
    @graph.add("bar")
    @graph.link("foo", "bar")
    @graph.unlink("foo", "bar")
    @graph["foo"].children.should == Set[]
    @graph["bar"].parents.should == Set[]
  end

  it "can remove nodes" do
    @graph.add("foo")
    @graph.add("bar")
    @graph.nodes.should == [Node.new("foo"), Node.new("bar")]
    @graph.link("foo", "bar")
    @graph.remove("foo")
    @graph.nodes.should == [Node.new("bar")]
    @graph["bar"].children.should == Set[]
    @graph["bar"].parents.should == Set[]
  end

  it "can add metadata to nodes" do
    @graph.add("foo", :meta => 1)
    @graph.add("bar")
    @graph["bar"].metadata[:meta] = 2

    @graph["foo"].metadata.should == { :meta => 1 }
    @graph["bar"].metadata.should == { :meta => 2 }
  end
end

