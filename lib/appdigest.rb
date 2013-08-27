class Appdigest
  attr_reader :connection
  def initialize(options = {})
    @appfigures = Appfigures.new( {:username => options[:username], :password => options[:password]})
  end
  
  
  def todays_revenue(sort_by = nil)
    
#     sales = APPFIGURES.sales_per_app(2.days.ago, 2.days.ago)
    sales = @appfigures.sales_per_inapp(2.days.ago, 2.days.ago)
    
    sales = self.bayesian_rank(sales, "revenue_per_download", "downloads")
    
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