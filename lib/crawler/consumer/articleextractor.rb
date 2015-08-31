class ArticleExtractor
	attr_reader :title,:keywords,:description,:date,:text,
		:linkdensity
	def initialize(page,once=false)
		@page=page.encode('utf-8')
		@blockwidth=3
		@threshold=83
		@extractonce=once
		@text=[]
		#when linkdensity > 0.7 maybe it is a navigate website
		#we can multipate with the deeping of url path to get a more pricise data
		@linkdensity=0.0
	end

	def preprocess
		@title=@keywords=@description=@date=""
		#extract title
		@title=$1 if @page =~ /<title>(.*)<\/title>/mi  #get title

		#match keywords 
		#<meta name="keyword" content=/>
		@keywords=$1 if @page =~ /<meta\s+name="keywords"\s+content="?(.*?)["|\/]>/mi
		@keywords=$1 if @page =~ /<meta\s+content="?(.*?)"?\s+name="keywords"\/?>/mi
		
		#match description
		@description=$1 if @page =~ /<meta\s+content="?(.*?)"?\s+name="description"\/?>/mi
		@description=$1 if @page =~ /<meta\s+name="description"\s+content="?(.*?)["|\/]>/mi

		#match date time
		#for chinese date
		@date=$& if @page =~ /\d{4}年\d{1,2}月\d{1,2}日(\s*\d{1,2}.\d{1,2})?/u
		@date=$& if @page =~ /\d{4}([:\/-])\d{1,2}\1\d{1,2}(\s*\d{1,2}.\d{1,2})?/

		@page.gsub!(/<!--.*?-->/,"")								 #remove html comment
		@page.gsub!(/<script.*?>.*?<\/script>/mi,"") #remove script
		@page.gsub!(/<style.*?>.*?<\/style>/mi,"")   #remove css
		@page.gsub!(/&.+?;/i,"")                     #remove special char
		@page.gsub!(/<\/?br>/i,"\n")
		@orgpage=@page.clone

		#remove all non link tag
		@orgpage.gsub!(/<([^a\/].*?|\/[^a].*?)>/im,'')
		@page.gsub!(/<.*?>/m,"")

		@lines=@page.split("\n")
		@orglines=@orgpage.split("\n")

		@linenum=Array.new(@lines.size){0}
		@linkscale=Array.new(@lines.size){0.0}

		0.upto(@lines.size-@blockwidth) do |i|
			wordsum=0
			linkwordsum=0.0
			i.upto(i+@blockwidth-1) do |j|
				wordsum+=@lines[j].gsub(/\s+/,'').size
				@orglines[j].scan(/<a.*?>(.*?)<\/a>/i) do |fetch|
					linkwordsum+=fetch.to_s.gsub(/\s+/,'').size
				end
			end
			@linenum[i]=wordsum
			factor=1
			factor=wordsum if wordsum > 0
			@linkscale[i]=linkwordsum/factor
		end

		#caculate links average percent
		#we can use this data to decide which page is a blog or article web
		@linkdensity=@linkscale.inject{|sum,i| sum + i} / @linkscale.size
	end

	def extract
		preprocess unless title
		#analyze 
		blockstart = blockend = -1
		started=ended=false

		@linenum.each_index do |i|
			#puts "##{i} #{@linenum[i]} #{@linkscale[i]} #{@lines[i]}"
			if @linenum[i] > @threshold and @linkscale[i] < 0.6 and not started
				if (@linenum[i+1] and @linenum[i+1]!=0) or (@linenum[i+2] and @linenum[i+2]!=0) or (@linenum[i+3] and @linenum[i+3]!=0)
					started=true
					blockstart=i
					#puts "start"
				end
			end

			if started
				if (@linenum[i]<@threshold and  @linkscale[i]>1) or 
						@linenum[i]==0 or @linenum[i+1] == 0
					ended=true
					#puts "end"
					blockend=i
				end
			end

			if ended
				blockstart.upto(blockend) do |line|
					@text<<@lines[line] if @lines[line].size > 0
				end
				#@text+=@lines[blockstart..blockend]
				started=ended=false
				if @extractonce
					break
				end
			end
		end

		@text.join("\n")
	end
end

=begin
require 'mechanize'
a=Mechanize.new
#p=a.get('http://667vv.com/AAwz/348bd749ca9ee5f03b04b8a2f0befc79.html')
p=a.get(ARGV[0],false)
e=ArticleExtractor.new(p.parser.to_s)
puts e.extract
p e.date
p e.keywords
p e.title
p e.description
p e.linkdensity
=end
