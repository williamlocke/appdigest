require 'rubygems'
require 'rails'
require 'appfigures'

class Appdigest

  def initialize(options = {})
    @appfigures = Appfigures.new( {:username => options[:username], :password => options[:password]})
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
    
    sales = @appfigures.date_sales(start_date, end_date)
    sales_data = {}
    
    sales.each do |sales_by_day|
      
      sales_by_day.each do |sale|
        
        if sale['product_type'] == "app"  
          if sales_data[sale.product_id].nil?
            sales_data[sale.product_id] = {}   
            sales_data[sale.product_id]["revenue"] = 0.0     
            sales_data[sale.product_id]["downloads"] = 0
            sales_data[sale.product_id]["start_date"] = sale.date
          end
          
          puts "\n"
          puts (sale.date - sales_data[sale.product_id]["start_date"]).to_i
          puts "\n"
          puts (date_range.to_i / 86400)
          puts "\n"
                    
          if date_range and (sale.date - sales_data[sale.product_id]["start_date"]).to_i > (date_range.to_i / 86400)
            puts "not adding data for this date"
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
    
    sales = @appfigures.date_sales(start_date, end_date)
    
    sales_data = {}
    
    sales.each do |sale|
      if sale['product_type'] == "inapp"
        if sales_data[sale.product_id].nil?
          sales_data[sale.product_id] = {}        
        end
        sales_data[sale.product_id]["revenue"] = sale.revenue
        sales_data[sale.product_id]["downloads"] = sale.downloads
        sales_data[sale.product_id]["name"] = sale.name
        
        sales_data[sale.product_id]["purchases"] = sale.downloads
        
        sales.each do |app_sale|
          if app_sale.product_id == sale.parent_id
            sales_data[sale.product_id]["downloads"] = app_sale["downloads"]
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

  
  def yesterdays_revenue(type = nil, sort_by = nil)
    from_date = 2.days.ago
    to_date = 2.days.ago
    
    return self.revenue(from_date, to_date, type, sort_by)
  end
  
  def last_weeks_revenue(type = nil, sort_by = nil)
    from_date = 9.days.ago
    to_date = 2.days.ago
    
    return self.revenue(from_date, to_date, type, sort_by)
  end
  
  def all_time_revenue(type = nil, sort_by = nil)
    from_date = 1000.days.ago
    to_date = 2.days.ago
    return self.revenue(from_date, to_date, type, sort_by)
  end
  
  def first_months_revenue(type = nil, sort_by = nil)
    from_date = 1000.days.ago
    to_date = 2.days.ago
    return self.revenue(from_date, to_date, type, sort_by, 30.days)
  end
  
  def first_weeks_revenue(type = nil, sort_by = nil)
    from_date = 1000.days.ago
    to_date = 2.days.ago
    return self.revenue(from_date, to_date, type, sort_by, 7.days)
  end
  
  def first_days_revenue(type = nil, sort_by = nil)
    from_date = 1000.days.ago
    to_date = 2.days.ago
    return self.revenue(from_date, to_date, type, sort_by, 1.days)
  end
  
  
  
end