require 'crawler'
app=Crawler.new do |crawler|
  logger STDOUT
  loglevel Logger::DEBUG

  proxy_list=[['59.127.154.78',80],['180.166.112.47',8888]]
  agent do |a|
    a.allow_robots
    #a.user_agent_alias='Mac Safari'
    #proxy pool
    proxy_list.each{
      |key| 
      a.add_proxy(key[0],key[1])
    }
    a.auto_switch_user_agent
    a.open_timeout=10
    a.read_timeout=10
  end

  start_urls ['http://667vv.com','http://667vv.com/AAtb/zipai/']

  filters allow:{
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

  thread_limit 1
  delay 0
  dbname 1
  encoding nil
  consumer_wait_queue_limit 100


  #when the crawler is down send a mail to administrator
  enable_email do
    #the administrator's email address
    to 'carney520@hotmail.com'
    from '920432773@qq.com'  #the email-address which same as the authentic user
    address 'smtp.qq.com'
    port 25
    username '920432773'
    password '**'
    enable_starttls_auto true
    enable_ssl false
  end

  consumer do |c|
    c.thread_limit=1
    c.delay=0
    save_dir='/home/pi/share/toupai'
    c.task={
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
            #          such as 'asdacada123asdad.jpg'
            #extname: the resource extname
            #index  : a uniq index
            #we should return a string and ensure the string a legal for file save
            #by default it return a string like "#{title[0..15]}/filename"
            #It will save as save_dir/20150820/pagetitle/0.jpg
            File.join("#{Time.now.strftime("%Y%m%d")}","#{title[0..15]}","#{index.to_s+extname}")
          end

          #images download
          #Image.new(page,thread_limit=2)
          imagedownload=Consumer::Images.new(page,3).saveto(save_dir).select(/^\/uploads/).enable_thumbnail
          imagedownload.formatter=save_formatter
          imagedownload.consume
        end
      }
    }
  end
end.start

#Warning it will clear the unvisits queue and visiteds queue
app.clear!
