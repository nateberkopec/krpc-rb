require "socket"

RSpec.describe KRPC::Connection do

  before(:example) { @connection = connect }
  after(:example)  { @connection.close }

  context "with default server" do
    before(:context) { start_server }
    after(:context)  { stop_server }

    specify "send & receive" do
      @connection.send "foo"
      expect(@connection.recv(3)).to eq "foo"
    end

    specify "long send & long receive" do
      msg = "foo" * 4096
      @connection.send msg
      expect(@connection.recv(msg.length)).to eq msg
    end

    specify "send & receive varint" do
      int = 83752476526753
      msg = KRPC::ProtobufUtils::Encoder.encode_varint(int)
      @connection.send msg
      expect(@connection.recv_varint).to eq int
    end

    specify "#connected?" do
      expect(@connection.connected?).to be true
      expect(@connection.connected?).to be true
      @connection.close
      expect(@connection.connected?).to be false
      expect(@connection.connected?).to be false
    end

    specify "double close handling" do
      expect(@connection.close).to be true
      expect(@connection.close).to be false
    end
  end


  context "when responses are received in chunks" do
    before(:context) { start_server(:chunking) }
    after(:context)  { stop_server }

    specify "send & receive" do
      @connection.send "foo"
      expect(@connection.recv(3)).to eq "foo"
    end

    specify "long send & long receive" do
      msg = "foo" * 4096
      @connection.send msg
      expect(@connection.recv(msg.length)).to eq msg
    end

    specify "send & receive varint" do
      int = 83752476526753
      msg = KRPC::ProtobufUtils::Encoder.encode_varint(int)
      @connection.send msg
      expect(@connection.recv_varint).to eq int
    end
  end


  def start_server(type = :default)
    @server = TCPServer.open(0)
    @server_port = @server.addr[1]

    @server_thread = case type
      when :chunking
        create_server_thread do |conn, data|
          data.chars.each_with_index do |d, i|
            conn.send(d, 0)
            sleep 0.2 if i < 7
          end
        end
      else
        create_server_thread {|conn, data| conn.send(data, 0) }
    end
  end

  def stop_server
    @server_thread.terminate
    @server_port = nil
    @server.close
  end

  def create_server_thread(&block)
    Thread.new do
      while (conn = @server.accept)
        loop do
          data = conn.recv(2**16)
          break if data.empty?
          yield(conn, data)
        end
        conn.close
      end
    end
  end

  def connect
    KRPC::Connection.new("localhost", @server_port).connect
  end

end