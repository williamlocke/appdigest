require 'thor'

require 'rubygems'
require 'rails'
require 'appfigures'
require 'active_support/all'
require 'table_print'
require 'rails'
require 'action_view'
include ActionView::Helpers::NumberHelper

module Appdigest
  class CLI < Thor
    
    
		desc "search KEYWORDS_CSV", "Returns history (and totals) for in-app or apps whose names contain any of given keywords (keywords should be a csv e.g. 'character,patient'"
	  method_option :verbose, :aliases => "-v", :desc => "Be verbose"
	  method_option :sort_by, :desc => "Column to sort values by (defaults to revenue_per_download)"
	  method_option :username, :alias => "-u", :desc => "Your appfigures username"
	  method_option :password, :alias => "-p", :desc => "Your appfigures password"
	  method_option :type, :desc => "The type of data to return. E.g. --type inapp , --type app. (defaults to --type inapp)"
	  method_option :days, :desc => "The first x days of apps release to return data for. E.g. --days 3 returns first 3 days"
	  method_option :week, :desc => "Shows data for first week of apps release"
	  method_option :month, :desc => "Shows data for first month of apps release"
	  method_option :year, :desc => "Shows data for first year of apps release"
	  method_option :except, :desc => "CSV of keywords such that any in-app or app containing will be removed from data"
	  def search(keywords_csv)
	    appdigest = Appdigest.new options
	    sales = appdigest.search(keywords_csv, options)
	    puts "\n"
	    tp sales, :index, {:name => {:width => 100}}, :downloads, :revenue, :revenue_per_download, :purchases_per_download
	  end
	  
		desc "recent", "Returns recent days app or in-app history for a specified period (defaults to week)"
	  method_option :verbose, :aliases => "-v", :desc => "Be verbose"
	  method_option :keywords, :desc => "Only show app or in-apps whose name contains one of given keywords (use a CSV e.g 'makeover,makeup'"
	  method_option :sort_by, :desc => "Column to sort values by (defaults to revenue_per_download)"
	  method_option :username, :alias => "-u", :desc => "Your appfigures username"
	  method_option :password, :alias => "-p", :desc => "Your appfigures password"
	  method_option :type, :desc => "The type of data to return. E.g. --type inapp , --type app. (defaults to --type app)"
	  method_option :days, :desc => "The first x days of apps release to return data for. E.g. --days 3 returns first 3 days"
	  method_option :week, :desc => "Shows data for first week of apps release"
	  method_option :month, :desc => "Shows data for first month of apps release"
	  method_option :year, :desc => "Shows data for first year of apps release"
	  def recent()
	    appdigest = Appdigest.new options
	    sales = appdigest.recent(options)
	    puts "\n"
	    tp sales, :index, {:name => {:width => 100}}, :downloads, :revenue, :revenue_per_download, :purchases_per_download
	  end
	  
	  
		desc "count", "Counts number of releases in a given period (defaults to week)"
	  method_option :verbose, :aliases => "-v", :desc => "Be verbose"
	  method_option :keywords, :desc => "Only show app or in-apps whose name contains one of given keywords (use a CSV e.g 'makeover,makeup'"
	  method_option :username, :alias => "-u", :desc => "Your appfigures username"
	  method_option :password, :alias => "-p", :desc => "Your appfigures password"
	  method_option :type, :desc => "The type of data to return. E.g. --type inapp , --type app. (defaults to --type app)"
	  method_option :days, :desc => "The first x days of apps release to return data for. E.g. --days 3 returns first 3 days"
	  method_option :week, :desc => "Shows data for first week of apps release"
	  method_option :month, :desc => "Shows data for first month of apps release"
	  method_option :year, :desc => "Shows data for first year of apps release"
	  def count()
	    appdigest = Appdigest.new options
	    sales = appdigest.count(options)
	    puts "\n"
	    tp sales, :index, {:name => {:width => 100}}, :downloads, :revenue, :revenue_per_download, :purchases_per_download
	  end
	  


  end

  class Appdigest
    # @todo: make caching optional
  
    TIME_ZONE = "America/Los_Angeles"
    CACHE_PATH = File::SEPARATOR + ["tmp", "cache", "appdigest"].join(File::SEPARATOR)
    FILE_STORE = ActiveSupport::Cache::FileStore.new(CACHE_PATH)
    EARLIEST_POSSIBLE_APP_STORE_DATE = Time.new(2013,2,1)
    
    def initialize(options = {})
	    if options[:username] and options[:password]
	      @appfigures = Appfigures.new( {:username => options[:username], :password => options[:password]})
	    elsif ENV['APPFIGURES_USERNAME'] and ENV['APPFIGURES_PASSWORD']
	      @appfigures = Appfigures.new( {:username => ENV['APPFIGURES_USERNAME'], :password => ENV['APPFIGURES_PASSWORD']})
	    else
	      puts "ERROR: appfigures username/password not provides (-u name@example.com -p password)"
	    end
