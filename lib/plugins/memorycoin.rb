#!/usr/bin/env ruby

require 'net/http'
require 'open-uri'
require 'timeout'
require 'json'

# creates a new fantasy-irc plugin
plugin = Plugin.new "memorycoin"

# only talk in these rooms
@mmc_rooms = ['#memorycoin', '#extasie', '##mmc-spam']

##### POINT THIS TO YOUR MEMORYCOIN DAEMON #####
@mmc_path = '/path/to/memorycoind'

# gets memorycoin blockchain info
def mmc_blockinfo

  # number of latest block
  @blckhigh = `#{@mmc_path} getblockcount`

  # hash of latest block
  blckhash = `#{@mmc_path} getblockhash #{@blckhigh}`

  # complete json of latest block
  blckinfo = `#{@mmc_path} getblock #{blckhash}`

  # difficulty of latest block
  @blckdiff = `#{@mmc_path} getdifficulty`

  # number of 30th latest block
  rcnthigh = @blckhigh.to_i - 30

  # hash of 30th latest block
  rcnthash = `#{@mmc_path} getblockhash #{rcnthigh}`

  # complete json of 30th latest block
  rcntinfo = `#{@mmc_path} getblock #{rcnthash}`

  # timestamp of latest block
  blcktime = JSON.parse(blckinfo)['time'].to_i

  # timestamp of 30th latest block
  rcnttime = JSON.parse(rcntinfo)['time'].to_i

  # average blocktime of 30 last blocks in seconds
  @blocktime = (blcktime.to_f - rcnttime.to_f) / 30.0

  # current hashrate in hashs per minute
  @hashrate = ((2 ** 32) * @blckdiff.to_f) / (@blocktime.to_f / 60.0)

  # calculates current block reward and total minted coins
  i = 0
  currweek = ((@blckhigh.to_f / 1680.0) - 0.5).round
  @reward = 280.0 ### @TODO: initial reward was limited, PTS shares
  @minted = 715842.49 ### @TODO: initial reward was limited, PTS shares
  while i < currweek do
    @minted += @reward * 1680.0
    @reward *= 0.95
    i += 1
  end
  @minted += (@blckhigh.to_f - (currweek * 1680.0)) * @reward

end # end mmc_blockinfo

# gets memorycoin voting info
def mmc_voteinfo

  # gets memorycoin blockchain info
  mmc_blockinfo

  # gets the last vote block number
  tlock = @blckhigh.to_f / 20.0
  block = @blckhigh.to_i - ((tlock - tlock.round) * 20.0).round
  if (block > @blckhigh.to_i)
    block -= 20
  end

  # parse voting info
  begin
    t = Timeout.timeout(5) do
      @votes = JSON.parse(open("http://www.mmcvotes.com/block/#{block}?output=json").read)
    end
  rescue Timeout::Error
    @votes = nil
  end
end # end mmc_voteinfo

# calculates solo mining time based on hashrate
def mmc_solotime(rate=0)

  # initialize variables
  @solotime = 0.0
  rate = rate.to_f

  # gets memorycoin blockchain info
  mmc_blockinfo

  # avoid division by zero
  if (rate != 0)

    # calculates time
    @solotime = (@blckdiff.to_f * (2 ** 32)) / rate
  end

end # end mmc_solotime

