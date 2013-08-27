class Appdigest
  attr_reader :connection
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
  	  puts "\nRANK: %f" % rank
  	  
      hash["bayesian_ranked_" + rank_value_field] = rank
      
      
      new_array.push(hash)
	  end
	  
    return new_array
  end

  
  def todays_revenue(sort_by = nil)
    
#     sales = APPFIGURES.sales_per_app(2.days.ago, 2.days.ago)
    sales = @appfigures.sales_per_inapp(2.days.ago, 2.days.ago)
    
    sales = Appdigest.bayesian_rank(sales, "revenue_per_download", "downloads")
    
	  descending = -1
    sorted_sales = sales.sort_by { |k, v| k["revenue_per_download"] * descending  }
    sorted_sales = sales.sort_by { |k, v| k["revenue"] * descending  }
    sorted_sales = sales.sort_by { |k, v| k["bayesian_ranked_revenue_per_download"] * descending  }
    
    sales_array = []
    sales.each do |sale|
      
    end
    
    return sorted_sales
  end
  
  
end