#       @appfigures = Appfigures.new( {:username => options[:username], :password => options[:password]})
    end
    
   
    def self.bayesian_rank(array, rank_value_field, rank_count_field)
  		sum_of_rank_count_fields = 0
  		sum_of_rank_value_fields = 0		
  
  	  array.each do |hash|
        sum_of_rank_count_fields = sum_of_rank_count_fields + hash[rank_count_field].to_i
        if not hash[rank_value_field].infinite?
          sum_of_rank_value_fields = sum_of_rank_value_fields + hash[rank_value_field].to_f
        end
  	  end
  	  
  	  avg_rank_count = sum_of_rank_count_fields / array.length
  	  avg_rank_value = sum_of_rank_value_fields / array.length
  
  	  new_array = []
  	  
  	  array.each do |hash|
    	  rank = (avg_rank_count * avg_rank_value + hash[rank_count_field].to_i * hash[rank_value_field].to_f) / (avg_rank_count + hash[rank_count_field].to_i).to_f
    	  
    	  if rank.infinite? or rank.nan?
    	   rank = 0.0
    	  end
  
        hash["bayesian_ranked_" + rank_value_field] = rank      
        
        new_array.push(hash)
  	  end
      return new_array
    end
    
    
    def sales_per_app(start_date, end_date, date_range = nil)
      url = "sales/dates+products/#{start_date.strftime('%Y-%m-%d')}/#{end_date.strftime('%Y-%m-%d')}"
      sales = FILE_STORE.read(url)
      
      puts url
      
      if sales.nil?
        sales = @appfigures.date_sales(start_date, end_date)
        FILE_STORE.write(url, sales)
        puts "sales object WRITTEN TO cache for url: %s" % url
      else
        puts "sales object pulled from cache for url: %s" % url
      end
      
      sales_data = {}
      
      sales.each do |sales_by_day|
        sales_by_day.each do |sale|        
          if sale['product_type'] == "app"  
            if sales_data[sale.product_id].nil?
              sales_data[sale.product_id] = {}   
              sales_data[sale.product_id]["ref_no"] = sale.ref_no     
              sales_data[sale.product_id]["revenue"] = 0.0     
              sales_data[sale.product_id]["downloads"] = 0
              sales_data[sale.product_id]["start_date"] = sale.date
            end
  
            if date_range and (sale.date - sales_data[sale.product_id]["start_date"]).to_i > (date_range.to_i / 86400)
              if sales_data[sale.product_id]["end_date"].nil?
                sales_data[sale.product_id]["end_date"] = sale.date - 1.day
              end
              next
            end
            
            sales_data[sale.product_id]["revenue"] += sale.revenue
            sales_data[sale.product_id]["downloads"] += sale.downloads
            sales_data[sale.product_id]["name"] = sale.name
          else
            if sales_data[sale.parent_id].nil?
              sales_data[sale.parent_id] = {}
              sales_data[sale.parent_id]["revenue"] = 0.0
              sales_data[sale.parent_id]["downloads"] = 0
              sales_data[sale.parent_id]["start_date"] = sale.date
            end
            
            if date_range and (sale.date - sales_data[sale.parent_id]["start_date"]).to_i > (date_range.to_i / 86400)
              if sales_data[sale.parent_id]["end_date"].nil?
                sales_data[sale.parent_id]["end_date"] = sale.date - 1.day
              end
              next
            end
            
            sales_data[sale.parent_id]["revenue"] += sale.revenue
          end
        end
      end
      
      sales_array = []
      sales_data.each do |product_id, data|
        sales_array.push(
          Hashie::Mash.new({
            'product_id'     =>  product_id,
            'ref_no'     =>  data['ref_no'], # This is the identifier as it appears in app store
            'name'     =>  data['name'],
            'start_date'     =>  data['start_date'],
            'end_date'     =>  data['end_date'],
            'revenue'     =>  data['revenue'].to_f,
            'downloads'     =>  data['downloads'].to_i,
            'revenue_per_download' => data['revenue'].to_f / data['downloads'].to_i
          })
        )
      end
      return sales_array    
    end
    
    
    def sales_per_inapp(start_date, end_date, date_range = nil)
      url = "sales/dates+products/#{start_date.strftime('%Y-%m-%d')}/#{end_date.strftime('%Y-%m-%d')}"
      sales = FILE_STORE.read(url)
      if sales.nil?
        sales = @appfigures.date_sales(start_date, end_date)
        FILE_STORE.write(url, sales)
        puts "sales object WRITTEN TO cache for url: %s" % url
      else
        puts "sales object pulled from cache for url: %s" % url
      end
      
      function_key = __method__.to_s + url + "&date_range=" + (date_range.nil? ? "" : date_range.to_s)
      sales_array = FILE_STORE.read(function_key)
      if not sales_array.nil?
        puts "DEBUG: sales_data found in cache."
        return sales_array
      end
      
      
      sales_data = {}
      
      sales.each do |sales_by_day|
      
        $stdout.write '.'
        
        sales_by_day.each do |sale|
          if sale['product_type'] == "inapp"
            if sales_data[sale.product_id].nil?
              sales_data[sale.product_id] = {}   
              sales_data[sale.product_id]["revenue"] = 0.0
              sales_data[sale.product_id]["downloads"] = 0
              sales_data[sale.product_id]["purchases"] = 0
              sales_data[sale.product_id]["start_date"] = sale.date
            end
            
            if date_range and (sale.date - sales_data[sale.product_id]["start_date"]).to_i > (date_range.to_i / 86400)
              if sales_data[sale.product_id]["end_date"].nil?
                sales_data[sale.product_id]["end_date"] = sale.date - 1.day
              end
              next
            end
            
            sales_data[sale.product_id]["revenue"] += sale.revenue
            sales_data[sale.product_id]["name"] = sale.name
            
            sales_data[sale.product_id]["purchases"] += sale.downloads
            
  #           sales_data[sale.product_id]["downloads"] = 0
            if sales_data[sale.product_id]["downloads"] <= 0
              sales.each do |app_sales_by_day|
                app_sales_by_day.each do |app_sale|            
                  if app_sale.product_id == sale.parent_id
                    sales_data[sale.product_id]["downloads"] += app_sale["downloads"]
                  end
                end            
              end      
            end
          end
        end
      end
      
      sales_array = []
      sales_data.each do |product_id, data|      
        sales_array.push(
          Hashie::Mash.new({
            'product_id'     =>  product_id,
            'name'     =>  data['name'],
            'revenue'     =>  data['revenue'].to_f,
            'downloads'     =>  data['downloads'].to_i,
            'revenue_per_download' => data['revenue'].to_f / data['downloads'].to_i,
            'purchases_per_download' => data['purchases'].to_f / data['downloads'].to_i
          })
        )
      end
      
      
      puts "DEBUG: writing sales_array to cache"
      FILE_STORE.write(function_key, sales_array)
          
      return sales_array    
    end
    
    def total_sales(start_date, end_date)
      sales_data = {"revenue"=>0.0, "downloads"=>0}
      
      sales = self.sales_per_app(start_date, end_date)
      sales.each do |sale|
        sales_data["revenue"] += sale.revenue
        sales_data["downloads"] += sale.downloads
      end
          
      return Hashie::Mash.new({
          'revenue'      => sales_data["revenue"].to_f,
          'downloads'       => sales_data['downloads'].to_i
        })
    end
    
    
    def revenue(from_date, to_date, type = nil, sort_by = nil, date_range = nil)
          
      if type == "inapp"
        sales = self.sales_per_inapp(from_date, to_date, date_range)
      elsif type == "total"
        return self.total_sales(from_date, to_date)
      elsif type == "app" or type == nil
        sales = self.sales_per_app(from_date, to_date, date_range)
      else
        raise Exception.new("Unknown type: %s. Select 'inapp', 'app', or 'total'" % type)
      end
      
      
      if type == "inapp"
        sales = Appdigest.bayesian_rank(sales, "purchases_per_download", "downloads")
      end
      
      
      sales = Appdigest.bayesian_rank(sales, "revenue_per_download", "downloads")
      
  	  descending = -1
      
      if sort_by
        sorted_sales = sales.sort_by { |k, v| k[sort_by] * descending  }
      else
        sorted_sales = sales.sort_by { |k, v| k["bayesian_ranked_revenue_per_download"] * descending  }
      end
      
      return sorted_sales
    end
  
    
    ### Revenue functions by date
    def yesterdays_revenue(type = nil, sort_by = nil)
      from_date = 1.days.ago.in_time_zone(TIME_ZONE)
      to_date = 1.days.ago.in_time_zone(TIME_ZONE)
      
      return self.revenue(from_date, to_date, type, sort_by)
    end
    
    def last_weeks_revenue(type = nil, sort_by = nil)
      from_date = 8.days.ago.in_time_zone(TIME_ZONE)
      to_date = 1.days.ago.in_time_zone(TIME_ZONE)
      
      return self.revenue(from_date, to_date, type, sort_by)
    end
    
    def last_months_revenue(type = nil, sort_by = nil)
      from_date = 31.days.ago.in_time_zone(TIME_ZONE)
      to_date = 1.days.ago.in_time_zone(TIME_ZONE)
      
      return self.revenue(from_date, to_date, type, sort_by)
    end
    
    def all_time_revenue(type = nil, sort_by = nil)
      from_date = 1000.days.ago.in_time_zone(TIME_ZONE)
      to_date = 1.days.ago.in_time_zone(TIME_ZONE)
      return self.revenue(from_date, to_date, type, sort_by)
    end
    
    def first_months_revenue(type = nil, sort_by = nil)
      from_date = 1000.days.ago.in_time_zone(TIME_ZONE)
      to_date = 1.days.ago.in_time_zone(TIME_ZONE)
      return self.revenue(from_date, to_date, type, sort_by, 30.days)
    end
    
    def first_weeks_revenue(type = nil, sort_by = nil)
      from_date = 1000.days.ago.in_time_zone(TIME_ZONE)
      to_date = 1.days.ago.in_time_zone(TIME_ZONE)
      return self.revenue(from_date, to_date, type, sort_by, 7.days)
    end
    
    def first_days_revenue(type = nil, sort_by = nil)
      from_date = 1000.days.ago.in_time_zone(TIME_ZONE)
      to_date = 1.days.ago.in_time_zone(TIME_ZONE)
      return self.revenue(from_date, to_date, type, sort_by, 1.days)
    end
    
    def new_releases(min_release_date = nil)
      if min_release_date.nil?
        min_release_date = 31.days.ago.in_time_zone(TIME_ZONE)
      end
      
      sales = self.sales_per_app(36.days.ago.in_time_zone(TIME_ZONE), 1.day.ago.in_time_zone(TIME_ZONE), nil)
      newly_released_apps = []
      
      sales.each do |sale|
        if sale.start_date > min_release_date.to_date
          newly_released_apps.push(sale)
        end
      end
      
      sales = Appdigest.bayesian_rank(sales, "revenue_per_download", "downloads")
      return newly_released_apps
    end
    
    def humanize(sales)
      sales.each do |sale|
        
        if not sale['revenue_per_download'].nil?
          sale['revenue_per_download'] = number_with_precision(sale['revenue_per_download'].to_f.infinite? ? 0 : (sale['revenue_per_download'] * 100), :precision => 2)
        end

        if not sale['bayesian_ranked_revenue_per_download'].nil?
          sale['bayesian_ranked_revenue_per_download'] = number_with_precision(sale['bayesian_ranked_revenue_per_download'].to_f.infinite? ? 0 : (sale['bayesian_ranked_revenue_per_download'] * 100), :precision => 2)
        end
        
        sale['downloads'] = number_with_delimiter(sale['downloads'], :delimiter => ",")
        sale['revenue'] =  number_to_currency(sale['revenue'])
        
        if not sale['purchases_per_download'].nil?
          sale['purchases_per_download'] = number_with_precision(sale['purchases_per_download'].to_f.infinite? ? 0 : (sale['purchases_per_download'] * 100), :precision => 2)
        end
        
        if not sale['bayesian_ranked_purchases_per_download'].nil?
          sale['bayesian_ranked_purchases_per_download'] = number_with_precision(sale['bayesian_ranked_purchases_per_download'].to_f.infinite? ? 0 : (sale['bayesian_ranked_purchases_per_download'] * 100), :precision => 2)
        end
         
        if sale['name']
          sale['name'] = sale['name'].gsub("com.ninjafishstudios", "").gsub(".", " ").gsub("_", " ").titleize()
        end
      end
    end
    
    def totalize(sales)
      if sales.count == 0
        puts "WARNING: sales data is empty"
        return
      end
      total_revenue = 0
      total_downloads = 0
      total_purchases = 0
      total_revenue_per_download = 0
      total_purchases_per_download = 0
      
      sales.each do |sale|
        
        
        total_revenue += sale['revenue'].to_f
        total_downloads += sale['downloads'].to_f
        if sale['purchases']
          total_purchases += sale['purchases'].to_f
        end
        total_revenue_per_download += sale['revenue_per_download'].to_f
        total_purchases_per_download += sale['purchases_per_download'].to_f
      end
      
      total = {}      
      sales[0].each do |k, v|
        total[k] = ""
      end

      total['name'] = "Totals"
      total['revenue'] = total_revenue
      
      #total['downloads'] = total_downloads / sales.count()
      total['downloads'] = total_downloads
      
      total['purchases'] = total_purchases
      total['revenue_per_download'] = total_revenue_per_download / sales.count()
      total['purchases_per_download'] = total_purchases_per_download / sales.count()
      
      sales.push(total)
    end
    
    def from_date_from_options(options)
      from = 7
      if options[:days]
        from = options[:days].to_i
      elsif options[:week]
        from = 7
      elsif options[:month]
        from = 30
      elsif options[:year]
        from = 365
      end
      
      return from.days.ago.in_time_zone(TIME_ZONE)
    end
    
    def recent(options)
      new_options = {}
      options.each do |k,v|
        new_options[k]=v
      end
      new_options['recent'] = true
      
      new_options[:from_date] = from_date_from_options(options)
      
      keywords = "*"
      if options[:keywords]
        keywords = options[:keywords]
      end
      
      if options[:type].nil?
        new_options[:type] = "app"
      end
      
      if options[:sort_by].nil?
        new_options['sort_by'] = "revenue"
      end
      
      return self.search(keywords, new_options)
    end
    
    
    def count(options)
      sales = self.recent(options)
      
      from_date = self.from_date_from_options(options)
      count = 0
      apps_released = []
      sales.each do |sale|
        puts "sale start date: %s" % sale['start_date']
