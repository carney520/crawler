require './waitting'
describe Waiting do
	it "test wait" do
		i=0
		wait=Waiting.new(3) do
			i = 0
		end
		wait.waiting
	end
end
