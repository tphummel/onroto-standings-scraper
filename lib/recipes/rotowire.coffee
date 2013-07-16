request = require "request"
$       = require "jquery"
_       = require "underscore"
moment  = require "moment"

creds   = (require __dirname+"/../../config/creds").rotowire

stats = [
  {long: "Batting Average", short: "Avg", type: "float"}
  {long: "Home Runs (Batter)", short: "HR", type: "int"}
  {long: "RBI", short: "RBI", type: "int"}
  {long: "Runs (Batter)", short: "R", type: "int"}
  {long: "Stolen Bases", short: "SB", type: "int"}
  {long: "ERA", short: "ERA", type: "float"}
  {long: "Saves", short: "S", type: "int"}
  {long: "Strikeouts", short: "K", type: "int"}
  {long: "WHIP", short: "WHIP", type: "float"}
  {long: "Wins", short: "W", type: "int"}
]

getThroughDate = (lines) ->
  date = null

  dateRegexp = /[0-9]{1,2}\/[0-9]{1,2}\/[0-9]{4}/
  arrMatch = lines[0].match dateRegexp

  if arrMatch[0]
    date = (moment arrMatch[0]).format "YYYY-MM-DD"

  return date

getSeason = (date) ->
  return (moment date).format "YYYY"

doOverall = (csvTable, byTeam) ->
  headers = csvTable[0]
  arrHeaders = (headers.split ",").map (field) -> field.replace /\s+/, ""
  arrHeaders = arrHeaders.slice 0, -1

  csvTeams = csvTable.slice 1

  for line, j in csvTeams
    rank = j+1
    fields = line.split ","
    teamName = fields[0]
    byTeam[teamName] = {}

    fields = fields.slice 1
    statHeaders = arrHeaders.slice 1

    for header, i in statHeaders
      byTeam[teamName][header] = {}

      trimmedStat = fields[i].replace /\s+/, ""
      floatStat = parseFloat trimmedStat
      byTeam[teamName][header].points = floatStat 

doStats = (statGroups, byTeam) ->
  for group in statGroups
    statName = group[0]
    statDetail = _.find stats, (cat) -> cat.long is statName
    headers = group[1].split ","

    teamLines = group.slice 2
    for line in teamLines
      fields = line.split ","
      team = fields[0]
      stat = fields[1]

      if statDetail.type is "float"
        stat = parseFloat stat
      else if statDetail.type is "int"
        stat = parseInt stat, 10

      byTeam[team][statDetail.short].stat = stat

doRanks = (byTeam) ->
  prevRank = null
  rank = 0
  count = 0
  prevPoints = null
  for team, statObjs of byTeam
    rank += 1
    count += 1
    points = statObjs.Total.points
    if points is prevPoints
      statObjs.Total.rank = prevRank
    else
      statObjs.Total.rank = rank
    prevRank = statObjs.Total.rank
    prevPoints = points

groupLines = (lines) ->
  statGroups = []
  for line, i in lines
    groupIx = Math.floor (i / 14)
    statGroups[groupIx] ?= []
    statGroups[groupIx].push line

  if statGroups[statGroups.length-1][0] isnt 'Wins'
    statGroups = statGroups.slice 0, -1

  statGroups

createDocs = (throughDate, season, league, byTeam) ->
  docs = []
  docs = _.map byTeam, (statObjs, team) ->

    doc = 
      thru_date: throughDate
      team: team
      league: league
      season: season
      rank: statObjs.Total.rank
      points: statObjs.Total.points
      created_at: new Date()
      stats: {}
    
    for stat, detail of statObjs
      unless stat is "Total"
        doc.stats[stat] = detail

    doc

  return docs

onStandings = (e, r, body) ->
  console.log "e: ", e if e?
  
  longToShort = {}
  for cat in stats
    longToShort[cat.long] = cat.short

  byTeam = {}

  content = $(body).find(".content").text()
  
  lines = content.split "\n"
  lines = lines.map (line) -> line.replace /(\r|\t)/gm, ""
  lines = lines.filter (line) -> line.length > 0
  
  throughDate = getThroughDate lines
  season = getSeason throughDate
  league = "rotowire_#{creds.leagueId}"

  csvOverall = lines.slice 1,14
  doOverall csvOverall, byTeam

  statLines = lines.slice 14
  statGroups = groupLines statLines

  doStats statGroups, byTeam

  doRanks byTeam

  docs = createDocs throughDate, season, league, byTeam

getStats = (cb) ->
  opts = 
    uri: "http://www.rotowire.com/users/signon.htm"
    followRedirects: true
    followAllRedirects: true
    form: 
      p1: creds.pass
      UserName: creds.user
      submit: "Login"
      link: "/mlbcommish13/standingstext.htm?leagueid=#{creds.leagueId}"
      x: 31
      y: 16

  request.post opts, cb

module.exports = 
  getStats: getStats
  onStandings: onStandings