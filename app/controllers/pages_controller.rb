class PagesController < ApplicationController
  
  require 'rubygems'
  require 'hpricot'
  require 'mechanize'
  require 'uri'
  WWW::Mechanize.html_parser = Hpricot
   
  def index
    @pollen_count = PollenCount.find(:first, :order => 'date desc')
    if params[:pollen_count] == 'weeds'
      count = @count = @pollen_count.weeds
        if count == 0
          count = 0
        elsif count <= 9
          count = 12.5
        elsif count <= 49
          count = 50
        elsif count <= 499
          count = 75
        elsif count > 500
          count = 100
        end
        @nab_scale = %w(0-9 10-49 50-499 >500)
    elsif params[:pollen_count] == 'fungi'
      count = @count = @pollen_count.fungi
        if count == 0
          count = 0
        elsif count <= 6499
          count = 12.5
        elsif count <= 12999
          count = 50
        elsif count <= 49999
          count = 75
        elsif count > 50000
          count = 100
        end
        @nab_scale = %w(0-6499 6500-12999 13000-49999 >50000)
    elsif params[:pollen_count] == 'grass'
      count = @count = @pollen_count.grass
        if count == 0
          count = 0
        elsif count <= 4
          count = 12.5
        elsif count <= 19
          count = 50
        elsif count <= 199
          count = 75
        elsif count > 200
          count = 100
        end
        @nab_scale = %w(0-4 5-19 20-199 >200)
    else
      count = @count = @pollen_count.trees
      if count == 0
        count = 0
      elsif count <= 14
        count = 12.5
      elsif count <= 89
        count = 50
      elsif count <= 1499
        count = 75
      elsif count > 1500
        count = 100
      end
      @nab_scale = %w(0-14 15-89 90-1499 >1500)
    end
    respond_to do |page|
      page.html { @graph =  Gchart.meter(:data => [count], :encoding => 'text', :size => '264x210', :bar_colors => ['00FF00', 'FFFF00', 'FF0000']) }
    end
  end
  
  def graph_code
    @pollen_count = PollenCount.find(:first, :order => 'date desc')
    #bar = BarGlass.new
    bar.on_click = "alert('hello there')"
    bar.set_values((1..9).to_a)
    @values = [@pollen_count.grass, @pollen_count.trees, @pollen_count.weeds, @pollen_count.fungi]
    @values = @values.select{|v| !v.zero?}
    bar.values  = @values
    
    #chart = OpenFlashChart.new
    chart.bg_colour = '#FFFFFF'
    chart.add_element(bar)
    
    chart.x_axis = nil
    
    render :text => chart.to_s
  end
  
  def get_pollen_count
    @elements=[]
    agent = WWW::Mechanize.new
    agent.keep_alive = false # true causes TypeError
    page = agent.get('http://www.aaaai.org/nab/collectors/index.cfm')
    page = page.form_with(:action => 'index.cfm?p=start') do |f|
      f['LIusername'] = 'pdaftary'
      f['LIpassword'] = 'ffw242'
    end.click_button
    page = page.parser { |f| Hpricot f, :xhtml_strict => true }
    page = (page/'table[3]/tr/td').first
    page = (page/'table/tr')
    page = page[4..page.size].each do |val|
      day = (val/'td').first.inner_html
      grass = (val/'td')[1].inner_html
      trees = (val/'td')[2].inner_html
      weeds = (val/'td')[3].inner_html
      fungi = (val/'td')[4].inner_html
      pollen_count = PollenCount.find_or_create_by_date(:date => Date.parse(day), :grass => grass, :trees => trees, :weeds => weeds, :fungi => fungi)
      unless pollen_count.new_record?
        pollen_count.update_attributes(:date => Date.parse(day), :grass => grass, :trees => trees, :weeds => weeds, :fungi => fungi)
      end
    end 
  end
  
  def send_contact_form
    Pony.mail :to => 'info@allergywaco.com',
        :from => params[:contact][:author_email],
        :subject => 'Contact form sent',
        :body => body

    flash[:notice] = "Thanks for sending us a message."
    redirect_to :back
  end
  
  def send_satisfaction_survey
    Pony.mail :to => 'info@allergywaco.com',
        :from => params[:survey][:author_email],
        :subject => 'Survey from AACOW',
        :body => survey_body

    flash[:notice] = "Thanks for sending us a message."
    redirect_to :back
  end
  
  def body
    
    body = "YOU GOT A MESSAGE FROM AACOW.COM \n\n" +

    			"NAME: #{params[:contact][:author] } \n\n" +

    			"E MAIL: #{params[:contact][:author_email]} \n\n" +

    			"Message: #{params[:contact][:body]} \n\n"
      return body
  end
  
  def survey_body
    body = "YOU GOT A SURVEY FROM AACOW.COM \n\n" +

    			"NAME: #{params[:survey][:author] } \n\n" +
    			
    			"PHONE: #{params[:survey][:author_phone] } \n\n" +
    			
    			"ADDRESS 1: #{params[:survey][:author_address_1] } \n\n" +
    			
    			"ADDRESS 2: #{params[:survey][:author_address_2] } \n\n" +
    			
    			"CITY: #{params[:survey][:author_city] } \n\n" +
    			
    			"STATE: #{params[:survey][:author_state] } \n\n" +
    			
    			"ZIP: #{params[:survey][:author_zip] } \n\n" +

    			"E MAIL: #{params[:survey][:author_email]} \n\n" +
    			
    			"Date of Appointment: #{params[:date][:month]}/#{params[:date][:day]}/#{params[:date][:year]} \n\n" +
    			
    			"Reason for Appointment: #{params[:survey][:reason_for_appt] } \n\n" +
    			
    			"Caregiver seen: #{params[:survey][:caregiver_seen] } \n\n" +

    			"Message: #{params[:survey][:message]} \n\n"
    			
      return body
  end
  
  def historical_pollen_count
    params[:pollen_count] ? type = params[:pollen_count].to_sym : type = 'trees'

    if params[:pollen_count] == 'grass'
      @max = '200'
      @nab_scale = %w(0-4 5-19 20-199 >200)
    elsif params[:pollen_count] == 'weeds'
      @max = '500'
      @nab_scale = %w(0-9 10-49 50-499 >500)
    elsif params[:pollen_count] == 'fungi'
      @max = '50000'
      @nab_scale = %w(0-6499 6500-12999 13000-49999 >50000)
    else
      @max = '1500'
      @nab_scale = %w(0-14 15-89 90-1499 >1500)
    end

    @data = {}
    for pc in PollenCount.all
      @data.merge! pc.date => { type.to_sym => pc[type] }
    end
    
    respond_to do |format|
      format.html
      format.js {
        render :update do |page|
          page['graph_holder'].replace_html(:partial => 'pages/historical_graph', :object => @data)
        end
      }
    end
  end
  
end
