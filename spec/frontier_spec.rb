require 'redis'
describe Frontier do
	before(:all) do
		@frontier=Frontier.new('frontier')
		@frontier.unvisits_clear!
		@url1=URI("http://www.baidu.com")
		@url2=URI("http://667vv.com/AAwz/4fedf8bebdf009aa7365fbbb8d71df4e.html")
		
		@frontier.push(@url1)
		@frontier.push(@url2)
	end
	it "get unvisited link" do
		@vurl1=@frontier.shift
		@vurl2=@frontier.shift
		url1=URI("http://www.url.com")
		url2=URI("http://3g.qq.com")

		url1.host=@frontier.domains.get('www.url.com')
		url2.host=@frontier.domains.get('3g.qq.com')
		expect(@vurl1).to eq(@url1)
		expect(@vurl2).to eq(@url2)
		expect(@frontier.empty?).to be true
		@frontier.visited(@vurl1)
		@frontier.visited(@vurl2)
	end

	it "is visited?" do
		expect(@frontier.visited?(@url1)).to be true
		expect(@frontier.visited?(@url2)).to be true
		expect(@frontier.visited?("http://www.fuck.com")).to be false
	end

	it "test invaild url" do
		expect(@frontier.push("asdcsdfasdfad")).to be false
	end
end

#test Domains class
describe Domains do
	before(:all) do
		@domains=Domains.new(Redis.new)
	end
	it "test push" do
		@domains["www.baidu.com"]='180.97.33.107'
		@domains["www.yeebing.com"]='123.78.12.1'
		@domains["www.yeeshit.com"]='192.168.1.19'
	end

	it "test exists" do
		expect(@domains.include?("www.baidu.com")).to be true
		expect(@domains.include?("www.yeebing.com")).to be true
		expect(@domains.include?("www.ivy.com")).to be false
	end
	it "test get" do
		expect(@domains["www.baidu.com"]).to eq("180.97.33.107")
	end
	it "test del" do
		@domains.delete!("www.baidu.com")
		expect(@domains.get("www.baidu.com")).to eq(nil)
		expect(@domains.include?("www.baidu.com")).to be false
	end
	it "test if the net is up" do
		expect(Domains.up?("www.baidu.com")).to be true
		expect(Domains.up?("180.97.33.108")).to be true
	end

	it "test 'each' and delete teh invaild key" do

	end
end

