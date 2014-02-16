require 'sinatra/base'
require 'thin'
require 'erb'
require 'em-websocket'
require 'json'
require 'pry'


EventMachine.run do

  class App < Sinatra::Base
    get '/' do
       erb :index
    end
  end

  class Client

    @@client_ct = 0

    attr_reader :sock, :id

    def initialize(sock)
      @@client_ct += 1
      @sock = sock
      @id = @@client_ct
    end

    def username=(username)
      @username = username
    end

    def username
      @username == nil || @username == "" ? "Secretive Person #{self.id}" : @username
    end

  end

    $clients = []

    EventMachine::WebSocket.start(:host => '0.0.0.0', :port => 8080) do |ws|
      ws.onopen do |handshake|
        puts "Websocket connection opened"
        client = Client.new(ws)
        $clients << client
      end

      ws.onmessage do |msg|
        msg = JSON.parse(msg)
        if msg["event"] == "username"
          client = $clients.select {|c| c.sock == ws }.first
          client.username = msg["data"]["text"]
          b = JSON.generate({
            event: "new_client",
            id: client.username
          })
          $clients.each do |c|
            c.sock.send(b)
          end
        elsif msg["event"] == "user_message"
          id = $clients.select { |c| c.sock.signature == ws.signature }.first
          a = JSON.generate({
            event: "message",
            time: Time.now.strftime("%T"),
            text: msg["data"]["text"],
            id: id.username
          })
          puts a
          $clients.each do |c|
            c.sock.send(a)
          end
        end
      end

      ws.onclose do
        puts "Websocket connection closed"
        client = $clients.select {|c| c.sock == ws }.first
        d = JSON.generate({
          event: "delete_client",
          id: client.username
        })
        $clients.each do |c|
          c.sock.send(d)
        end
        $clients.delete(client)
      end

    end

  App.run! :port => 9393, :bind => '0.0.0.0'

end

