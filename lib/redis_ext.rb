class Redis
  #
  # Used to send SSDB command
  #
  # @param [<type>] command SSDB command
  # @param [<type>] *args arguments
  #
  #
  def call_ssdb(command, *args)
    synchronize do |client|
      client.call([command] + args)
    end
  end
end
