# Script to add user enrollments and then update those enrollments based on CSV
# file. Currently set to update completion date and score but you can update
# other attributes as well as per
# https://docs.bridgeapp.com/doc/api/html/author_enrollments.html

# gems to include make sure you have installed these on your computer
# you can verify by going to terminal on your computer and typing in
# gem install <gemname>
require 'csv'
require 'json'
require 'net/http'

# Replace this with the your instance specific authentication token
access_token = "accessToken"

# Your Bridge domain. Do not include https://, or, bridgeapp.com.
bridge_domain = 'waz'

# Path to the CSV file containing the learner enrollment ID, score, and completion date.
csv_file = '/Users/username/location/userdata.csv'

#---------------------Do not edit below this line unless you know what you're doing-------------------#

# If access token is not defined, ask for token
unless access_token
    puts 'What is your access token? Do not include "Authorization Basic", only the token'
    access_token = gets.chomp
    sleep(1)
end

# If domain is not defined, ask for domain
unless bridge_domain
    puts 'What is your Bridge domain? Do not includes, "https://, or, bridgeapp.com"'
    bridge_domain = gets.chomp
    sleep(1)
end

# If CSV path is not defined, ask for path
unless csv_file
    puts 'Where is your enrollment update CSV located? e.g., "/Users/Name/Desktop/Example.csv"'
    csv_file = gets.chomp
    sleep(1)
end

# If file doesn't exist bail out
unless File.exists?(csv_file)
    raise 'Error: cannot locate the CSV file at the specified file path. Please correct this and run again.'
end

# This script only deals with author api endpoints.
base_url = "https://#{bridge_domain}.bridgeapp.com/api/author"

# Starting marker cause sometimes I forget to clear my console before starting scripts
puts "------------------------------------------------------------------Starting"

# Loop through each row is CSV file and create users
CSV.foreach(csv_file, headers:true) do |row|

    # url for course enrollments. Mostly running this to ensure that course exists
    # before attempting to enroll user. I probably had a good reason for this but
    # but most likely this will be removed for the sake of speed.
    url = URI("#{base_url}/course_templates/#{row['courseid']}/enrollments")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    # Create request that will passed to pridge API endpoint
    request = Net::HTTP::Get.new(url)
    request["authorization"] = "Basic #{access_token}"
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'

    # Send request and log the response
    response = http.request(request)

    # If call has an error, report it back in terminal and move on to the next row
    unless response.code == "200"
      puts "#{row.to_s}-----------------------------error #{response.code}"
      next
    end

    # Parse response, this should also be removed for speed reason after testing
    json = JSON.parse(response.body)

    # Create new API request to create a user with the ID specified in the CSV
    request = Net::HTTP::Post.new(url)
    request["authorization"] = "Basic #{access_token}"
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'
    payload = {"enrollments" => ["user_id" => row['bridgeuserid']]}

    # Convert payload to JSON
    request.body = payload.to_json

    # Send request and log the response
    response = http.request(request)

    # If call has an error, report it back in terminal and move on to the next row
    unless response.code == "204"
      puts "#{row.to_s}-----------------------------error #{response.code}"
    end
end

# Marker so I can differentiate which part of the script is generating errors
puts "------------------------------------------------------------------halfway-ish"

# Loop through each row is CSV file, search for enrollment and update that enrollment
CSV.foreach(csv_file, headers:true) do |row|

    # url for course enrollments. This data is used to find the users enrollments
    # so that they can be updated.
    url = URI("#{base_url}/course_templates/#{row['courseid']}/enrollments")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    # Create request that will passed to pridge API endpoint
    request = Net::HTTP::Get.new(url)
    request["authorization"] = "Basic #{access_token}"
    request["content-type"] = 'application/json'
    request["cache-control"] = 'no-cache'

    # Send request and log the response
    response = http.request(request)

    # If call has an error, report it back in terminal and move on to the next row
    unless response.code == "200"
      puts "#{row.to_s}-----------------------------error #{response.code}"
      next
    end

    # Parse response, this should also be removed for speed reason after testing
    json = JSON.parse(response.body)

    # Loop through each enrollment and when the correct enrollment is found
    # that enrollment is updated with the information in the row
    i = 0
    while i < json["enrollments"].length
      if json["enrollments"][i]["links"]["learner"]["id"] == row['bridgeuserid']
        enroll = json["enrollments"][i]["id"]
        url = URI("#{base_url}/enrollments/#{enroll}")
        request = Net::HTTP::Patch.new(url)
        request["authorization"] = "Basic #{access_token}"
        request["content-type"] = 'application/json'
        request["cache-control"] = 'no-cache'

        # Added this because formatting of CSV for the school this script was written for
        # was a bit... wonky so I just clipped out the bad bits rather than reformating the csv manually
        stringDate = row['completed']
        stringDate.slice! "+AC0"
        stringDate.slice! "+AC0"

        # Create payload for API call
        payload = {"enrollments" => ["completed_at" => stringDate,"score" => row['score']]}
        request.body = payload.to_json

        # Send request and log the response
        response = http.request(request)

        # If call has an error, report it back in terminal and move on to the next row
        unless response.code == "200"
          puts payload
          puts "#{row.to_s}-----------------------------error #{response.code}"
        end
      end
      i+=1
    end
end

# Some markers so I know when I'm done.
puts "------------------------------------------------------------------Hopefully done"
puts "------------------------------------------------------------------check for errors"