# update bter api
def update_bter_json
  if @toogle.nil?
    @toogle = true
  end
  begin
    t = Timeout.timeout(5) do
      if @cache_bter_json.nil?
        @mmc_btc = JSON.parse(open('https://bter.com/api/1/ticker/mmc_btc').read.gsub(/\'/,'"'))
        @pts_btc = JSON.parse(open('https://bter.com/api/1/ticker/pts_btc').read.gsub(/\'/,'"'))
        @cache_bter_json = Time.now.to_i
      else
        if @cache_bter_json < (Time.now.to_i - 300)
          @mmc_btc = JSON.parse(open('https://bter.com/api/1/ticker/mmc_btc').read.gsub(/\'/,'"'))
          @pts_btc = JSON.parse(open('https://bter.com/api/1/ticker/pts_btc').read.gsub(/\'/,'"'))
          @cache_bter_json = Time.now.to_i
        end
      end
    end
  rescue Timeout::Error
    @status = "connection timeout"
    @mmc_btc = nil
    @pts_btc = nil
    @cache_bter_json = nil
  end
end

# update btc-e api
def update_btce_json
  begin
    t = Timeout.timeout(5) do
      if @cache_btce_json.nil?
        @ltc_btc = JSON.parse(open('https://btc-e.com/api/2/ltc_btc/ticker').read)
        @eur_usd = JSON.parse(open('https://btc-e.com/api/2/eur_usd/ticker').read)
        @cache_btce_json = Time.now.to_i
      else
        if @cache_btce_json < (Time.now.to_i - 300)
          @ltc_btc = JSON.parse(open('https://btc-e.com/api/2/ltc_btc/ticker').read)
          @eur_usd = JSON.parse(open('https://btc-e.com/api/2/eur_usd/ticker').read)
          @cache_btce_json = Time.now.to_i
        end
      end
    end
  rescue Timeout::Error
    @status = "connection timeout"
    @ltc_btc = nil
    @eur_usd = nil
    @cache_btce_json = nil
  end
end

# update bitstamp api
def update_bitstamp_json
  begin
    t = Timeout.timeout(5) do
      if @cache_bitstamp_json.nil?
        @btc_usd = JSON.parse(open('https://www.bitstamp.net/api/ticker').read)
        @cache_bitstamp_json = Time.now.to_i
      else
        if @cache_bitstamp_json < (Time.now.to_i - 300)
          @btc_usd = JSON.parse(open('https://www.bitstamp.net/api/ticker').read)
          @cache_bitstamp_json = Time.now.to_i
        end
      end
    end
  rescue Timeout::Error
    @status = "connection timeout"
    @btc_usd = nil
    @cache_bitstamp_json = nil
  end
end

# displays plugin help commands
plugin.handle(/^help$/i) do |data|
  if @mmc_rooms.include?(data[:room].name)
    next data[:room].say "Memorycoin Statistics: .mmc .diff .solo .ticker .conv .vote .info"
  end
end

# displays memorycoin network block statistics
plugin.handle(/^mmc$/i) do |data|
  #if @mmc_rooms.include?(data[:room].name)
    mmc_blockinfo
    @reward = @reward.round(3)
    @minted = @minted.round(3)
    next data[:room].say "Memorycoin Network Block: #{@blckhigh.to_i}, Difficulty: #{@blckdiff.gsub(/\n/,'')}, Reward: #{@reward}, Minted: #{@minted}."
  #end
end

# displays memorycoin network difficulty statistics
plugin.handle(/^diff$/i) do |data|
  if @mmc_rooms.include?(data[:room].name)
    mmc_blockinfo
    blcktime = @blocktime.to_f
    blcktstr = 'seconds'
    if blcktime > 86400 * 365.2424
      blcktime /= 86400 * 365.2424
      blcktstr = 'years'
    elsif blcktime > 86400 * 30
      blcktime /= 86400 * 30
      blcktstr = 'months'
    elsif blcktime > 86400 * 7
      blcktime /= 86400 * 7
      blcktstr = 'weeks'
    elsif blcktime > 86400
      blcktime /= 86400
      blcktstr = 'days'
    elsif blcktime > 3600
      blcktime /= 3600
      blcktstr = 'hours'
    elsif blcktime > 120
      blcktime /= 60
      blcktstr = 'minutes'
    end
    hshrate = @hashrate.to_f
    hashstr = ''
    if hshrate > 1000000000000
      hshrate /= 1000000000000.0
      hashstr = 'T'
    elsif hshrate > 1000000000
      hshrate /= 1000000000.0
      hashstr = 'G'
    elsif hshrate > 1000000
      hshrate /= 1000000.0
      hashstr = 'M'
    elsif hshrate > 1000
      hshrate /= 1000.0
      hashstr = 'k'
    end
    blcktime = blcktime.round(3)
    hshrate = hshrate.round(3)
    next data[:room].say "Memorycoin Difficulty: #{@blckdiff.gsub(/\n/,'')}, Current blocktime: #{blcktime} #{blcktstr}, Network hashrate: #{hshrate} #{hashstr}H/min."
  end
end

# calculates solo mining time based on user input
plugin.handle(/^solo$/i) do |data, args|
  if @mmc_rooms.include?(data[:room].name)
    if args.empty?
      next data[:room].say "Shows expected time to find a block mining solo. Usage: .solo <H/min>."
    else
      rate = args.first.to_f
      mmc_solotime(rate)
      solo = @solotime.to_f
      turn = ((60.0 * 24.0) / solo) * @reward
      sltm = 'minutes'
      if solo > 60 * 24 * 30 * 365.2424
        solo /= 60.0 * 24.0 * 30.0 * 365.2424
        sltm = 'years'
      elsif solo > 60 * 24 * 30
        solo /= 60.0 * 24.0 * 30.0
        sltm = 'months'
      elsif solo > 60 * 24
        solo /= 60.0 * 24.0
        sltm = 'days'
      elsif solo > 60
        solo /= 60.0
        sltm = 'hours'
      end
      solo = solo.round(3)
      turn = turn.round(3)
      next data[:room].say "Time to find a block mining solo: #{solo} #{sltm}, Turnout: #{turn} MMC/day."
    end
  end
end

# displays memorycoin value
plugin.handle(/^ticker$/i) do |data, args|
  if @mmc_rooms.include?(data[:room].name)
    update_bter_json
    if @pts_btc.nil?
      next data[:room].say "Bter API ticker timeout. Try again later."
    else
      update_btce_json
      if @eur_usd.nil?
        next data[:room].say "BTC-e API ticker timeout. Try again later."
      else
        update_bitstamp_json
        if @btc_usd.nil?
          next data[:room].say "Bitstamp API ticker timeout. Try again later."
        else
          mmc_btc = @mmc_btc['last'].to_f
          pts_btc = @pts_btc['last'].to_f
          ltc_btc = @ltc_btc["ticker"]["last"].to_f
          eur_usd = @eur_usd["ticker"]["last"].to_f
          btc_usd = @btc_usd["last"].to_f
          if args.empty?
            args[0] = "btc"
          end
          mmc_usd = (mmc_btc * btc_usd).round(2)
          mmc_ltc = (mmc_btc / ltc_btc).round(5)
          mmc_pts = (mmc_btc / pts_btc).round(5)
          ltc_usd = (ltc_btc * btc_usd).round(2)
          pts_usd = (pts_btc * btc_usd).round(2)
          mmc_eur = ((mmc_btc * btc_usd) / eur_usd).round(2)
          usd_eur = (1 / eur_usd).round(2)
          eur_usd = eur_usd.round(2)
          mmc_btc = mmc_btc.round(5)
          btc_usd = btc_usd.round(2)
          if args[0].downcase.eql? "btc"
            next data[:room].say "Ticker BTC: 1 MMC = #{mmc_btc} BTC = #{mmc_usd} USD. 1 BTC = #{btc_usd} USD. Source: Bter (MMC/BTC), Bitstamp (BTC/USD)."
          elsif args[0].downcase.eql? "ltc"
            next data[:room].say "Ticker LTC: 1 MMC = #{mmc_ltc} LTC = #{mmc_usd} USD. 1 LTC = #{ltc_usd} USD. Source: Bter (MMC/BTC), BTC-e (LTC/BTC), Bitstamp (BTC/USD)."
          elsif args[0].downcase.eql? "pts"
            next data[:room].say "Ticker PTS: 1 MMC = #{mmc_pts} PTS = #{mmc_usd} USD. 1 PTS = #{pts_usd} USD. Source: Bter (MMC/BTC, PTS/BTC), Bitstamp (BTC/USD)."
          elsif args[0].downcase.eql? "eur"
            next data[:room].say "Ticker EUR: 1 MMC = #{mmc_eur} EUR = #{mmc_usd} USD. 1 EUR = #{eur_usd} USD. Source: Bter (MMC/BTC), BTC-e (EUR/USD), Bitstamp (BTC/USD)."
          elsif args[0].downcase.eql? "usd"
            next data[:room].say "Ticker USD: 1 MMC = #{mmc_usd} USD = #{mmc_eur} EUR. 1 USD = #{usd_eur} EUR. Source: Bter (MMC/BTC), BTC-e (EUR/USD), Bitstamp (BTC/USD)."
          else
            next data[:room].say "Usage: .ticker <usd|eur|btc|ltc|pts>."
          end
        end
      end
    end
  end
end

# converts any mmc amount
plugin.handle(/^conv$/i) do |data, args|
  if @mmc_rooms.include?(data[:room].name)
    update_bter_json
    if @pts_btc.nil?
      next data[:room].say "Bter API ticker timeout. Try again later."
    else
      update_btce_json
      if @eur_usd.nil?
        next data[:room].say "BTC-e API ticker timeout. Try again later."
      else
        update_bitstamp_json
        if @btc_usd.nil?
          next data[:room].say "Bitstamp API ticker timeout. Try again later."
        else
          mmc_btc = @mmc_btc['last'].to_f
          pts_btc = @pts_btc['last'].to_f
          ltc_btc = @ltc_btc["ticker"]["last"].to_f
          eur_usd = @eur_usd["ticker"]["last"].to_f
          btc_usd = @btc_usd["last"].to_f
          if args.empty?
            next data[:room].say "Converts any MMC amount in other currencies. Usage: .conv <mmc>."
          else
            mmc = args[0].to_f
            mmc_usd = (mmc * mmc_btc * btc_usd).round(2)
            mmc_ltc = ((mmc * mmc_btc) / ltc_btc).round(5)
            mmc_pts = ((mmc * mmc_btc) / pts_btc).round(5)
            mmc_eur = ((mmc * mmc_btc * btc_usd) / eur_usd).round(2)
            mmc_btc = mmc * mmc_btc
            mmc_btc = mmc_btc.round(5)
            mmc = mmc.round(5)
            next data[:room].say "Converter: #{mmc} MMC = #{mmc_usd} USD = #{mmc_eur} EUR = #{mmc_btc} BTC = #{mmc_ltc} LTC = #{mmc_pts} PTS. Source: Bter (MMC/BTC, PTS/BTC), BTC-e (LTC/BTC, EUR/USD), Bitstamp (BTC/USD)."
          end
        end
      end
    end
  end
end

# displays elected candidates
plugin.handle(/^vote$/i) do |data, args|
  if @mmc_rooms.include?(data[:room].name)
    mmc_voteinfo
    if args.empty?
      next data[:room].say "Shows elected candidates. Usage: .vote <ceo|cto|cno|cmo|cso|cha>."
    else
      if @votes.nil?
        next data[:room].say "Data source currently down. This can be fixed by adding votes information to memorycoin deamon."
      else
        success = false
        voted = @votes['block']['log'].split("\n")
        voted.each do |line|
          if line.start_with?('Candidate Elected: MVTE')
            if line.include?(args[0]) and not success
              success = true
              next data[:room].say line
            end
          end
        end
        if not success
          next data[:room].say "Shows elected candidates. Usage: .vote <ceo|cto|cno|cmo|cso|cha>."
        end
      end
    end
  end
end

# displays generic bot and plugin information
plugin.handle(/^info$/i) do |data|
  if @mmc_rooms.include?(data[:room].name)
    data[:room].say "Sternburg is a ruby bot instance of fantasy-irc gem by v2px: https://rubygems.org/gems/fantasy-irc | Plugins for Memorycoin statistics written by don-Schoe."
    next data[:room].say "MMC donations for the bot accepted: M7x1L1bFbspnvFwnZkuQUy6De2xiQfst2u, type .help for usage instructoins. Join ##MMC-Spam for excessive usage."
  end
end

# add plugin to bot instance
$bot.plugins.add(plugin)
