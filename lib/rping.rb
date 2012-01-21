require 'socket'

class RPing
  MAX_LEN = 64 * 1024

  def initialize(options = {})
    @count    = options.fetch(:count, 1)
    @interval = options.fetch(:interval, 1)
    @timeout  = options.fetch(:timeout, 4)
    @icmp_id  = (self.object_id ^  Process.pid) & 0xffff
    @seq_num  = 1
  end

  def self.ping(dest, options = {}, &block)
    self.new(options).ping(dest, &block)
  end

  def ping(addr, &block)
    unless addr =~ /\A\d{3}\.\d{3}\.\d{3}\.\d{3}\Z/
      addr = IPSocket.getaddress(addr)
    end

    sock = nil
    buf = []

    begin
      sock = make_socket
      th = ping_recv(sock, buf, &block)
      ping_send(sock, addr)
      th.join
    ensure
      sock.close if sock
    end

    return buf
  end

  def make_socket
    Socket.new(Socket::AF_INET, Socket::SOCK_RAW, Socket::IPPROTO_ICMP)
  end

  def ping_send(sock, addr)
    sockaddr = Socket.pack_sockaddr_in(0, addr)

    @count.times do |i|
      sleep @interval unless i.zero?
      req = make_echo_request
      sock.send(req, 0, sockaddr)
    end
  end

  def ping_recv(sock, buf = nil, &block)
    Thread.start do
      @count.times do
        reply = ping_recv0(sock)
        yield(reply) if block
        buf << reply if buf
      end
    end
  end

  private
  def ping_recv0(sock)
    reply = nil

    begin
      if select([sock], nil, nil, @timeout)
        msg = sock.recv(MAX_LEN)
        recv_time = Time.now.to_f
        ip, icmp = unpack_echo_reply(msg)

        # icmp[0] == 0: Type == Echo Reply
        if icmp[0] == 0 and icmp[3] == @icmp_id
          reply = {
            :dest => ip[8].bytes.to_a.join('.'),
            :src  => ip[9].bytes.to_a.join('.'),
            :size => msg.length,
            :ttl  => ip[5],
            :seq  => icmp[4],
            :time => (recv_time - icmp[5]) * 1000,
          }
        end
      end
    rescue Timeout::Error
    end

    return reply
  end

  def make_echo_request
    data = Time.now.to_f

    req = [
      [       8, :C], # Type = Echo
      [       0, :C], # Code = 0
      [       0, :n], # Checksum
      [@icmp_id, :n], # Identification
      [@seq_num, :n], # Sequence Number
      [    data, :d], # Data
    ]

    @seq_num += 1
    req = req.map {|i| i[0] }.pack(req.map {|i| i[1] }.join)
    update_checksum(req)

    return req
  end

  def update_checksum(buf)
    sum = 0
    buf.unpack('n*').each {|i| sum += i }

    unless (buf.length % 2).zero?
      sum += buf[-1].unpack('n')[0]
    end

    sum = (sum & 0xffff) + (sum >> 16);
    sum = (sum & 0xffff) + (sum >> 16);

    buf[2, 2] = [~sum & 0xffff].pack('n')
  end

  def unpack_echo_reply(buf)
    tmpl = [
      # IP
      :C,  # Version, IHL
      :C,  # Type of Service
      :n,  # Total Length
      :n,  # Identification 
      :n,  # Flags, Fragment Offset
      :C,  # Time to Live,
      :C,  # Protocol
      :n,  # Header Checksum
      :a4, # Source Address
      :a4, # Destination Address
      # ICMP
      :C,  # Type
      :C,  # Code
      :n,  # Checksum
      :n,  # Identification
      :n,  # Sequence Number
      :d,  # Data
    ]

    reply = buf.unpack(tmpl.join)
    ip = reply.slice(0, 19)
    icmp = reply.slice(10, 6)

    return [ip, icmp]
  end
end
