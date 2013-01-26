plugin = Plugin.new "corecommands"

plugin.handle(/^date$/i) do |data|
    next data[:room].say Time.now.localtime.strftime "%a, %d %b %Y %T %z"
end

plugin.handle(/^ping$/i) do |data, args|
    if args.empty? then
        next data[:room].say "ping needs more arguments"
    end

    if args[0].match(/[^a-z0-9\.-]/i) then
        next data[:room].say "invalid characters in argument"
    end

    Thread.new do
        ping = `/bin/ping -w 3 -c 1 -- #{args[0]} 2>&1`

        if ping.match /unknown host (.+)/ then
            data[:room].say "unknown host #{$1}"
        elsif ping.match /^(64 bytes.+)/ then
            data[:room].say "#{$1}"
        elsif ping.match /0 received/m then
            data[:room].say "no reply :-("
        else
            data[:room].say "bogus hostname"
        end

        next
    end
end

plugin.handle(/^host$/i) do |data, args|
    if args.empty? then
        next data[:room].say "host needs more arguments"
    end

    if args[0].match(/^a-z0-9\.-/i) then
        next data[:room].say "invalid characters in argument"
    end

    Thread.new do
        host = `/usr/bin/host #{args[0]} 2>&1`
        lines = host.split(/\n/)
        lines.take(3).each do |line|
            data[:room].say line
        end

        next
    end
end

$bot.plugins.add(plugin)
