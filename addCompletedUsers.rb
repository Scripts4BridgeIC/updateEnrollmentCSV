# gems to include make sure you have installed these on your computer
# you can verify by going to terminal on your computer and typing in
# gem install <gemname>
require 'csv'
require 'json'
require 'net/http'
#Replace these values with the correct values for your own situation

access_token = "MmFjNzFmMDItYmM2ZC00YTEyLTkyMjEtMjhjYmZkYmNkOTc1OjcxYjU5M2ZhLTgyNmQtNGQ2MS1hYmUwLThkNmQwYzAxYjVjNA=="

# Your Bridge domain. Do not include https://, or, bridgeapp.com.
bridge_domain = 'thriveupstate'

# Path to the CSV file containing the learner enrollment ID, score, and completion date.
csv_file = '/Users/swasilewski/Desktop/Bridge/RubyScripts/thrive/TU4.csv'

#---------------------Do not edit below this line unless you know what you're doing-------------------#

unless access_token
    puts 'What is your access token? Do not include "Authorization Basic", only the token'
    access_token = gets.chomp
    sleep(1)
end

unless bridge_domain
    puts 'What is your Bridge domain? Do not includes, "https://, or, bridgeapp.com"'
    bridge_domain = gets.chomp
    sleep(1)
end

unless csv_file
    puts 'Where is your enrollment update CSV located? e.g., "/Users/Name/Desktop/Example.csv"'
    csv_file = gets.chomp
    sleep(1)
end

unless File.exists?(csv_file)
    raise 'Error: cannot locate the CSV file at the specified file path. Please correct this and run again.'
end

base_url = "https://#{bridge_domain}.bridgeapp.com/api/author"

puts "------------------------------------------------------------------Starting"
CSV.foreach(csv_file, headers:true) do |row|
    url = URI("#{base_url}/course_templates/#{row['courseid']}/enrollments")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["authorization"] = "Basic #{access_token}"
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'
    response = http.request(request)
    unless response.code == "200"
      puts "#{row.to_s}-----------------------------error #{response.code}"
      next
    end

    json = JSON.parse(response.body)
    request = Net::HTTP::Post.new(url)
    request["authorization"] = "Basic #{access_token}"
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'
    payload = {"enrollments" => ["user_id" => row['bridgeuserid']]}

    request.body = payload.to_json

    #puts request.body
    response = http.request(request)
    #puts response.code
    unless response.code == "204"
      puts payload
      puts "#{row.to_s}-----------------------------error #{response.code}"
    end

end

puts "------------------------------------------------------------------halfway-ish"

CSV.foreach(csv_file, headers:true) do |row|
    url = URI("#{base_url}/course_templates/#{row['courseid']}/enrollments")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["authorization"] = "Basic #{access_token}"
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'

    response = http.request(request)
    unless response.code == "200"
      puts "#{row.to_s}-----------------------------error #{response.code}"
      next
    end
    json = JSON.parse(response.body)


    i = 0
    while i < json["enrollments"].length
      if json["enrollments"][i]["links"]["learner"]["id"] == row['bridgeuserid']
        enroll = json["enrollments"][i]["id"]
        url = URI("#{base_url}/enrollments/#{enroll}")
        request = Net::HTTP::Patch.new(url)
        request["authorization"] = "Basic #{access_token}"
        request["content-type"] = 'application/json'
        request["cache-control"] = 'no-cache'
        stringDate = row['completed']
        stringDate.slice! "+AC0"
        stringDate.slice! "+AC0"
        #puts stringDate
        payload = {"enrollments" => ["completed_at" => stringDate,"score" => row['score']]}
        request.body = payload.to_json

        #puts request.body

        response = http.request(request)
        #puts response.code
        unless response.code == "200"
          puts payload
          puts "#{row.to_s}-----------------------------error #{response.code}"
        end
      end
      i+=1
    end
end
puts "------------------------------------------------------------------Hopefully done"
puts "------------------------------------------------------------------check for errors"
