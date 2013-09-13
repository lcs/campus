class WorldHandler

  def self.create_response(text="I am a response.", type="info")
    {:text => text, :type => type}.to_json
  end

  def respond
    ResponseArray.new
  end

  def self.motd
    create_response("#{MOTD}", "system")
  end

  def self.who_are_you
      challenge = %[Who are you? (Type 'visitors' to see a list of previous visitors.)]
      create_response(challenge, "system")
  end

  def self.visitors
    resp = %[#{WorldObject.everything.select {|o| o.is_a?(Person)}.sort{|a,b| a.name <=> b.name}.join(", ")}]
    resp = "There are no previous visitors." if resp.blank?
    create_response resp, "info"
  end

  def self.create_person(ws, name)
    ws.person = Person.new(NOWHERE)
    ws.person.name = name
    CONNECTION_MAP[ws.person] = ws
    ws.identified = true
    str = "#{name} (a Person object) has been temporarily created and your connection is attached as #{name}.\nType 'help' for an explanation of what you can do here."
    create_response(str, "system")
  end

  def self.attach(ws, user)
    if CONNECTION_MAP[user].nil?
      ws.person = user
      CONNECTION_MAP[user] = ws
      ws.identified = true
      str = "You are attached as #{user.name}."
      create_response(str, "system")
    else
      create_response("That user is already attached. Try again.", "system")
    end
  end

  def self.go(ws, msg=nil)
    begin
      if msg.nil?
        ws.identified = false
        ws.send motd
        ws.send who_are_you
      else
        if ws.identified
          responses = ws.person.instance_eval(msg)
          if responses.is_a? ResponseArray
            responses.each {|r| ws.send r} 
          else
            ws.send create_response(responses.inspect, "info")
          end
        else
          if msg == "visitors"
            ws.send visitors
            ws.send who_are_you
          else
            login = WorldObject.everything.select {|o| o.is_a?(Person) && o.name == msg }
            if login.size > 1
              LOG.error %{ERROR: Name duplicate found for #{msg}.}
              raise "Errcode:HEEZAPONG! There are multiple Person objects with that name in the system.\nError logged.\nTalk to an admin to resolve, or log in as someone else and fix the name duplication."
            elsif login.size == 0
              ws.send create_person(ws, msg)
            else
              ws.send attach(ws, login.first)
            end
          end
        end
      end
    rescue Exception => e
      LOG.error e.inspect.to_s + "\n" + e.message + "\n" + e.backtrace.join("\n")
      str = %[Errcode:GLARG! #{msg} - #{e.message}\n#{e.backtrace.join("\n")}]
      ws.send create_response(str, "system")
    end
  end
end
