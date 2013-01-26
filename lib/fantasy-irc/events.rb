require 'securerandom'

module Fantasy
    module Event
        class Factory
            def initialize
                puts "Initializing new Event::Factory #{self}"
                @data, @data[:events] = Hash.new, Hash.new
            end

            def create name
                name.downcase!

                if not @data[:events][name].nil? then
                    return @data[:events][name]
                    # TODO: log warning
                end

                @data[:events][name] = Event.new(name)
            end

            def by_name name
                name.downcase!

                if not @data[:events][name] then
                    raise "Tried to access unknown event \"#{name}\" in Event::Factory \"#{self}\""
                end

                @data[:events][name]
            end
        end

        class Event
            attr_reader :name

            def initialize(name)
                puts "New Event with name #{name}"
                @name = name
                @data = Hash.new
            end

            def register(&callback)
                uuid = SecureRandom.uuid()

                if @data[:callbacks].nil? then
                    @data[:callbacks] = Hash.new
                end

                @data[:callbacks][uuid] = callback
                puts "#{self}: registered callback #{callback} with uuid #{uuid}."
            end

            def call(args=nil)
                if @data[:callbacks].nil? or @data[:callbacks].empty? then
                    return
                end

                @data[:callbacks].each { |uuid, proc|
                    proc.call(args)
                }
            end
        end
    end
end
