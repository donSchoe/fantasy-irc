#!/usr/bin/env ruby

require 'net/http'
require 'open-uri'
require 'timeout'
require 'json'

# creates a new fantasy-irc plugin
plugin = Plugin.new "protoshares"

# only talk in these rooms
@pts_rooms = ['#protoshares', '#bitsharestalk', '#beeeeer.org', '##pts-spam']

##### POINT THIS TO YOUR PROTOSHARES DAEMON #####
@pts_path = '/path/to/protosharesd'

# gets protoshares blockchain info
def pts_blockinfo

  # number of latest block
	@blckhigh = `#{@pts_path} getblockcount`

  # hash of latest block
  blckhash = `#{@pts_path} getblockhash #{@blckhigh}`

  # complete json of latest block
  blckinfo = `#{@pts_path} getblock #{blckhash}`

  # difficulty of latest block
  @blckdiff = `#{@pts_path} getdifficulty`

  # number of 30th latest block
  rcnthigh = @blckhigh.to_i - 30

  # hash of 30th latest block
  rcnthash = `#{@pts_path} getblockhash #{rcnthigh}`

  # complete json of 30th latest block
  rcntinfo = `#{@pts_path} getblock #{rcnthash}`

  # number of last diff change block
  @chnghigh = ((((@blckhigh.to_f / 4032.0) - 0.5).round) * 4032.0).to_i

  # hash of last diff change block
  chnghash = `#{@pts_path} getblockhash #{@chnghigh}`

  # complete json of last diff change  block
  chnginfo = `#{@pts_path} getblock #{chnghash}`

  # timestamp of latest block
  @blcktime = JSON.parse(blckinfo)['time'].to_i

  # timestamp of 30th latest block
  rcnttime = JSON.parse(rcntinfo)['time'].to_i

  # timestamp of last diff change block
  @chngtime = JSON.parse(chnginfo)['time'].to_i

  # average blocktime of 30 last blocks in seconds
  @blocktime = (@blcktime.to_f - rcnttime.to_f) / 30.0

  # current hashrate in hashs per minute ### @TODO collisions per minute
  @hashrate = ((2 ** 32) * @blckdiff.to_f) / (@blocktime.to_f / 60.0)

  # calculates current block reward and total minted coins
  i = 0
  currweek = ((@blckhigh.to_f / 2016.0) - 0.5).round
  @reward = 50.0
  @minted = 0.0
  while i < currweek do
    @minted += @reward * 2016.0
    @reward *= 0.95
    i += 1
  end
  @minted += (@blckhigh.to_f - (currweek * 2016.0)) * @reward

end # end pts_blockinfo

# calculates solo mining time based on hashrate
def pts_solotime(rate=0) ### @TODO collisions per minute

  # initialize variables
  @solotime = 0.0
  rate = rate.to_f

  # gets protoshares blockchain info
  pts_blockinfo

  # avoid division by zero
  if (rate != 0)

    # calculates time
    @solotime = (@blckdiff.to_f * (2 ** 32)) / rate
  end

end # end pts_solotime

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
  if @pts_rooms.include?(data[:room].name)
    next data[:room].say "Protoshares Statistics: .pts .diff .solo .ticker .conv .info"
  end
end

# displays protoshares network block statistics
plugin.handle(/^pts$/i) do |data|
  #if @pts_rooms.include?(data[:room].name)
    pts_blockinfo
    @reward = @reward.round(3)
    @minted = @minted.round(3)
    next data[:room].say "Protoshares Network Block: #{@blckhigh.to_i}, Difficulty: #{@blckdiff.gsub(/\n/,'')}, Reward: #{@reward}, Minted: #{@minted}."
  #end
end

# displays protoshares network difficulty statistics
plugin.handle(/^diff$/i) do |data|
  if @pts_rooms.include?(data[:room].name)
    pts_blockinfo
    blcktime = @blocktime.to_f
    chngblck = ((@blckhigh.to_f / 4032.0) + 0.5).round
    chngblck *= 4032.0
    chngblck -= @blckhigh.to_i
    chngtime = chngblck * blcktime
    chngtmstr = 'seconds'
    if chngtime > 86400 * 365
      chngtime /= 86400 * 365.2424
      chngtmstr = 'years'
    elsif chngtime > 86400 * 30
      chngtime /= 86400 * 30
      chngtmstr = 'months'
    elsif chngtime > 86400 * 7
      chngtime /= 86400 * 7
      chngtmstr = 'weeks'
    elsif chngtime > 86400
      chngtime /= 86400
      chngtmstr = 'days'
    elsif chngtime > 3600
      chngtime /= 3600
      chngtmstr = 'hours'
    elsif chngtime > 120
      chngtime /= 60
      chngtmstr = 'minutes'
    end
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
    blckdif = @blckhigh.to_f - @chnghigh.to_f
    timedif = @blcktime.to_f - @chngtime.to_f
    nexdifp = 300.0 / (timedif / blckdif)
    nexdiff = nexdifp * @blckdiff.to_f
    nexdifp = nexdifp * 100.0 - 100.0
    nexdifp = nexdifp.round(2)
    if nexdifp > 0
      nexdifp = '+' + nexdifp.to_s + '%'
    else
      nexdifp = nexdifp.to_s + '%'
    end
    nexdiff = nexdiff.round(8)
    chngtime = chngtime.round(2)
    blcktime = blcktime.round(3)
    hshrate = hshrate.round(3)
    chngblck = chngblck.to_i.to_s
    #next data[:room].say "Protoshares Difficulty: #{@blckdiff.gsub(/\n/,'')}, current blocktime: #{blcktime} #{blcktstr}, next diff #{nexdiff} (#{nexdifp}) in #{chngblck} blocks (#{chngtime} #{chngtmstr}), Network hashrate: #{hshrate} #{hashstr}H/min."
    next data[:room].say "Protoshares Difficulty: #{@blckdiff.gsub(/\n/,'')}, current blocktime: #{blcktime} #{blcktstr}, next diff #{nexdiff} (#{nexdifp}) in #{chngblck} blocks (#{chngtime} #{chngtmstr}), Network hashrate: #{hshrate} #{hashstr}H/min. Please help converting this to <C/min> - https://bitsharestalk.org/index.php?topic=1737.0 - Thanks!"
  end
