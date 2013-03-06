module Fantasy
    class Plugins
        attr_reader :plugins

        def initialize
            @plugins = {}
        end

        def add plugin
            @plugins[plugin.name] = plugin
            puts "#{plugin.name} = #{plugin}"
        end

        def load name
            Kernel::load "plugins/#{name}.rb"
        end

        def command command, data, args
            if not args.nil?
                args = args.split(' ')
            else
                args = []
            end
            @plugins.values.each do |plugin|
                puts "#{plugin}"
                plugin.handle! command, data, args
            end
        end
    end
end

class Plugin
    attr_reader :name

    def initialize name
        @name = name
        @handlers = {}
    end

    def handle pattern, &block
        @handlers[pattern] = block
    end

    def handles? command
        @handlers.keys.each do |pattern|
            if command.match pattern then
                return true
            end
        end

        return false
    end

    def handle! command, data, args=[]
        puts "trying to handle #{command} with #{data} and #{args}"
        @handlers.each do |pattern, block|
            if command.match(pattern) then
                puts "#{block} handles #{command}"
                begin
                    Kernel.eval(block.call data, args)
                rescue Exception => e
                    puts "#{block} failed with Exception #{e}"
                end

                break
            end
        end
    end
end
