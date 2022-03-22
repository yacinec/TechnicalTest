require 'dotenv'
require 'uri'
require 'net/http'
require 'json'
require 'csv'
require 'net/ftp'
require 'Date'

Dotenv.load

def fetch(uri, limit=10)
    if limit == 0
        raise ArgumentError, 'too many HTTP redirects' if limit == 0
    end

    response = Net::HTTP.get_response(uri)
    case response
    when Net::HTTPSuccess then
        response
    when Net::HTTPFound then
        location = response['location']
        fetch(URI(location), limit - 1)
    else
        response.value
    end
end

def createCsv(datas, headers)
    fileName = "guests-#{Date.today}.csv"
    CSV.open(fileName, 'w') do |csv|
        csv << headers
        datas.each do |data|
            csv << CSV::Row.new(data.keys, data.values)
        end
    end
    
    fileName
end

def uploadToFtp(fileName) 
    Net::FTP.open(ENV['HOST'], ENV['USERNAME'], ENV['PASSWORD']) do |ftp|
        ftp.putbinaryfile(fileName)
    end
end

def downloadFromFtp(filename)
    Net::FTP.open(ENV['HOST'], ENV['USERNAME'], ENV['PASSWORD']) do |ftp|
        ftp.getbinaryfile(fileName, "temp-#{fileName}")
    end
    CSV.read "temp-#{fileName}"
end


# Get the data from the API
uri = URI(ENV["URI"])
params = {:auth_token => ENV["AUTH_TOKEN"]}
uri.query = URI.encode_www_form(params)

result = fetch(uri)
result = JSON.parse(result.body)
 

# Get guest from the JSON object
guests = []
result.each do |guest| 
        guests.push(
            { 
                email: guest['email'],
                company_name: guest['company_name'],
                identity: "#{guest['first_name']} #{guest['last_name']}",
                uid: guest['uid'],
                from_tesla: guest['company_name'] == "Tesla"
            }
        )
    
end

# Save the guest into the CSV file
headers = ['email','company_name','identity', 'uid', 'from_tesla']
fileName = createCsv(guests, headers)

# Upload the CSV file to the FTP server
uploadToFtp(fileName)

# Download the CSV file from the FTP server and read it into the console
downloadFromFtp(fileName)