end

# calculates solo mining time based on user input
plugin.handle(/^solo$/i) do |data, args|
  if @pts_rooms.include?(data[:room].name)
    if args.empty?
      next data[:room].say "Shows expected time to find a block mining solo. Usage: .solo <H/min>. Please help converting this to <C/min> - https://bitsharestalk.org/index.php?topic=1737.0 - Thanks!"
    else
      rate = args.first.to_f
      pts_solotime(rate)
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
      #next data[:room].say "Time to find a block mining solo: #{solo} #{sltm}, Turnout: #{turn} PTS/day."
      next data[:room].say "Time to find a block mining solo: #{solo} #{sltm}, Turnout: #{turn} PTS/day. Please help converting this to <C/min> - https://bitsharestalk.org/index.php?topic=1737.0 - Thanks!"
    end
  end
end

# displays protoshares value
plugin.handle(/^ticker$/i) do |data, args|
  if @pts_rooms.include?(data[:room].name)
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
          pts_usd = (pts_btc * btc_usd).round(2)
          pts_ltc = (pts_btc / ltc_btc).round(5)
          pts_mmc = (pts_btc / mmc_btc).round(5)
          ltc_usd = (ltc_btc * btc_usd).round(2)
          pts_eur = ((pts_btc * btc_usd) / eur_usd).round(2)
          usd_eur = (1 / eur_usd).round(2)
          eur_usd = eur_usd.round(2)
          pts_btc = pts_btc.round(5)
          btc_usd = btc_usd.round(2)
          if args[0].downcase.eql? "btc"
            next data[:room].say "Ticker BTC: 1 PTS = #{pts_btc} BTC = #{pts_usd} USD. 1 BTC = #{btc_usd} USD. Source: Bter (PTS/BTC), Bitstamp (BTC/USD)."
          elsif args[0].downcase.eql? "ltc"
            next data[:room].say "Ticker LTC: 1 PTS = #{pts_ltc} LTC = #{pts_usd} USD. 1 LTC = #{ltc_usd} USD. Source: Bter (PTS/BTC), BTC-e (LTC/BTC), Bitstamp (BTC/USD)."
          elsif args[0].downcase.eql? "mmc"
            next data[:room].say "Ticker MMC: 1 PTS = #{pts_mmc} MMC = #{pts_usd} USD. 1 MMC = #{mmc_usd} USD. Source: Bter (MMC/BTC, PTS/BTC), Bitstamp (BTC/USD)."
          elsif args[0].downcase.eql? "eur"
            next data[:room].say "Ticker EUR: 1 PTS = #{pts_eur} EUR = #{pts_usd} USD. 1 EUR = #{eur_usd} USD. Source: Bter (PTS/BTC), BTC-e (EUR/USD), Bitstamp (BTC/USD)."
          elsif args[0].downcase.eql? "usd"
            next data[:room].say "Ticker USD: 1 PTS = #{pts_usd} USD = #{pts_eur} EUR. 1 USD = #{usd_eur} EUR. Source: Bter (PTS/BTC), BTC-e (EUR/USD), Bitstamp (BTC/USD)."
          else
            next data[:room].say "Usage: .ticker <usd|eur|btc|ltc|mmc>."
          end
        end
      end
    end
  end
end

# converts any pts amount
plugin.handle(/^conv$/i) do |data, args|
  if @pts_rooms.include?(data[:room].name)
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
          btc_usd = @btc_usd["last"].to_f
          eur_usd = @eur_usd["ticker"]["last"].to_f
          if args.empty?
            next data[:room].say "Converts any PTS amount in other currencies. Usage: .conv <pts>."
          else
            pts = args[0].to_f
            pts_usd = (pts * pts_btc * btc_usd).round(2)
            pts_ltc = ((pts * pts_btc) / ltc_btc).round(5)
            pts_mmc = ((pts * pts_btc) / mmc_btc).round(5)
            pts_eur = ((pts * pts_btc * btc_usd) / eur_usd).round(2)
            pts_btc = (pts * pts_btc).round(5)
            pts = pts.round(5)
            next data[:room].say "Converter: #{pts} PTS = #{pts_usd} USD = #{pts_eur} EUR = #{pts_btc} BTC = #{pts_ltc} LTC = #{pts_mmc} MMC. Source: Bter (MMC/BTC, PTS/BTC), BTC-e (LTC/BTC, EUR/USD), Bitstamp (BTC/USD)."
          end
        end
      end
    end
  end
end

# displays generic bot and plugin information
plugin.handle(/^info$/i) do |data|
  if @pts_rooms.include?(data[:room].name)
    data[:room].say "Sternburg is a ruby bot instance of fantasy-irc gem by v2px: https://rubygems.org/gems/fantasy-irc | Plugins for Protoshare statistics written by don-Schoe."
    next data[:room].say "PTS dontations accepted: PcDLYukq5RtKyRCeC1Gv5VhAJh88ykzfka, type .help for usage instructoins. Join ##PTS-Spam for excessive usage."
  end
end

# add plugin to bot instance
$bot.plugins.add(plugin)