#         sale_date = Date.strptime(sale['start_date'], "%Y-%m-%d")
#         puts "sale date: %s" % sale_date
        puts "from date: %s" % from_date.strftime("%Y-%m-%d")
        if sale['start_date'].to_s != from_date.strftime("%Y-%m-%d").to_s
          puts "date NOT same"
          if not sale['name'].nil? and not sale['product_id'].nil? and sale['name'] != "Totals"
            puts "product is game"
            count = count + 1
            apps_released.push(sale['name'])
          end
          puts sale
        end
                
      end
      
      puts "Count: %d" % count
      
      
      return apps_released
    end
    
    
    
    def search(keywords_csv, options)
      sort_by = "bayesian_ranked_revenue_per_download"
      if options['sort_by']
        sort_by = options['sort_by']
      end
      
      date_range = 30.days
      if options[:days]
        date_range = options[:days].to_i.days
      elsif options[:week]
        date_range = 7.days
      elsif options[:month]
        date_range = 30.days
      elsif options[:year]
        date_range = 365.days
      end
      
      if options[:recent]
        date_range = nil
      end
      
      type = "inapp"
      if options[:type]
        type = options[:type]
      end
      
#       from_date = 1000.days.ago.in_time_zone(TIME_ZONE)
      from_date = Appdigest::EARLIEST_POSSIBLE_APP_STORE_DATE
      to_date = 1.days.ago.in_time_zone(TIME_ZONE)
      
