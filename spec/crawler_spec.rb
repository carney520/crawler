#coding: utf-8

#test visited queue
describe VisitedQueue do

	before(:all) do
		@queue=VisitedQueue.new
	end

	it "push link" do
		@queue.push("http://www.baidu.com")
		expect(@queue.has_key?("http://www.baidu.com")).to be true
	end

	it "test if include link?" do
		expect(@queue.include?("http://www.baidu.com")).to be true
		expect(@queue.include?("http://g.com")).to be false
	end
end


#test uri filter
describe Filter do
	before(:all) do
		@filter=Filter.new
		@filter.add("http://www.baidu.com",["/s","/ulize","a/b/c"])
		@filter.add("http://www.ivy.com",["ivy","ui/iu"])
	end
	it "test host format and path format" do
		expect{@filter.add("www.baidu.com")}.to raise_error(HostFormatError)
	end

	it "test if allow nil" do
		expect(@filter.allow?(nil)).to be false
	end

	it  "test if allow other host" do
		expect(@filter.allow?("http://www.google.com")).to be false
		expect(@filter.allow?("http://www.baidu.com")).to be true
	end

	it "test path allow" do
		expect(@filter.allow?("http://www.baidu.com/")).to be true
		expect(@filter.allow?("http://www.baidu.com/s")).to be true
		expect(@filter.allow?("http://www.baidu.com/s/uy")).to be true
		expect(@filter.allow?("http://www.baidu.com/sjk")).to be false
		expect(@filter.allow?("http://www.baidu.com/ulize")).to be true
		expect(@filter.allow?("http://www.baidu.com/a")).to be false
		expect(@filter.allow?("http://www.baidu.com/a/b/c")).to be true
	end
	it "test multi allow" do
		expect(@filter.allow?("http://www.ivy.com")).to be true
		expect(@filter.allow?("http://www.ivy.com/ivy")).to be true
		expect(@filter.allow?("http://www.ivy.com/ivyd")).to be false
		expect(@filter.allow?("http://www.ivy.com/ui/iu")).to be true
	end
end
