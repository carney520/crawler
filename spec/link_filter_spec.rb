require './frontier'
describe LinkFilter do
	it "test allow" do
		allow={
			"http://667vv.com"=>{
				"/aww"=>nil
			},
			"ads.asca"=>nil
		}
		expect{LinkFilter.new(allow,nil)}.to raise_error(HostFormatError)
	end

	it "test result" do
		allow={
			"http://667vv.com"=>{
				"/aww"=>nil,
				"sdaad"=>"ad "
			},
			"http://www.baidu.com"=>nil
		}
		deny={
			"http://google.com"=>{
				"adsa"=>'dasa'
			},
			"http://deny.ruby"=>nil
		}
		links= LinkFilter.new(allow,deny)
		p links.allows
		p links.denies
	end

	it "check allow?" do
		allow={
			"http://google.com"=>{
				"/"=>nil,
				"/a"=>nil,
				"/b/a"=>'a=c'
			}
		}
		deny={
			"http://baidu.com"=>{
				"c"=>nil
			}
		}
		filter=LinkFilter.new(allow,deny)
		p filter.allows
		p filter.denies
		frontier=Frontier.new(1)
		frontier.filter_compile(filter)
		expect(frontier.allow?(Frontier.uri_compile('http://google.com/'))).to be true
		expect(frontier.allow?(Frontier.uri_compile('http://google.com'))).to be true
		expect(frontier.allow?(Frontier.uri_compile('http://google.com/a'))).to be true
		expect(frontier.allow?(Frontier.uri_compile('http://google.com/ab'))).to be false
		expect(frontier.allow?(Frontier.uri_compile('http://google.com/b/a?a=c'))).to be true
		expect(frontier.allow?(Frontier.uri_compile('http://google.com/b/a/?a=c'))).to be true
		expect(frontier.allow?(Frontier.uri_compile('http://google.com/b/a/a/?a=c'))).to be true

		expect(frontier.deny?(Frontier.uri_compile('http://baidu.com/c/a/?a=c'))).to be true
		expect(frontier.deny?(Frontier.uri_compile('http://baidu.com/'))).to be false
	end
end