#       puts "Earliest date: %s" % from_date
      
      if options[:from_date]
        from_date = options[:from_date]
      end
      
      sales = self.revenue(from_date, to_date, type, sort_by, date_range)
      
      keywords = keywords_csv.split(",")
      
      puts "keywords: %s" % keywords
      
      filtered_sales = []
      i = 0
      sales.each do |sale|
        keywords.each do |keyword|
          
          
          keyword_match = false
          if sale['name']
            keyword_match = true
            keyword.split("+").each do |keyword_fragment|
              if sale['name'].downcase.index(keyword_fragment.downcase).nil?
                keyword_match = false
              end
            end
          end
          
          if keyword_match or keywords_csv == "*"
            
            if options[:except]
              found = false
              options[:except].split(",").each do |except_word|
                if sale['name'].downcase.index(except_word.downcase)
                  found = true
                  break
                end
              end
              if found
                next
              end
            end
            i += 1
            sale['index'] = i
            filtered_sales.push(sale)
          end
        end
      end
      
      filtered_sales = filtered_sales.sort_by { |k, v| k[sort_by] * -1  } 
      self.totalize(filtered_sales)
      self.humanize(filtered_sales)
      return filtered_sales      
    end
  
    def rank_revenue_hash(options)
      # traverse each app id, request rank history for given period. 
      app_ids = []
      
      rank_revenue_hash = {}
      app_ids.each do |app_id|
        
        revenue_history = @appfigures.sales(app_id, options)
        rank_history = @appfigures.ranks(app_id, options)
        
        rank_history.each do |date, value|
        
          # Get a specific revenue value
          revenue = revenue_history[date]
          
          # get rank as integer value
          rank = value
          
          if not rank_revenue_hash[rank] 
            rank_revenue_hash[rank] = []
          end
          
          rank_revenue_hash[rank].push(revenue)
          
        end
      end
    
    end
  end
  
end