class WorldHandler

  def self.create_response(text="I am a response.", type="info")
    {:text => text, :type => type}.to_json
  end

  def respond
    ResponseArray.new
  end

  def self.motd
    create_response("#{CGI.escapeHTML(MOTD)}", "system")
  end

  def self.visitors
    resp = %[#{WorldObject.everything.select {|o| o.is_a?(Person)}.sort{|a,b| a.name <=> b.name}.join(", ")}]
    resp = "There are no previous visitors." if resp.blank?
    create_response resp, "info"
  end

  def self.create_person(ws)
    ws.person = Person.new(NOWHERE)
    CONNECTION_MAP[ws.person] = ws
    str = "#{ws.person.name} (a Person object) has been temporarily created and your connection is attached.\nType 'help' for an explanation of what you can do here."
    create_response(str, "system")
  end

  def self.attach(ws, user)
    if CONNECTION_MAP[user].nil?
      ws.person = user
      CONNECTION_MAP[user] = ws
      str = "You are attached as #{user.name}."
      create_response(str, "system")
    else
      create_response("That user is already attached. Try again.", "system")
    end
  end

  def self.go(ws, msg=nil)
    begin
      if msg.nil?
        # initial connection
        ws.send motd
        ws.send create_person(ws)
      else
        responses = ws.person.instance_eval(msg)
        if responses.is_a? ResponseArray
          responses.each {|r| ws.send r} 
        else
          ws.send create_response(CGI.escapeHTML(responses.inspect), "info")
        end
      end
    rescue Exception => e
      LOG.error e.inspect.to_s + "\n" + e.message + "\n" + e.backtrace.join("\n")
      str = %[Errcode:GLARG! #{msg} - #{e.message}\n#{e.backtrace.join("\n")}]
      ws.send create_response(str, "system")
    end
  end
end
