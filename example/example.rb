require 'crawler'

Crawler.new do |crawler|
	crawler.start_urls=['http://667vv.com','http://667vv.com/AAtb/zipai/']
	crawler.filters={
		allow:{
			#'host'=>{
			#'/path'=>'query'
			#}
			'http://667vv.com'=>{
				#allow 'http://677vv.com' and 'http://677vv.com/'
				'/'=>nil,
				#allow 'http://677vv.com/AAtb/zipai[/*]'
				'/AAtb/zipai'=>nil,
				#allow 'http://677vv.com/AAwz[/*]'
				'/AAwz'=>nil
			}
		},
		deny:{
		}
	}
	crawler.thread_limit=1
	crawler.delay=0
	crawler.dbname=1
	crawler.encoding=nil
	crawler.consumer_wait_queue_limit=100


	#when the crawler is down send a mail to administrator
	crawler.enable_email=false
	#the administrator's email address
	crawler.email='carney520@hotmail.com'
	crawler.from='920432773@qq.com'  #the email-address which same as the authentic user
	crawler.address='smtp.qq.com'
	crawler.port=25
	crawler.username='920432773'
	crawler.password='***'
	crawler.enable_starttls_auto=true

	consumer=crawler.consumer
	consumer.thread_limit=1
	consumer.delay=0
	save_dir='/home/pi/share/toupai'
	consumer.task={
		#global consumer
		'.'=>nil,
		#host name
		'667vv.com'=>{
			#path
			'/AAwz'=>proc do |page|
=begin 
				#article extrator
				saver=Consumer::FileSaver.new('/home/pi/share')
				Consumer::Article.new(page).saveto(saver).consume
=end
				save_formatter = proc do |uri,title,filename,extname,index|
				#uri  : the page uri
				#title: the page title
				#filename: the source native filename.note that it included extname 
				#					such as 'asdacada123asdad.jpg'
				#extname: the resource extname
				#index  : a uniq index
				#we should return a string and ensure the string a legal for file save
				#by default it return a string like "#{title[0..15]}/filename"
					File.join("#{Time.now.strftime("%Y%m%d")}","#{title[0..15]}","#{index.to_s+extname}")
				end

				#images download
				imagedownload=Consumer::Images.new(page).saveto(save_dir).select(/^\/uploads/).enable_thumbnail
				imagedownload.formatter=save_formatter
				imagedownload.consume
			end
		}
	}
end.start

