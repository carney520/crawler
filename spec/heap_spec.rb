require './heap'
describe Heap do
	before(:all) do
		@heap=Heap.new
	end
	it "push" do
		@heap<< 9
		@heap<< 7
		@heap<< 19
		@heap<< 18
		@heap<< 4
		@heap<< 8
		@heap<< 1
		@heap<< 56
		@heap<< 27
		@heap<< 9
	end
	it "pop" do
		expect(@heap.pop).to eq(56)
		expect(@heap.pop).to eq(27)
		expect(@heap.pop).to eq(19)
		expect(@heap.pop).to eq(18)
		expect(@heap.pop).to eq(9)
		expect(@heap.pop).to eq(9)
		expect(@heap.pop).to eq(8)
		expect(@heap.pop).to eq(7)
		expect(@heap.pop).to eq(4)
		expect(@heap.pop).to eq(1)
		expect(@heap.pop).to eq(nil)
		expect(@heap.empty?).to be true
		expect(@heap.size).to eq(0)
		expect(@heap.first).to eq(nil)
	end
	it "decs" do
		heap=Heap.new{|l,r| r<=>l}
		heap<<9
		heap<<0
		heap<<1
		expect(heap.pop).to eq(0)
		expect(heap.pop).to eq(1)
		expect(heap.pop).to eq(9)
	end

	it "take" do
		heap=Heap.new{|l,r| r<=>l}
		heap<<9
		heap<<0
		heap<<1
		expect(heap.take(4)).to eq([0,1,9])
	end
end
